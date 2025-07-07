#!/usr/bin/env nu

# Test script for stk_business_partner module
# Created using templates without looking at existing test
# Template Version: 2025-01-04

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_bp($random_suffix)"

# Import modules and assert
use ../modules *
use std/assert

# === Testing CRUD operations ===
# print "=== Testing bp creation ==="
let created = (bp new $"Test bp($test_suffix)")
assert ($created | is-not-empty) "Should create bp"
assert ($created.uu | is-not-empty) "Should have UUID"
assert ($created.name.0 | str contains $test_suffix) "Name should contain test suffix"

# print "=== Testing bp list ==="
let list_result = (bp list)
assert ($list_result | where name =~ $test_suffix | is-not-empty) "Should find created bp"

# print "=== Testing bp get ==="
let get_result = ($created.uu.0 | bp get)
assert ($get_result.uu == $created.uu.0) "Should get correct record"

# print "=== Testing bp revoke ==="
let revoke_result = ($created.uu.0 | bp revoke)
assert ($revoke_result.is_revoked.0 == true) "Should be revoked"

# print "=== Testing bp list --all ==="
let all_list = (bp list --all | where name =~ $test_suffix)
assert ($all_list | where is_revoked == true | is-not-empty) "Should show revoked records"

# === Testing UUID input variations ===
# Create a parent record for UUID tests
let parent = (bp new $"UUID Test Parent($test_suffix)")
let parent_uu = $parent.uu.0

# print "=== Testing bp get with string UUID ==="
let get_string = ($parent_uu | bp get)
assert ($get_string.uu == $parent_uu) "Should get correct record with string UUID"

# print "=== Testing bp get with record input ==="
let get_record = ($parent | first | bp get)
assert ($get_record.uu == $parent_uu) "Should get correct record from record input"

# print "=== Testing bp get with table input ==="
let get_table = ($parent | bp get)
assert ($get_table.uu == $parent_uu) "Should get correct record from table input"

# print "=== Testing bp get with --uu parameter ==="
let get_param = (bp get --uu $parent_uu)
assert ($get_param.uu == $parent_uu) "Should get correct record with --uu parameter"

# print "=== Testing bp get with empty table (should fail) ==="
try {
    [] | bp get
    error make {msg: "Empty table should have failed"}
} catch {
    # print "  ✓ Empty table correctly rejected"
}

# print "=== Testing bp get with multi-row table ==="
let multi_table = [$parent, $parent] | flatten
let get_multi = ($multi_table | bp get)
assert ($get_multi.uu == $parent_uu) "Should use first row from multi-row table"

# print "=== Testing bp revoke with string UUID ==="
let revoke_item = (bp new $"Revoke Test($test_suffix)")
let revoke_string = ($revoke_item.uu.0 | bp revoke)
assert ($revoke_string.is_revoked.0 == true) "Should revoke with string UUID"

# print "=== Testing bp revoke with --uu parameter ==="
let revoke_item2 = (bp new $"Revoke Test 2($test_suffix)")
let revoke_param = (bp revoke --uu $revoke_item2.uu.0)
assert ($revoke_param.is_revoked.0 == true) "Should revoke with --uu parameter"

# print "=== Testing bp revoke with record input ==="
let revoke_item3 = (bp new $"Revoke Test 3($test_suffix)")
let revoke_record = ($revoke_item3 | first | bp revoke)
assert ($revoke_record.is_revoked.0 == true) "Should revoke from record input"

# print "=== Testing bp revoke with table input ==="
let revoke_item4 = (bp new $"Revoke Test 4($test_suffix)")
let revoke_table = ($revoke_item4 | bp revoke)
assert ($revoke_table.is_revoked.0 == true) "Should revoke from table input"

# === Testing type support ===
# print "=== Testing bp types ==="
let types = (bp types)
assert ($types | is-not-empty) "Should have types"
assert ($types | columns | any {|col| $col == "uu"}) "Types should have uu"
assert ($types | columns | any {|col| $col == "search_key"}) "Types should have search_key"

# Use first type for testing
let test_type = ($types | first)

# print "=== Testing bp creation with type ==="
let typed = (bp new $"Typed($test_suffix)" --type-search-key $test_type.search_key)
assert ($typed.type_uu.0 == $test_type.uu) "Should have correct type"

# print "=== Testing bp get shows type ==="
let typed_get = ($typed.uu.0 | bp get)
assert ($typed_get.type_name | is-not-empty) "Should show type name"
assert ($typed_get.type_enum | is-not-empty) "Should show type enum"

# === Testing JSON parameter ===
# print "=== Testing bp creation with JSON ==="
let json_created = (bp new $"JSON Test($test_suffix)" --json '{"test": true, "value": 42}')
assert ($json_created | is-not-empty) "Should create with JSON"

# print "=== Verifying stored JSON ==="
let json_detail = ($json_created.uu.0 | bp get)
assert ($json_detail.record_json.test == true) "Should store JSON test field"
assert ($json_detail.record_json.value == 42) "Should store JSON value field"

# print "=== Testing bp creation without JSON (default) ==="
let no_json = (bp new $"No JSON Test($test_suffix)")
let no_json_detail = ($no_json.uu.0 | bp get)
assert ($no_json_detail.record_json == {}) "Should default to empty object"

# print "=== Testing bp creation with complex JSON ==="
let complex_json = '{"nested": {"deep": {"value": "found"}}, "array": [1, 2, 3]}'
let complex_created = (bp new $"Complex JSON($test_suffix)" --json $complex_json)
let complex_detail = ($complex_created.uu.0 | bp get)
assert ($complex_detail.record_json.nested.deep.value == "found") "Should store nested JSON"
assert (($complex_detail.record_json.array | length) == 3) "Should store JSON arrays"

# === Testing template pattern ===
# print "=== Testing bp template creation ==="
let template = (bp new $"Template($test_suffix)" --template)
assert ($template.is_template.0 == true) "Should create as template"

# print "=== Testing bp regular creation ==="
let regular = (bp new $"Regular($test_suffix)")
assert (($regular.is_template?.0 | default false) == false) "Should not be template"

# print "=== Testing default bp list excludes templates ==="
let default_list = (bp list | where name =~ $test_suffix)
assert ($default_list | where name =~ "Regular" | is-not-empty) "Should show regular"
assert ($default_list | where name =~ "Template" | is-empty) "Should hide templates"

# print "=== Testing bp list --templates ==="
let template_list = (bp list --templates | where name =~ $test_suffix)
assert ($template_list | where name =~ "Template" | is-not-empty) "Should show templates"
assert ($template_list | where name =~ "Regular" | is-empty) "Should hide regular"

# print "=== Testing revoked template not in --templates list ==="
let revoked_template = (bp new $"Revoked Template($test_suffix)" --template)
let revoked = ($revoked_template.uu.0 | bp revoke)
let template_list_after = (bp list --templates | where name =~ $test_suffix)
assert ($template_list_after | where name =~ "Revoked Template" | is-empty) "Should not show revoked templates"

# print "=== Testing bp list --all ==="
let all_list = (bp list --all | where name =~ $test_suffix)
assert ($all_list | where name =~ "Regular" | is-not-empty) "Should show regular"
assert ($all_list | where name =~ "Template" | is-not-empty) "Should show templates"
assert ($all_list | where name =~ "Revoked Template" | is-not-empty) "Should show revoked templates with --all"

# print "=== Testing direct bp get on template ==="
let get_template = ($template.uu.0 | bp get)
assert ($get_template.is_template == true) "Should get template directly"

"=== All tests completed successfully ==="