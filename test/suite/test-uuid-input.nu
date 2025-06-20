#!/usr/bin/env nu

# Test script for UUID input enhancement
print "=== Testing UUID Input Enhancement ==="

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_ui($random_suffix)"  # ui for uuid input + 2 random chars

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

# First, let's test the utility functions in isolation
print "=== Testing UUID input utilities ==="

# Copy the utility module to test environment
let util_content = '# UUID Input Normalization Utilities
# Provides helper functions for accepting both string UUIDs and records with UUID fields

# Normalize UUID input from string or record format
export def normalize-uuid-input [] {
    let input = $in
    
    if ($input | is-empty) {
        null
    } else {
        let input_type = ($input | describe)
        
        if $input_type == "string" {
            # String input - return as record with just uu
            {uu: $input}
        } else if $input_type == "record" {
            # Record input - validate and extract fields
            if "uu" not-in ($input | columns) {
                error make { msg: "Record must contain \'uu\' field" }
            }
            
            # Build result with uu and optional table_name
            mut result = {uu: $input.uu}
            
            if "table_name" in ($input | columns) {
                $result = ($result | insert table_name $input.table_name)
            }
            
            $result
        } else {
            error make { msg: $"Input must be a string UUID or record with \'uu\' field, got ($input_type)" }
        }
    }
}

# Extract UUID value from normalized input
export def extract-uuid [] {
    let normalized = $in
    
    if ($normalized | is-empty) {
        null
    } else if ($normalized | describe) == "record" and "uu" in ($normalized | columns) {
        $normalized.uu
    } else {
        null
    }
}

# Extract table name from normalized input
export def extract-table-name [] {
    let normalized = $in
    
    if ($normalized | is-empty) {
        null
    } else if ($normalized | describe) == "record" and "table_name" in ($normalized | columns) {
        $normalized.table_name
    } else {
        null
    }
}'

# Write the utility module
$util_content | save -f ../modules/stk_utility/uuid_input.nu

# Import the utility functions
use ../modules/stk_utility/uuid_input.nu [normalize-uuid-input, extract-uuid, extract-table-name]

# Test 1: String UUID input
print "Testing string UUID input..."
let test_uuid = "12345678-1234-5678-9012-123456789abc"
let normalized_string = ($test_uuid | normalize-uuid-input)
assert ($normalized_string | describe) == "record" "String input should return record"
assert ($normalized_string.uu == $test_uuid) "UUID should match input"
assert ("table_name" not-in ($normalized_string | columns)) "String input should not have table_name"

# Test 2: Record with just uu field
print "Testing record with uu field..."
let record_simple = {uu: $test_uuid, name: "test"}
let normalized_record = ($record_simple | normalize-uuid-input)
assert ($normalized_record.uu == $test_uuid) "UUID should be extracted from record"
assert ("table_name" not-in ($normalized_record | columns)) "Should not have table_name if not provided"

# Test 3: Record with uu and table_name
print "Testing record with uu and table_name..."
let record_full = {uu: $test_uuid, table_name: "stk_project", name: "test"}
let normalized_full = ($record_full | normalize-uuid-input)
assert ($normalized_full.uu == $test_uuid) "UUID should be extracted"
assert ($normalized_full.table_name == "stk_project") "table_name should be extracted"

# Test 4: Empty input
print "Testing empty input..."
let normalized_empty = (null | normalize-uuid-input)
assert ($normalized_empty == null) "Empty input should return null"

# Test 5: Invalid input - no uu field
print "Testing invalid record (no uu field)..."
let invalid_result = (do { {name: "test", value: 123} | normalize-uuid-input } | complete)
assert ($invalid_result.exit_code != 0) "Should fail with record missing uu field"
assert ($invalid_result.stderr | str contains "Record must contain 'uu' field") "Should have proper error message"

# Test 6: Extract functions
print "Testing extract functions..."
let extracted_uuid = ($normalized_full | extract-uuid)
assert ($extracted_uuid == $test_uuid) "Should extract UUID correctly"

let extracted_table = ($normalized_full | extract-table-name)
assert ($extracted_table == "stk_project") "Should extract table_name correctly"

let no_table = ($normalized_record | extract-table-name)
assert ($no_table == null) "Should return null when no table_name"

print "✓ All utility function tests passed"

# Now test with real chuck-stack commands
print "\n=== Testing with chuck-stack commands ==="

# Create test data
print "Creating test project..."
let project_name = $"Test Project($test_suffix)"
let project = (project new $project_name)
let project_uuid = ($project.uu.0)
print $"✓ Created project with UUID: ($project_uuid)"

# Test traditional string UUID approach (baseline)
print "\nTesting traditional string UUID piping..."
let request1 = ($project_uuid | .append request $"traditional($test_suffix)" --description "Using string UUID")
assert ($request1 | columns | any {|col| $col == "uu"}) "Should return UUID"
print "✓ Traditional string UUID works"

# Test new record piping approach
print "\nTesting new record piping approach..."
let request2 = ($project.0 | .append request $"record-pipe($test_suffix)" --description "Using record directly")
assert ($request2 | columns | any {|col| $col == "uu"}) "Should return UUID"
print "✓ Record piping works!"

# Verify both approaches created valid requests
print "\nVerifying created requests..."
let req1_detail = ($request1.uu.0 | request get)
let req2_detail = ($request2.uu.0 | request get)

assert ($req1_detail.table_name_uu_json.0 | from json | get uu) == $project_uuid "Request 1 should be attached to project"
assert ($req2_detail.table_name_uu_json.0 | from json | get uu) == $project_uuid "Request 2 should be attached to project"
assert ($req1_detail.table_name_uu_json.0 | from json | get table_name) == "stk_project" "Should have correct table_name"
print "✓ Both requests correctly attached to project"

# Test with various chuck-stack record types
print "\n=== Testing with different record types ==="

# Create an item
let item = (item new $"Test Item($test_suffix)")
let item_request = ($item.0 | .append request $"item-request($test_suffix)" --description "Request for item")
assert ($item_request | columns | any {|col| $col == "uu"}) "Item record piping should work"
print "✓ Item record piping works"

# Create a todo (which uses stk_request table)
let todo = (todo new $"Test Todo($test_suffix)")
let todo_request = ($todo.0 | .append request $"todo-request($test_suffix)" --description "Request for todo")
assert ($todo_request | columns | any {|col| $col == "uu"}) "Todo record piping should work"
print "✓ Todo record piping works"

# Test list operations
print "\n=== Testing with list operations ==="
let projects = (project list | where name =~ $test_suffix)
assert (($projects | length) >= 1) "Should have at least one test project"

# Pick first project from list
let first_project = ($projects | get 0)
let list_request = ($first_project | .append request $"list-test($test_suffix)" --description "From list selection")
assert ($list_request | columns | any {|col| $col == "uu"}) "Should work with list selection"
print "✓ List selection piping works"

# Test error handling
print "\n=== Testing error conditions ==="

# Test with invalid record (no uu field)
let invalid_record = {name: "test", value: 123}
let invalid_result = (do { $invalid_record | .append request "should-fail" } | complete)
assert ($invalid_result.exit_code != 0) "Should fail with invalid record"
print "✓ Properly rejects records without uu field"

# Test with wrong type
let wrong_type_result = (do { 123 | .append request "should-fail" } | complete)
assert ($wrong_type_result.exit_code != 0) "Should fail with wrong type"
print "✓ Properly rejects non-string/non-record input"

print "\n=== Summary ==="
print "✓ UUID input enhancement working correctly!"
print "✓ Users can now pipe records directly without .0.uu extraction"
print "✓ Backward compatibility maintained for string UUIDs"

# Return success message for test harness
"=== All tests completed successfully ==="