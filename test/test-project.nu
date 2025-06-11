#!/usr/bin/env nu

# Test script for stk_project module - UUID-only piping compatible
echo "=== Testing stk_project Module ==="

# REQUIRED: Import modules and assert
use ./modules *
use std/assert

echo "=== Testing project types command ==="
let types_result = (project types)
assert (($types_result | length) > 0) "Should return at least one project type"
assert ($types_result | columns | any {|col| $col == "type_enum"}) "Result should contain 'type_enum' field"
assert ($types_result | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($types_result | columns | any {|col| $col == "name"}) "Result should contain 'name' field"

# Check that expected types exist
let type_enums = ($types_result | get type_enum)
assert ($type_enums | any {|t| $t == "CLIENT"}) "Should have CLIENT type"
assert ($type_enums | any {|t| $t == "INTERNAL"}) "Should have INTERNAL type"
assert ($type_enums | any {|t| $t == "RESEARCH"}) "Should have RESEARCH type"
assert ($type_enums | any {|t| $t == "MAINTENANCE"}) "Should have MAINTENANCE type"
echo "✓ Project types verified successfully"

echo "=== Testing project line types command ==="
let line_types_result = (project line types)
assert (($line_types_result | length) > 0) "Should return at least one project line type"
assert ($line_types_result | columns | any {|col| $col == "type_enum"}) "Result should contain 'type_enum' field"
assert ($line_types_result | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($line_types_result | columns | any {|col| $col == "name"}) "Result should contain 'name' field"

# Check that expected line types exist
let line_type_enums = ($line_types_result | get type_enum)
assert ($line_type_enums | any {|t| $t == "TASK"}) "Should have TASK type"
assert ($line_type_enums | any {|t| $t == "MILESTONE"}) "Should have MILESTONE type"
assert ($line_type_enums | any {|t| $t == "DELIVERABLE"}) "Should have DELIVERABLE type"
assert ($line_type_enums | any {|t| $t == "RESOURCE"}) "Should have RESOURCE type"
echo "✓ Project line types verified successfully"

echo "=== Testing basic project creation ==="
let test_project = (project new "Website Redesign")
assert ($test_project | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($test_project.uu | is-not-empty) "UUID field should not be empty"
assert ($test_project | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
assert ($test_project.name.0 | str contains "Website Redesign") "Name should match input"
echo "✓ Basic project creation verified"

echo "=== Testing project creation with description ==="
let described_project = (project new "CRM Development" --description "Internal CRM system development")
assert ($described_project | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($described_project.uu | is-not-empty) "UUID field should not be empty"
assert ($described_project | columns | any {|col| $col == "description"}) "Result should contain 'description' field"
assert ($described_project.description.0 | str contains "Internal CRM system development") "Description should match input"
echo "✓ Project with description verified"

# Extract UUID for subsequent tests
let project_uuid = ($described_project.uu.0)
echo $"Using project UUID: ($project_uuid)"

echo "=== Testing project line creation ==="
let simple_line = (project line new $project_uuid "User Authentication")
assert ($simple_line | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($simple_line.uu | is-not-empty) "UUID field should not be empty"
assert ($simple_line | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
assert ($simple_line.name.0 | str contains "User Authentication") "Name should match input"
echo "✓ Basic project line creation verified"

echo "=== Testing project line with description and type ==="
let described_line = (project line new $project_uuid "Database Design" --description "Complete database design" --type "TASK")
assert ($described_line | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($described_line.uu | is-not-empty) "UUID field should not be empty"
assert ($described_line | columns | any {|col| $col == "description"}) "Result should contain 'description' field"
assert ($described_line.description.0 | str contains "Complete database design") "Description should match input"
echo "✓ Project line with description verified"

echo "=== Testing UUID-only piping for project request ==="
let project_request_result = ($project_uuid | project request --description "need budget approval for project expansion")
assert ($project_request_result | columns | any {|col| $col == "uu"}) "Piped project request should return UUID"
assert ($project_request_result.uu | is-not-empty) "Project request UUID should not be empty"
echo "✓ UUID-only piping verified: project request with piped UUID"

echo "=== Testing UUID-only piping for project line request ==="
let line_uuid = ($simple_line.uu.0)
let line_request_result = ($line_uuid | project line request --description "clarification needed on requirements")
assert ($line_request_result | columns | any {|col| $col == "uu"}) "Piped line request should return UUID"
assert ($line_request_result.uu | is-not-empty) "Line request UUID should not be empty"
echo "✓ UUID-only piping verified: project line request with piped UUID"

echo "=== Testing project revoke with UUID piping ==="
let revoke_result = ($project_uuid | project revoke)
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
assert (($revoke_result.is_revoked.0) == true) "Project should be marked as revoked"
echo "✓ Project revoke with piped UUID verified"

echo "=== All tests completed successfully ==="