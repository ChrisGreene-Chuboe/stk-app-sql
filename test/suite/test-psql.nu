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

# print "=== Testing psql list-records --where parameter ==="

# Create a business partner and contacts for testing
let test_bp = (bp new $"Test Company($test_suffix)")
let bp_uuid = $test_bp.uu

# Create contacts with and without the business partner link
let contact1 = ($test_bp | contact new $"Contact One($test_suffix)")
let contact2 = ($test_bp | contact new $"Contact Two($test_suffix)")
let contact3 = (contact new $"Contact Three($test_suffix)")  # No BP link

# Test basic --where filtering
let filtered_contacts = (psql list-records "api" "stk_contact" --where {stk_business_partner_uu: $bp_uuid})
assert (($filtered_contacts | length) >= 2) "Should find at least 2 contacts for the business partner"
assert (($filtered_contacts | all {|c| $c.stk_business_partner_uu == $bp_uuid})) "All results should have the correct business partner UUID"
#print "✓ Basic --where filtering verified"

# Test multiple conditions with --where
let multi_filter = (psql list-records "api" "stk_contact" --where {stk_business_partner_uu: $bp_uuid, is_valid: true})
assert (($multi_filter | all {|c| $c.stk_business_partner_uu == $bp_uuid and $c.is_valid == true})) "All results should match both conditions"
#print "✓ Multiple condition --where filtering verified"

# Test --where with null value
let null_filter = (psql list-records "api" "stk_contact" --where {stk_business_partner_uu: null} --limit 50)
assert (($null_filter | any {|c| $c.name == $contact3.name})) "Should find contact without business partner"
# Check that our specific test contact has null BP
# Note: PostgreSQL returns NULL as string "null" due to .psqlrc-nu configuration
let our_contact = ($null_filter | where name == $contact3.name | first)
assert ($our_contact.stk_business_partner_uu == "null") "Our test contact should have null business partner"
#print "✓ NULL value --where filtering verified"

# Test empty --where (should behave same as no --where)
let empty_where = (psql list-records "api" "stk_contact" --where {})
let no_where = (psql list-records "api" "stk_contact")
assert (($empty_where | length) == ($no_where | length)) "Empty --where should return same results as no --where"
#print "✓ Empty --where parameter verified"

# Return success string as final expression
"=== All tests completed successfully ==="
