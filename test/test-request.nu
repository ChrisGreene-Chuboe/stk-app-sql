#!/usr/bin/env nu

# Test script for stk_request module
echo "=== Testing stk_request Module ==="

# REQUIRED: Import modules and assert
use ./modules *
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

echo "=== Testing request-to-request attachment (parent-child relationship) ==="
let parent_request_uu = (request list | where name == "budget-review" | get uu.0)
let child_request_result = (.append request "sub-task-1" --description "Review Q1 financial data" --attach $parent_request_uu)
assert ($child_request_result | columns | any {|col| $col == "uu"}) "Child request creation should return UUID"
echo "✓ Parent-child request relationship created"

echo "=== Testing request-to-request attachment with piped UUID ==="
let piped_child_result = (request list | where name == "budget-review" | get uu.0 | .append request "sub-task-2" --description "Prepare quarterly presentation")
assert ($piped_child_result | columns | any {|col| $col == "uu"}) "Piped child request creation should return UUID"
echo "✓ Parent-child request relationship created with piped UUID"

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

echo "=== All tests completed successfully ==="