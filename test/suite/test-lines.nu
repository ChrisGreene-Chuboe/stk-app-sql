#!/usr/bin/env nu

# Test script for enhanced lines command with column selection
#print "=== Testing Enhanced lines Command ==="

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

#print "=== Setting up test data ==="
# Create a test project with lines
let test_project = (project new "Lines Column Test Project" --description "Testing enhanced lines command")
let project_uuid = $test_project.uu
#print $"Created project with UUID: ($project_uuid)"

# Create project lines with various data
let line1 = ($project_uuid | project line new "Line One" --description "First test line" --type-search-key "TASK")
let line2 = ($project_uuid | project line new "Line Two" --description "Second test line" --type-search-key "MILESTONE")
let line3 = ($project_uuid | project line new "Line Three" --type-search-key "DELIVERABLE")  # No description
#print "✓ Created 3 project lines"

#print "=== Test 1: Default behavior (name, description, search_key columns) ==="
let default_result = (project list | where name == "Lines Column Test Project" | lines)
assert ($default_result | columns | any {|col| $col == "lines"}) "Should have lines column"

let lines_data = ($default_result.lines.0)
assert (($lines_data | length) == 3) "Should have 3 lines"

# Check that we have the default columns (that exist in the table)
let line_columns = ($lines_data | get 0 | columns)
#print $"Columns returned by default: ($line_columns)"

# Verify we have name and description (search_key likely doesn't exist in project_line)
assert ("name" in $line_columns) "Should include name column"
assert ("description" in $line_columns) "Should include description column"

# Verify we don't have all columns (e.g., no uu, created, etc.)
assert ("uu" not-in $line_columns) "Should NOT include uu in default view"
assert ("created" not-in $line_columns) "Should NOT include created in default view"
assert ("header_uu" not-in $line_columns) "Should NOT include header_uu in default view"
#print "✓ Default behavior verified - showing only default columns that exist"

#print "=== Test 2: --detail flag (all columns) ==="
let all_result = (project list | where name == "Lines Column Test Project" | lines --detail)
let all_lines_data = ($all_result.lines.0)
let all_columns = ($all_lines_data | get 0 | columns)
#print $"Columns with --detail flag: ($all_columns)"

# Verify we have all standard columns
assert ("uu" in $all_columns) "Should include uu with --detail"
assert ("created" in $all_columns) "Should include created with --detail"
assert ("header_uu" in $all_columns) "Should include header_uu with --detail"
assert ("table_name" in $all_columns) "Should include table_name with --detail"
assert ("type_uu" in $all_columns) "Should include type_uu with --detail"

# Verify we have more columns than default
assert (($all_columns | length) > ($line_columns | length)) "--detail should return more columns than default"
#print "✓ --detail flag verified - showing all columns"

#print "=== Test 3: Custom column selection ==="
let custom_result = (project list | where name == "Lines Column Test Project" | lines name created uu)
let custom_lines_data = ($custom_result.lines.0)
let custom_columns = ($custom_lines_data | get 0 | columns)
#print $"Custom columns: ($custom_columns)"

# Should have exactly the requested columns
assert ($custom_columns == ["name", "created", "uu"]) "Should have exactly the requested columns"
assert (($custom_columns | length) == 3) "Should have exactly 3 columns"
#print "✓ Custom column selection verified"

#print "=== Test 4: Verify line data integrity ==="
# Check that the data matches what we created
let line_names = ($lines_data | get name | sort)
assert ($line_names == ["Line One", "Line Three", "Line Two"]) "Line names should match"

# Check descriptions (Line Three has no description)
let line_one = ($lines_data | where name == "Line One" | get 0)
assert ($line_one.description == "First test line") "Line One description should match"

let line_three = ($lines_data | where name == "Line Three" | get 0)
# NOTE: Due to psql configuration, NULL values are returned as string "null"
assert ($line_three.description == "null") "Line Three should have null description"
#print "✓ Line data integrity verified"

#print "=== Test 5: Table without line table (using item) ==="
let test_item = (item new "Test Item for Lines")
let item_with_lines = ($test_item | lines)
assert ($item_with_lines | columns | any {|col| $col == "lines"}) "Should have lines column"
assert ($item_with_lines.lines == null) "Items should have null lines (no item_line table)"
#print "✓ Tables without line tables return null"

#print "=== Test 6: Empty lines (project with no lines) ==="
let empty_project = (project new "Empty Lines Project")
let empty_result = ($empty_project | lines)
assert ($empty_result | columns | any {|col| $col == "lines"}) "Should have lines column"
assert ($empty_result.lines == []) "Should have empty array for project with no lines"
#print "✓ Empty lines array verified"

#print "=== Test 7: Multiple records in pipeline ==="
# Get multiple projects with lines
let multi_result = (project list | where name =~ "Lines" | lines)
assert (($multi_result | length) >= 2) "Should have at least 2 projects"

# Each should have a lines column
$multi_result | each { |record|
    assert ("lines" in ($record | columns)) "Each record should have lines column"
}
#print "✓ Multiple records with lines verified"

#print "=== Test 8: Working with single records ==="
# lines command now handles both records and tables
let single_project = ($project_uuid | project get)
let single_with_lines = ($single_project | lines)
assert (($single_with_lines | describe | str starts-with "record")) "Should return a record when given a record"
assert ($single_with_lines | columns | any {|col| $col == "lines"}) "Should have lines column"
assert (($single_with_lines.lines | length) == 3) "Should have 3 lines"
#print "✓ Single record handling verified (direct record input)"

#print "=== Test 9: Error handling - invalid column ==="
# The lines command gracefully handles errors by returning an error object
let result_with_error = (project list | where name == "Lines Column Test Project" | lines name fake_column)
let lines_result = ($result_with_error.lines.0)

# Verify that an error was caught and handled
assert ($lines_result | describe | str contains "record") "Lines should contain error record"
assert ("error" in ($lines_result | columns)) "Should have error field"
assert (($lines_result.error | str length) > 0) "Should have error message"
#print "✓ Lines command handles errors gracefully"

#print "=== Test 10: --all flag (include revoked records) ==="
# Create a project line and then revoke it
let revoked_line = ($project_uuid | project line new "Revoked Line" --description "Will be revoked")
let revoked_uuid = $revoked_line.uu
$revoked_uuid | project line revoke

# Without --all, should not see revoked line
let active_only = (project list | where name == "Lines Column Test Project" | lines)
let active_lines = ($active_only.lines.0)
assert (($active_lines | where name == "Revoked Line" | length) == 0) "Default should not show revoked lines"
assert (($active_lines | length) == 3) "Should still have 3 active lines"

# With --all, should see revoked line
let all_including_revoked = (project list | where name == "Lines Column Test Project" | lines --all)
let all_lines = ($all_including_revoked.lines.0)
assert (($all_lines | where name == "Revoked Line" | length) == 1) "--all should show revoked lines"
assert (($all_lines | length) == 4) "Should have 4 lines total (3 active + 1 revoked)"
#print "✓ --all flag verified - includes revoked records"

#print "=== Test 11: --table flag forces table output ==="
# Test that --table flag always returns a table, even for single record
let single_for_table = ($project_uuid | project get)
let forced_table = ($single_for_table | lines --table)
assert (($forced_table | describe | str starts-with "table")) "Should return a table with --table flag"
assert (($forced_table | length) == 1) "Table should have one row"
assert (($forced_table.lines.0 | length) == 3) "Should have 3 active lines"
#print "✓ --table flag forces table output verified"

"=== All tests completed successfully ==="
