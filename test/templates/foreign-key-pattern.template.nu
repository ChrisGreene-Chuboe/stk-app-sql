# === Foreign Key Pipeline Pattern Tests ===
# Template Version: 2025-01-15
# Use this template for modules that accept foreign table records via pipeline
# Replace: MODULE (your module name), FOREIGN_MODULE (the foreign table module), FK_COLUMN (foreign key column name)

# === Testing foreign key pipeline input ===
# print "=== Testing foreign key pipeline input ===" # COMMENTED OUT - uncomment only for debugging

# Create a foreign record to link
let foreign_record = (FOREIGN_MODULE new $"Test Foreign($test_suffix)")
assert (($foreign_record | columns | any {|col| $col == "uu"})) "Foreign record creation should return UUID"

# Test pipeline input with table (from list/where)
let from_list = (FOREIGN_MODULE list | where name =~ $test_suffix | first | MODULE new $"From List($test_suffix)")
assert (($from_list | columns | any {|col| $col == "uu"})) "Should create MODULE from foreign list"

# Verify foreign key was set
let list_detail = ($from_list.uu | MODULE get)
assert ($list_detail.FK_COLUMN == $foreign_record.uu) "Foreign key should match foreign record UUID"
# print "✓ Foreign key pipeline from list works" # COMMENTED OUT

# Test pipeline input with record
let from_record = ($foreign_record | MODULE new $"From Record($test_suffix)")
assert (($from_record | columns | any {|col| $col == "uu"})) "Should create MODULE from foreign record"

# Test pipeline input with UUID string
let from_uuid = ($foreign_record.uu | MODULE new $"From UUID($test_suffix)")
assert (($from_uuid | columns | any {|col| $col == "uu"})) "Should create MODULE from UUID string"

# Test direct parameter still works
let from_param = (MODULE new $"From Param($test_suffix)" --FK_COLUMN $foreign_record.uu)
assert (($from_param | columns | any {|col| $col == "uu"})) "Should create MODULE with direct parameter"

# Test pipeline overrides parameter
let override_foreign = (FOREIGN_MODULE new $"Override Foreign($test_suffix)")
let overridden = ($override_foreign | MODULE new $"Override Test($test_suffix)" --FK_COLUMN $foreign_record.uu)
let override_detail = ($overridden.uu | MODULE get)
assert ($override_detail.FK_COLUMN == $override_foreign.uu) "Pipeline should override parameter"

# === Testing invalid foreign key relationships ===
# print "=== Testing invalid foreign key relationships ===" # COMMENTED OUT - uncomment only for debugging

# Create an unrelated record (replace UNRELATED_MODULE with a module that has no FK relationship)
# Example: let unrelated = (item new $"Unrelated($test_suffix)")
# try {
#     $unrelated | MODULE new $"Should Fail($test_suffix)"
#     assert false "Should have thrown error for invalid foreign key"
# } catch { |err|
#     assert (($err.msg | str contains "Cannot link")) "Should show friendly foreign key error"
#     assert (($err.msg | str contains "no foreign key relationship")) "Should explain the issue"
# }

# Verify all created records
let all_modules = (MODULE list | where name =~ $test_suffix)
assert (($all_modules | length) >= 5) "Should have created at least 5 MODULE records"
# print $"✓ Created ($all_modules | length) MODULE records with foreign keys" # COMMENTED OUT