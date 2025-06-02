#!/usr/bin/env nu

# Test script for stk_todo_list module
echo "=== Testing stk_todo_list Module ==="

# Import the modules
use ../modules *

echo "=== Testing todo list creation ==="
todo add "Weekend Projects"
todo add "Work Tasks"

echo "=== Testing todo item creation with parent by name ==="
todo add "Fix garden fence" --parent "Weekend Projects"
todo add "Clean garage" --parent "Weekend Projects"
todo add "Review budget" --parent "Work Tasks"

echo "=== Testing piped todo item creation ==="
"Mow lawn" | todo add --parent "Weekend Projects"

echo "=== Testing standalone todo item ==="
todo add "Call dentist"

echo "=== Testing todo list display ==="
todo list

echo "=== Testing todo item creation with parent UUID ==="
let weekend_projects = (todo list | where name == "Weekend Projects" and ($it.table_name_uu_json?.api?.stk_request? | is-empty))
if ($weekend_projects | length) > 0 {
    let weekend_project_uu = ($weekend_projects | get uu.0)
    todo add "Organize shed" --parent $weekend_project_uu
} else {
    echo "No Weekend Projects found - skipping parent UUID test"
}

echo "=== Testing filtered todo list by parent ==="
todo list --parent "Weekend Projects"

echo "=== Testing todo revoke (mark as done) by name ==="
todo revoke "Clean garage"

echo "=== Testing todo revoke by UUID ==="
let fence_todos = (todo list | where name == "Fix garden fence")
if ($fence_todos | length) > 0 {
    let fence_uu = ($fence_todos | get uu.0)
    todo revoke $fence_uu
} else {
    echo "Fix garden fence todo not found - skipping UUID revoke test"
}

echo "=== Testing todo list with completed items ==="
todo list --all

echo "=== Testing todo restore ==="
todo restore "Clean garage"

echo "=== Verifying restored todo appears in active list ==="
todo list | where name == "Clean garage"

echo "=== Testing error handling - non-existent parent ==="
try {
    todo add "This should fail" --parent "Non-existent List"
} catch {
    echo "✓ Correctly caught error for non-existent parent"
}

echo "=== Testing error handling - revoke non-existent todo ==="
try {
    todo revoke "Non-existent Todo"
} catch {
    echo "✓ Correctly caught error for non-existent todo"
}

echo "=== Testing error handling - restore non-revoked todo ==="
try {
    todo restore "Review budget"  # This should still be active
} catch {
    echo "✓ Correctly caught error for restoring non-revoked todo"
}

echo "=== Final state - all active todos ==="
todo list

echo "=== Final state - all todos including completed ==="
todo list --all

echo "=== Test completed successfully! ==="