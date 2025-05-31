#!/usr/bin/env nu

# Test script for stk_event module
echo "=== Testing stk_event Module with Constants ==="

# Import the modules
use ../modules *

echo "=== Testing event creation ==="
"Test event with constants" | .append event "test-constants"

echo "=== Testing event list ==="
event list

echo "=== Testing event get ==="
let event_uu = (event list | get uu.0)
event get $event_uu

echo "=== Testing event request functionality ==="
"investigate this event" | event request $event_uu

echo "=== Verifying request was created ==="
request list | select name description table_name_uu_json

echo "=== Testing event revoke ==="
event revoke $event_uu

echo "=== Verifying revoked status ==="
event get $event_uu | select name is_revoked