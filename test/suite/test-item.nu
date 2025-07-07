#!/usr/bin/env nu

# Test script for stk_item module
# Template Version: 2025-01-05

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_si($random_suffix)"

# Import modules and assert
use ../modules *
use std/assert

# === Testing CRUD operations ===

# print "=== Testing item overview command ==="
# Note: 'item' is a nushell function, not an external command, so we can't use complete
# Just verify it runs without error
item
# If we get here, the command succeeded

# print "=== Testing item creation ==="
let created = (item new $"Test item($test_suffix)")
assert ($created | is-not-empty) "Should create item"
assert ($created.uu | is-not-empty) "Should have UUID"
assert ($created.name.0 | str contains $test_suffix) "Name should contain test suffix"

# print "=== Testing item list ==="
let list_result = (item list)
assert ($list_result | where name =~ $test_suffix | is-not-empty) "Should find created item"

# print "=== Testing item get ==="
let get_result = ($created.uu.0 | item get)
assert ($get_result.uu == $created.uu.0) "Should get correct record"


# print "=== Testing item revoke ==="
let revoke_result = ($created.uu.0 | item revoke)
assert ($revoke_result.is_revoked.0 == true) "Should be revoked"

# print "=== Testing item list --all ==="
let all_list = (item list --all | where name =~ $test_suffix)
assert ($all_list | where is_revoked == true | is-not-empty) "Should show revoked records"

# === Testing UUID input variations ===

# Create parent for UUID testing
let parent = (item new $"Parent item($test_suffix)")
let parent_uu = ($parent.uu.0)

# print "=== Testing item get with string UUID ==="
let get_string = ($parent_uu | item get)
assert ($get_string.uu == $parent_uu) "Should get correct record with string UUID"

# print "=== Testing item get with record input ==="
let get_record = ($parent | first | item get)
assert ($get_record.uu == $parent_uu) "Should get correct record from record input"

# print "=== Testing item get with table input ==="
let get_table = ($parent | item get)
assert ($get_table.uu == $parent_uu) "Should get correct record from table input"

# print "=== Testing item get with --uu parameter ==="
let get_param = (item get --uu $parent_uu)
assert ($get_param.uu == $parent_uu) "Should get correct record with --uu parameter"

# print "=== Testing item get with empty table (should fail) ==="
try {
    [] | item get
    error make {msg: "Empty table should have failed"}
} catch {
    # print "  ✓ Empty table correctly rejected"
}

# print "=== Testing item get with multi-row table ==="
let multi_table = [$parent, $parent] | flatten
let get_multi = ($multi_table | item get)
assert ($get_multi.uu == $parent_uu) "Should use first row from multi-row table"

# print "=== Testing item revoke with string UUID ==="
let revoke_item = (item new $"Revoke Test($test_suffix)")
let revoke_string = ($revoke_item.uu.0 | item revoke)
assert ($revoke_string.is_revoked.0 == true) "Should revoke with string UUID"

# print "=== Testing item revoke with --uu parameter ==="
let revoke_item2 = (item new $"Revoke Test 2($test_suffix)")
let revoke_param = (item revoke --uu $revoke_item2.uu.0)
assert ($revoke_param.is_revoked.0 == true) "Should revoke with --uu parameter"

# print "=== Testing item revoke with record input ==="
let revoke_item3 = (item new $"Revoke Test 3($test_suffix)")
let revoke_record = ($revoke_item3 | first | item revoke)
assert ($revoke_record.is_revoked.0 == true) "Should revoke from record input"

# print "=== Testing item revoke with table input ==="
let revoke_item4 = (item new $"Revoke Test 4($test_suffix)")
let revoke_table = ($revoke_item4 | item revoke)
assert ($revoke_table.is_revoked.0 == true) "Should revoke from table input"

# === Testing type support ===

# print "=== Testing item types ==="
let types = (item types)
assert ($types | is-not-empty) "Should have types"
assert ($types | columns | any {|col| $col == "uu"}) "Types should have uu"
assert ($types | columns | any {|col| $col == "search_key"}) "Types should have search_key"

# Use first type for testing
let test_type = ($types | first)

# print "=== Testing item creation with type ==="
let typed = (item new $"Typed($test_suffix)" --type-search-key $test_type.search_key)
assert ($typed.type_uu.0 == $test_type.uu) "Should have correct type"

# print "=== Testing item get shows type ==="
let typed_get = ($typed.uu.0 | item get)
assert ($typed_get.type_name | is-not-empty) "Should show type name"
assert ($typed_get.type_enum | is-not-empty) "Should show type enum"

# === Testing JSON parameter ===

# print "=== Testing item creation with JSON ==="
let json_created = (item new $"JSON Test($test_suffix)" --json '{"test": true, "value": 42}')
assert ($json_created | is-not-empty) "Should create with JSON"

# print "=== Verifying stored JSON ==="
let json_detail = ($json_created.uu.0 | item get)
assert ($json_detail.record_json.test == true) "Should store JSON test field"
assert ($json_detail.record_json.value == 42) "Should store JSON value field"

# print "=== Testing item creation without JSON (default) ==="
let no_json = (item new $"No JSON Test($test_suffix)")
let no_json_detail = ($no_json.uu.0 | item get)
assert ($no_json_detail.record_json == {}) "Should default to empty object"

# print "=== Testing item creation with complex JSON ==="
let complex_json = '{"nested": {"deep": {"value": "found"}}, "array": [1, 2, 3]}'
let complex_created = (item new $"Complex JSON($test_suffix)" --json $complex_json)
let complex_detail = ($complex_created.uu.0 | item get)
assert ($complex_detail.record_json.nested.deep.value == "found") "Should store nested JSON"
assert (($complex_detail.record_json.array | length) == 3) "Should store JSON arrays"

# === Additional item-specific tests ===

# print "=== Testing item creation with description ==="
let described = (item new $"Described item($test_suffix)" --description "Test description")
let described_detail = ($described.uu.0 | item get)
assert ($described_detail.description == "Test description") "Should store description"

# print "=== Testing item list includes type info ==="
let list_with_types = (item list | where name =~ $test_suffix)
assert ($list_with_types | is-not-empty) "Should list items"
assert ($list_with_types | columns | any {|col| $col == "type_name"}) "Should include type_name"
assert ($list_with_types | columns | any {|col| $col == "type_enum"}) "Should include type_enum"

# print "=== Testing .append event with item UUID ==="
let event_item = (item new $"Event Test($test_suffix)")
let event_result = ($event_item.uu.0 | .append event "price-updated" --description "Price changed")
assert ($event_result | is-not-empty) "Should create event"
assert ($event_result.uu | is-not-empty) "Event should have UUID"

# print "=== Testing .append request with item UUID ==="
let request_item = (item new $"Request Test($test_suffix)")
let request_result = ($request_item.uu.0 | .append request "inventory-check" --description "Check stock")
assert ($request_result | is-not-empty) "Should create request"
assert ($request_result.uu | is-not-empty) "Request should have UUID"

"=== All tests completed successfully ==="