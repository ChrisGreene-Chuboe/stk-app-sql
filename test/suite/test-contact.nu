#!/usr/bin/env nu

# Test script for stk_contact module
# Template Version: 2025-01-08

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_sc($random_suffix)"

# Import modules and assert
use ../modules *
use std/assert

# === Testing CRUD operations ===

# print "=== Testing contact overview command ==="
# Note: Module commands are nushell functions, not external commands, so we can't use complete
# Verify command exists and returns non-empty string
let overview_result = contact
assert (($overview_result | str length) > 0) "Overview command should return non-empty text"

# print "=== Testing contact creation ==="
let created = (contact new $"Test contact($test_suffix)")
assert (($created | describe | str starts-with "record")) "Should return a record"
assert ($created.uu | is-not-empty) "Should have UUID"
assert ($created.name | str contains $test_suffix) "Name should contain test suffix"

# print "=== Testing contact list ==="
let list_result = (contact list)
assert ($list_result | where name =~ $test_suffix | is-not-empty) "Should find created contact"

# print "=== Testing contact get ==="
let get_result = ($created.uu | contact get)
assert ($get_result.uu == $created.uu) "Should get correct record"

# print "=== Testing contact revoke ==="
let revoke_result = ($created.uu | contact revoke)
assert ($revoke_result.is_revoked.0 == true) "Should be revoked"

# print "=== Testing contact list --all ==="
let all_list = (contact list --all | where name =~ $test_suffix)
assert ($all_list | where is_revoked == true | is-not-empty) "Should show revoked records"

# === Testing UUID input variations ===

# Create a parent record for UUID tests
let parent = (contact new $"UUID Test Parent($test_suffix)")
let parent_uu = $parent.uu

# print "=== Testing contact get with string UUID ==="
let get_string = ($parent_uu | contact get)
assert ($get_string.uu == $parent_uu) "Should get correct record with string UUID"

# print "=== Testing contact get with record input ==="
let get_record = ($parent | contact get)
assert ($get_record.uu == $parent_uu) "Should get correct record from record input"

# print "=== Testing contact get with table input ==="
let parent_table = (contact list | where name =~ $test_suffix | first 1)
let get_table = ($parent_table | contact get)
assert ($get_table.uu == $parent_uu) "Should get correct record from table input"

# print "=== Testing contact get with --uu parameter ==="
let get_param = (contact get --uu $parent_uu)
assert ($get_param.uu == $parent_uu) "Should get correct record with --uu parameter"

# print "=== Testing contact get with empty table (should fail) ==="
try {
    [] | contact get
    error make {msg: "Empty table should have failed"}
} catch {
    # print "  ✓ Empty table correctly rejected"
}

# print "=== Testing contact get with multi-row table ==="
let multi_table = [$parent, $parent] | flatten
let get_multi = ($multi_table | contact get)
assert ($get_multi.uu == $parent_uu) "Should use first row from multi-row table"

# print "=== Testing contact revoke with string UUID ==="
let revoke_item = (contact new $"Revoke Test($test_suffix)")
let revoke_string = ($revoke_item.uu | contact revoke)
assert ($revoke_string.is_revoked.0 == true) "Should revoke with string UUID"

# print "=== Testing contact revoke with --uu parameter ==="
let revoke_item2 = (contact new $"Revoke Test 2($test_suffix)")
let revoke_param = (contact revoke --uu $revoke_item2.uu)
assert ($revoke_param.is_revoked.0 == true) "Should revoke with --uu parameter"

# print "=== Testing contact revoke with record input ==="
let revoke_item3 = (contact new $"Revoke Test 3($test_suffix)")
let revoke_record = ($revoke_item3 | contact revoke)
assert ($revoke_record.is_revoked.0 == true) "Should revoke from record input"

# print "=== Testing contact revoke with table input ==="
let revoke_item4 = (contact new $"Revoke Test 4($test_suffix)")
# For table input, need to convert record to single-row table
let revoke_table = ([$revoke_item4] | contact revoke)
assert ($revoke_table.is_revoked.0 == true) "Should revoke from table input"

# === Testing type support ===

# print "=== Testing contact types ==="
let types = (contact types)
assert ($types | is-not-empty) "Should have types"
assert ($types | columns | any {|col| $col == "uu"}) "Types should have uu"
assert ($types | columns | any {|col| $col == "search_key"}) "Types should have search_key"

# Use first type for testing
let test_type = ($types | first)

# print "=== Testing contact creation with type ==="
let typed = (contact new $"Typed($test_suffix)" --type-search-key $test_type.search_key)
assert ($typed.type_uu == $test_type.uu) "Should have correct type"

# print "=== Testing contact get shows type ==="
let typed_get = ($typed.uu | contact get)
assert ($typed_get.type_name | is-not-empty) "Should show type name"
assert ($typed_get.type_enum | is-not-empty) "Should show type enum"

# === Testing JSON parameter ===

# print "=== Testing contact creation with JSON ==="
let json_created = (contact new $"JSON Test($test_suffix)" --json '{"test": true, "value": 42}')
assert (($json_created | describe | str starts-with "record")) "Should return a record"

# print "=== Verifying stored JSON ==="
let json_detail = ($json_created.uu | contact get)
assert ($json_detail.record_json.test == true) "Should store JSON test field"
assert ($json_detail.record_json.value == 42) "Should store JSON value field"

# print "=== Testing contact creation without JSON (default) ==="
let no_json = (contact new $"No JSON Test($test_suffix)")
let no_json_detail = ($no_json.uu | contact get)
assert ($no_json_detail.record_json == {}) "Should default to empty object"

# print "=== Testing contact creation with complex JSON ==="
let complex_json = '{"nested": {"deep": {"value": "found"}}, "array": [1, 2, 3]}'
let complex_created = (contact new $"Complex JSON($test_suffix)" --json $complex_json)
let complex_detail = ($complex_created.uu | contact get)
assert ($complex_detail.record_json.nested.deep.value == "found") "Should store nested JSON"
assert (($complex_detail.record_json.array | length) == 3) "Should store JSON arrays"

# === Foreign Key Pipeline Pattern Tests ===

# === Testing foreign key pipeline input ===
# print "=== Testing foreign key pipeline input ===" # COMMENTED OUT - uncomment only for debugging

# Create a foreign record to link
let foreign_record = (bp new $"Test Foreign($test_suffix)")
assert (($foreign_record | columns | any {|col| $col == "uu"})) "Foreign record creation should return UUID"

# Test pipeline input with table (from list/where)
let from_list = (bp list | where name =~ $test_suffix | first | contact new $"From List($test_suffix)")
assert (($from_list | columns | any {|col| $col == "uu"})) "Should create contact from foreign list"

# Verify foreign key was set
let list_detail = ($from_list.uu | contact get)
assert ($list_detail.stk_business_partner_uu == $foreign_record.uu) "Foreign key should match foreign record UUID"
# print "✓ Foreign key pipeline from list works" # COMMENTED OUT

# Test pipeline input with record
let from_record = ($foreign_record | contact new $"From Record($test_suffix)")
assert (($from_record | columns | any {|col| $col == "uu"})) "Should create contact from foreign record"

# Test pipeline input with UUID string
let from_uuid = ($foreign_record.uu | contact new $"From UUID($test_suffix)")
assert (($from_uuid | columns | any {|col| $col == "uu"})) "Should create contact from UUID string"

# Test direct parameter still works
let from_param = (contact new $"From Param($test_suffix)" --business-partner-uu $foreign_record.uu)
assert (($from_param | columns | any {|col| $col == "uu"})) "Should create contact with direct parameter"

# Test pipeline overrides parameter
let override_foreign = (bp new $"Override Foreign($test_suffix)")
let overridden = ($override_foreign | contact new $"Override Test($test_suffix)" --business-partner-uu $foreign_record.uu)
let override_detail = ($overridden.uu | contact get)
assert ($override_detail.stk_business_partner_uu == $override_foreign.uu) "Pipeline should override parameter"

# === Testing invalid foreign key relationships ===
# print "=== Testing invalid foreign key relationships ===" # COMMENTED OUT - uncomment only for debugging

# Create an unrelated record (item has no FK relationship to contact)
let unrelated = (item new $"Unrelated($test_suffix)")
try {
    $unrelated | contact new $"Should Fail($test_suffix)"
    assert false "Should have thrown error for invalid foreign key"
} catch { |err|
    assert (($err.msg | str contains "Cannot link")) "Should show friendly foreign key error"
    assert (($err.msg | str contains "no foreign key relationship")) "Should explain the issue"
}

# Verify all created records
let all_contacts = (contact list | where name =~ $test_suffix)
assert (($all_contacts | length) >= 5) "Should have created at least 5 contact records"
# print $"✓ Created ($all_contacts | length) contact records with foreign keys" # COMMENTED OUT

# === Testing contact list filtering and enrichment ===
# print "=== Testing contact list filtering and enrichment ===" # COMMENTED OUT - uncomment only for debugging

# Create test data for filtering
let filter_bp1 = (bp new $"Filter Corp($test_suffix)")
let filter_bp2 = (bp new $"Filter Inc($test_suffix)")

# Create contacts for each business partner
let filter_contact1_1 = ($filter_bp1 | contact new $"Filter John($test_suffix)")
let filter_contact1_2 = ($filter_bp1 | contact new $"Filter Jane($test_suffix)")
let filter_contact2_1 = ($filter_bp2 | contact new $"Filter Bob($test_suffix)")

# Create a contact without business partner
let filter_orphan = (contact new $"Filter Orphan($test_suffix)")

# Test pipe business partner record to contact list
let filtered_by_record = ($filter_bp1 | contact list)
assert (($filtered_by_record | length) >= 2) "Should find at least 2 contacts for BP1"
assert (($filtered_by_record | all {|c| $c.stk_business_partner_uu == $filter_bp1.uu})) "All contacts should belong to BP1"
assert (($filtered_by_record | any {|c| $c.name == $filter_contact1_1.name})) "Should find Filter John"
assert (($filtered_by_record | any {|c| $c.name == $filter_contact1_2.name})) "Should find Filter Jane"

# Test pipe business partner table to contact list
let filtered_by_table = (bp list | where name == $filter_bp2.name | contact list)
assert (($filtered_by_table | length) >= 1) "Should find at least 1 contact for BP2"
assert (($filtered_by_table | all {|c| $c.stk_business_partner_uu == $filter_bp2.uu})) "All contacts should belong to BP2"
assert (($filtered_by_table | any {|c| $c.name == $filter_contact2_1.name})) "Should find Filter Bob"

# Test contact list without piped input (should return all recent contacts)
let all_recent_contacts = (contact list)
assert (($all_recent_contacts | length) > 0) "Should return some contacts"

# === Testing contacts enrichment command ===
# print "=== Testing contacts enrichment command ===" # COMMENTED OUT - uncomment only for debugging

# Test basic contacts enrichment
let enriched_bps = (bp list | where name =~ $"Filter.*($test_suffix)" | contacts)
assert (($enriched_bps | all {|bp| "contacts" in ($bp | columns)})) "All BPs should have contacts column"

# Find our test BPs in the enriched results
let bp1_enriched = ($enriched_bps | where name == $filter_bp1.name | first)
let bp2_enriched = ($enriched_bps | where name == $filter_bp2.name | first)

assert (($bp1_enriched.contacts | length) >= 2) "BP1 should have at least 2 contacts"
assert (($bp2_enriched.contacts | length) >= 1) "BP2 should have at least 1 contact"

# Test contacts enrichment with specific columns
let enriched_specific = (bp list | where name =~ $"Filter.*($test_suffix)" | contacts name)
let bp1_specific = ($enriched_specific | where name == $filter_bp1.name | first)
assert (("name" in ($bp1_specific.contacts.0 | columns))) "Should have name column"
let first_columns = ($bp1_specific.contacts.0 | columns | first 1)
assert ($first_columns.0 == "name") "Name should be the first column when specifically requested"

# Test contacts enrichment with --detail
let enriched_detail = (bp list | where name =~ $"Filter.*($test_suffix)" | contacts --detail)
let bp1_detail = ($enriched_detail | where name == $filter_bp1.name | first)
assert (("record_json" in ($bp1_detail.contacts.0 | columns))) "Detail should include all columns"

# Test table without foreign key relationship (should get empty contacts)
let items_enriched = (item list | first 3 | contacts)
assert (($items_enriched | all {|item| $item.contacts == []})) "Items should have empty contacts array"

"=== All tests completed successfully ==="