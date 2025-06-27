#!/usr/bin/env nu

# Test script for stk_request module
echo "=== Testing stk_request Module ==="

# Test-specific suffix to ensure test isolation and idempotency
# Generate random 2-char suffix from letters (upper/lower) and numbers
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_sr($random_suffix)"  # sr for stk_request + 2 random chars

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

echo "=== Testing standalone request creation ==="
let standalone_result = (.append request "budget-review" --description "Review quarterly budget")
assert ($standalone_result | columns | any {|col| $col == "uu"}) "Standalone request creation should return UUID"
assert ($standalone_result.uu | is-not-empty) "UUID field should not be empty"
echo "✓ Standalone request created with UUID:" ($standalone_result.uu)

echo "=== Testing request list ==="
let requests = (request list)
assert (($requests | length) > 0) "Request list should contain at least one request"
assert ($requests | columns | any {|col| $col == "name"}) "Request list should contain name column"
assert ($requests | columns | any {|col| $col == "description"}) "Request list should contain description column"
echo "✓ Request list verified with" ($requests | length) "requests"

echo "=== Testing request get ==="
let request_uu = (request list | get uu.0)
let request_detail = ($request_uu | request get)
assert (($request_detail | length) == 1) "Request get should return exactly one record"
assert (($request_detail.uu.0) == $request_uu) "Returned request should have matching UUID"
assert ($request_detail | columns | any {|col| $col == "table_name_uu_json"}) "Request detail should contain table_name_uu_json"
echo "✓ Request get verified for UUID:" $request_uu

echo "=== Testing request get with record input ==="
let request_record = (request list | get 0)
let record_detail = ($request_record | request get)
assert (($record_detail | length) == 1) "Request get with record should return exactly one record"
assert (($record_detail.uu.0) == $request_record.uu) "Returned request should match record's UUID"
echo "✓ Request get with record input verified"

echo "=== Testing request get with table input ==="
let request_table = (request list | where name == "budget-review")
let table_detail = ($request_table | request get)
assert (($table_detail | length) == 1) "Request get with table should return exactly one record"
assert (($table_detail.name.0) == "budget-review") "Returned request should match query"
echo "✓ Request get with table input verified"

echo "=== Creating test event for attachment test ==="  
let test_event_result = (.append event "test-attachment" --description "test event for attachment")
assert ($test_event_result | columns | any {|col| $col == "uu"}) "Test event creation should return UUID"
echo "✓ Test event created for attachment testing"

echo "=== Testing attached request creation with --attach ==="
let event_uu = (event list | get uu.0)
let attached_request_result = (.append request "bug-fix" --description "Fix critical bug in authentication" --attach $event_uu)
assert ($attached_request_result | columns | any {|col| $col == "uu"}) "Attached request creation should return UUID"
assert ($attached_request_result.uu | is-not-empty) "Attached request UUID should not be empty"
echo "✓ Attached request created with --attach parameter"

echo "=== Testing attached request creation with piped UUID ==="
let piped_request_result = (event list | get uu.0 | .append request "follow-up" --description "Follow up on the test event")
assert ($piped_request_result | columns | any {|col| $col == "uu"}) "Piped request creation should return UUID"
assert ($piped_request_result.uu | is-not-empty) "Piped request UUID should not be empty"
echo "✓ Attached request created with piped UUID"

echo "=== Testing attached request creation with piped record ==="
let piped_record_result = (event list | get 0 | .append request "record-follow-up" --description "Follow up with record input")
assert ($piped_record_result | columns | any {|col| $col == "uu"}) "Piped record request creation should return UUID"
assert ($piped_record_result.uu | is-not-empty) "Piped record request UUID should not be empty"
echo "✓ Attached request created with piped record"

echo "=== Testing attached request creation with piped table ==="
let piped_table_result = (event list | where name == "test-attachment" | .append request "table-follow-up" --description "Follow up with table input")
assert ($piped_table_result | columns | any {|col| $col == "uu"}) "Piped table request creation should return UUID"
assert ($piped_table_result.uu | is-not-empty) "Piped table request UUID should not be empty"
echo "✓ Attached request created with piped table"

echo "=== Testing request-to-request attachment (parent-child relationship) ==="
let parent_request_uu = (request list | where name == "budget-review" | get uu.0)
let child_request_result = (.append request "sub-task-1" --description "Review Q1 financial data" --attach $parent_request_uu)
assert ($child_request_result | columns | any {|col| $col == "uu"}) "Child request creation should return UUID"
echo "✓ Parent-child request relationship created"

echo "=== Testing request-to-request attachment with piped UUID ==="
let piped_child_result = (request list | where name == "budget-review" | get uu.0 | .append request "sub-task-2" --description "Prepare quarterly presentation")
assert ($piped_child_result | columns | any {|col| $col == "uu"}) "Piped child request creation should return UUID"
echo "✓ Parent-child request relationship created with piped UUID"

echo "=== Testing request-to-request attachment with piped record ==="
let parent_record = (request list | where name == "budget-review" | get 0)
let record_child_result = ($parent_record | .append request "sub-task-3" --description "Review financial metrics")
assert ($record_child_result | columns | any {|col| $col == "uu"}) "Record child request creation should return UUID"
echo "✓ Parent-child request relationship created with piped record"

echo "=== Testing request-to-request attachment with piped table ==="
let parent_table = (request list | where name == "budget-review")
let table_child_result = ($parent_table | .append request "sub-task-4" --description "Compile executive summary")
assert ($table_child_result | columns | any {|col| $col == "uu"}) "Table child request creation should return UUID"
echo "✓ Parent-child request relationship created with piped table"

echo "=== Verifying attachment data structure ==="
let attached_requests = (request list | where table_name_uu_json != {})
assert (($attached_requests | length) > 0) "Should find requests with attachments"
echo "✓ Attachment verification completed with" ($attached_requests | length) "attached requests"

echo "=== Testing request processing ==="
let request_to_process = (request list | where name == "budget-review" | get uu.0)
let process_result = (request process $request_to_process)
assert ($process_result | columns | any {|col| $col == "is_processed"}) "Process should return is_processed status"
echo "✓ Request processing functionality verified"

echo "=== Verifying processed status ==="
let processed_request = ($request_to_process | request get)
assert (($processed_request.is_processed.0) == true) "Processed request should show is_processed as true"
echo "✓ Processed status verification completed"

echo "=== Testing request revoke ==="
let revoke_test_request = (.append request "test-revoke" --description "Request for revoke testing")
let revoke_result = ($revoke_test_request.uu.0 | request revoke)
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
let revoked_request = ($revoke_test_request.uu.0 | request get)
assert (($revoked_request.is_revoked.0) == true) "Revoked request should show is_revoked as true"
echo "✓ Request revoke functionality verified"

echo "=== Testing request revoke with record input ==="
let revoke_record_request = (.append request "test-revoke-record" --description "Request for record revoke testing")
let revoke_record_result = ($revoke_record_request.0 | request revoke)
assert ($revoke_record_result | columns | any {|col| $col == "is_revoked"}) "Record revoke should return is_revoked status"
assert (($revoke_record_result.is_revoked.0) == true) "Record revoked request should be marked as revoked"
echo "✓ Request revoke with record input verified"

echo "=== Testing request revoke with table input ==="
let revoke_table_request = (.append request "test-revoke-table" --description "Request for table revoke testing")
let revoke_table_result = (request list | where name == "test-revoke-table" | request revoke)
assert ($revoke_table_result | columns | any {|col| $col == "is_revoked"}) "Table revoke should return is_revoked status"
assert (($revoke_table_result.is_revoked.0) == true) "Table revoked request should be marked as revoked"
echo "✓ Request revoke with table input verified"

echo "=== Testing request revoke with piped UUID ==="
let pipeline_request = (.append request "pipeline-revoke-test" --description "Request for pipeline revoke testing")
let pipeline_revoke_result = ($pipeline_request.uu.0 | request revoke)
assert ($pipeline_revoke_result | columns | any {|col| $col == "is_revoked"}) "Pipeline revoke should return is_revoked status"
assert (($pipeline_revoke_result.is_revoked.0) == true) "Pipeline revoked request should be marked as revoked"
echo "✓ Request revoke with piped UUID verified"

echo "=== Testing .append event with request UUID ==="
let active_request_uu = ($standalone_result.uu.0)  # Use an unrevoked request
let request_event_result = ($active_request_uu | .append event "request-updated" --description "request has been updated with additional details")
assert ($request_event_result | columns | any {|col| $col == "uu"}) "Request event should return UUID"
assert ($request_event_result.uu | is-not-empty) "Request event UUID should not be empty"
echo "✓ .append event with piped request UUID verified"

echo "=== Testing .append request to attach to another request ==="
let meta_request_result = ($active_request_uu | .append request "meta-request" --description "follow-up request about this request")
assert ($meta_request_result | columns | any {|col| $col == "uu"}) "Meta request should return UUID"
assert ($meta_request_result.uu | is-not-empty) "Meta request UUID should not be empty"
echo "✓ .append request with piped request UUID verified (request-to-request attachment)"

echo "=== Testing empty table input (creates standalone request) ==="
let empty_table = (request list | where name == "nonexistent-request-xyz-123")
assert (($empty_table | length) == 0) "Empty filter should return empty table"
let empty_result = ($empty_table | .append request "empty-table-test" --description "Created from empty table")
assert ($empty_result | columns | any {|col| $col == "uu"}) "Empty table should create standalone request"
let empty_detail = ($empty_result.uu.0 | request get)
assert (($empty_detail.table_name_uu_json.0.uu | is-empty)) "Empty table request should have no attachment"
echo "✓ Empty table creates standalone request verified"

echo "=== Testing multi-row table input (uses first row) ==="
let multi_requests = (request list | take 3)
assert (($multi_requests | length) >= 2) "Should have at least 2 requests for multi-row test"
let multi_result = ($multi_requests | .append request "multi-row-test" --description "Attached to first of multiple rows")
assert ($multi_result | columns | any {|col| $col == "uu"}) "Multi-row table should return request"
let multi_detail = ($multi_result.uu.0 | request get)
let first_uu = ($multi_requests.0.uu)
assert (($multi_detail.table_name_uu_json.0.uu) == $first_uu) "Multi-row table should attach to first row"
echo "✓ Multi-row table input verified (uses first row)"

echo "=== Testing request types command ==="
let types_result = (request types)
assert (($types_result | length) > 0) "Should return at least one request type"
assert ($types_result | columns | any {|col| $col == "type_enum"}) "Result should contain 'type_enum' field"
assert ($types_result | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($types_result | columns | any {|col| $col == "name"}) "Result should contain 'name' field"

# Check that expected types exist
let type_enums = ($types_result | get type_enum)
assert ($type_enums | any {|t| $t == "NOTE"}) "Should have NOTE type"
assert ($type_enums | any {|t| $t == "TODO"}) "Should have TODO type"
echo "✓ Request types verified successfully"

echo "=== Testing request list --detail command ==="
let detailed_requests_list = (request list --detail)
assert (($detailed_requests_list | length) >= 1) "Should return at least one detailed request"
assert ($detailed_requests_list | columns | any {|col| $col == "type_enum"}) "Detailed list should contain 'type_enum' field"
assert ($detailed_requests_list | columns | any {|col| $col == "type_name"}) "Detailed list should contain 'type_name' field"
echo "✓ Request list --detail verified successfully"

echo "=== Testing request get --detail command ==="
let first_request_uu = (request list | get uu.0)
let detailed_request = ($first_request_uu | request get --detail)
assert (($detailed_request | length) == 1) "Should return exactly one detailed request"
assert ($detailed_request | columns | any {|col| $col == "uu"}) "Detailed request should contain 'uu' field"
assert ($detailed_request | columns | any {|col| $col == "type_enum"}) "Detailed request should contain 'type_enum' field"
assert ($detailed_request | columns | any {|col| $col == "type_name"}) "Detailed request should contain 'type_name' field"
echo "✓ Request get --detail verified with type:" ($detailed_request.type_enum.0)

echo "=== Testing request creation with JSON data ==="
let json_request = (.append request "feature-request" --json '{"priority": "medium", "component": "ui", "estimated_effort": "2 weeks"}' --description "Add dark mode support")
assert ($json_request | columns | any {|col| $col == "uu"}) "JSON request creation should return UUID"
assert ($json_request.uu | is-not-empty) "JSON request UUID should not be empty"
echo "✓ Request with JSON created, UUID:" ($json_request.uu)

echo "=== Verifying request's record_json field ==="
let json_request_detail = ($json_request.uu.0 | request get)
assert (($json_request_detail | length) == 1) "Should retrieve exactly one request"
assert ($json_request_detail | columns | any {|col| $col == "record_json"}) "Request should have record_json column"
let stored_json = ($json_request_detail.record_json.0)
assert ($stored_json | columns | any {|col| $col == "priority"}) "JSON should contain priority field"
assert ($stored_json | columns | any {|col| $col == "component"}) "JSON should contain component field"
assert ($stored_json | columns | any {|col| $col == "estimated_effort"}) "JSON should contain estimated_effort field"
assert ($stored_json.priority == "medium") "Priority should be medium"
assert ($stored_json.component == "ui") "Component should be ui"
assert ($stored_json.estimated_effort == "2 weeks") "Estimated effort should be 2 weeks"
echo "✓ JSON data verified: record_json contains structured data"

echo "=== Testing request creation without JSON (default behavior) ==="
let no_json_request = (.append request "simple-request" --description "Request without JSON metadata")
let no_json_detail = ($no_json_request.uu.0 | request get)
assert ($no_json_detail.record_json.0 == {}) "record_json should be empty object when no JSON provided"
echo "✓ Default behavior verified: no JSON parameter results in empty JSON object"

echo "=== Testing request with attachment and JSON ==="
let test_item = (item new "Test Product")
let item_uuid = ($test_item.uu.0)
let attached_json_request = ($item_uuid | .append request "inventory-check" --json '{"warehouse": "west", "urgency": "high", "quantity_threshold": 100}' --description "Check inventory levels")
assert ($attached_json_request | columns | any {|col| $col == "uu"}) "Attached JSON request should return UUID"
let attached_detail = ($attached_json_request.uu.0 | request get)
assert ($attached_detail.table_name_uu_json.0 != {}) "Should have attachment data"
assert ($attached_detail.record_json.0.warehouse == "west") "Warehouse should be west"
assert ($attached_detail.record_json.0.urgency == "high") "Urgency should be high"
echo "✓ Request with attachment and JSON verified"

echo "=== Testing complex nested JSON for request ==="
let complex_json = '{"workflow": {"steps": ["review", "approve", "implement"], "approvers": ["manager", "director"]}, "metadata": {"created_by": "system", "tags": ["urgent", "compliance", "audit"]}, "deadline": "2024-12-31"}'
let complex_request = (.append request "compliance-audit" --json $complex_json --description "Annual compliance audit request")
let complex_detail = ($complex_request.uu.0 | request get)
let complex_stored = ($complex_detail.record_json.0)
assert (($complex_stored.workflow.steps | length) == 3) "Should have 3 workflow steps"
assert ($complex_stored.workflow.approvers.1 == "director") "Second approver should be director"
assert (($complex_stored.metadata.tags | length) == 3) "Should have 3 tags"
assert ($complex_stored.deadline == "2024-12-31") "Deadline should be 2024-12-31"
#print "✓ Complex nested JSON structure verified"

# print "=== Testing table_name optimization (piped record with table_name) ==="
# When piping from a list command, records include table_name
# This test verifies the optimization that avoids DB lookup when table_name is known
let project_for_optimization = (project new $"Optimization Test Project($test_suffix)")
let project_uu = ($project_for_optimization.uu.0)

# Get the project with table_name included
let project_with_table = (project list | where uu == $project_uu | get 0)
assert (($project_with_table.table_name? | is-not-empty)) "Project record should include table_name"
assert (($project_with_table.table_name == "stk_project")) "Table name should be stk_project"

# Pipe the full record (includes table_name) to .append request
let optimized_request = ($project_with_table | .append request $"optimized-attachment($test_suffix)" --description "Uses table_name from record")
assert (($optimized_request | columns | any {|col| $col == "uu"})) "Optimized request should return UUID"

# Verify the attachment is correct
let optimized_detail = ($optimized_request.uu.0 | request get)
assert (($optimized_detail.table_name_uu_json.0.table_name == "stk_project")) "Should have correct table name"
assert (($optimized_detail.table_name_uu_json.0.uu == $project_uu)) "Should have correct UUID"
#print "✓ Table name optimization verified (avoids DB lookup when table_name provided)"

# print "=== Testing --attach parameter still works (falls back to DB lookup) ==="
# When using --attach with just a UUID string, it should still work
let attach_request = (.append request $"attach-test($test_suffix)" --attach $project_uu --description "Uses --attach parameter")
assert (($attach_request | columns | any {|col| $col == "uu"})) "Attach request should return UUID"

# Verify the attachment is correct
let attach_detail = ($attach_request.uu.0 | request get)
assert (($attach_detail.table_name_uu_json.0.table_name == "stk_project")) "Should have correct table name via DB lookup"
assert (($attach_detail.table_name_uu_json.0.uu == $project_uu)) "Should have correct UUID"
#print "✓ --attach parameter verified (uses DB lookup for table_name)"

# print "=== Comparing optimized vs fallback results ==="
# Both methods should produce identical results
assert (($optimized_detail.table_name_uu_json.0 == $attach_detail.table_name_uu_json.0)) "Both methods should produce identical table_name_uu_json"
#print "✓ Optimization produces identical results to DB lookup"

print "=== Testing request get with --uu parameter ==="
let test_uu = (request list | get uu.0)
let uu_param_result = (request get --uu $test_uu)
assert (($uu_param_result | length) == 1) "Request get --uu should return exactly one record"
assert (($uu_param_result.uu.0) == $test_uu) "Returned request should have matching UUID"
print "✓ Request get --uu parameter verified"

print "=== Testing request get --detail with --uu parameter ==="
let detail_uu_result = (request get --uu $test_uu --detail)
assert (($detail_uu_result | length) == 1) "Request get --uu --detail should return exactly one record"
assert ($detail_uu_result | columns | any {|col| $col == "type_enum"}) "Detailed result should contain type_enum"
print "✓ Request get --uu --detail verified"

print "=== Testing request revoke with --uu parameter ==="
let revoke_uu_test = (.append request "test-revoke-uu-param" --description "Request for --uu revoke testing")
let revoke_uu = ($revoke_uu_test.uu.0)
let revoke_uu_result = (request revoke --uu $revoke_uu)
assert ($revoke_uu_result | columns | any {|col| $col == "is_revoked"}) "Revoke --uu should return is_revoked status"
assert (($revoke_uu_result.is_revoked.0) == true) "Request should be marked as revoked"
print "✓ Request revoke --uu parameter verified"

print "=== Testing error when no UUID provided to get ==="
# Test error handling with try/catch
try {
    null | request get
    assert false "Request get should have thrown an error"
} catch {|e|
    assert ($e.msg | str contains "UUID required via piped input or --uu parameter") "Should show correct error message"
}
print "✓ Request get error handling verified"

print "=== Testing error when no UUID provided to revoke ==="
# Test error handling with try/catch
try {
    null | request revoke
    assert false "Request revoke should have thrown an error"
} catch {|e|
    assert ($e.msg | str contains "UUID required via piped input or --uu parameter") "Should show correct error message"
}
print "✓ Request revoke error handling verified"

# Return success string as final expression (no echo needed)
"=== All tests completed successfully ==="
