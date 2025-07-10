#!/usr/bin/env nu

# Test script for children command in stk_psql
# print "=== Testing children Command ==="

# Test-specific suffix to ensure test isolation and idempotency
# Generate random 2-char suffix from letters (upper/lower) and numbers
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_ch($random_suffix)"  # ch for children + 2 random chars

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

# print "=== Test 1: Table with parent_uu column (stk_project) ==="

# Create parent project
let parent_name = $"Parent Project($test_suffix)"
let parent = (project new $parent_name --description "Top-level project")
assert (($parent | columns | any {|col| $col == "uu"})) "Parent creation should return UUID"
let parent_uuid = $parent.uu
# print $"✓ Created parent project: ($parent_name), UUID: ($parent_uuid)"

# Create child projects
let child1_name = $"Child Project 1($test_suffix)"
let child2_name = $"Child Project 2($test_suffix)"
let child1 = ($parent_uuid | project new $child1_name --description "First sub-project")
let child2 = ($parent_uuid | project new $child2_name --description "Second sub-project")
# print "✓ Created 2 child projects"

# Test children command with default columns
let parent_with_children = (project list | where name == $parent_name | children)
assert (($parent_with_children | length) == 1) "Should return one parent record"
assert (("children" in ($parent_with_children.0 | columns))) "Should have children column"
assert (($parent_with_children.0.children | length) == 2) "Should have 2 children"
# print "✓ Default columns test passed"

# Verify default columns (name, description, type_uu)
let first_child = $parent_with_children.0.children.0
let child_columns = ($first_child | columns)
assert (("name" in $child_columns)) "Default columns should include name"
assert (("description" in $child_columns)) "Default columns should include description"
assert (("type_uu" in $child_columns)) "Default columns should include type_uu"
# print "✓ Default columns verified: name, description, type_uu"

# Test children command with specific columns
let parent_specific_cols = (project list | where name == $parent_name | children name created)
assert (($parent_specific_cols.0.children | length) == 2) "Should still have 2 children"
let specific_child_cols = ($parent_specific_cols.0.children.0 | columns)
assert (("name" in $specific_child_cols)) "Should have requested name column"
assert (("created" in $specific_child_cols)) "Should have requested created column"
assert (("description" not-in $specific_child_cols)) "Should not have unrequested description"
# print "✓ Specific columns test passed"

# Test children command with --detail flag
let parent_all_cols = (project list | where name == $parent_name | children --detail)
let all_child_cols = ($parent_all_cols.0.children.0 | columns)
assert (("uu" in $all_child_cols)) "All columns should include uu"
assert (("created_by_uu" in $all_child_cols)) "All columns should include created_by_uu"
assert (("is_revoked" in $all_child_cols)) "All columns should include is_revoked"
# print "✓ All columns test passed"

# print "=== Test 2: Table without parent_uu column (stk_item) ==="

# Create an item
let item_name = $"Test Item($test_suffix)"
let item = (item new $item_name --description "Test item for children")
# print $"✓ Created item: ($item_name)"

# Test children command on table without parent_uu
let item_with_children = (item list | where name == $item_name | children)
assert (($item_with_children | length) == 1) "Should return one item record"
assert (("children" in ($item_with_children.0 | columns))) "Should have children column"
assert (($item_with_children.0.children | length) == 0) "Should have empty array for children"
assert (($item_with_children.0.children | describe) == "list<any>") "Empty children should be a list"
# print "✓ Table without parent_uu returns empty array"

# print "=== Test 3: Record with no children ==="

# Create standalone project (no children)
let standalone_name = $"Standalone Project($test_suffix)"
let standalone = (project new $standalone_name --description "Project without children")
let standalone_with_children = (project list | where name == $standalone_name | children)
assert (($standalone_with_children.0.children | length) == 0) "Should have no children"
assert (($standalone_with_children.0.children | describe) == "list<any>") "Empty children should be a list"
# print "✓ Record with no children returns empty array"

# print "=== Test 4: Multiple records at once ==="

# Get all test projects and add children column
let all_test_projects = (project list | where name =~ $test_suffix | children)
assert (($all_test_projects | length) >= 3) "Should have at least 3 test projects"

# Count children for each
let children_counts = ($all_test_projects | each {|p| {name: $p.name, child_count: ($p.children | length)}})
let parent_count = ($children_counts | where child_count > 0 | length)
let childless_count = ($children_counts | where child_count == 0 | length)
assert (($parent_count) >= 1) "Should have at least 1 parent project"
assert (($childless_count) >= 2) "Should have at least 2 childless projects"
# print "✓ Multiple records processed correctly"

# print "=== Test 5: Revoked children exclusion ==="

# Create a child and then revoke it
let revoked_child_name = $"Revoked Child($test_suffix)"
let revoked_child = ($parent_uuid | project new $revoked_child_name)
let revoked_uuid = $revoked_child.uu

# Revoke the child
project revoke --uu $revoked_uuid
# print $"✓ Created and revoked child project"

# Check that revoked child is not included
let parent_after_revoke = (project list | where name == $parent_name | children)
assert (($parent_after_revoke.0.children | length) == 2) "Should still have only 2 active children"
let child_names = ($parent_after_revoke.0.children | get name)
assert (($revoked_child_name not-in $child_names)) "Revoked child should not be in children list"
# print "✓ Revoked children are properly excluded"

# print "=== Test 6: Edge case - empty input ==="
let empty_result = ([] | children)
assert (($empty_result | length) == 0) "Empty input should return empty array"
assert (($empty_result | describe) == "list<any>") "Empty result should be a list"
# print "✓ Empty input handled correctly"

# Return success message for test harness
"=== All tests completed successfully ==="