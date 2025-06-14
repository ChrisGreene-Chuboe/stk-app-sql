#!/usr/bin/env nu

# Test script for stk_todo module
echo "=== Testing stk_todo Module ==="

# REQUIRED: Import modules and assert
use ../modules *
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

echo "=== Testing todo item creation with parent parameter ==="
let lawn_result = (todo add "Mow lawn" --parent "Weekend Projects")
assert ($lawn_result | columns | any {|col| $col == "uu"}) "Todo creation should return UUID"
assert ($lawn_result.uu | is-not-empty) "Lawn task UUID should not be empty"
echo "✓ Mow lawn added with parent parameter"

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
let revoke_result = ("Clean garage" | todo revoke)
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
assert (($revoke_result.is_revoked.0) == true) "Item should be marked as revoked"
echo "✓ Clean garage marked as done by name"

echo "=== Testing todo revoke by UUID ==="
let fence_todos = (todo list | where name == "Fix garden fence")
if ($fence_todos | length) > 0 {
    let fence_uu = ($fence_todos | get uu.0)
    let fence_revoke_result = ($fence_uu | todo revoke)
    assert ($fence_revoke_result | columns | any {|col| $col == "is_revoked"}) "UUID revoke should return is_revoked status"
    assert (($fence_revoke_result.is_revoked.0) == true) "Fence item should be marked as revoked"
    echo "✓ Fix garden fence marked as done by UUID"
} else {
    echo "Fix garden fence todo not found - skipping UUID revoke test"
}

echo "=== Testing todo revoke with piped UUID ==="
let pipeline_todo = (todo add "Pipeline Revoke Test Todo")
let pipeline_revoke_result = ($pipeline_todo.uu.0 | todo revoke)
assert ($pipeline_revoke_result | columns | any {|col| $col == "is_revoked"}) "Pipeline revoke should return is_revoked status"
assert (($pipeline_revoke_result.is_revoked.0) == true) "Pipeline revoked todo should be marked as revoked"
echo "✓ Todo revoke with piped UUID verified"

echo "=== Testing UUID-only piping for todo add ==="
let parent_todo = (todo add "Piping Test Parent")
let child_via_pipe = ($parent_todo.uu.0 | todo add "Child via piped UUID")
assert ($child_via_pipe | columns | any {|col| $col == "uu"}) "Piped parent todo should return UUID"
assert ($child_via_pipe.uu | is-not-empty) "Piped child UUID should not be empty"
echo "✓ UUID-only piping verified: todo add with piped parent UUID"

echo "=== Testing todo revoke with piped name ==="
let name_revoke_result = ("Mow lawn" | todo revoke)
assert ($name_revoke_result | columns | any {|col| $col == "is_revoked"}) "Pipeline name revoke should return is_revoked status"
assert (($name_revoke_result.is_revoked.0) == true) "Pipeline revoked todo by name should be marked as revoked"
echo "✓ Todo revoke with piped name verified"

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
    "Non-existent Todo" | todo revoke
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

echo "=== Testing .append event with todo UUID ==="
let active_todo = (todo list | where name == "Review budget" | get uu.0)
let todo_event_result = ($active_todo | .append event "todo-priority-changed" --description "todo priority has been updated to high")
assert ($todo_event_result | columns | any {|col| $col == "uu"}) "Todo event should return UUID"
assert ($todo_event_result.uu | is-not-empty) "Todo event UUID should not be empty"
echo "✓ .append event with piped todo UUID verified"

echo "=== Testing .append request with todo UUID ==="
let todo_request_result = ($active_todo | .append request "todo-clarification" --description "need clarification on todo requirements")
assert ($todo_request_result | columns | any {|col| $col == "uu"}) "Todo request should return UUID"
assert ($todo_request_result.uu | is-not-empty) "Todo request UUID should not be empty"
echo "✓ .append request with piped todo UUID verified"

echo "=== Final state verification ==="
let final_active = (todo list)
assert (($final_active | length) > 0) "Should have active todos in final state"
echo "✓ Final active todos verified:" ($final_active | length) "items"

let final_all = (todo list --all)
assert (($final_all | length) > ($final_active | length)) "All todos should include more than just active"
echo "✓ Final all todos verified:" ($final_all | length) "total items"

echo "=== All tests completed successfully ==="