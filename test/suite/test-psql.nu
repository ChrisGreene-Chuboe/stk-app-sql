#!/usr/bin/env nu

# Test script for stk_psql module

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

# Test 1: Basic functionality
# Test that valid queries work correctly
let basic_result = (psql exec "SELECT 1 as test_value, 'hello' as test_text")
assert (($basic_result | length) == 1) "Should return one row"
assert ($basic_result.0.test_value == "1") "Should return correct numeric value"
assert ($basic_result.0.test_text == "hello") "Should return correct text value"

# Test 2: Error handling
# Test that SQL errors can be caught with try/catch
let error_result = (try {
    psql exec "SELECT column_that_does_not_exist FROM table_does_not_exist"
    false  # If we get here, no error was thrown
} catch { |err|
    # Verify error message contains expected content
    ($err.msg | str contains "PostgreSQL error:") and ($err.msg | str contains "does not exist")
})

assert $error_result "SQL errors should be catchable and contain PostgreSQL error message"

# Test 3: Date column conversion
# Test that created/updated columns are converted to datetime
let date_result = (psql exec "SELECT now() as created, now() as updated")
assert (($date_result.0.created | describe | str contains "date")) "Created should be datetime"
assert (($date_result.0.updated | describe | str contains "date")) "Updated should be datetime"

# Test 4: Boolean column conversion
# Test that is_* and has_* columns are converted to boolean
let bool_result = (psql exec "SELECT true as is_active, false as has_data")
assert ($bool_result.0.is_active == true) "is_active should be true"
assert ($bool_result.0.has_data == false) "has_data should be false"

# Test 5: JSON column handling
# Test that *_json columns are parsed
let json_result = (psql exec "SELECT '{\"key\": \"value\"}'::jsonb as test_json")
assert (($json_result.0.test_json | describe | str contains "record")) "JSON should be parsed as record"
assert ($json_result.0.test_json.key == "value") "JSON content should be accessible"

"=== All tests completed successfully ==="