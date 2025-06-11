#!/usr/bin/env nu

# Test script for stk_project module
echo "=== Testing stk_project Module ==="

# REQUIRED: Import modules and assert
use ./modules *
use std/assert

echo "=== Testing project types command ==="
let types_result = (project types)

echo "=== Verifying project types were returned ==="
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

echo "=== Verifying project line types were returned ==="
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

echo "=== Testing basic project creation (default type) ==="
let simple_project = (project new "Website Redesign")

echo "=== Verifying basic project creation ==="
assert ($simple_project | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($simple_project.uu | is-not-empty) "UUID field should not be empty"
assert ($simple_project | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
assert ($simple_project.name.0 | str contains "Website Redesign") "Name should match input"
echo "✓ Basic project creation verified with UUID:" ($simple_project.uu)

echo "=== Testing project creation with description ==="
let described_project = (project new "CRM Development" --description "Internal CRM system development")

echo "=== Verifying project with description ==="
assert ($described_project | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($described_project.uu | is-not-empty) "UUID field should not be empty"
assert ($described_project | columns | any {|col| $col == "description"}) "Result should contain 'description' field"
assert ($described_project.description.0 | str contains "Internal CRM system development") "Description should match input"
echo "✓ Project with description verified with UUID:" ($described_project.uu)

echo "=== Testing project creation with specific type ==="
let typed_project = (project new "AI Research" --type "RESEARCH" --description "Research new AI technologies")

echo "=== Verifying typed project creation ==="
assert ($typed_project | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($typed_project.uu | is-not-empty) "UUID field should not be empty"
assert ($typed_project.name.0 | str contains "AI Research") "Name should match input"
echo "✓ Typed project creation verified with UUID:" ($typed_project.uu)

echo "=== Testing project list command ==="
let projects_list = (project list)

echo "=== Verifying project list results ==="
assert (($projects_list | length) >= 3) "Should return at least the 3 projects we created"
assert ($projects_list | columns | any {|col| $col == "uu"}) "List should contain 'uu' field"
assert ($projects_list | columns | any {|col| $col == "name"}) "List should contain 'name' field"
assert ($projects_list | columns | any {|col| $col == "created"}) "List should contain 'created' field"
assert ($projects_list | columns | any {|col| $col == "is_revoked"}) "List should contain 'is_revoked' field"

# Check that our created projects are in the list
let project_names = ($projects_list | get name)
assert ($project_names | any {|name| $name | str contains "Website Redesign"}) "Should find our website project in list"
assert ($project_names | any {|name| $name | str contains "CRM Development"}) "Should find our CRM project in list"
assert ($project_names | any {|name| $name | str contains "AI Research"}) "Should find our research project in list"
echo "✓ Project list verified successfully"

echo "=== Testing project get command ==="
let first_project_uu = ($projects_list | get uu.0)
let retrieved_project = (project get $first_project_uu)

echo "=== Verifying project get results ==="
assert (($retrieved_project | length) == 1) "Should return exactly one project"
assert ($retrieved_project | columns | any {|col| $col == "uu"}) "Retrieved project should contain 'uu' field"
assert ($retrieved_project.uu.0 == $first_project_uu) "Retrieved UUID should match requested UUID"
assert ($retrieved_project | columns | any {|col| $col == "name"}) "Retrieved project should contain 'name' field"
echo "✓ Project get verified for UUID:" $first_project_uu

echo "=== Testing project detail command ==="
let detailed_project = (project detail $first_project_uu)

echo "=== Verifying project detail results ==="
assert (($detailed_project | length) == 1) "Should return exactly one detailed project"
assert ($detailed_project | columns | any {|col| $col == "uu"}) "Detailed project should contain 'uu' field"
assert ($detailed_project | columns | any {|col| $col == "type_enum"}) "Detailed project should contain 'type_enum' field"
assert ($detailed_project | columns | any {|col| $col == "type_name"}) "Detailed project should contain 'type_name' field"
assert ($detailed_project.uu.0 == $first_project_uu) "Detailed UUID should match requested UUID"
echo "✓ Project detail verified with type:" ($detailed_project.type_enum.0)

# Use the second project for line testing
echo "=== Testing project line creation ==="
let test_project_uu = ($described_project.uu.0)
let simple_line = (project line new $test_project_uu "User Authentication")

echo "=== Verifying basic project line creation ==="
assert ($simple_line | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($simple_line.uu | is-not-empty) "UUID field should not be empty"
assert ($simple_line | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
assert ($simple_line.name.0 | str contains "User Authentication") "Name should match input"
echo "✓ Basic project line creation verified with UUID:" ($simple_line.uu)

echo "=== Testing project line creation with description and type ==="
let described_line = (project line new $test_project_uu "Database Design" --description "Complete database design" --type "TASK")

echo "=== Verifying project line with description ==="
assert ($described_line | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($described_line.uu | is-not-empty) "UUID field should not be empty"
assert ($described_line | columns | any {|col| $col == "description"}) "Result should contain 'description' field"
assert ($described_line.description.0 | str contains "Complete database design") "Description should match input"
echo "✓ Project line with description verified with UUID:" ($described_line.uu)

echo "=== Testing project line creation with milestone type ==="
let milestone_line = (project line new $test_project_uu "Production Deployment" --type "MILESTONE" --description "Deploy to production server")

echo "=== Verifying milestone line creation ==="
assert ($milestone_line | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($milestone_line.uu | is-not-empty) "UUID field should not be empty"
assert ($milestone_line.name.0 | str contains "Production Deployment") "Name should match input"
echo "✓ Milestone line creation verified with UUID:" ($milestone_line.uu)

echo "=== Testing project line list command ==="
let lines_list = (project line list $test_project_uu)

echo "=== Verifying project line list results ==="
assert (($lines_list | length) >= 3) "Should return at least the 3 lines we created"
assert ($lines_list | columns | any {|col| $col == "uu"}) "List should contain 'uu' field"
assert ($lines_list | columns | any {|col| $col == "name"}) "List should contain 'name' field"
assert ($lines_list | columns | any {|col| $col == "created"}) "List should contain 'created' field"
assert ($lines_list | columns | any {|col| $col == "is_revoked"}) "List should contain 'is_revoked' field"

# Check that our created lines are in the list
let line_names = ($lines_list | get name)
assert ($line_names | any {|name| $name | str contains "User Authentication"}) "Should find our auth line in list"
assert ($line_names | any {|name| $name | str contains "Database Design"}) "Should find our database line in list"
assert ($line_names | any {|name| $name | str contains "Production Deployment"}) "Should find our deployment line in list"
echo "✓ Project line list verified successfully"

echo "=== Testing project line get command ==="
let first_line_uu = ($lines_list | get uu.0)
let retrieved_line = (project line get $first_line_uu)

echo "=== Verifying project line get results ==="
assert (($retrieved_line | length) == 1) "Should return exactly one line"
assert ($retrieved_line | columns | any {|col| $col == "uu"}) "Retrieved line should contain 'uu' field"
assert ($retrieved_line.uu.0 == $first_line_uu) "Retrieved UUID should match requested UUID"
assert ($retrieved_line | columns | any {|col| $col == "name"}) "Retrieved line should contain 'name' field"
echo "✓ Project line get verified for UUID:" $first_line_uu

echo "=== Testing project line detail command ==="
let detailed_line = (project line detail $first_line_uu)

echo "=== Verifying project line detail results ==="
assert (($detailed_line | length) == 1) "Should return exactly one detailed line"
assert ($detailed_line | columns | any {|col| $col == "uu"}) "Detailed line should contain 'uu' field"
assert ($detailed_line | columns | any {|col| $col == "type_enum"}) "Detailed line should contain 'type_enum' field"
assert ($detailed_line | columns | any {|col| $col == "type_name"}) "Detailed line should contain 'type_name' field"
assert ($detailed_line.uu.0 == $first_line_uu) "Detailed UUID should match requested UUID"
echo "✓ Project line detail verified with type:" ($detailed_line.type_enum.0)

echo "=== Testing project revoke command ==="
let revoke_result = (project revoke $first_project_uu)

echo "=== Verifying project revoke results ==="
assert ($revoke_result | columns | any {|col| $col == "uu"}) "Revoke result should contain 'uu' field"
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke result should contain 'is_revoked' field"
assert ($revoke_result.uu.0 == $first_project_uu) "Revoked UUID should match requested UUID"
assert ($revoke_result.is_revoked.0) "Project should be marked as revoked"
echo "✓ Project revoke verified for UUID:" $first_project_uu

echo "=== Testing project line revoke command ==="
let line_revoke_result = (project line revoke $first_line_uu)

echo "=== Verifying project line revoke results ==="
assert ($line_revoke_result | columns | any {|col| $col == "uu"}) "Line revoke result should contain 'uu' field"
assert ($line_revoke_result | columns | any {|col| $col == "is_revoked"}) "Line revoke result should contain 'is_revoked' field"
assert ($line_revoke_result.uu.0 == $first_line_uu) "Revoked UUID should match requested UUID"
assert ($line_revoke_result.is_revoked.0) "Project line should be marked as revoked"
echo "✓ Project line revoke verified for UUID:" $first_line_uu

echo "=== Testing project revoke with piped UUID ==="
let pipeline_project = (project new "Pipeline Revoke Test Project")
let pipeline_revoke_result = ($pipeline_project.uu.0 | project revoke)
assert ($pipeline_revoke_result | columns | any {|col| $col == "is_revoked"}) "Pipeline revoke should return is_revoked status"
assert (($pipeline_revoke_result.is_revoked.0) == true) "Pipeline revoked project should be marked as revoked"
echo "✓ Project revoke with piped UUID verified"

echo "=== Testing project line revoke with piped UUID ==="
let pipeline_line = (project line new $test_project_uu "Pipeline Line Revoke Test")
let line_pipeline_revoke_result = ($pipeline_line.uu.0 | project line revoke)
assert ($line_pipeline_revoke_result | columns | any {|col| $col == "is_revoked"}) "Pipeline line revoke should return is_revoked status"
assert (($line_pipeline_revoke_result.is_revoked.0) == true) "Pipeline revoked line should be marked as revoked"
echo "✓ Project line revoke with piped UUID verified"

echo "=== Testing help examples ==="

echo "=== Example: Create a simple project ==="
let example_project1 = (project new "Mobile App Development")
assert ($example_project1 | columns | any {|col| $col == "uu"}) "Example project should be created successfully"
echo "✓ Help example 1 verified"

echo "=== Example: Create project with type and description ==="
let example_project2 = (project new "Server Maintenance" --type "MAINTENANCE")
assert ($example_project2 | columns | any {|col| $col == "uu"}) "Example typed project should be created successfully"
echo "✓ Help example 2 verified"

echo "=== Example: List and filter projects ==="
let filtered_projects = (project list | where name =~ "Development")
assert (($filtered_projects | length) >= 1) "Should find at least one development project"
echo "✓ Help example filtering verified"

echo "=== Example: Get project details ==="
let latest_project_uu = (project list | get uu.0)
let example_detail = (project detail $latest_project_uu)
assert ($example_detail | columns | any {|col| $col == "type_enum"}) "Example detail should include type information"
echo "✓ Help example detail verified"

echo "=== All tests completed successfully ==="