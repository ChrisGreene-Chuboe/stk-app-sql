#!/usr/bin/env nu

# Test script for stk_todo module
# Template Version: 2025-01-05

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_st($random_suffix)"

# Import modules and assert
use ../modules *
use std/assert

# === Testing CRUD operations ===

# print "=== Testing todo overview command ==="
# Note: Module commands are nushell functions, not external commands, so we can't use complete
# Just verify it runs without error
todo
# If we get here, the command succeeded

# print "=== Testing todo creation ==="
let created = (todo new $"Test todo($test_suffix)")
assert ($created | is-not-empty) "Should create todo"
assert ($created.uu | is-not-empty) "Should have UUID"
assert ($created.name.0 | str contains $test_suffix) "Name should contain test suffix"

# print "=== Testing todo list ==="
let list_result = (todo list)
assert ($list_result | where name =~ $test_suffix | is-not-empty) "Should find created todo"

# print "=== Testing todo get ==="
let get_result = ($created.uu.0 | todo get)
assert ($get_result.uu == $created.uu.0) "Should get correct record"

# print "=== Testing todo get (type info always included) ==="
let get_with_type = ($created.uu.0 | todo get)
assert ($get_with_type | columns | any {|col| $col | str contains "type"}) "Should include type info"

# print "=== Testing todo revoke ==="
let revoke_result = ($created.uu.0 | todo revoke)
assert ($revoke_result.is_revoked.0 == true) "Should be revoked"

# print "=== Testing todo list --all ==="
let all_list = (todo list --all | where name =~ $test_suffix)
assert ($all_list | where is_revoked == true | is-not-empty) "Should show revoked records"

# === Testing UUID input variations ===

# Create parent for UUID testing
let parent = (todo new $"Parent todo($test_suffix)")
let parent_uu = ($parent.uu.0)

# print "=== Testing todo get with string UUID ==="
let get_string = ($parent_uu | todo get)
assert ($get_string.uu == $parent_uu) "Should get correct record with string UUID"

# print "=== Testing todo get with record input ==="
let get_record = ($parent | first | todo get)
assert ($get_record.uu == $parent_uu) "Should get correct record from record input"

# print "=== Testing todo get with table input ==="
let get_table = ($parent | todo get)
assert ($get_table.uu == $parent_uu) "Should get correct record from table input"

# print "=== Testing todo get with --uu parameter ==="
let get_param = (todo get --uu $parent_uu)
assert ($get_param.uu == $parent_uu) "Should get correct record with --uu parameter"

# print "=== Testing todo get with empty table (should fail) ==="
try {
    [] | todo get
    error make {msg: "Empty table should have failed"}
} catch {
    # print "  ✓ Empty table correctly rejected"
}

# print "=== Testing todo get with multi-row table ==="
let multi_table = [$parent, $parent] | flatten
let get_multi = ($multi_table | todo get)
assert ($get_multi.uu == $parent_uu) "Should use first row from multi-row table"

# print "=== Testing todo revoke with string UUID ==="
let revoke_item = (todo new $"Revoke Test($test_suffix)")
let revoke_string = ($revoke_item.uu.0 | todo revoke)
assert ($revoke_string.is_revoked.0 == true) "Should revoke with string UUID"

# print "=== Testing todo revoke with --uu parameter ==="
let revoke_item2 = (todo new $"Revoke Test 2($test_suffix)")
let revoke_param = (todo revoke --uu $revoke_item2.uu.0)
assert ($revoke_param.is_revoked.0 == true) "Should revoke with --uu parameter"

# print "=== Testing todo revoke with record input ==="
let revoke_item3 = (todo new $"Revoke Test 3($test_suffix)")
let revoke_record = ($revoke_item3 | first | todo revoke)
assert ($revoke_record.is_revoked.0 == true) "Should revoke from record input"

# print "=== Testing todo revoke with table input ==="
let revoke_item4 = (todo new $"Revoke Test 4($test_suffix)")
let revoke_table = ($revoke_item4 | todo revoke)
assert ($revoke_table.is_revoked.0 == true) "Should revoke from table input"

# === Testing type support ===

# print "=== Testing todo types ==="
let types = (todo types)
assert ($types | is-not-empty) "Should have types"
assert ($types | columns | any {|col| $col == "uu"}) "Types should have uu"
assert ($types | columns | any {|col| $col == "search_key"}) "Types should have search_key"

# Note: Todo is a domain wrapper - it uses stk_request table with TODO type
# Types are filtered and not settable via todo new command

# === Testing JSON parameter ===

# print "=== Testing todo creation with JSON ==="
let json_created = (todo new $"JSON Test($test_suffix)" --json '{"test": true, "value": 42}')
assert ($json_created | is-not-empty) "Should create with JSON"

# print "=== Verifying stored JSON ==="
let json_detail = ($json_created.uu.0 | todo get)
assert ($json_detail.record_json.test == true) "Should store JSON test field"
assert ($json_detail.record_json.value == 42) "Should store JSON value field"

# print "=== Testing todo creation without JSON (default) ==="
let no_json = (todo new $"No JSON Test($test_suffix)")
let no_json_detail = ($no_json.uu.0 | todo get)
assert ($no_json_detail.record_json == {}) "Should default to empty object"

# print "=== Testing todo creation with complex JSON ==="
let complex_json = '{"nested": {"deep": {"value": "found"}}, "array": [1, 2, 3]}'
let complex_created = (todo new $"Complex JSON($test_suffix)" --json $complex_json)
let complex_detail = ($complex_created.uu.0 | todo get)
assert ($complex_detail.record_json.nested.deep.value == "found") "Should store nested JSON"
assert (($complex_detail.record_json.array | length) == 3) "Should store JSON arrays"

# === Additional todo-specific tests ===

# print "=== Testing todo parent-child pattern ==="
let parent_todo = (todo new $"Parent Task($test_suffix)" --description "Main task")
let child_todo = ($parent_todo.uu.0 | todo new $"Child Task($test_suffix)" --description "Subtask")
assert ($child_todo | is-not-empty) "Should create child todo"
let child_detail = ($child_todo.uu.0 | todo get)
assert ($child_detail.table_name_uu_json != {}) "Child should have attachment to parent"

# Note: Todos can only have other todos as parents (via piped input)
# To attach a todo to a non-todo entity, use .append request on that entity instead

# print "=== Testing todo list filtering ==="
# Since todo is a wrapper, it should only show TODO type requests
let todo_list = (todo list | where name =~ $test_suffix)
assert (($todo_list | length) > 0) "Should find todos"
# All items from todo list should be processable by todo commands
let first_todo = ($todo_list | first)
let todo_verify = ($first_todo.uu | todo get)
assert ($todo_verify | is-not-empty) "Todo list items should work with todo get"

# print "=== Testing todo with description ==="
let described = (todo new $"Described todo($test_suffix)" --description "Important task details")
let described_detail = ($described.uu.0 | todo get)
assert ($described_detail.description == "Important task details") "Should store description"

# print "=== Testing todo list (type info always included) ==="
let list_with_type = (todo list | where name =~ $test_suffix)
assert ($list_with_type | is-not-empty) "Should list with type info"
assert ($list_with_type | columns | any {|col| $col == "type_name"}) "Should include type_name"
assert ($list_with_type | columns | any {|col| $col == "type_enum"}) "Should include type_enum"

# print "=== Testing .append event on todo ==="
let todo_for_event = (todo new $"Event Test Todo($test_suffix)")
let todo_event = ($todo_for_event.uu.0 | .append event $"status-changed($test_suffix)" --description "Todo completed")
assert ($todo_event | is-not-empty) "Should create event"
assert ($todo_event.uu | is-not-empty) "Event should have UUID"

# print "=== Testing .append request on todo ==="
# Note: Since todo IS a request, this creates a child request
let todo_for_request = (todo new $"Request Test Todo($test_suffix)")
let todo_request = ($todo_for_request.uu.0 | .append request $"follow-up($test_suffix)" --description "Additional work needed")
assert ($todo_request | is-not-empty) "Should create request"
assert ($todo_request.uu | is-not-empty) "Request should have UUID"

"=== All tests completed successfully ==="