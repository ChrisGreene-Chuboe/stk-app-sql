#!/usr/bin/env nu

# Simple test script
echo "=== Testing Basic Functionality ==="

# REQUIRED: Import modules and assert
use ./modules *
use std/assert

echo "=== Creating a simple event ==="
let result = ("Test event content" | .append event "test-simple")

echo "=== Verifying event was created successfully ==="
# Check that we got a result with a uu field
assert ($result | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
# Check that the uu field is not empty 
assert ($result.uu | is-not-empty) "UUID field should not be empty"
echo "✓ Event creation verified with UUID:" ($result.uu)

echo "=== All tests completed successfully ==="