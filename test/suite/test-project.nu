#!/usr/bin/env nu

# Test script for stk_project module - UUID-only piping compatible
echo "=== Testing stk_project Module ==="

# REQUIRED: Import modules and assert
use ../modules *
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
let simple_line = ($project_uuid | project line new "User Authentication")
assert ($simple_line | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($simple_line.uu | is-not-empty) "UUID field should not be empty"
assert ($simple_line | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
assert ($simple_line.name.0 | str contains "User Authentication") "Name should match input"
echo "✓ Basic project line creation verified"

echo "=== Testing project line with description and type ==="
let described_line = ($project_uuid | project line new "Database Design" --description "Complete database design" --type-search-key "TASK")
assert ($described_line | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($described_line.uu | is-not-empty) "UUID field should not be empty"
assert ($described_line | columns | any {|col| $col == "description"}) "Result should contain 'description' field"
assert ($described_line.description.0 | str contains "Complete database design") "Description should match input"
echo "✓ Project line with description verified"

echo "=== Testing project line list with piped UUID ==="
let line_list = ($project_uuid | project line list)
assert (($line_list | length) >= 2) "Should return at least 2 lines (the ones we created)"
assert ($line_list | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($line_list | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
let line_names = ($line_list | get name)
assert ($line_names | any {|name| $name | str contains "User Authentication"}) "Should contain User Authentication line"
assert ($line_names | any {|name| $name | str contains "Database Design"}) "Should contain Database Design line"
echo "✓ Project line list with piped UUID verified"

echo "=== Testing UUID-only piping for project request ==="
let project_request_result = ($project_uuid | .append request "project-budget-approval" --description "need budget approval for project expansion")
assert ($project_request_result | columns | any {|col| $col == "uu"}) "Piped project request should return UUID"
assert ($project_request_result.uu | is-not-empty) "Project request UUID should not be empty"
echo "✓ UUID-only piping verified: .append request with piped project UUID"

echo "=== Testing UUID-only piping for project line request ==="
let line_uuid = ($simple_line.uu.0)
let line_request_result = ($line_uuid | .append request "line-requirements-clarification" --description "clarification needed on requirements")
assert ($line_request_result | columns | any {|col| $col == "uu"}) "Piped line request should return UUID"
assert ($line_request_result.uu | is-not-empty) "Line request UUID should not be empty"
echo "✓ UUID-only piping verified: .append request with piped project line UUID"

echo "=== Testing .append event with project UUID ==="
let project_event_result = ($project_uuid | .append event "project-milestone" --description "project milestone achieved")
assert ($project_event_result | columns | any {|col| $col == "uu"}) "Project event should return UUID"
assert ($project_event_result.uu | is-not-empty) "Project event UUID should not be empty"
echo "✓ .append event with piped project UUID verified"

echo "=== Testing .append event with project line UUID ==="
let line_event_result = ($line_uuid | .append event "line-completed" --description "project line completed successfully")
assert ($line_event_result | columns | any {|col| $col == "uu"}) "Line event should return UUID"
assert ($line_event_result.uu | is-not-empty) "Line event UUID should not be empty"
echo "✓ .append event with piped project line UUID verified"

echo "=== Testing project list command ==="
let projects_list = (project list)
assert (($projects_list | length) >= 1) "Should return at least one project"
assert ($projects_list | columns | any {|col| $col == "uu"}) "List should contain 'uu' field"
assert ($projects_list | columns | any {|col| $col == "name"}) "List should contain 'name' field"
echo "✓ Project list verified successfully"

echo "=== Testing project list --detail command ==="
let detailed_projects_list = (project list --detail)
assert (($detailed_projects_list | length) >= 1) "Should return at least one detailed project"
assert ($detailed_projects_list | columns | any {|col| $col == "type_enum"}) "Detailed list should contain 'type_enum' field"
assert ($detailed_projects_list | columns | any {|col| $col == "type_name"}) "Detailed list should contain 'type_name' field"
echo "✓ Project list --detail verified successfully"

echo "=== Testing project get command ==="
let first_project_uu = ($projects_list | get uu.0)
let retrieved_project = ($first_project_uu | project get)
assert (($retrieved_project | length) == 1) "Should return exactly one project"
assert ($retrieved_project | columns | any {|col| $col == "uu"}) "Retrieved project should contain 'uu' field"
assert ($retrieved_project.uu.0 == $first_project_uu) "Retrieved UUID should match requested UUID"
echo "✓ Project get verified for UUID:" $first_project_uu

echo "=== Testing project get --detail command ==="
let detailed_project = ($first_project_uu | project get --detail)
assert (($detailed_project | length) == 1) "Should return exactly one detailed project"
assert ($detailed_project | columns | any {|col| $col == "uu"}) "Detailed project should contain 'uu' field"
assert ($detailed_project | columns | any {|col| $col == "type_enum"}) "Detailed project should contain 'type_enum' field"
assert ($detailed_project | columns | any {|col| $col == "type_name"}) "Detailed project should contain 'type_name' field"
echo "✓ Project get --detail verified with type:" ($detailed_project.type_enum.0)

echo "=== Testing project line get command ==="
let first_line_uu = ($line_list | get uu.0)
let retrieved_line = ($first_line_uu | project line get)
assert (($retrieved_line | length) == 1) "Should return exactly one project line"
assert ($retrieved_line | columns | any {|col| $col == "uu"}) "Retrieved line should contain 'uu' field"
assert ($retrieved_line.uu.0 == $first_line_uu) "Retrieved line UUID should match requested UUID"
echo "✓ Project line get verified for UUID:" $first_line_uu

echo "=== Testing project line get --detail command ==="
let detailed_line = ($first_line_uu | project line get --detail)
assert (($detailed_line | length) == 1) "Should return exactly one detailed project line"
assert ($detailed_line | columns | any {|col| $col == "uu"}) "Detailed line should contain 'uu' field"
assert ($detailed_line | columns | any {|col| $col == "type_enum"}) "Detailed line should contain 'type_enum' field"
assert ($detailed_line | columns | any {|col| $col == "type_name"}) "Detailed line should contain 'type_name' field"
echo "✓ Project line get --detail verified with type:" ($detailed_line.type_enum.0)

echo "=== Testing project revoke with UUID piping ==="
let revoke_result = ($project_uuid | project revoke)
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
assert (($revoke_result.is_revoked.0) == true) "Project should be marked as revoked"
echo "✓ Project revoke with piped UUID verified"

echo "=== Testing lines command - Step 1: Basic functionality ==="
# Create a test project for lines
let lines_test_project = (project new "Lines Test Project")
let lines_project_uuid = ($lines_test_project.uu.0)

# Create some project lines
$lines_project_uuid | project line new "Task 1" --description "First task"
$lines_project_uuid | project line new "Task 2" --description "Second task"

echo "=== Testing lines command adds column ==="
let projects_with_lines = (project list | lines)
assert ($projects_with_lines | columns | any {|col| $col == "lines"}) "Result should contain 'lines' column"
echo "✓ Lines column added successfully"

echo "=== Testing lines content for stk_project ==="
let test_proj = ($projects_with_lines | where name == "Lines Test Project" | get 0)
assert ($test_proj.lines | is-not-empty) "Project should have lines"
assert (($test_proj.lines | length) == 2) "Project should have 2 lines"

# Check the line names
let line_names = ($test_proj.lines | get name)
assert ($line_names | any {|n| $n == "Task 1"}) "Should have Task 1"
assert ($line_names | any {|n| $n == "Task 2"}) "Should have Task 2"
echo "✓ Lines data fetched successfully"

echo "=== All tests completed successfully ==="