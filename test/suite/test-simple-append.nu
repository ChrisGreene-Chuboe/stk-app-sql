#!/usr/bin/env nu

# Simple test for .append request UUID input
echo "=== Testing Simple .append request ==="

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

# Test 1: Create standalone request
echo "Test 1: Standalone request..."
let request1 = (.append request "test-standalone" --description "No attachment")
echo $"Created request: ($request1)"
echo $"Columns: ($request1 | columns)"

# Test 2: Create request with string UUID
echo "\nTest 2: String UUID attachment..."
let project = (project new "Test Project")
echo $"Created project: ($project)"
let project_uuid = $project.0.uu
let request2 = ($project_uuid | .append request "test-string" --description "String UUID")
echo $"Created request: ($request2)"

# Test 3: Create request with record
echo "\nTest 3: Record attachment..."
let request3 = ($project.0 | .append request "test-record" --description "Record input")
echo $"Created request: ($request3)"

# Test 4: Create request with table
echo "\nTest 4: Table attachment..."
let projects = (project list | take 1)
echo $"Projects table: ($projects)"
let request4 = ($projects | .append request "test-table" --description "Table input")
echo $"Created request: ($request4)"

# Return success message for test harness
"=== All tests completed successfully ==="