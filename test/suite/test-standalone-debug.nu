#!/usr/bin/env nu

# Debug standalone request
print "=== Testing Standalone Request ==="

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

# Create standalone request
print "Creating standalone request..."
let request = (.append request "standalone-test" --description "No attachment")
print $"Request created: ($request)"

# Get request details
let detail = ($request.uu.0 | request get)
print $"\nRequest details:"
print $"  table_name_uu_json: ($detail.table_name_uu_json)"
print $"  table_name_uu_json.0: ($detail.table_name_uu_json.0)"
print $"  table_name_uu_json type: ($detail.table_name_uu_json.0 | describe)"

# Check if it's the string "null"
print $"\nIs it 'null' string? (($detail.table_name_uu_json.0 == 'null'))"
print $"Is it null? (($detail.table_name_uu_json.0 == null))"
print $"Is it empty? (($detail.table_name_uu_json.0 | is-empty))"

# Return success message for test harness
"=== All tests completed successfully ==="