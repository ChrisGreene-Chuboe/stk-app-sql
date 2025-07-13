#!/bin/bash
# convert-to-partition-incremental.sh - Incrementally convert normal table to partitioned
# Usage: ./convert-to-partition-incremental.sh <file> <partition_column> <partition_type>
# Example: ./convert-to-partition-incremental.sh migration.sql type_uu LIST
# Example: ./convert-to-partition-incremental.sh migration.sql created RANGE
# Example: ./convert-to-partition-incremental.sh migration.sql stk_entity_uu LIST

if [ $# -ne 3 ]; then
    echo "Usage: $0 <migration-file.sql> <partition_column> <partition_type>"
    echo "Partition types: LIST, RANGE, HASH"
    echo "Common columns: type_uu, stk_entity_uu, created"
    exit 1
fi

FILE=$1
PARTITION_COL=$2
PARTITION_TYPE=$3
BACKUP="${FILE}.backup-$(date +%Y%m%d-%H%M%S)"

# Validate partition type
if [[ ! "$PARTITION_TYPE" =~ ^(LIST|RANGE|HASH)$ ]]; then
    echo "Error: Partition type must be LIST, RANGE, or HASH"
    exit 1
fi

# Extract table name from file
TABLE_NAME=$(grep -oP 'CREATE TABLE private\.\K(stk_\w+)(?= \()' "$FILE" | head -1)
if [ -z "$TABLE_NAME" ]; then
    echo "Error: Could not find table name in file"
    exit 1
fi

echo "Converting $TABLE_NAME to partitioned table..."
echo "Partition column: $PARTITION_COL"
echo "Partition type: $PARTITION_TYPE"

# Create backup
cp "$FILE" "$BACKUP"
echo "✓ Created backup: $BACKUP"

# Step 1: Add primary table
echo "Step 1: Adding primary table..."
sed -i "/----PARTITION_GUIDE: Step 1/a\\
-- primary table\\
-- this table is needed to support both (1) partitioning and (2) being able to maintain a single primary key and single foreign key references\\
CREATE TABLE private.${TABLE_NAME} (\\
  uu UUID PRIMARY KEY DEFAULT gen_random_uuid()\\
);\\
" "$FILE"

# Step 2: Rename main table to _part
echo "Step 2: Renaming table to ${TABLE_NAME}_part..."
sed -i "s/CREATE TABLE private\.${TABLE_NAME} (/-- partition table\nCREATE TABLE private.${TABLE_NAME}_part (/" "$FILE"

# Step 3: Change uu column
echo "Step 3: Updating uu column..."
sed -i "s/uu UUID PRIMARY KEY DEFAULT gen_random_uuid(),/uu UUID NOT NULL REFERENCES private.${TABLE_NAME}(uu),/" "$FILE"

# Step 4: Remove UNIQUE from search_key
echo "Step 4: Removing UNIQUE constraint from search_key..."
sed -i "s/search_key TEXT NOT NULL UNIQUE/search_key TEXT NOT NULL/" "$FILE"

# Step 5: Add composite primary key
echo "Step 5: Adding composite primary key..."
sed -i "s/description TEXT$/description TEXT,\n  primary key (uu, ${PARTITION_COL})/" "$FILE"

# Step 6: Add partition clause
echo "Step 6: Adding partition clause..."
sed -i "s/^);$/\) PARTITION BY ${PARTITION_TYPE} (${PARTITION_COL});/" "$FILE"

# Step 7: Update comment and add default partition
echo "Step 7: Updating table comment and adding default partition..."
sed -i "s/COMMENT ON TABLE private\.${TABLE_NAME} IS/COMMENT ON TABLE private.${TABLE_NAME}_part IS/" "$FILE"

# Add default partition based on type
if [ "$PARTITION_TYPE" = "LIST" ]; then
    sed -i "/COMMENT ON TABLE private\.${TABLE_NAME}_part IS/a\\
\\
-- first partitioned table to hold the actual data -- others can be created later\\
CREATE TABLE private.${TABLE_NAME}_part_default PARTITION OF private.${TABLE_NAME}_part DEFAULT;" "$FILE"
elif [ "$PARTITION_TYPE" = "RANGE" ]; then
    sed -i "/COMMENT ON TABLE private\.${TABLE_NAME}_part IS/a\\
\\
-- example range partitions - adjust as needed\\
-- CREATE TABLE private.${TABLE_NAME}_part_2024 PARTITION OF private.${TABLE_NAME}_part FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');\\
-- CREATE TABLE private.${TABLE_NAME}_part_default PARTITION OF private.${TABLE_NAME}_part DEFAULT;" "$FILE"
else # HASH
    sed -i "/COMMENT ON TABLE private\.${TABLE_NAME}_part IS/a\\
\\
-- hash partitions for even distribution\\
CREATE TABLE private.${TABLE_NAME}_part_0 PARTITION OF private.${TABLE_NAME}_part FOR VALUES WITH (modulus 4, remainder 0);\\
CREATE TABLE private.${TABLE_NAME}_part_1 PARTITION OF private.${TABLE_NAME}_part FOR VALUES WITH (modulus 4, remainder 1);\\
CREATE TABLE private.${TABLE_NAME}_part_2 PARTITION OF private.${TABLE_NAME}_part FOR VALUES WITH (modulus 4, remainder 2);\\
CREATE TABLE private.${TABLE_NAME}_part_3 PARTITION OF private.${TABLE_NAME}_part FOR VALUES WITH (modulus 4, remainder 3);" "$FILE"
fi

# Step 8: Replace view
echo "Step 8: Updating view to use join..."
sed -i "s/CREATE VIEW api\.${TABLE_NAME} AS SELECT \* FROM private\.${TABLE_NAME};/CREATE VIEW api.${TABLE_NAME} AS\nSELECT stkp.* -- note all values reside in and are pulled from the ${TABLE_NAME}_part table (not the primary ${TABLE_NAME} table)\nFROM private.${TABLE_NAME} stk\nJOIN private.${TABLE_NAME}_part stkp on stk.uu = stkp.uu\n;/" "$FILE"

# Step 9: Add partition triggers
echo "Step 9: Adding partition triggers..."
sed -i "/----PARTITION_GUIDE: Step 9/a\\
\\
CREATE TRIGGER t00010_generic_partition_insert\\
    INSTEAD OF INSERT ON api.${TABLE_NAME}\\
    FOR EACH ROW\\
    EXECUTE FUNCTION private.t00010_generic_partition_insert();\\
\\
CREATE TRIGGER t00020_generic_partition_update\\
    INSTEAD OF UPDATE ON api.${TABLE_NAME}\\
    FOR EACH ROW\\
    EXECUTE FUNCTION private.t00020_generic_partition_update();\\
\\
CREATE TRIGGER t00030_generic_partition_delete\\
    INSTEAD OF DELETE ON api.${TABLE_NAME}\\
    FOR EACH ROW\\
    EXECUTE FUNCTION private.t00030_generic_partition_delete();" "$FILE"

# Clean up guide comments
echo "Step 10: Cleaning up guide comments..."
sed -i '/----PARTITION_GUIDE:/d' "$FILE"
sed -i '/----PARTITION_OPTIONS:/,+5d' "$FILE"

echo "✓ Conversion complete!"
echo ""
echo "Review the changes and test thoroughly before using in production."
echo "Backup saved as: $BACKUP"