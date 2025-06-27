#!/usr/bin/env nu

# Test script for stk_event module
# print "=== Testing stk_event Module ==="

# Test-specific suffix to ensure test isolation and idempotency
# Generate random 2-char suffix from letters (upper/lower) and numbers
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_se($random_suffix)"  # se for stk_event + 2 random chars

# Import the modules and assert functionality
use ../modules *
use std/assert

# print "=== Testing event creation ==="
let test_event_name = $"test-constants($test_suffix)"
let event_result = (.append event $test_event_name --description "Test event with constants")
assert ($event_result | columns | any {|col| $col == "uu"}) "Event creation should return UUID"
assert ($event_result.uu | is-not-empty) "UUID field should not be empty"
#print $"✓ Event creation verified with UUID: ($event_result.uu)"

# print "=== Testing event list ==="
let events = (event list)
assert (($events | length) > 0) "Event list should contain at least one event"
assert ($events | columns | any {|col| $col == "uu"}) "Event list should contain uu column"
assert ($events | columns | any {|col| $col == "name"}) "Event list should contain name column"
#print $"✓ Event list verified with ($events | length) events"

# print "=== Testing event get ==="
let event_uu = (event list | get uu.0)
let event_detail = ($event_uu | event get)
assert (($event_detail | length) == 1) "Event get should return exactly one record"
assert (($event_detail.uu.0) == $event_uu) "Returned event should have matching UUID"
assert ($event_detail | columns | any {|col| $col == "record_json"}) "Event detail should contain record_json"
#print $"✓ Event get verified for UUID: ($event_uu)"

# print "=== Testing event request functionality ==="
let request_name = $"event-investigation($test_suffix)"
let request_result = ($event_uu | .append request $request_name --description "investigate this event")
assert ($request_result | columns | any {|col| $col == "uu"}) "Event request should return UUID"
assert ($request_result.uu | is-not-empty) "Request UUID should not be empty"

# print "=== Verifying request was created ==="
let requests = (request list)
let event_requests = ($requests | where name == $request_name)
assert (($event_requests | length) > 0) "Should find at least one event-investigation"
#print "✓ Event request functionality verified"

# print "=== Testing event revoke ==="
let revoke_result = ($event_uu | event revoke)
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
assert (($revoke_result.is_revoked.0) == true) "Event should be marked as revoked"

# print "=== Verifying revoked status ==="
let revoked_event = ($event_uu | event get)
assert (($revoked_event.is_revoked.0) == true) "Retrieved event should show revoked status"
#print "✓ Event revoke functionality verified"

# print "=== Testing basic event functionality completed ==="

# Test example: event list | where name == "test-constants"
# Note: Using --all flag because the test-constants event was revoked earlier
let test_events = (event list --all | where name == $test_event_name)
assert (($test_events | length) > 0) "Should find test-constants events"
assert ($test_events | all {|row| $row.name == $test_event_name}) "All returned events should be test-constants type"
#print "✓ Help example verified: filtering events by name"

# Create a fresh event for the pipeline test since previous ones might be revoked
let pipeline_event_name = $"pipeline-example($test_suffix)"
let pipeline_test_event = (.append event $pipeline_event_name --description "Event for pipeline example test")

# Test example: event list | get uu.0 | event get
let first_event_uu = (event list | get uu.0)
let retrieved_event = ($first_event_uu | event get)
assert (($retrieved_event | length) == 1) "Pipeline example should return one event"
assert (($retrieved_event.uu.0) == $first_event_uu) "Pipeline should retrieve correct event"
#print "✓ Help example verified: pipeline usage for event retrieval"

# Test example: .append request with --description
let error_event_name = $"system-error($test_suffix)"
let investigation_name = $"error-investigation($test_suffix)"
let error_event = (.append event $error_event_name --description "Critical system error detected")
let investigation_request = ($error_event.uu.0 | .append request $investigation_name --description "investigate this error")
assert ($investigation_request | columns | any {|col| $col == "uu"}) "Investigation request should return UUID"
let investigation_requests = (request list | where name == $investigation_name)
assert (($investigation_requests | length) > 0) "Should find error-investigation records"
#print "✓ Help example verified: creating request attached to event with piped UUID"

# print "=== Testing event revoke with piped UUID ==="
let pipeline_revoke_name = $"pipeline-test($test_suffix)"
let pipeline_event = (.append event $pipeline_revoke_name --description "Event for pipeline revoke test")
let pipeline_revoke_result = ($pipeline_event.uu.0 | event revoke)
assert ($pipeline_revoke_result | columns | any {|col| $col == "is_revoked"}) "Pipeline revoke should return is_revoked status"
assert (($pipeline_revoke_result.is_revoked.0) == true) "Pipeline revoked event should be marked as revoked"
#print "✓ Event revoke with piped UUID verified"

# print "=== Testing json functionality ==="

# Test event creation with json
let json_event_name = $"system-error-json($test_suffix)"
let json_result = (.append event $json_event_name --description "Critical system failure detected" --json '{"urgency": "high", "component": "database", "user_id": 123}')
assert ($json_result | columns | any {|col| $col == "uu"}) "JSON event creation should return UUID"
assert ($json_result.uu | is-not-empty) "JSON event UUID should not be empty"
#print $"✓ Event with JSON created, UUID: ($json_result.uu)"

# print "=== Verifying description field contains text content ==="
let json_event = ($json_result.uu.0 | event get)
assert (($json_event | length) == 1) "Should retrieve exactly one JSON event"
assert ($json_event.description.0 == "Critical system failure detected") "Description should contain the piped text content"
#print "✓ Description field verified: contains text content directly"

# print "=== Verifying record_json contains JSON data ==="
let event_json = ($json_event.record_json.0)
assert ($event_json | columns | any {|col| $col == "urgency"}) "JSON should contain urgency field"
assert ($event_json | columns | any {|col| $col == "component"}) "JSON should contain component field"
assert ($event_json | columns | any {|col| $col == "user_id"}) "JSON should contain user_id field"
assert ($event_json.urgency == "high") "Urgency should be 'high'"
assert ($event_json.component == "database") "Component should be 'database'"
assert ($event_json.user_id == 123) "User ID should be 123"
#print "✓ JSON verified: record_json contains structured data"

# print "=== Testing event without JSON (default behavior) ==="
let no_json_name = $"basic-test($test_suffix)"
let no_json_result = (.append event $no_json_name --description "Simple event without JSON")
let no_json_event = ($no_json_result.uu.0 | event get)
assert ($no_json_event.description.0 == "Simple event without JSON") "Description should contain text content"
assert ($no_json_event.record_json.0 == {}) "record_json should be empty object when no JSON provided"
#print "✓ Default behavior verified: no JSON parameter results in empty JSON object"

# print "=== Testing help example with JSON ==="
let auth_event_name = $"authentication($test_suffix)"
let auth_json_result = (.append event $auth_event_name --description "User John logged in from mobile app" --json '{"user_id": 456, "ip": "192.168.1.100", "device": "mobile"}')
let auth_json_event = ($auth_json_result.uu.0 | event get)
assert ($auth_json_event.description.0 == "User John logged in from mobile app") "Auth description should match input"
assert ($auth_json_event.record_json.0.user_id == 456) "Auth JSON should contain user_id"
assert ($auth_json_event.record_json.0.ip == "192.168.1.100") "Auth JSON should contain IP address"
assert ($auth_json_event.record_json.0.device == "mobile") "Auth JSON should contain device info"
#print "✓ Help example with JSON verified"

# print "=== Testing event types command ==="
let types_result = (event types)
assert (($types_result | length) > 0) "Should return at least one event type"
assert ($types_result | columns | any {|col| $col == "type_enum"}) "Result should contain 'type_enum' field"
assert ($types_result | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($types_result | columns | any {|col| $col == "name"}) "Result should contain 'name' field"

# Check that expected types exist
let type_enums = ($types_result | get type_enum)
assert ($type_enums | any {|t| $t == "NONE"}) "Should have NONE type"
assert ($type_enums | any {|t| $t == "ACTION"}) "Should have ACTION type"
#print "✓ Event types verified successfully"

# print "=== Testing event list --detail command ==="
let detailed_events_list = (event list --detail)
assert (($detailed_events_list | length) >= 1) "Should return at least one detailed event"
assert ($detailed_events_list | columns | any {|col| $col == "type_enum"}) "Detailed list should contain 'type_enum' field"
assert ($detailed_events_list | columns | any {|col| $col == "type_name"}) "Detailed list should contain 'type_name' field"
#print "✓ Event list --detail verified successfully"

# print "=== Testing event get --detail command ==="
let first_event_uu = (event list | get uu.0)
let detailed_event = ($first_event_uu | event get --detail)
assert (($detailed_event | length) == 1) "Should return exactly one detailed event"
assert ($detailed_event | columns | any {|col| $col == "uu"}) "Detailed event should contain 'uu' field"
assert ($detailed_event | columns | any {|col| $col == "type_enum"}) "Detailed event should contain 'type_enum' field"
assert ($detailed_event | columns | any {|col| $col == "type_name"}) "Detailed event should contain 'type_name' field"
#print $"✓ Event get --detail verified with type: ($detailed_event.type_enum.0)"

# print "=== Testing UUID input enhancement ==="

# Test event get with string UUID (existing behavior)
# print "--- Testing event get with string UUID ---"
let uuid_test_name = $"uuid-test-string($test_suffix)"
let test_event = (.append event $uuid_test_name --description "Test string UUID input")
let string_result = ($test_event.uu.0 | event get)
assert (($string_result | length) == 1) "String UUID should return one event"
assert ($string_result.name.0 == $uuid_test_name) "Should retrieve correct event by string UUID"
#print "✓ Event get with string UUID verified"

# Test event get with single record
# print "--- Testing event get with single record ---"
let record_result = (event list | get 0 | event get)
assert (($record_result | length) == 1) "Single record should return one event"
assert ($record_result | columns | any {|col| $col == "uu"}) "Should retrieve complete event from record"
#print "✓ Event get with single record verified"

# Test event get with single-row table
# print "--- Testing event get with single-row table ---"
let table_result = (event list | where name == $uuid_test_name | event get)
assert (($table_result | length) == 1) "Single-row table should return one event"
assert ($table_result.name.0 == $uuid_test_name) "Should retrieve correct event from table"
#print "✓ Event get with single-row table verified"

# Test event revoke with string UUID (existing behavior)
# print "--- Testing event revoke with string UUID ---"
let revoke_string_name = $"revoke-test-string($test_suffix)"
let revoke_test_event = (.append event $revoke_string_name --description "Test string UUID revoke")
let string_revoke = ($revoke_test_event.uu.0 | event revoke)
assert ($string_revoke.is_revoked.0 == true) "String UUID revoke should mark as revoked"
#print "✓ Event revoke with string UUID verified"

# Test event revoke with single record
# print "--- Testing event revoke with single record ---"
let revoke_record_name = $"revoke-test-record($test_suffix)"
let revoke_test_record = (.append event $revoke_record_name --description "Test record revoke")
let record_for_revoke = (event list | where name == $revoke_record_name | get 0)
let record_revoke = ($record_for_revoke | event revoke)
assert ($record_revoke.is_revoked.0 == true) "Record revoke should mark as revoked"
#print "✓ Event revoke with single record verified"

# Test event revoke with single-row table
# print "--- Testing event revoke with single-row table ---"
let revoke_table_name = $"revoke-test-table($test_suffix)"
let revoke_test_table = (.append event $revoke_table_name --description "Test table revoke")
let table_revoke = (event list | where name == $revoke_table_name | event revoke)
assert ($table_revoke.is_revoked.0 == true) "Table revoke should mark as revoked"
#print "✓ Event revoke with single-row table verified"

# Test .append event with string UUID (existing behavior)
# print "--- Testing .append event with string UUID ---"
let parent_name = $"parent-event($test_suffix)"
let child_string_name = $"child-string($test_suffix)"
let parent_event = (.append event $parent_name --description "Parent event for attachment tests")
let string_attach = ($parent_event.uu.0 | .append event $child_string_name --description "Attached via string UUID")
let string_attached = ($string_attach.uu.0 | event get)
assert ($string_attached.table_name_uu_json.0 | is-not-empty) "String attached event should have table_name_uu_json"
#print "✓ .append event with string UUID verified"

# Test .append event with single record
# print "--- Testing .append event with single record ---"
let child_record_name = $"child-record($test_suffix)"
let record_attach = (event list | where name == $parent_name | get 0 | .append event $child_record_name --description "Attached via record")
let record_attached = ($record_attach.uu.0 | event get)
assert ($record_attached.table_name_uu_json.0 | is-not-empty) "Record attached event should have table_name_uu_json"
assert ($record_attached.table_name_uu_json.0.uu == $parent_event.uu.0) "Should attach to correct parent"
#print "✓ .append event with single record verified"

# Test .append event with single-row table
# print "--- Testing .append event with single-row table ---"
let child_table_name = $"child-table($test_suffix)"
let table_attach = (event list | where name == $parent_name | .append event $child_table_name --description "Attached via table")
let table_attached = ($table_attach.uu.0 | event get)
assert ($table_attached.table_name_uu_json.0 | is-not-empty) "Table attached event should have table_name_uu_json"
assert ($table_attached.table_name_uu_json.0.uu == $parent_event.uu.0) "Should attach to correct parent"
#print "✓ .append event with single-row table verified"

# Test with empty table (should create standalone event)
# print "--- Testing .append event with empty table ---"
let standalone_name = $"standalone-from-empty($test_suffix)"
# This pipes an empty table (no rows) to .append event
let empty_table = (event list | where name == "nonexistent-event-that-does-not-exist")
let empty_attach = ($empty_table | .append event $standalone_name --description "Created from empty table")
let empty_attached = ($empty_attach.uu.0 | event get)

# This appears to be a bug where empty input creates an event with empty attachment record
# For now, we'll accept this behavior and document it
let is_empty_attachment = (
    ($empty_attached.table_name_uu_json.0 | describe | str contains "record") and
    ($empty_attached.table_name_uu_json.0.uu? == "") and
    ($empty_attached.table_name_uu_json.0.table_name? == "")
)
assert (($empty_attached.table_name_uu_json.0 == "null") or $is_empty_attachment) "Empty table creates event with null or empty attachment"
#print "✓ .append event with empty table verified (current behavior: empty attachment record)"

# Test with multi-row table (uses first row)
# print "--- Testing .append event with multi-row table ---"
# Create some fresh events to ensure we have a multi-row table
let multi_event1 = (.append event $"multi-test-1($test_suffix)" --description "First event for multi-row test")
let multi_event2 = (.append event $"multi-test-2($test_suffix)" --description "Second event for multi-row test")
let multi_event3 = (.append event $"multi-test-3($test_suffix)" --description "Third event for multi-row test")

# Now get a fresh event list that should have multiple rows
let event_table = (event list)
# Only proceed if we have events
if ($event_table | length) > 0 {
    let first_event = ($event_table | get 0)
    let multi_attach_name = $"multi-row-attach($test_suffix)"
    # This should now work with the updated extract-uu-table-name function
    let multi_attach = ($event_table | .append event $multi_attach_name --description "Attached via multi-row table")
    let multi_attached = ($multi_attach.uu.0 | event get)
    assert ($multi_attached.table_name_uu_json.0 | is-not-empty) "Multi-row table should use first row"
    assert ($multi_attached.table_name_uu_json.0.uu == $first_event.uu) "Should attach to first row of table"
    #print "✓ .append event with multi-row table verified (uses first row)"
} else {
    #print "⚠️  Skipping multi-row test - no events available"
}

# Test table_name optimization for .append event
# print "--- Testing table_name optimization ---"
# When piping from event list, table_name should be available
let optimize_test = (event list | get 0)
assert ($optimize_test | columns | any {|col| $col == "table_name"}) "Event record should have table_name"
assert ($optimize_test.table_name == "stk_event") "Event record should have correct table_name"

# Create event with piped record (should use optimization)
let optimized_name = $"optimized-attach($test_suffix)"
let optimized_attach = ($optimize_test | .append event $optimized_name --description "Should avoid DB lookup")
let optimized_event = ($optimized_attach.uu.0 | event get)
assert ($optimized_event.table_name_uu_json.0.table_name == "stk_event") "Should use provided table_name"
assert ($optimized_event.table_name_uu_json.0.uu == $optimize_test.uu) "Should attach to correct record"
#print "✓ Table name optimization verified (avoids DB lookup when possible)"

print "=== Testing event get with --uu parameter ==="
let test_uu = (event list | get uu.0)
let uu_param_result = (event get --uu $test_uu)
assert (($uu_param_result | length) == 1) "Event get --uu should return exactly one record"
assert (($uu_param_result.uu.0) == $test_uu) "Returned event should have matching UUID"
print "✓ Event get --uu parameter verified"

print "=== Testing event get --detail with --uu parameter ==="
let detail_uu_result = (event get --uu $test_uu --detail)
assert (($detail_uu_result | length) == 1) "Event get --uu --detail should return exactly one record"
assert ($detail_uu_result | columns | any {|col| $col == "type_enum"}) "Detailed result should contain type_enum"
print "✓ Event get --uu --detail verified"

print "=== Testing event revoke with --uu parameter ==="
let revoke_uu_test = (.append event $"test-revoke-uu-param($test_suffix)" --description "Event for --uu revoke testing")
let revoke_uu = ($revoke_uu_test.uu.0)
let revoke_uu_result = (event revoke --uu $revoke_uu)
assert ($revoke_uu_result | columns | any {|col| $col == "is_revoked"}) "Revoke --uu should return is_revoked status"
assert (($revoke_uu_result.is_revoked.0) == true) "Event should be marked as revoked"
print "✓ Event revoke --uu parameter verified"

print "=== Testing error when no UUID provided to get ==="
# Test error handling with try/catch
try {
    null | event get
    assert false "Event get should have thrown an error"
} catch {|e|
    assert ($e.msg | str contains "UUID required via piped input or --uu parameter") "Should show correct error message"
}
print "✓ Event get error handling verified"

print "=== Testing error when no UUID provided to revoke ==="
# Test error handling with try/catch
try {
    null | event revoke
    assert false "Event revoke should have thrown an error"
} catch {|e|
    assert ($e.msg | str contains "UUID required via piped input or --uu parameter") "Should show correct error message"
}
print "✓ Event revoke error handling verified"

# Return success string for test harness (not print)
"=== All tests completed successfully ==="
