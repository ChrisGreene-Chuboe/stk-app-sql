#!/usr/bin/env nu

# Debug normalize-uuid-input
print "=== Testing normalize-uuid-input ==="

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

# Test the function exists
print "Testing if normalize-uuid-input exists..."
let test_uuid = "12345678-1234-5678-9012-123456789abc"
let result = ($test_uuid | normalize-uuid-input)
print $"Result: ($result)"
print $"Type: ($result | describe)"

# Test with record
print "\nTesting with record..."
let record = {uu: $test_uuid, name: "test"}
let result2 = ($record | normalize-uuid-input)
print $"Result: ($result2)"
print $"Type: ($result2 | describe)"

# Return success message for test harness
"=== All tests completed successfully ==="