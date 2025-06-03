#!/usr/bin/env nu

# Test script for stk_request module
echo "=== Testing stk_request Module ==="

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
let request_detail = (request get $request_uu)
assert (($request_detail | length) == 1) "Request get should return exactly one record"
assert (($request_detail.uu.0) == $request_uu) "Returned request should have matching UUID"
assert ($request_detail | columns | any {|col| $col == "table_name_uu_json"}) "Request detail should contain table_name_uu_json"
echo "✓ Request get verified for UUID:" $request_uu

echo "=== Creating test event for attachment test ==="  
let test_event_result = ("test event for attachment" | .append event "test-attachment")
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
let processed_request = (request get $request_to_process)
assert (($processed_request.is_processed.0) == true) "Processed request should show is_processed as true"
echo "✓ Processed status verification completed"

echo "=== Testing request revoke ==="
let revoke_test_request = (.append request "test-revoke" --description "Request for revoke testing")
let revoke_result = (request revoke ($revoke_test_request.uu.0))
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
let revoked_request = (request get ($revoke_test_request.uu.0))
assert (($revoked_request.is_revoked.0) == true) "Revoked request should show is_revoked as true"
echo "✓ Request revoke functionality verified"

echo "=== All tests completed successfully ==="