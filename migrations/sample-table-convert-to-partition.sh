#!/bin/bash

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <file> [partition_column] [partition_type]"
    echo "Defaults: partition_column=type_uu, partition_type=LIST"
    exit 1
fi

FILE=$1
PART_COL=${2:-type_uu}
PART_TYPE=${3:-LIST}
BACKUP="${FILE}.backup-$(date +%Y%m%d-%H%M%S)"

cp "$FILE" "$BACKUP"
echo "✓ Created backup: $BACKUP"

# Get table name
TABLE=$(grep -oP 'CREATE TABLE private\.\K(stk_\w+)(?= \()' "$FILE" | grep -v "_type" | head -1)
echo "Converting $TABLE to partitioned..."

# 1. Insert primary table
sed -i "/----partition: insert_primary/a\\
-- primary table\\
-- this table is needed to support both (1) partitioning and (2) being able to maintain a single primary key and single foreign key references\\
CREATE TABLE private.${TABLE} (\\
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid()\\
);\\
" "$FILE"

# 2. Rename table
sed -i "s/CREATE TABLE private\.${TABLE} ( ----partition: rename_table/-- partition table\nCREATE TABLE private.${TABLE}_part (/" "$FILE"

# 3. Change uu column
sed -i "s/  uu UUID PRIMARY KEY DEFAULT gen_random_uuid(), ----partition: change_uu/  uu UUID NOT NULL REFERENCES private.${TABLE}(uu),/" "$FILE"

# 4. Remove UNIQUE from search_key (only in main table, not type table)
sed -i "/CREATE TABLE private\.${TABLE}_part/,/^);/s/search_key TEXT NOT NULL UNIQUE/search_key TEXT NOT NULL/" "$FILE"

# 5. Add primary key
sed -i "s/  description TEXT ----partition: add_pk/  description TEXT,\n  primary key (uu, ${PART_COL})/" "$FILE"

# 6. Add partition by
sed -i "s/); ----partition: add_partition_by/) PARTITION BY ${PART_TYPE} (${PART_COL});/" "$FILE"

# 7. Update comment
sed -i "s/COMMENT ON TABLE private\.${TABLE} IS/COMMENT ON TABLE private.${TABLE}_part IS/" "$FILE"

# 8. Insert default partition
sed -i "/----partition: insert_default/a\\
\\
-- first partitioned table to hold the actual data -- others can be created later\\
CREATE TABLE private.${TABLE}_part_default PARTITION OF private.${TABLE}_part DEFAULT;" "$FILE"

# 9. Replace view
sed -i "s/CREATE VIEW api\.${TABLE} AS SELECT \* FROM private\.${TABLE};/CREATE VIEW api.${TABLE} AS\\
SELECT stkp.* -- note all values reside in and are pulled from the ${TABLE}_part table (not the primary ${TABLE} table)\\
FROM private.${TABLE} stk\\
JOIN private.${TABLE}_part stkp on stk.uu = stkp.uu\\
;/" "$FILE"

# 10. Insert triggers
sed -i "/----partition: insert_triggers/a\\
\\
CREATE TRIGGER t00010_generic_partition_insert\\
    INSTEAD OF INSERT ON api.${TABLE}\\
    FOR EACH ROW\\
    EXECUTE FUNCTION private.t00010_generic_partition_insert();\\
\\
CREATE TRIGGER t00020_generic_partition_update\\
    INSTEAD OF UPDATE ON api.${TABLE}\\
    FOR EACH ROW\\
    EXECUTE FUNCTION private.t00020_generic_partition_update();\\
\\
CREATE TRIGGER t00030_generic_partition_delete\\
    INSTEAD OF DELETE ON api.${TABLE}\\
    FOR EACH ROW\\
    EXECUTE FUNCTION private.t00030_generic_partition_delete();" "$FILE"

# 11. Clean up markers
sed -i '/^----partition:/d' "$FILE"
sed -i 's/ ----partition:[^ ]*//g' "$FILE"

echo "✓ Conversion complete!"