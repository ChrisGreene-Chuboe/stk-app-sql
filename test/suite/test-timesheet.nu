#!/usr/bin/env nu

# Test script for stk_timesheet module

# Test-specific suffix to ensure test isolation and idempotency
# Generate random 2-char suffix from letters (upper/lower) and numbers
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_ts($random_suffix)"  # ts for stk_timesheet + 2 random chars

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

#print "=== Setting up test data ==="
# Create a project to attach timesheets to
let project_name = $"Timesheet Test Project($test_suffix)"
let project_result = (project new $project_name --description "Project for timesheet testing")
assert (($project_result | length) > 0) "Project creation should return result"
let project_uuid = $project_result.uu.0
#print "✓ Created test project with UUID:" $project_uuid

# Create a project line (task) to test attachment
let task_name = $"Implementation Task($test_suffix)"
let task_result = ($project_uuid | project line new $task_name --type-search-key "TASK")
assert (($task_result | length) > 0) "Task creation should return result"
let task_uuid = $task_result.uu.0
#print "✓ Created test task with UUID:" $task_uuid

#print "=== Testing .append timesheet with minutes ==="
let timesheet1 = ($project_uuid | .append timesheet --minutes 90 --description "Code review")
assert (($timesheet1 | length) > 0) "Timesheet creation should return result"
assert (($timesheet1.uu | is-not-empty)) "Timesheet should have UUID"
#print "✓ Created timesheet with 90 minutes"

#print "=== Testing .append timesheet with hours ==="
let timesheet2 = ($task_uuid | .append timesheet --hours 2.5 --description "Implementation work")
assert (($timesheet2 | length) > 0) "Timesheet creation with hours should work"
assert (($timesheet2.uu | is-not-empty)) "Timesheet should have UUID"
#print "✓ Created timesheet with 2.5 hours"

#print "=== Testing .append timesheet with custom start date ==="
let custom_date = "2024-01-15T09:00:00Z"
let timesheet3 = ($project_uuid | .append timesheet --minutes 45 --start-date $custom_date)
assert (($timesheet3 | length) > 0) "Timesheet with custom date should work"
#print "✓ Created timesheet with custom start date"

#print "=== Testing timesheet list ==="
let timesheets = (timesheet list)
assert (($timesheets | length) > 0) "Should have timesheets in list"
assert (($timesheets | columns | any {|col| $col == "record_json"})) "Should have record_json column"
assert (($timesheets | columns | any {|col| $col == "table_name_uu_json"})) "Should have attachment column"
#print "✓ Timesheet list returns results"

# Filter to our test timesheets
let test_timesheets = ($timesheets | where {|t| 
    $t.table_name_uu_json.uu == $project_uuid or $t.table_name_uu_json.uu == $task_uuid
})
#print "Debug: Total timesheets:" ($timesheets | length)
#print "Debug: Project UUID:" $project_uuid
#print "Debug: Task UUID:" $task_uuid
#print "Debug: First timesheet attachment:" ($timesheets | get 0.table_name_uu_json | to nuon)
assert (($test_timesheets | length) >= 3) "Should have at least 3 test timesheets"
#print "✓ Found" ($test_timesheets | length) "test timesheets"

#print "=== Testing timesheet list with detail ==="
let detailed_timesheets = (timesheet list --detail)
assert (($detailed_timesheets | columns | any {|col| $col == "type_name"})) "Detailed list should include type_name"
assert (($detailed_timesheets | columns | any {|col| $col == "type_enum"})) "Detailed list should include type_enum"
#print "✓ Detailed timesheet list includes type information"

#print "=== Testing timesheet get ==="
let first_uuid = $timesheet1.uu.0
let retrieved = ($first_uuid | timesheet get)
assert (($retrieved | length) == 1) "Should retrieve exactly one record"
assert (($retrieved.uu.0 == $first_uuid)) "Retrieved UUID should match requested"
assert (($retrieved.record_json.0.minutes == 90)) "Should have correct minutes"
assert (($retrieved.record_json.0.description == "Code review")) "Should have correct description"
#print "✓ Retrieved timesheet with correct data"

#print "=== Testing timesheet get with --uu parameter ==="
let retrieved_uu = (timesheet get --uu $timesheet2.uu.0)
assert (($retrieved_uu | length) == 1) "Should retrieve with --uu parameter"
assert (($retrieved_uu.record_json.0.minutes == 150)) "Should have 150 minutes (2.5 hours)"
#print "✓ Retrieved timesheet using --uu parameter"

#print "=== Testing timesheet filtering with nushell pipelines ==="
# Test filtering by project
let project_timesheets = (timesheet list | where table_name_uu_json.uu == $project_uuid)
assert (($project_timesheets | length) >= 2) "Should have at least 2 timesheets for project"
#print "✓ Filtered timesheets by project"

# Test filtering by date
let dated_timesheet = (timesheet list | where record_json.start_date == $custom_date)
assert (($dated_timesheet | length) >= 1) "Should find timesheet with custom date"
#print "✓ Filtered timesheets by date"

# Test calculating total minutes
let total_minutes = ($test_timesheets | get record_json.minutes | math sum)
assert (($total_minutes >= 285)) "Total minutes should be at least 285 (90+150+45)"
let total_hours = ($total_minutes / 60 | math round --precision 2)
#print $"✓ Calculated total: ($total_minutes) minutes = ($total_hours) hours"

#print "=== Testing timesheet revoke ==="
let revoke_result = ($first_uuid | timesheet revoke)
assert (($revoke_result | length) > 0) "Revoke should return result"
assert (($revoke_result.is_revoked.0 == true)) "Timesheet should be marked as revoked"
#print "✓ Revoked timesheet successfully"

# Verify revoked timesheet doesn't appear in normal list
let active_timesheets = (timesheet list | where table_name_uu_json.uu == $project_uuid)
let all_timesheets = (timesheet list --all | where table_name_uu_json.uu == $project_uuid)
assert (($all_timesheets | length) > ($active_timesheets | length)) "All list should have more than active list"
#print "✓ Revoked timesheet hidden from normal list"

#print "=== Testing timesheet types ==="
let types = (timesheet types)
assert (($types | length) > 0) "Should have at least one timesheet type"
assert (($types | where type_enum == "TIMESHEET" | length) == 1) "Should have TIMESHEET type"
#print "✓ Timesheet types command works"

#print "=== Testing error conditions ==="
# Test missing time parameter
let error_result = try {
    $project_uuid | .append timesheet --description "No time specified"
    false
} catch {
    true
}
assert ($error_result) "Should fail without minutes or hours"
#print "✓ Correctly fails without time parameter"

# Test both minutes and hours
let error_result2 = try {
    $project_uuid | .append timesheet --minutes 60 --hours 1
    false
} catch {
    true
}
assert ($error_result2) "Should fail with both minutes and hours"
#print "✓ Correctly fails with both time parameters"

# Test excessive minutes
let error_result3 = try {
    $project_uuid | .append timesheet --minutes 1441
    false
} catch {
    true
}
assert ($error_result3) "Should fail with minutes > 1440"
#print "✓ Correctly fails with excessive minutes"

# Test missing attachment
let error_result4 = try {
    .append timesheet --minutes 60
    false
} catch {
    true
}
assert ($error_result4) "Should fail without attachment"
#print "✓ Correctly fails without attachment"

# Return success message for test harness
"=== All tests completed successfully ==="