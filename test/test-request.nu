#!/usr/bin/env nu

# Test script for stk_request module
echo "=== Testing stk_request Nushell Module ==="

# Import the modules
use ../modules *

echo "=== Testing standalone request creation ==="
"Review quarterly budget" | .append request "budget-review"

echo "=== Testing request list ==="
request list

echo "=== Testing request get ==="
let request_uu = (request list | get uu.0)
request get $request_uu

echo "=== Creating test event for attachment test ==="  
"test event for attachment" | .append event "test-attachment"

echo "=== Testing attached request creation ==="
let event_uu = (event list | get uu.0)
"Fix critical bug in authentication" | .append request "bug-fix" --attach $event_uu

echo "=== Showing all requests to verify attachment ==="
request list | select name description table_name_uu_json

echo "=== Testing request processing ==="
let request_to_process = (request list | where name == "budget-review" | get uu.0)
request process $request_to_process

echo "=== Verifying processed status ==="
request get $request_to_process | select name is_processed