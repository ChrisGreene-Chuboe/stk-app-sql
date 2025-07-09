#!/usr/bin/env nu

# Test script for stk_event module
# Template Version: 2025-01-08

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_se($random_suffix)"

# Import modules and assert
use ../modules *
use std/assert

# === Testing CRUD operations ===

# print "=== Testing event overview command ==="
# Note: Module commands are nushell functions, not external commands, so we can't use complete
# Verify command exists and returns non-empty string
let overview_result = event
assert (($overview_result | str length) > 0) "Overview command should return non-empty text"

# print "=== Testing event creation (using .append pattern) ==="
let created = (.append event $"Test event($test_suffix)" --description "Test description")
assert (($created | describe | str starts-with "record")) "Should create event"
assert ($created.uu | is-not-empty) "Should have UUID"
assert ($created.name | str contains $test_suffix) "Name should contain test suffix"

# print "=== Testing event list ==="
let list_result = (event list)
assert ($list_result | where name =~ $test_suffix | is-not-empty) "Should find created event"

# print "=== Testing event get ==="
let get_result = ($created.uu | event get)
assert ($get_result.uu == $created.uu) "Should get correct record"


# print "=== Testing event revoke ==="
let revoke_result = ($created.uu | event revoke)
assert ($revoke_result.is_revoked.0 == true) "Should be revoked"

# print "=== Testing event list --all ==="
let all_list = (event list --all | where name =~ $test_suffix)
assert ($all_list | where is_revoked == true | is-not-empty) "Should show revoked records"

# === Testing UUID input variations ===

# Create parent for UUID testing
let parent = (.append event $"Parent event($test_suffix)")
let parent_uu = $parent.uu

# print "=== Testing event get with string UUID ==="
let get_string = ($parent_uu | event get)
assert ($get_string.uu == $parent_uu) "Should get correct record with string UUID"

# print "=== Testing event get with record input ==="
let get_record = ($parent | event get)
assert ($get_record.uu == $parent_uu) "Should get correct record from record input"

# print "=== Testing event get with table input ==="
let get_table = ([$parent] | event get)
assert ($get_table.uu == $parent_uu) "Should get correct record from table input"

# print "=== Testing event get with --uu parameter ==="
let get_param = (event get --uu $parent_uu)
assert ($get_param.uu == $parent_uu) "Should get correct record with --uu parameter"

# print "=== Testing event get with empty table (should fail) ==="
try {
    [] | event get
    error make {msg: "Empty table should have failed"}
} catch {
    # print "  ✓ Empty table correctly rejected"
}

# print "=== Testing event get with multi-row table ==="
let multi_table = [$parent, $parent]
let get_multi = ($multi_table | event get)
assert ($get_multi.uu == $parent_uu) "Should use first row from multi-row table"

# print "=== Testing event revoke with string UUID ==="
let revoke_item = (.append event $"Revoke Test($test_suffix)")
let revoke_string = ($revoke_item.uu | event revoke)
assert ($revoke_string.is_revoked.0 == true) "Should revoke with string UUID"

# print "=== Testing event revoke with --uu parameter ==="
let revoke_item2 = (.append event $"Revoke Test 2($test_suffix)")
let revoke_param = (event revoke --uu $revoke_item2.uu)
assert ($revoke_param.is_revoked.0 == true) "Should revoke with --uu parameter"

# print "=== Testing event revoke with record input ==="
let revoke_item3 = (.append event $"Revoke Test 3($test_suffix)")
let revoke_record = ($revoke_item3 | event revoke)
assert ($revoke_record.is_revoked.0 == true) "Should revoke from record input"

# print "=== Testing event revoke with table input ==="
let revoke_item4 = (.append event $"Revoke Test 4($test_suffix)")
let revoke_table = ([$revoke_item4] | event revoke)
assert ($revoke_table.is_revoked.0 == true) "Should revoke from table input"

# === Testing type support ===

# print "=== Testing event types ==="
let types = (event types)
assert ($types | is-not-empty) "Should have types"
assert ($types | columns | any {|col| $col == "uu"}) "Types should have uu"
assert ($types | columns | any {|col| $col == "search_key"}) "Types should have search_key"

# Note: Events have types but they're not settable via .append event command
# Types are likely set through database defaults or triggers

# === Testing JSON parameter ===

# print "=== Testing event creation with JSON ==="
let json_created = (.append event $"JSON Test($test_suffix)" --json '{"test": true, "value": 42}')
assert (($json_created | describe | str starts-with "record")) "Should create with JSON"

# print "=== Verifying stored JSON ==="
let json_detail = ($json_created.uu | event get)
assert ($json_detail.record_json.test == true) "Should store JSON test field"
assert ($json_detail.record_json.value == 42) "Should store JSON value field"

# print "=== Testing event creation without JSON (default) ==="
let no_json = (.append event $"No JSON Test($test_suffix)")
let no_json_detail = ($no_json.uu | event get)
assert ($no_json_detail.record_json == {}) "Should default to empty object"

# print "=== Testing event creation with complex JSON ==="
let complex_json = '{"nested": {"deep": {"value": "found"}}, "array": [1, 2, 3]}'
let complex_created = (.append event $"Complex JSON($test_suffix)" --json $complex_json)
let complex_detail = ($complex_created.uu | event get)
assert ($complex_detail.record_json.nested.deep.value == "found") "Should store nested JSON"
assert (($complex_detail.record_json.array | length) == 3) "Should store JSON arrays"

# === Additional event-specific tests ===

# print "=== Testing event attachment pattern ==="
# Create a project to attach events to
let project = (project new $"Event Test Project($test_suffix)")
let project_uu = $project.uu

# print "=== Testing .append event with piped UUID ==="
let attached_event = ($project_uu | .append event $"Project Event($test_suffix)" --description "Project updated")
assert (($attached_event | describe | str starts-with "record")) "Should create attached event"
let attached_detail = ($attached_event.uu | event get)
assert ($attached_detail.table_name_uu_json != {}) "Should have attachment data"
# Note: The exact structure of table_name_uu_json may vary - just verify it's populated

# print "=== Testing .append event with --attach parameter ==="
let param_attached = (.append event $"Param Event($test_suffix)" --attach $project_uu --description "Using attach param")
assert (($param_attached | describe | str starts-with "record")) "Should create event with --attach"
let param_detail = ($param_attached.uu | event get)
assert ($param_detail.table_name_uu_json != {}) "Should have attachment data via --attach"

# print "=== Testing event list includes type info ==="
let list_with_types = (event list | where name =~ $test_suffix)
assert ($list_with_types | is-not-empty) "Should list events"
assert ($list_with_types | columns | any {|col| $col == "type_name"}) "Should include type_name"
assert ($list_with_types | columns | any {|col| $col == "type_enum"}) "Should include type_enum"

# print "=== Testing events enrichment command ==="
let enriched = (project list | where name =~ $test_suffix | events)
assert ($enriched | columns | any {|col| $col == "events"}) "Should have events column"
let project_events = ($enriched | first).events
assert (($project_events | where name =~ "Project Event") | is-not-empty) "Should find attached events"

# print "=== Testing .append request on event ==="
let event_for_request = (.append event $"Request Test Event($test_suffix)")
let event_request = ($event_for_request.uu | .append request $"investigate($test_suffix)" --description "Look into this")
assert (($event_request | describe | str starts-with "record")) "Should create request"
assert ($event_request.uu | is-not-empty) "Request should have UUID"

"=== All tests completed successfully ==="