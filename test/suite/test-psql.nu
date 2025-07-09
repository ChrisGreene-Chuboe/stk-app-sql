#!/usr/bin/env nu

# Test script for stk_psql module
# Template version: 2025-01-08
# print "=== Testing stk_psql Module ==="

# Test-specific suffix to ensure test isolation and idempotency
# Generate random 2-char suffix from letters (upper/lower) and numbers
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_ps($random_suffix)"  # ps for psql + 2 random chars

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

# print "=== Testing psql get-table-name-uu command ==="

# Create a test project to get a valid UUID
let test_project = (project new $"Test Project($test_suffix)")
let project_uuid = ($test_project.uu)

# Test the new psql get-table-name-uu command
let result = (psql get-table-name-uu $project_uuid)
assert ((($result | describe) | str starts-with "record")) "Should return a record"
assert (("table_name" in ($result | columns))) "Should have table_name field"
assert (("uu" in ($result | columns))) "Should have uu field"
assert (($result.table_name == "stk_project")) "Table name should be stk_project"
assert (($result.uu == $project_uuid)) "UUID should match input"
#print "✓ psql get-table-name-uu verified for project"

# Test with different table types
let test_item = (item new $"Test Item($test_suffix)")
let item_uuid = ($test_item.uu)
let item_result = (psql get-table-name-uu $item_uuid)
assert (($item_result.table_name == "stk_item")) "Should identify stk_item table"
assert (($item_result.uu == $item_uuid)) "UUID should match"
#print "✓ psql get-table-name-uu verified for item"

# Test with request
let test_request = (.append request $"Test Request($test_suffix)")
let request_uuid = ($test_request.uu)
let request_result = (psql get-table-name-uu $request_uuid)
assert (($request_result.table_name == "stk_request")) "Should identify stk_request table"
assert (($request_result.uu == $request_uuid)) "UUID should match"
#print "✓ psql get-table-name-uu verified for request"

# Test error handling with non-existent UUID
# print "=== Testing error handling for non-existent UUID ==="
try {
    # Use a random UUID that definitely won't exist
    let non_existent_uuid = "99999999-9999-9999-9999-999999999999"
    psql get-table-name-uu $non_existent_uuid
    assert false "Should have thrown error for non-existent UUID"
} catch { |err|
    assert (($err.msg | str contains "UUID not found")) "Error message should indicate UUID not found"
    #print "✓ Error handling verified for non-existent UUID"
}

# Return success string as final expression
"=== All tests completed successfully ==="
