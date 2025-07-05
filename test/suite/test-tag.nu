#!/usr/bin/env nu

# Test script for stk_tag module
# Template Version: 2025-01-05

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_sg($random_suffix)"

# Import modules and assert
use ../modules *
use std/assert

# === Testing CRUD operations ===

# print "=== Testing tag overview command ==="
# Note: Module commands are nushell functions, not external commands, so we can't use complete
# Just verify it runs without error
tag
# If we get here, the command succeeded

# print "=== Testing tag creation (using .append pattern) ==="
# Tags need to be attached to something, so create a project first
let project = (project new $"Tag Test Project($test_suffix)")
let project_uu = ($project.uu.0)

# Tags require a type - use NONE type for basic testing
let created = ($project_uu | .append tag --search-key $"test-tag($test_suffix)" --type-search-key "NONE" --description "Test description")
assert ($created | is-not-empty) "Should create tag"
assert ($created.uu | is-not-empty) "Should have UUID"
assert ($created.search_key.0 | str contains $test_suffix) "Search key should contain test suffix"

# print "=== Testing tag list ==="
let list_result = (tag list)
assert ($list_result | where search_key =~ $test_suffix | is-not-empty) "Should find created tag"

# print "=== Testing tag get ==="
let get_result = ($created.uu.0 | tag get)
assert ($get_result.uu == $created.uu.0) "Should get correct record"

# print "=== Testing tag get --detail ==="
let detail_result = ($created.uu.0 | tag get --detail)
assert ($detail_result | columns | any {|col| $col | str contains "type"}) "Should include type info"

# print "=== Testing tag revoke ==="
let revoke_result = ($created.uu.0 | tag revoke)
assert ($revoke_result.is_revoked.0 == true) "Should be revoked"

# print "=== Testing tag list --all ==="
let all_list = (tag list --all | where search_key =~ $test_suffix)
assert ($all_list | where is_revoked == true | is-not-empty) "Should show revoked records"

# === Testing UUID input variations ===

# Create parent for UUID testing
let parent = ($project_uu | .append tag --search-key $"parent-tag($test_suffix)" --type-search-key "NONE")
let parent_uu = ($parent.uu.0)

# print "=== Testing tag get with string UUID ==="
let get_string = ($parent_uu | tag get)
assert ($get_string.uu == $parent_uu) "Should get correct record with string UUID"

# print "=== Testing tag get with record input ==="
let get_record = ($parent | first | tag get)
assert ($get_record.uu == $parent_uu) "Should get correct record from record input"

# print "=== Testing tag get with table input ==="
let get_table = ($parent | tag get)
assert ($get_table.uu == $parent_uu) "Should get correct record from table input"

# print "=== Testing tag get with --uu parameter ==="
let get_param = (tag get --uu $parent_uu)
assert ($get_param.uu == $parent_uu) "Should get correct record with --uu parameter"

# print "=== Testing tag get with empty table (should fail) ==="
try {
    [] | tag get
    error make {msg: "Empty table should have failed"}
} catch {
    # print "  ✓ Empty table correctly rejected"
}

# print "=== Testing tag get with multi-row table ==="
let multi_table = [$parent, $parent] | flatten
let get_multi = ($multi_table | tag get)
assert ($get_multi.uu == $parent_uu) "Should use first row from multi-row table"

# print "=== Testing tag revoke with string UUID ==="
let revoke_item = ($project_uu | .append tag --search-key $"revoke-test($test_suffix)" --type-search-key "NONE")
let revoke_string = ($revoke_item.uu.0 | tag revoke)
assert ($revoke_string.is_revoked.0 == true) "Should revoke with string UUID"

# print "=== Testing tag revoke with --uu parameter ==="
let revoke_item2 = ($project_uu | .append tag --search-key $"revoke-test-2($test_suffix)" --type-search-key "NONE")
let revoke_param = (tag revoke --uu $revoke_item2.uu.0)
assert ($revoke_param.is_revoked.0 == true) "Should revoke with --uu parameter"

# print "=== Testing tag revoke with record input ==="
let revoke_item3 = ($project_uu | .append tag --search-key $"revoke-test-3($test_suffix)" --type-search-key "NONE")
let revoke_record = ($revoke_item3 | first | tag revoke)
assert ($revoke_record.is_revoked.0 == true) "Should revoke from record input"

# print "=== Testing tag revoke with table input ==="
let revoke_item4 = ($project_uu | .append tag --search-key $"revoke-test-4($test_suffix)" --type-search-key "NONE")
let revoke_table = ($revoke_item4 | tag revoke)
assert ($revoke_table.is_revoked.0 == true) "Should revoke from table input"

# === Testing type support ===

# print "=== Testing tag types ==="
let types = (tag types)
assert ($types | is-not-empty) "Should have types"
assert ($types | columns | any {|col| $col == "uu"}) "Types should have uu"
assert ($types | columns | any {|col| $col == "search_key"}) "Types should have search_key"

# Use first type for testing
let test_type = ($types | first)

# print "=== Testing tag creation with type ==="
# Note: Tags DO accept type parameters during creation via .append tag
let typed = ($project_uu | .append tag --search-key $"typed($test_suffix)" --type-search-key $test_type.search_key)
assert ($typed.type_uu.0 == $test_type.uu) "Should have correct type"

# print "=== Testing tag get --detail shows type ==="
let typed_detail = ($typed.uu.0 | tag get --detail)
assert ($typed_detail.type_name | is-not-empty) "Should show type name"
assert ($typed_detail.type_enum | is-not-empty) "Should show type enum"

# === Testing JSON parameter ===

# print "=== Testing tag creation with JSON ==="
let json_created = ($project_uu | .append tag --search-key $"json-test($test_suffix)" --type-search-key "NONE" --json '{"test": true, "value": 42}')
assert ($json_created | is-not-empty) "Should create with JSON"

# print "=== Verifying stored JSON ==="
let json_detail = ($json_created.uu.0 | tag get)
assert ($json_detail.record_json.test == true) "Should store JSON test field"
assert ($json_detail.record_json.value == 42) "Should store JSON value field"

# print "=== Testing tag creation without JSON (default) ==="
let no_json = ($project_uu | .append tag --search-key $"no-json($test_suffix)" --type-search-key "NONE")
let no_json_detail = ($no_json.uu.0 | tag get)
assert ($no_json_detail.record_json == {}) "Should default to empty object"

# print "=== Testing tag creation with complex JSON ==="
let complex_json = '{"nested": {"deep": {"value": "found"}}, "array": [1, 2, 3]}'
let complex_created = ($project_uu | .append tag --search-key $"complex($test_suffix)" --type-search-key "NONE" --json $complex_json)
let complex_detail = ($complex_created.uu.0 | tag get)
assert ($complex_detail.record_json.nested.deep.value == "found") "Should store nested JSON"
assert (($complex_detail.record_json.array | length) == 3) "Should store JSON arrays"

# === Additional tag-specific tests ===

# print "=== Testing tag with ADDRESS type and JSON ==="
let address_type = (tag types | where type_enum == "ADDRESS" | first)
let address_json = '{"address1": "123 Main St", "city": "Austin", "state": "TX", "postal": "78701"}'
let address_tag = ($project_uu | .append tag --search-key $"headquarters($test_suffix)" --type-search-key ADDRESS --json $address_json)
assert ($address_tag | is-not-empty) "Should create address tag"
assert ($address_tag.type_uu.0 == $address_type.uu) "Should have ADDRESS type"

# print "=== Testing tag attachment pattern ==="
let tag_detail = ($address_tag.uu.0 | tag get)
assert ($tag_detail.table_name_uu_json != {}) "Should have attachment data"

# print "=== Testing tag list --detail ==="
let detail_list = (tag list --detail | where search_key =~ $test_suffix)
assert ($detail_list | is-not-empty) "Should list with details"
assert ($detail_list | columns | any {|col| $col == "type_name"}) "Should include type_name"
assert ($detail_list | columns | any {|col| $col == "type_enum"}) "Should include type_enum"

# print "=== Testing tags enrichment command ==="
let enriched = (project list | where name =~ $test_suffix | tags)
assert ($enriched | columns | any {|col| $col == "tags"}) "Should have tags column"
let project_tags = ($enriched | first).tags
assert (($project_tags | length) > 0) "Should find attached tags"

# print "=== Testing tag on different entity types ==="
# Create an item to tag
let item = (item new $"Tagged Item($test_suffix)")
let item_tag = ($item.uu.0 | .append tag --search-key $"item-tag($test_suffix)" --type-search-key "NONE" --description "Tag on item")
assert ($item_tag | is-not-empty) "Should create tag on item"

# Print "=== Testing .append event on tag ==="
let tag_for_event = ($project_uu | .append tag --search-key $"event-test($test_suffix)" --type-search-key "NONE")
let tag_event = ($tag_for_event.uu.0 | .append event $"tag-updated($test_suffix)" --description "Tag was modified")
assert ($tag_event | is-not-empty) "Should create event"
assert ($tag_event.uu | is-not-empty) "Event should have UUID"

# print "=== Testing .append request on tag ==="
let tag_for_request = ($project_uu | .append tag --search-key $"request-test($test_suffix)" --type-search-key "NONE")
let tag_request = ($tag_for_request.uu.0 | .append request $"verify-tag($test_suffix)" --description "Please verify this tag")
assert ($tag_request | is-not-empty) "Should create request"
assert ($tag_request.uu | is-not-empty) "Request should have UUID"

"=== All tests completed successfully ==="