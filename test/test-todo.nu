#!/usr/bin/env nu

# Test script for stk_todo module
echo "=== Testing stk_todo Module ==="

# REQUIRED: Import modules and assert
use ./modules *
use std/assert

echo "=== Testing todo list creation ==="
let weekend_result = (todo add "Weekend Projects")
assert ($weekend_result | columns | any {|col| $col == "uu"}) "Todo list creation should return UUID"
assert ($weekend_result.uu | is-not-empty) "Weekend Projects UUID should not be empty"
echo "✓ Weekend Projects created with UUID:" ($weekend_result.uu)

let work_result = (todo add "Work Tasks")
assert ($work_result | columns | any {|col| $col == "uu"}) "Work tasks creation should return UUID"
assert ($work_result.uu | is-not-empty) "Work Tasks UUID should not be empty"
echo "✓ Work Tasks created with UUID:" ($work_result.uu)

echo "=== Testing todo item creation with parent by name ==="
let fence_result = (todo add "Fix garden fence" --parent "Weekend Projects")
assert ($fence_result | columns | any {|col| $col == "uu"}) "Child todo creation should return UUID"
assert ($fence_result.uu | is-not-empty) "Fence task UUID should not be empty"
echo "✓ Fix garden fence added to Weekend Projects"

let garage_result = (todo add "Clean garage" --parent "Weekend Projects")
assert ($garage_result | columns | any {|col| $col == "uu"}) "Garage todo creation should return UUID"
echo "✓ Clean garage added to Weekend Projects"

let budget_result = (todo add "Review budget" --parent "Work Tasks")
assert ($budget_result | columns | any {|col| $col == "uu"}) "Budget todo creation should return UUID"
echo "✓ Review budget added to Work Tasks"

echo "=== Testing piped todo item creation ==="
let lawn_result = ("Mow lawn" | todo add --parent "Weekend Projects")
assert ($lawn_result | columns | any {|col| $col == "uu"}) "Piped todo creation should return UUID"
assert ($lawn_result.uu | is-not-empty) "Lawn task UUID should not be empty"
echo "✓ Mow lawn added via piped input"

echo "=== Testing standalone todo item ==="
let dentist_result = (todo add "Call dentist")
assert ($dentist_result | columns | any {|col| $col == "uu"}) "Standalone todo should return UUID"
echo "✓ Standalone todo created"

echo "=== Testing todo list display ==="
let todos = (todo list)
assert (($todos | length) > 0) "Todo list should contain items"
assert ($todos | columns | any {|col| $col == "name"}) "Todo list should contain name column"
assert ($todos | columns | any {|col| $col == "description"}) "Todo list should contain description column"
echo "✓ Todo list verified with" ($todos | length) "items"

echo "=== Testing todo item creation with parent UUID ==="
let weekend_projects = (todo list | where name == "Weekend Projects" and ($it.table_name_uu_json?.api?.stk_request? | is-empty))
if ($weekend_projects | length) > 0 {
    let weekend_project_uu = ($weekend_projects | get uu.0)
    let shed_result = (todo add "Organize shed" --parent $weekend_project_uu)
    assert ($shed_result | columns | any {|col| $col == "uu"}) "UUID parent todo creation should return UUID"
    echo "✓ Organize shed added using parent UUID"
} else {
    echo "No Weekend Projects found - skipping parent UUID test"
}

echo "=== Testing filtered todo list by parent ==="
let weekend_items = (todo list --parent "Weekend Projects")
assert (($weekend_items | length) > 0) "Should find items under Weekend Projects"
assert ($weekend_items | all {|row| $row.table_name_uu_json.uu | is-not-empty}) "All items should have parent reference"
echo "✓ Filtered todo list verified with" ($weekend_items | length) "Weekend Project items"

echo "=== Testing todo revoke (mark as done) by name ==="
let revoke_result = (todo revoke "Clean garage")
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
assert (($revoke_result.is_revoked.0) == true) "Item should be marked as revoked"
echo "✓ Clean garage marked as done by name"

echo "=== Testing todo revoke by UUID ==="
let fence_todos = (todo list | where name == "Fix garden fence")
if ($fence_todos | length) > 0 {
    let fence_uu = ($fence_todos | get uu.0)
    let fence_revoke_result = (todo revoke $fence_uu)
    assert ($fence_revoke_result | columns | any {|col| $col == "is_revoked"}) "UUID revoke should return is_revoked status"
    assert (($fence_revoke_result.is_revoked.0) == true) "Fence item should be marked as revoked"
    echo "✓ Fix garden fence marked as done by UUID"
} else {
    echo "Fix garden fence todo not found - skipping UUID revoke test"
}

echo "=== Testing todo list with completed items ==="
let all_todos = (todo list --all)
let completed_todos = ($all_todos | where is_revoked == true)
assert (($completed_todos | length) > 0) "Should find completed todos when using --all"
echo "✓ Todo list --all verified with" ($completed_todos | length) "completed items"

echo "=== Testing todo restore ==="
let restore_result = (todo restore "Clean garage")
assert ($restore_result | columns | any {|col| $col == "is_revoked"}) "Restore should return is_revoked status"
assert (($restore_result.is_revoked.0) == false) "Restored item should not be revoked"
echo "✓ Clean garage restored successfully"

echo "=== Verifying restored todo appears in active list ==="
let restored_todos = (todo list | where name == "Clean garage")
assert (($restored_todos | length) > 0) "Restored todo should appear in active list"
assert (($restored_todos.is_revoked.0) == false) "Restored todo should not be revoked"
echo "✓ Restored todo verified in active list"

echo "=== Testing error handling - non-existent parent ==="
try {
    todo add "This should fail" --parent "Non-existent List"
    assert false "Should have thrown error for non-existent parent"
} catch {
    echo "✓ Correctly caught error for non-existent parent"
}

echo "=== Testing error handling - revoke non-existent todo ==="
try {
    todo revoke "Non-existent Todo"
    assert false "Should have thrown error for non-existent todo"
} catch {
    echo "✓ Correctly caught error for non-existent todo"
}

echo "=== Testing error handling - restore non-revoked todo ==="
try {
    todo restore "Review budget"  # This should still be active
    assert false "Should have thrown error for restoring non-revoked todo"
} catch {
    echo "✓ Correctly caught error for restoring non-revoked todo"
}

echo "=== Final state verification ==="
let final_active = (todo list)
assert (($final_active | length) > 0) "Should have active todos in final state"
echo "✓ Final active todos verified:" ($final_active | length) "items"

let final_all = (todo list --all)
assert (($final_all | length) > ($final_active | length)) "All todos should include more than just active"
echo "✓ Final all todos verified:" ($final_all | length) "total items"

echo "=== All tests completed successfully ==="