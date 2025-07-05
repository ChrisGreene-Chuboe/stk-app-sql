#!/usr/bin/env nu

# Test script for stk_request module
# Template Version: 2025-01-05

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_sr($random_suffix)"

# Import modules and assert
use ../modules *
use std/assert

# === Testing CRUD operations ===

# print "=== Testing request overview command ==="
# Note: Module commands are nushell functions, not external commands, so we can't use complete
# Just verify it runs without error
request
# If we get here, the command succeeded

# print "=== Testing request creation (using .append pattern) ==="
let created = (.append request $"Test request($test_suffix)" --description "Test description")
assert ($created | is-not-empty) "Should create request"
assert ($created.uu | is-not-empty) "Should have UUID"
assert ($created.name.0 | str contains $test_suffix) "Name should contain test suffix"

# print "=== Testing request list ==="
let list_result = (request list)
assert ($list_result | where name =~ $test_suffix | is-not-empty) "Should find created request"

# print "=== Testing request get ==="
let get_result = ($created.uu.0 | request get)
assert ($get_result.uu == $created.uu.0) "Should get correct record"

# print "=== Testing request get --detail ==="
let detail_result = ($created.uu.0 | request get --detail)
assert ($detail_result | columns | any {|col| $col | str contains "type"}) "Should include type info"

# print "=== Testing request revoke ==="
let revoke_result = ($created.uu.0 | request revoke)
assert ($revoke_result.is_revoked.0 == true) "Should be revoked"

# print "=== Testing request list --all ==="
let all_list = (request list --all | where name =~ $test_suffix)
assert ($all_list | where is_revoked == true | is-not-empty) "Should show revoked records"

# === Testing UUID input variations ===

# Create parent for UUID testing
let parent = (.append request $"Parent request($test_suffix)")
let parent_uu = ($parent.uu.0)

# print "=== Testing request get with string UUID ==="
let get_string = ($parent_uu | request get)
assert ($get_string.uu == $parent_uu) "Should get correct record with string UUID"

# print "=== Testing request get with record input ==="
let get_record = ($parent | first | request get)
assert ($get_record.uu == $parent_uu) "Should get correct record from record input"

# print "=== Testing request get with table input ==="
let get_table = ($parent | request get)
assert ($get_table.uu == $parent_uu) "Should get correct record from table input"

# print "=== Testing request get with --uu parameter ==="
let get_param = (request get --uu $parent_uu)
assert ($get_param.uu == $parent_uu) "Should get correct record with --uu parameter"

# print "=== Testing request get with empty table (should fail) ==="
try {
    [] | request get
    error make {msg: "Empty table should have failed"}
} catch {
    # print "  ✓ Empty table correctly rejected"
}

# print "=== Testing request get with multi-row table ==="
let multi_table = [$parent, $parent] | flatten
let get_multi = ($multi_table | request get)
assert ($get_multi.uu == $parent_uu) "Should use first row from multi-row table"

# print "=== Testing request revoke with string UUID ==="
let revoke_item = (.append request $"Revoke Test($test_suffix)")
let revoke_string = ($revoke_item.uu.0 | request revoke)
assert ($revoke_string.is_revoked.0 == true) "Should revoke with string UUID"

# print "=== Testing request revoke with --uu parameter ==="
let revoke_item2 = (.append request $"Revoke Test 2($test_suffix)")
let revoke_param = (request revoke --uu $revoke_item2.uu.0)
assert ($revoke_param.is_revoked.0 == true) "Should revoke with --uu parameter"

# print "=== Testing request revoke with record input ==="
let revoke_item3 = (.append request $"Revoke Test 3($test_suffix)")
let revoke_record = ($revoke_item3 | first | request revoke)
assert ($revoke_record.is_revoked.0 == true) "Should revoke from record input"

# print "=== Testing request revoke with table input ==="
let revoke_item4 = (.append request $"Revoke Test 4($test_suffix)")
let revoke_table = ($revoke_item4 | request revoke)
assert ($revoke_table.is_revoked.0 == true) "Should revoke from table input"

# === Testing type support ===

# print "=== Testing request types ==="
let types = (request types)
assert ($types | is-not-empty) "Should have types"
assert ($types | columns | any {|col| $col == "uu"}) "Types should have uu"
assert ($types | columns | any {|col| $col == "search_key"}) "Types should have search_key"

# Note: Requests have types but they're not settable via .append request command
# Types are likely set through database defaults or triggers

# === Testing JSON parameter ===

# print "=== Testing request creation with JSON ==="
let json_created = (.append request $"JSON Test($test_suffix)" --json '{"test": true, "value": 42}')
assert ($json_created | is-not-empty) "Should create with JSON"

# print "=== Verifying stored JSON ==="
let json_detail = ($json_created.uu.0 | request get)
assert ($json_detail.record_json.test == true) "Should store JSON test field"
assert ($json_detail.record_json.value == 42) "Should store JSON value field"

# print "=== Testing request creation without JSON (default) ==="
let no_json = (.append request $"No JSON Test($test_suffix)")
let no_json_detail = ($no_json.uu.0 | request get)
assert ($no_json_detail.record_json == {}) "Should default to empty object"

# print "=== Testing request creation with complex JSON ==="
let complex_json = '{"nested": {"deep": {"value": "found"}}, "array": [1, 2, 3]}'
let complex_created = (.append request $"Complex JSON($test_suffix)" --json $complex_json)
let complex_detail = ($complex_created.uu.0 | request get)
assert ($complex_detail.record_json.nested.deep.value == "found") "Should store nested JSON"
assert (($complex_detail.record_json.array | length) == 3) "Should store JSON arrays"

# === Additional request-specific tests ===

# print "=== Testing request attachment pattern ==="
# Create a project to attach requests to
let project = (project new $"Request Test Project($test_suffix)")
let project_uu = ($project.uu.0)

# print "=== Testing .append request with piped UUID ==="
let attached_request = ($project_uu | .append request $"Project Request($test_suffix)" --description "Project needs review")
assert ($attached_request | is-not-empty) "Should create attached request"
let attached_detail = ($attached_request.uu.0 | request get)
assert ($attached_detail.table_name_uu_json != {}) "Should have attachment data"

# print "=== Testing .append request with --attach parameter ==="
let param_attached = (.append request $"Param Request($test_suffix)" --attach $project_uu --description "Using attach param")
assert ($param_attached | is-not-empty) "Should create request with --attach"
let param_detail = ($param_attached.uu.0 | request get)
assert ($param_detail.table_name_uu_json != {}) "Should have attachment data via --attach"

# print "=== Testing request process command ==="
let process_request = (.append request $"Process Test($test_suffix)")
let process_result = (request process $process_request.uu.0)
assert ($process_result.is_processed.0 == true) "Should be marked as processed"

# print "=== Testing request list --detail ==="
let detail_list = (request list --detail | where name =~ $test_suffix)
assert ($detail_list | is-not-empty) "Should list with details"
assert ($detail_list | columns | any {|col| $col == "type_name"}) "Should include type_name"
assert ($detail_list | columns | any {|col| $col == "type_enum"}) "Should include type_enum"

# print "=== Testing requests enrichment command ==="
let enriched = (project list | where name =~ $test_suffix | requests)
assert ($enriched | columns | any {|col| $col == "requests"}) "Should have requests column"
let project_requests = ($enriched | first).requests
assert (($project_requests | where name =~ "Project Request") | is-not-empty) "Should find attached requests"

# print "=== Testing parent-child request pattern ==="
let parent_request = (.append request $"Parent Task($test_suffix)")
let child_request = ($parent_request.uu.0 | .append request $"Child Task($test_suffix)" --description "Subtask of parent")
assert ($child_request | is-not-empty) "Should create child request"
let child_detail = ($child_request.uu.0 | request get)
assert ($child_detail.table_name_uu_json != {}) "Child should have attachment to parent"

# print "=== Testing .append event on request ==="
let request_for_event = (.append request $"Event Test Request($test_suffix)")
let request_event = ($request_for_event.uu.0 | .append event $"status-changed($test_suffix)" --description "Request status updated")
assert ($request_event | is-not-empty) "Should create event"
assert ($request_event.uu | is-not-empty) "Event should have UUID"

"=== All tests completed successfully ==="