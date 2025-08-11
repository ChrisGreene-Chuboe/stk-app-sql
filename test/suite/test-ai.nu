#!/usr/bin/env nu

# Test script for stk_ai module

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

# === Testing AI module functionality ===
# print "=== Testing AI module functionality ===" # COMMENTED OUT - uncomment only for debugging

# First check if AI is available by testing the ai test command
# Note: ai test prints its own connection status message
let ai_available = try {
    ai test
    true
} catch {
    false
}

if not $ai_available {
    print "WARNING: AI tool (claude) not available. Cannot run AI tests."
    print "Ensure claude CLI is installed and configured."
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

# Test 2: Complex schema conversion (validates capabilities needed by other modules)
# Test with a schema similar to what address module would use, but generic
let complex_schema = {
    type: "object"
    properties: {
        field1: {type: "string"}
        field2: {type: "string"}
        field3: {type: "string"}
        field4: {type: "string"}
        field5: {type: "string"}
    }
    required: ["field1", "field3", "field5"]
}

# Test that AI can extract structured data from unstructured text
let complex_result = ("Main item at location Austin code 78701" | ai text-to-json --schema $complex_schema)
assert (($complex_result | describe | str contains "record")) "Should return record for complex schema"
assert ("field1" in $complex_result) "Should have field1"
assert ("field3" in $complex_result) "Should have field3"
assert ("field5" in $complex_result) "Should have field5"

# Verify required fields are not null (critical for schema validation)
assert ($complex_result.field1 != null) "Required field1 should not be null"
assert ($complex_result.field3 != null) "Required field3 should not be null"
assert ($complex_result.field5 != null) "Required field5 should not be null"

# Test that all required fields have values (not empty strings)
assert ($complex_result.field1 | is-not-empty) "Required field1 should have content"
assert ($complex_result.field3 | is-not-empty) "Required field3 should have content"
assert ($complex_result.field5 | is-not-empty) "Required field5 should have content"
# print "✓ Complex schema conversion verified" # COMMENTED OUT

# Test 3: Error handling - missing schema
let error_result = (try {
    "test text" | ai text-to-json
    false  # If we get here, no error was thrown
} catch { |err|
    ($err.msg | str contains "Schema must be provided")
})
assert $error_result "Should error when schema is missing"
#print "✓ Error handling verified"

# Test 4: Error handling - empty input
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
