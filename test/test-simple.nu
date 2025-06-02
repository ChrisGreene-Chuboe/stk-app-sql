#!/usr/bin/env nu

# Simple test script
echo "=== Testing basic functionality ==="

# Import the modules  
use ../modules *
use std/assert

echo "=== Creating a simple standalone request ==="
let result = ("Test standalone request" | .append request "test-standalone")

echo "=== Verifying request was created successfully ==="
# Check that we got a result with a uu field
assert ($result | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
# Check that the uu field is not empty 
assert ($result.uu | is-not-empty) "UUID field should not be empty"
echo "✓ Request creation verified with UUID:" ($result.uu)