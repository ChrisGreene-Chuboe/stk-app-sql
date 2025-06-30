#!/usr/bin/env nu

# Test script for stk_ai module

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

#print "=== Testing AI module functionality ==="

# First check if AI is available by testing the ai test command
# Note: ai test prints its own connection status message
let ai_available = try {
    ai test
    true
} catch {
    false
}

if not $ai_available {
    print "WARNING: AI tool (aichat) not available. Cannot run AI tests."
    print "Install and configure aichat to test AI functionality."
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
#print "✓ Text-to-JSON conversion verified"

# Test 2: Error handling - missing schema
let error_result = (try {
    "test text" | ai text-to-json
    false  # If we get here, no error was thrown
} catch { |err|
    ($err.msg | str contains "Schema must be provided")
})
assert $error_result "Should error when schema is missing"
#print "✓ Error handling verified"

# Test 3: Error handling - empty input
let empty_error = (try {
    "" | ai text-to-json --schema $test_schema
    false  # If we get here, no error was thrown
} catch { |err|
    ($err.msg | str contains "Text input required")
})
assert $empty_error "Should error on empty input"
#print "✓ Empty input handling verified"

#print ""
#print "Note: Limited AI calls to minimize costs"

"=== All tests completed successfully ==="
