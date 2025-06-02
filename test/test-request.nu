#!/usr/bin/env nu

# Test script for stk_request module
echo "=== Testing stk_request Nushell Module ==="

# Import the modules
use ../modules *

echo "=== Testing standalone request creation ==="
.append request "budget-review" --description "Review quarterly budget"

echo "=== Testing request list ==="
request list

echo "=== Testing request get ==="
let request_uu = (request list | get uu.0)
request get $request_uu

echo "=== Creating test event for attachment test ==="  
"test event for attachment" | .append event "test-attachment"

echo "=== Testing attached request creation with --attach ==="
let event_uu = (event list | get uu.0)
.append request "bug-fix" --description "Fix critical bug in authentication" --attach $event_uu

echo "=== Testing attached request creation with piped UUID ==="
event list | get uu.0 | .append request "follow-up" --description "Follow up on the test event"

echo "=== Testing request-to-request attachment (parent-child relationship) ==="
let parent_request_uu = (request list | where name == "budget-review" | get uu.0)
.append request "sub-task-1" --description "Review Q1 financial data" --attach $parent_request_uu

echo "=== Testing request-to-request attachment with piped UUID ==="
request list | where name == "budget-review" | get uu.0 | .append request "sub-task-2" --description "Prepare quarterly presentation"

echo "=== Showing all requests to verify attachment ==="
request list | select name description table_name_uu_json

echo "=== Testing request processing ==="
let request_to_process = (request list | where name == "budget-review" | get uu.0)
request process $request_to_process

echo "=== Verifying processed status ==="
request get $request_to_process | select name is_processed