#!/usr/bin/env nu

# Test script for enhanced lines command with column selection
echo "=== Testing Enhanced lines Command ==="

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

echo "=== Setting up test data ==="
# Create a test project with lines
let test_project = (project new "Lines Column Test Project" --description "Testing enhanced lines command")
let project_uuid = ($test_project.uu.0)
echo $"Created project with UUID: ($project_uuid)"

# Create project lines with various data
let line1 = ($project_uuid | project line new "Line One" --description "First test line" --type-search-key "TASK")
let line2 = ($project_uuid | project line new "Line Two" --description "Second test line" --type-search-key "MILESTONE")
let line3 = ($project_uuid | project line new "Line Three" --type-search-key "DELIVERABLE")  # No description
echo "✓ Created 3 project lines"

echo "=== Test 1: Default behavior (name, description, search_key columns) ==="
let default_result = (project list | where name == "Lines Column Test Project" | lines)
assert ($default_result | columns | any {|col| $col == "lines"}) "Should have lines column"

let lines_data = ($default_result | get lines.0)
assert (($lines_data | length) == 3) "Should have 3 lines"

# Check that we have the default columns (that exist in the table)
let line_columns = ($lines_data | get 0 | columns)
echo $"Columns returned by default: ($line_columns)"

# Verify we have name and description (search_key likely doesn't exist in project_line)
assert ("name" in $line_columns) "Should include name column"
assert ("description" in $line_columns) "Should include description column"

# Verify we don't have all columns (e.g., no uu, created, etc.)
assert ("uu" not-in $line_columns) "Should NOT include uu in default view"
assert ("created" not-in $line_columns) "Should NOT include created in default view"
assert ("header_uu" not-in $line_columns) "Should NOT include header_uu in default view"
echo "✓ Default behavior verified - showing only default columns that exist"

echo "=== Test 2: --all flag (all columns) ==="
let all_result = (project list | where name == "Lines Column Test Project" | lines --all)
let all_lines_data = ($all_result | get lines.0)
let all_columns = ($all_lines_data | get 0 | columns)
echo $"Columns with --all flag: ($all_columns)"

# Verify we have all standard columns
assert ("uu" in $all_columns) "Should include uu with --all"
assert ("created" in $all_columns) "Should include created with --all"
assert ("header_uu" in $all_columns) "Should include header_uu with --all"
assert ("table_name" in $all_columns) "Should include table_name with --all"
assert ("type_uu" in $all_columns) "Should include type_uu with --all"

# Verify we have more columns than default
assert (($all_columns | length) > ($line_columns | length)) "--all should return more columns than default"
echo "✓ --all flag verified - showing all columns"

echo "=== Test 3: Custom column selection ==="
let custom_result = (project list | where name == "Lines Column Test Project" | lines name created uu)
let custom_lines_data = ($custom_result | get lines.0)
let custom_columns = ($custom_lines_data | get 0 | columns)
echo $"Custom columns: ($custom_columns)"

# Should have exactly the requested columns
assert ($custom_columns == ["name", "created", "uu"]) "Should have exactly the requested columns"
assert (($custom_columns | length) == 3) "Should have exactly 3 columns"
echo "✓ Custom column selection verified"

echo "=== Test 4: Verify line data integrity ==="
# Check that the data matches what we created
let line_names = ($lines_data | get name | sort)
assert ($line_names == ["Line One", "Line Three", "Line Two"]) "Line names should match"

# Check descriptions (Line Three has no description)
let line_one = ($lines_data | where name == "Line One" | get 0)
assert ($line_one.description == "First test line") "Line One description should match"

let line_three = ($lines_data | where name == "Line Three" | get 0)
# NOTE: Due to psql configuration, NULL values are returned as string "null"
assert ($line_three.description == "null") "Line Three should have null description"
echo "✓ Line data integrity verified"

echo "=== Test 5: Table without line table (using item) ==="
let test_item = (item new "Test Item for Lines")
let item_with_lines = ($test_item | lines)
assert ($item_with_lines | columns | any {|col| $col == "lines"}) "Should have lines column"
assert (($item_with_lines | get lines.0) == null) "Items should have null lines (no item_line table)"
echo "✓ Tables without line tables return null"

echo "=== Test 6: Empty lines (project with no lines) ==="
let empty_project = (project new "Empty Lines Project")
let empty_result = ($empty_project | lines)
assert ($empty_result | columns | any {|col| $col == "lines"}) "Should have lines column"
assert (($empty_result | get lines.0) == []) "Should have empty array for project with no lines"
echo "✓ Empty lines array verified"

echo "=== Test 7: Multiple records in pipeline ==="
# Get multiple projects with lines
let multi_result = (project list | where name =~ "Lines" | lines)
assert (($multi_result | length) >= 2) "Should have at least 2 projects"

# Each should have a lines column
$multi_result | each { |record|
    assert ("lines" in ($record | columns)) "Each record should have lines column"
}
echo "✓ Multiple records with lines verified"

echo "=== Test 8: Working with single records ==="
# When you need lines for a single record, wrap it in a list
let single_project = ($project_uuid | project get)
let single_with_lines = ([$single_project] | flatten | lines)
assert (($single_with_lines | length) == 1) "Should have one record"
assert ($single_with_lines | columns | any {|col| $col == "lines"}) "Should have lines column"
assert (($single_with_lines | get lines.0 | length) == 3) "Should have 3 lines"
echo "✓ Single record handling verified (wrap in list)"

echo "=== Test 9: Error handling - invalid column ==="
# The lines command gracefully handles errors by returning an error object
let result_with_error = (project list | where name == "Lines Column Test Project" | lines name fake_column)
let lines_result = ($result_with_error | get lines.0)

# Verify that an error was caught and handled
assert ($lines_result | describe | str contains "record") "Lines should contain error record"
assert ("error" in ($lines_result | columns)) "Should have error field"
assert (($lines_result.error | str length) > 0) "Should have error message"
echo "✓ Lines command handles errors gracefully"

echo "=== All tests completed successfully ==="