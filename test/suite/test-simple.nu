#!/usr/bin/env nu

# Simple test script
#print "=== Testing Basic Functionality ==="

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

#print "=== Creating a simple event ==="
let result = (.append event "test-simple" --description "Test event content")

#print "=== Verifying event was created successfully ==="
# Check that we got a result with a uu field
assert ($result | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
# Check that the uu field is not empty 
assert ($result.uu | is-not-empty) "UUID field should not be empty"
#print "✓ Event creation verified with UUID:" ($result.uu)

"=== All tests completed successfully ==="
