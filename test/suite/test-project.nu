#!/usr/bin/env nu

# Test script for stk_project module - UUID-only piping compatible
#print "=== Testing stk_project Module ==="

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

#print "=== Testing project types command ==="
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
#print "✓ Project types verified successfully"

#print "=== Testing project line types command ==="
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
#print "✓ Project line types verified successfully"

#print "=== Testing basic project creation ==="
let test_project = (project new "Website Redesign")
assert ($test_project | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($test_project.uu | is-not-empty) "UUID field should not be empty"
assert ($test_project | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
assert ($test_project.name.0 | str contains "Website Redesign") "Name should match input"
#print "✓ Basic project creation verified"

#print "=== Testing project creation with description ==="
let described_project = (project new "CRM Development" --description "Internal CRM system development")
assert ($described_project | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($described_project.uu | is-not-empty) "UUID field should not be empty"
assert ($described_project | columns | any {|col| $col == "description"}) "Result should contain 'description' field"
assert ($described_project.description.0 | str contains "Internal CRM system development") "Description should match input"
#print "✓ Project with description verified"

# Extract UUID for subsequent tests
let project_uuid = ($described_project.uu.0)
#print $"Using project UUID: ($project_uuid)"

#print "=== Testing project line creation ==="
let simple_line = ($project_uuid | project line new "User Authentication")
assert ($simple_line | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($simple_line.uu | is-not-empty) "UUID field should not be empty"
assert ($simple_line | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
assert ($simple_line.name.0 | str contains "User Authentication") "Name should match input"
#print "✓ Basic project line creation verified"

#print "=== Testing project line with description and type ==="
let described_line = ($project_uuid | project line new "Database Design" --description "Complete database design" --type-search-key "TASK")
assert ($described_line | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($described_line.uu | is-not-empty) "UUID field should not be empty"
assert ($described_line | columns | any {|col| $col == "description"}) "Result should contain 'description' field"
assert ($described_line.description.0 | str contains "Complete database design") "Description should match input"
#print "✓ Project line with description verified"

#print "=== Testing project line list with piped UUID ==="
let line_list = ($project_uuid | project line list)
assert (($line_list | length) >= 2) "Should return at least 2 lines (the ones we created)"
assert ($line_list | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($line_list | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
let line_names = ($line_list | get name)
assert ($line_names | any {|name| $name | str contains "User Authentication"}) "Should contain User Authentication line"
assert ($line_names | any {|name| $name | str contains "Database Design"}) "Should contain Database Design line"
#print "✓ Project line list with piped UUID verified"

#print "=== Testing UUID-only piping for project request ==="
let project_request_result = ($project_uuid | .append request "project-budget-approval" --description "need budget approval for project expansion")
assert ($project_request_result | columns | any {|col| $col == "uu"}) "Piped project request should return UUID"
assert ($project_request_result.uu | is-not-empty) "Project request UUID should not be empty"
#print "✓ UUID-only piping verified: .append request with piped project UUID"

#print "=== Testing UUID-only piping for project line request ==="
let line_uuid = ($simple_line.uu.0)
let line_request_result = ($line_uuid | .append request "line-requirements-clarification" --description "clarification needed on requirements")
assert ($line_request_result | columns | any {|col| $col == "uu"}) "Piped line request should return UUID"
assert ($line_request_result.uu | is-not-empty) "Line request UUID should not be empty"
#print "✓ UUID-only piping verified: .append request with piped project line UUID"

#print "=== Testing .append event with project UUID ==="
let project_event_result = ($project_uuid | .append event "project-milestone" --description "project milestone achieved")
assert ($project_event_result | columns | any {|col| $col == "uu"}) "Project event should return UUID"
assert ($project_event_result.uu | is-not-empty) "Project event UUID should not be empty"
#print "✓ .append event with piped project UUID verified"

#print "=== Testing .append event with project line UUID ==="
let line_event_result = ($line_uuid | .append event "line-completed" --description "project line completed successfully")
assert ($line_event_result | columns | any {|col| $col == "uu"}) "Line event should return UUID"
assert ($line_event_result.uu | is-not-empty) "Line event UUID should not be empty"
#print "✓ .append event with piped project line UUID verified"

#print "=== Testing project creation with parent UUID via pipe ==="
# Create a parent project first
let parent_project = (project new "Parent Project" --description "This is the parent project")
let parent_uuid = ($parent_project.uu.0)
#print $"Created parent project with UUID: ($parent_uuid)"

# Create sub-project using piped parent UUID
let sub_project = ($parent_uuid | project new "Sub-project via Pipe" --description "Created with piped parent UUID")
assert ($sub_project | columns | any {|col| $col == "uu"}) "Sub-project should have UUID"
assert ($sub_project.uu | is-not-empty) "Sub-project UUID should not be empty"
assert ($sub_project.name.0 | str contains "Sub-project via Pipe") "Sub-project name should match"

# Verify parent_uu is actually set in the returned data
assert ($sub_project | columns | any {|col| $col == "parent_uu"}) "Sub-project should have parent_uu column"
assert ($sub_project.parent_uu.0 == $parent_uuid) "Sub-project parent_uu should match parent UUID"
#print "✓ Sub-project creation with piped parent UUID verified"

#print "=== Testing multi-level hierarchy ==="
# Create grandchild project
let sub_uuid = ($sub_project.uu.0)
let grandchild = ($sub_uuid | project new "Grandchild Project" --description "Third level project")
assert ($grandchild.uu | is-not-empty) "Grandchild UUID should not be empty"
assert ($grandchild.parent_uu.0 == $sub_uuid) "Grandchild parent_uu should match sub-project UUID"
#print "✓ Multi-level project hierarchy verified"

#print "=== Testing parent UUID validation ==="
# Create a non-project UUID (using request)
let request = (.append request "test-request" --description "For validation testing")
let request_uuid = ($request.uu.0)

# Try to create project with non-project parent UUID - should fail
# Since psql validate-uuid-table throws immediately, we need to catch at the shell level
let invalid_result = (try { 
    $request_uuid | project new "Invalid Parent Test"
    {success: true}
} catch { |err|
    {success: false, error: $err.msg}
})
assert (not $invalid_result.success) "Should fail with non-project parent UUID"
assert ($invalid_result.error | str contains "not found in table stk_project") "Should show proper validation error"
#print "✓ Parent UUID validation verified - correctly rejects non-project UUIDs"

#print "=== Testing edge cases for parent UUID ==="
# Test with empty string
let empty_result = ("" | project new "Empty Parent Test")
assert ($empty_result.uu | is-not-empty) "Should create project with empty parent"
# NOTE: Due to psql configuration, NULL values are returned as string "null"
# This is a known issue that will be addressed in a future update
assert ($empty_result.parent_uu.0 == "null") "Should have null parent_uu with empty string input"

# Test with null (no piped input)
let null_result = (project new "No Parent Test")
assert ($null_result.uu | is-not-empty) "Should create project without parent"
# NOTE: Due to psql configuration, NULL values are returned as string "null"
assert ($null_result.parent_uu.0 == "null") "Should have null parent_uu without piped input"
#print "✓ Edge cases for parent UUID verified"

#print "=== Testing project new with table input ==="
# Create parent project
let table_parent = (project new "Parent for Table Test")
# Create sub-project using table input
let table_sub = (project list | where name == "Parent for Table Test" | project new "Sub via Table")
assert ($table_sub.uu | is-not-empty) "Should create sub-project with table input"
assert ($table_sub.parent_uu.0 == $table_parent.uu.0) "Sub-project parent_uu should match parent from table"
#print "✓ Project new with table input verified"

#print "=== Testing project new with record input ==="
# Create sub-project using record input
let record_sub = (project list | where name == "Parent for Table Test" | first | project new "Sub via Record")
assert ($record_sub.uu | is-not-empty) "Should create sub-project with record input"
assert ($record_sub.parent_uu.0 == $table_parent.uu.0) "Sub-project parent_uu should match parent from record"
#print "✓ Project new with record input verified"


#print "=== Testing project list command ==="
let projects_list = (project list)
assert (($projects_list | length) >= 1) "Should return at least one project"
assert ($projects_list | columns | any {|col| $col == "uu"}) "List should contain 'uu' field"
assert ($projects_list | columns | any {|col| $col == "name"}) "List should contain 'name' field"
#print "✓ Project list verified successfully"

#print "=== Testing project list includes type info ==="
let projects_list = (project list)
assert (($projects_list | length) >= 1) "Should return at least one project"
assert ($projects_list | columns | any {|col| $col == "type_enum"}) "List should contain 'type_enum' field"
assert ($projects_list | columns | any {|col| $col == "type_name"}) "List should contain 'type_name' field"
#print "✓ Project list verified successfully with type info"

#print "=== Testing project get command ==="
let first_project_uu = ($projects_list | get uu.0)
let retrieved_project = ($first_project_uu | project get)
assert ($retrieved_project | describe | str starts-with "record") "Should return a record, not a table"
assert ($retrieved_project | columns | any {|col| $col == "uu"}) "Retrieved project should contain 'uu' field"
assert ($retrieved_project.uu == $first_project_uu) "Retrieved UUID should match requested UUID"
#print "✓ Project get verified for UUID:" $first_project_uu

#print "=== Testing project get with --uu parameter ==="
let uu_param_project = (project get --uu $first_project_uu)
assert ($uu_param_project | describe | str starts-with "record") "Should return a record with --uu parameter"
assert ($uu_param_project.uu == $first_project_uu) "Retrieved UUID should match requested UUID with --uu"
#print "✓ Project get --uu parameter verified"

#print "=== Testing project get with table input ==="
let table_input_project = ($projects_list | where uu == $first_project_uu | project get)
assert ($table_input_project | describe | str starts-with "record") "Should return a record from table input"
assert ($table_input_project.uu == $first_project_uu) "Retrieved UUID should match from table input"
#print "✓ Project get with table input verified"

#print "=== Testing project get with record input ==="
let record_input_project = ($projects_list | where uu == $first_project_uu | get 0 | project get)
assert ($record_input_project | describe | str starts-with "record") "Should return a record from record input"
assert ($record_input_project.uu == $first_project_uu) "Retrieved UUID should match from record input"
#print "✓ Project get with record input verified"


#print "=== Testing project line get command ==="
let first_line_uu = ($line_list | get uu.0)
let retrieved_line = ($first_line_uu | project line get)
assert ($retrieved_line | describe | str starts-with "record") "Should return a record for project line"
assert ($retrieved_line | columns | any {|col| $col == "uu"}) "Retrieved line should contain 'uu' field"
assert ($retrieved_line.uu == $first_line_uu) "Retrieved line UUID should match requested UUID"
#print "✓ Project line get verified for UUID:" $first_line_uu

#print "=== Testing project line get with --uu parameter ==="
let uu_param_line = (project line get --uu $first_line_uu)
assert ($uu_param_line | describe | str starts-with "record") "Should return a record with --uu parameter"
assert ($uu_param_line.uu == $first_line_uu) "Retrieved line UUID should match requested UUID with --uu"
#print "✓ Project line get --uu parameter verified"

#print "=== Testing project line get with table input ==="
let table_input_line = ($line_list | where uu == $first_line_uu | project line get)
assert ($table_input_line | describe | str starts-with "record") "Should return a record from table input"
assert ($table_input_line.uu == $first_line_uu) "Retrieved line UUID should match from table input"
#print "✓ Project line get with table input verified"

#print "=== Testing project line get with record input ==="
let record_input_line = ($line_list | where uu == $first_line_uu | get 0 | project line get)
assert ($record_input_line | describe | str starts-with "record") "Should return a record from record input"
assert ($record_input_line.uu == $first_line_uu) "Retrieved line UUID should match from record input"
#print "✓ Project line get with record input verified"

#print "=== Testing project line new with table input ==="
# Create a project for line table input testing
let line_table_project = (project new "Project for Line Table Test")
# Create line using table input
let table_line = (project list | where name == "Project for Line Table Test" | project line new "Line via Table" --description "Created with table input")
assert ($table_line.uu | is-not-empty) "Should create project line with table input"
assert ($table_line.name.0 == "Line via Table") "Line name should match"
#print "✓ Project line new with table input verified"

#print "=== Testing project line new with record input ==="
# Create line using record input
let record_line = (project list | where name == "Project for Line Table Test" | first | project line new "Line via Record" --description "Created with record input")
assert ($record_line.uu | is-not-empty) "Should create project line with record input"
assert ($record_line.name.0 == "Line via Record") "Line name should match"
#print "✓ Project line new with record input verified"

#print "=== Testing project line list with table input ==="
# List lines using table input
let table_lines = (project list | where name == "Project for Line Table Test" | project line list)
assert (($table_lines | length) == 2) "Should list 2 lines with table input"
let table_line_names = ($table_lines | get name)
assert ($table_line_names | any {|n| $n == "Line via Table"}) "Should have Line via Table"
assert ($table_line_names | any {|n| $n == "Line via Record"}) "Should have Line via Record"
#print "✓ Project line list with table input verified"

#print "=== Testing project line list with record input ==="
# List lines using record input
let record_lines = (project list | where name == "Project for Line Table Test" | first | project line list)
assert (($record_lines | length) == 2) "Should list 2 lines with record input"
#print "✓ Project line list with record input verified"


#print "=== Testing project revoke with UUID piping ==="
let revoke_result = ($project_uuid | project revoke)
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
assert (($revoke_result.is_revoked.0) == true) "Project should be marked as revoked"
#print "✓ Project revoke with piped UUID verified"

#print "=== Testing project revoke with --uu parameter ==="
# Create a new project to revoke
let revoke_test_project = (project new "Project to Revoke via --uu")
let revoke_test_uuid = ($revoke_test_project.uu.0)
let uu_revoke_result = (project revoke --uu $revoke_test_uuid)
assert ($uu_revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke with --uu should return is_revoked status"
assert (($uu_revoke_result.is_revoked.0) == true) "Project should be marked as revoked via --uu"
#print "✓ Project revoke with --uu parameter verified"

#print "=== Testing project revoke with table input ==="
# Create another project to revoke
let table_revoke_project = (project new "Project to Revoke via Table")
let table_revoke_result = (project list | where name == "Project to Revoke via Table" | project revoke)
assert ($table_revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke with table should return is_revoked status"
assert (($table_revoke_result.is_revoked.0) == true) "Project should be marked as revoked via table input"
#print "✓ Project revoke with table input verified"

#print "=== Testing project line revoke with --uu parameter ==="
# Create a project and line for testing
let line_revoke_project = (project new "Project for Line Revoke Test")
let line_revoke_proj_uuid = ($line_revoke_project.uu.0)
let line_to_revoke = ($line_revoke_proj_uuid | project line new "Line to Revoke via --uu")
let line_revoke_uuid = ($line_to_revoke.uu.0)
let uu_line_revoke_result = (project line revoke --uu $line_revoke_uuid)
assert ($uu_line_revoke_result | columns | any {|col| $col == "is_revoked"}) "Line revoke with --uu should return is_revoked status"
assert (($uu_line_revoke_result.is_revoked.0) == true) "Project line should be marked as revoked via --uu"
#print "✓ Project line revoke with --uu parameter verified"

#print "=== Testing lines command - Step 1: Basic functionality ==="
# Create a test project for lines
let lines_test_project = (project new "Lines Test Project")
let lines_project_uuid = ($lines_test_project.uu.0)

# Create some project lines
$lines_project_uuid | project line new "Task 1" --description "First task"
$lines_project_uuid | project line new "Task 2" --description "Second task"

#print "=== Testing lines command adds column ==="
let projects_with_lines = (project list | lines)
assert ($projects_with_lines | columns | any {|col| $col == "lines"}) "Result should contain 'lines' column"
#print "✓ Lines column added successfully"

#print "=== Testing lines content for stk_project ==="
let test_proj = ($projects_with_lines | where name == "Lines Test Project" | get 0)
assert ($test_proj.lines | is-not-empty) "Project should have lines"
assert (($test_proj.lines | length) == 2) "Project should have 2 lines"

# Check the line names
let line_names = ($test_proj.lines | get name)
assert ($line_names | any {|n| $n == "Task 1"}) "Should have Task 1"
assert ($line_names | any {|n| $n == "Task 2"}) "Should have Task 2"
#print "✓ Lines data fetched successfully"

#print "=== Testing project creation with JSON data ==="
let json_project = (project new "Data Migration Project" --json '{"priority": "high", "estimated_hours": 120, "tech_stack": ["PostgreSQL", "Python", "Nushell"]}' --description "Complex data migration")
assert ($json_project | columns | any {|col| $col == "uu"}) "JSON project creation should return UUID"
assert ($json_project.uu | is-not-empty) "JSON project UUID should not be empty"
#print "✓ Project with JSON created, UUID:" ($json_project.uu)

#print "=== Verifying project's record_json field ==="
let json_project_detail = ($json_project.uu.0 | project get)
assert ($json_project_detail | describe | str starts-with "record") "Should return a record"
assert ($json_project_detail | columns | any {|col| $col == "record_json"}) "Project should have record_json column"
let stored_json = $json_project_detail.record_json
assert ($stored_json | columns | any {|col| $col == "priority"}) "JSON should contain priority field"
assert ($stored_json | columns | any {|col| $col == "estimated_hours"}) "JSON should contain estimated_hours field"
assert ($stored_json | columns | any {|col| $col == "tech_stack"}) "JSON should contain tech_stack field"
assert ($stored_json.priority == "high") "Priority should be high"
assert ($stored_json.estimated_hours == 120) "Estimated hours should be 120"
assert (($stored_json.tech_stack | length) == 3) "Tech stack should have 3 items"
#print "✓ JSON data verified: record_json contains structured data"

#print "=== Testing project creation without JSON (default behavior) ==="
let no_json_project = (project new "Simple Project" --description "Project without JSON metadata")
let no_json_detail = ($no_json_project.uu.0 | project get)
assert ($no_json_detail.record_json == {}) "record_json should be empty object when no JSON provided"
#print "✓ Default behavior verified: no JSON parameter results in empty JSON object"

#print "=== Testing project line creation with JSON data ==="
let json_line_project = (project new "Project for JSON Lines")
let json_line_uuid = ($json_line_project.uu.0)
let json_line = ($json_line_uuid | project line new "API Integration" --json '{"estimated_hours": 40, "priority": "high", "dependencies": ["auth-system", "database-layer"]}' --description "REST API integration task")
assert ($json_line | columns | any {|col| $col == "uu"}) "JSON line creation should return UUID"
assert ($json_line.uu | is-not-empty) "JSON line UUID should not be empty"
#print "✓ Project line with JSON created"

#print "=== Verifying project line's record_json field ==="
let json_line_detail = ($json_line.uu.0 | project line get)
assert ($json_line_detail | describe | str starts-with "record") "Should return a record"
assert ($json_line_detail | columns | any {|col| $col == "record_json"}) "Project line should have record_json column"
let line_stored_json = $json_line_detail.record_json
assert ($line_stored_json.estimated_hours == 40) "Line estimated hours should be 40"
assert ($line_stored_json.priority == "high") "Line priority should be high"
assert (($line_stored_json.dependencies | length) == 2) "Line should have 2 dependencies"
#print "✓ Project line JSON data verified"

#print "=== Testing complex nested JSON for project ==="
let complex_json = '{"budget": {"initial": 50000, "allocated": 35000, "currency": "USD"}, "team": {"size": 5, "roles": ["PM", "Dev", "QA", "UX", "DevOps"]}, "milestones": [{"name": "Phase 1", "date": "2024-03-01"}, {"name": "Phase 2", "date": "2024-06-01"}]}'
let complex_project = (project new "Enterprise Project" --json $complex_json --type-search-key "CLIENT")
let complex_detail = ($complex_project.uu.0 | project get)
let complex_stored = $complex_detail.record_json
assert ($complex_stored.budget.initial == 50000) "Initial budget should be 50000"
assert ($complex_stored.budget.currency == "USD") "Currency should be USD"
assert ($complex_stored.team.size == 5) "Team size should be 5"
assert (($complex_stored.milestones | length) == 2) "Should have 2 milestones"
assert ($complex_stored.milestones.0.name == "Phase 1") "First milestone should be Phase 1"
#print "✓ Complex nested JSON structure verified"

"=== All tests completed successfully ==="
