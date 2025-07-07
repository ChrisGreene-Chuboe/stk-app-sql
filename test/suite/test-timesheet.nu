#!/usr/bin/env nu

# Test script for stk_timesheet module
# Template Version: 2025-01-05

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_ts($random_suffix)"

# Import modules and assert
use ../modules *
use std/assert

# === Testing CRUD operations ===

# print "=== Testing timesheet overview command ==="
# Note: Module commands are nushell functions, not external commands, so we can't use complete
# Just verify it runs without error
timesheet
# If we get here, the command succeeded

# print "=== Testing timesheet creation (using .append pattern) ==="
# Timesheets need to be attached to something, so create a project first
let project = (project new $"Timesheet Test Project($test_suffix)")
let project_uu = ($project.uu.0)

let created = ($project_uu | .append timesheet --minutes 60 --description "Test work")
assert ($created | is-not-empty) "Should create timesheet"
assert ($created.uu | is-not-empty) "Should have UUID"
# Name format may vary - just verify it exists
assert ($created.name.0 | is-not-empty) "Should have name"

# print "=== Testing timesheet list ==="
let list_result = (timesheet list)
assert ($list_result | is-not-empty) "Should have timesheets"

# print "=== Testing timesheet get ==="
let get_result = ($created.uu.0 | timesheet get)
assert ($get_result.uu == $created.uu.0) "Should get correct record"

# print "=== Testing timesheet get (type info always included) ==="
let get_with_type = ($created.uu.0 | timesheet get)
assert ($get_with_type | columns | any {|col| $col | str contains "type"}) "Should include type info"

# print "=== Testing timesheet revoke ==="
let revoke_result = ($created.uu.0 | timesheet revoke)
assert ($revoke_result.is_revoked.0 == true) "Should be revoked"

# print "=== Testing timesheet list --all ==="
let all_list = (timesheet list --all)
assert ($all_list | where is_revoked == true | is-not-empty) "Should show revoked records"

# === Testing UUID input variations ===

# Create parent for UUID testing
let parent = ($project_uu | .append timesheet --minutes 30)
let parent_uu = ($parent.uu.0)

# print "=== Testing timesheet get with string UUID ==="
let get_string = ($parent_uu | timesheet get)
assert ($get_string.uu == $parent_uu) "Should get correct record with string UUID"

# print "=== Testing timesheet get with record input ==="
let get_record = ($parent | first | timesheet get)
assert ($get_record.uu == $parent_uu) "Should get correct record from record input"

# print "=== Testing timesheet get with table input ==="
let get_table = ($parent | timesheet get)
assert ($get_table.uu == $parent_uu) "Should get correct record from table input"

# print "=== Testing timesheet get with --uu parameter ==="
let get_param = (timesheet get --uu $parent_uu)
assert ($get_param.uu == $parent_uu) "Should get correct record with --uu parameter"

# print "=== Testing timesheet get with empty table (should fail) ==="
try {
    [] | timesheet get
    error make {msg: "Empty table should have failed"}
} catch {
    # print "  ✓ Empty table correctly rejected"
}

# print "=== Testing timesheet get with multi-row table ==="
let multi_table = [$parent, $parent] | flatten
let get_multi = ($multi_table | timesheet get)
assert ($get_multi.uu == $parent_uu) "Should use first row from multi-row table"

# print "=== Testing timesheet revoke with string UUID ==="
let revoke_item = ($project_uu | .append timesheet --minutes 15)
let revoke_string = ($revoke_item.uu.0 | timesheet revoke)
assert ($revoke_string.is_revoked.0 == true) "Should revoke with string UUID"

# print "=== Testing timesheet revoke with --uu parameter ==="
let revoke_item2 = ($project_uu | .append timesheet --minutes 20)
let revoke_param = (timesheet revoke --uu $revoke_item2.uu.0)
assert ($revoke_param.is_revoked.0 == true) "Should revoke with --uu parameter"

# print "=== Testing timesheet revoke with record input ==="
let revoke_item3 = ($project_uu | .append timesheet --minutes 25)
let revoke_record = ($revoke_item3 | first | timesheet revoke)
assert ($revoke_record.is_revoked.0 == true) "Should revoke from record input"

# print "=== Testing timesheet revoke with table input ==="
let revoke_item4 = ($project_uu | .append timesheet --minutes 35)
let revoke_table = ($revoke_item4 | timesheet revoke)
assert ($revoke_table.is_revoked.0 == true) "Should revoke from table input"

# === Testing type support ===

# print "=== Testing timesheet types ==="
let types = (timesheet types)
assert ($types | is-not-empty) "Should have types"
assert ($types | columns | any {|col| $col == "uu"}) "Types should have uu"
assert ($types | columns | any {|col| $col == "search_key"}) "Types should have search_key"

# Note: Timesheet is a domain wrapper - it uses stk_event table with TIMESHEET type
# Types are filtered and not settable via .append timesheet command

# === Testing automatic JSON data ===
# Note: Timesheet doesn't have a --json parameter, but it automatically stores time data in record_json

# print "=== Testing timesheet automatic JSON data ==="
let auto_json = ($project_uu | .append timesheet --minutes 50)
let auto_json_detail = ($auto_json.uu.0 | timesheet get)
# Timesheet automatically adds minutes to record_json
assert ($auto_json_detail.record_json.minutes == 50) "Should have minutes in JSON"

# === Additional timesheet-specific tests ===

# print "=== Testing timesheet with hours parameter ==="
let hours_timesheet = ($project_uu | .append timesheet --hours 2.5 --description "Long task")
assert ($hours_timesheet | is-not-empty) "Should create timesheet with hours"
let hours_detail = ($hours_timesheet.uu.0 | timesheet get)
assert ($hours_detail.record_json.minutes == 150) "Should convert 2.5 hours to 150 minutes"

# print "=== Testing timesheet with custom start date ==="
let custom_date = "2024-01-15T09:00:00Z"
let dated_timesheet = ($project_uu | .append timesheet --minutes 40 --start-date $custom_date)
assert ($dated_timesheet | is-not-empty) "Should create timesheet with custom date"
let dated_detail = ($dated_timesheet.uu.0 | timesheet get)
assert ($dated_detail.record_json.start_date == $custom_date) "Should store custom start date"

# print "=== Testing timesheet attachment pattern ==="
# Create a project line to attach timesheet to
let task = ($project_uu | project line new $"Test Task($test_suffix)" --type-search-key "TASK")
let task_timesheet = ($task.uu.0 | .append timesheet --minutes 90 --description "Task work")
assert ($task_timesheet | is-not-empty) "Should create timesheet on task"
let task_detail = ($task_timesheet.uu.0 | timesheet get)
assert ($task_detail.table_name_uu_json != {}) "Should have attachment to task"

# print "=== Testing timesheet list (type info always included) ==="
let list_with_type = (timesheet list | take 5)
assert ($list_with_type | is-not-empty) "Should list with type info"
assert ($list_with_type | columns | any {|col| $col == "type_name"}) "Should include type_name"
assert ($list_with_type | columns | any {|col| $col == "type_enum"}) "Should include type_enum"

# print "=== Testing timesheet with description ==="
let described = ($project_uu | .append timesheet --minutes 75 --description "Important meeting")
let described_detail = ($described.uu.0 | timesheet get)
assert ($described_detail.description == "Important meeting") "Should store description"

# print "=== Testing .append event on timesheet ==="
# Note: Since timesheet IS an event, we can attach other events to it
let timesheet_for_event = ($project_uu | .append timesheet --minutes 120)
let timesheet_event = ($timesheet_for_event.uu.0 | .append event $"review-complete($test_suffix)" --description "Manager approved")
assert ($timesheet_event | is-not-empty) "Should create event"
assert ($timesheet_event.uu | is-not-empty) "Event should have UUID"

# print "=== Testing .append request on timesheet ==="
let timesheet_for_request = ($project_uu | .append timesheet --minutes 180)
let timesheet_request = ($timesheet_for_request.uu.0 | .append request $"approve-overtime($test_suffix)" --description "Please approve overtime")
assert ($timesheet_request | is-not-empty) "Should create request"
assert ($timesheet_request.uu | is-not-empty) "Request should have UUID"

"=== All tests completed successfully ==="