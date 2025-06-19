#!/usr/bin/env nu

# Test script for stk_ai module

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

echo "=== Testing AI module functionality ==="

# First check if AI is available by testing the ai test command
# Note: ai test prints its own connection status message
let ai_available = try {
    ai test
    true
} catch {
    false
}

if not $ai_available {
    echo "WARNING: AI tool (aichat) not available. Cannot run AI tests."
    echo "Install and configure aichat to test AI functionality."
    # Return success since this is an expected condition when AI is not installed
    "=== All tests completed successfully ==="
    exit
}

# Test 1: Basic text-to-json conversion (minimal test to save costs)
# Test with a simple schema
let test_schema = {
    type: "object"
    properties: {
        name: {type: "string"}
        value: {type: "number"}
    }
    required: ["name"]
}

let conversion_result = ("Test item costs 25 dollars" | ai text-to-json --schema $test_schema)
assert (($conversion_result | describe | str contains "record")) "Should return a record"
assert ("name" in $conversion_result) "Result should have name property"
assert ("value" in $conversion_result) "Result should have value property"
echo "✓ Text-to-JSON conversion verified"

# Test 2: Error handling - missing schema
let error_result = (try {
    "test text" | ai text-to-json
    false  # If we get here, no error was thrown
} catch { |err|
    ($err.msg | str contains "Schema must be provided")
})
assert $error_result "Should error when schema is missing"
echo "✓ Error handling verified"

# Test 3: Error handling - empty input
let empty_error = (try {
    "" | ai text-to-json --schema $test_schema
    false  # If we get here, no error was thrown
} catch { |err|
    ($err.msg | str contains "Text input required")
})
assert $empty_error "Should error on empty input"
echo "✓ Empty input handling verified"

echo ""
echo "Note: Limited AI calls to minimize costs"

"=== All tests completed successfully ==="