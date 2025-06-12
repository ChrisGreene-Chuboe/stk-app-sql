#!/usr/bin/env nu

# Test script for stk_event module
echo "=== Testing stk_event Module ==="

# Import the modules and assert functionality
use ./modules *
use std/assert

echo "=== Testing event creation ==="
let event_result = (.append event "test-constants" --description "Test event with constants")
assert ($event_result | columns | any {|col| $col == "uu"}) "Event creation should return UUID"
assert ($event_result.uu | is-not-empty) "UUID field should not be empty"
echo "✓ Event creation verified with UUID:" ($event_result.uu)

echo "=== Testing event list ==="
let events = (event list)
assert (($events | length) > 0) "Event list should contain at least one event"
assert ($events | columns | any {|col| $col == "uu"}) "Event list should contain uu column"
assert ($events | columns | any {|col| $col == "name"}) "Event list should contain name column"
echo "✓ Event list verified with" ($events | length) "events"

echo "=== Testing event get ==="
let event_uu = (event list | get uu.0)
let event_detail = ($event_uu | event get)
assert (($event_detail | length) == 1) "Event get should return exactly one record"
assert (($event_detail.uu.0) == $event_uu) "Returned event should have matching UUID"
assert ($event_detail | columns | any {|col| $col == "record_json"}) "Event detail should contain record_json"
echo "✓ Event get verified for UUID:" $event_uu

echo "=== Testing event request functionality ==="
let request_result = ($event_uu | .append request "event-investigation" --description "investigate this event")
assert ($request_result | columns | any {|col| $col == "uu"}) "Event request should return UUID"
assert ($request_result.uu | is-not-empty) "Request UUID should not be empty"

echo "=== Verifying request was created ==="
let requests = (request list)
let event_requests = ($requests | where name == "event-investigation")
assert (($event_requests | length) > 0) "Should find at least one event-investigation"
echo "✓ Event request functionality verified"

echo "=== Testing event revoke ==="
let revoke_result = ($event_uu | event revoke)
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
assert (($revoke_result.is_revoked.0) == true) "Event should be marked as revoked"

echo "=== Verifying revoked status ==="
let revoked_event = ($event_uu | event get)
assert (($revoked_event.is_revoked.0) == true) "Retrieved event should show revoked status"
echo "✓ Event revoke functionality verified"

echo "=== Testing basic event functionality completed ==="

# Test example: event list | where name == "test-constants"
let test_events = (event list | where name == "test-constants")
assert (($test_events | length) > 0) "Should find test-constants events"
assert ($test_events | all {|row| $row.name == "test-constants"}) "All returned events should be test-constants type"
echo "✓ Help example verified: filtering events by name"

# Test example: event list | get uu.0 | event get
let first_event_uu = (event list | get uu.0)
let retrieved_event = ($first_event_uu | event get)
assert (($retrieved_event | length) == 1) "Pipeline example should return one event"
assert (($retrieved_event.uu.0) == $first_event_uu) "Pipeline should retrieve correct event"
echo "✓ Help example verified: pipeline usage for event retrieval"

# Test example: .append request with --description
let error_event = (.append event "system-error" --description "Critical system error detected")
let investigation_request = ($error_event.uu.0 | .append request "error-investigation" --description "investigate this error")
assert ($investigation_request | columns | any {|col| $col == "uu"}) "Investigation request should return UUID"
let investigation_requests = (request list | where name == "error-investigation")
assert (($investigation_requests | length) > 0) "Should find error-investigation records"
echo "✓ Help example verified: creating request attached to event with piped UUID"

echo "=== Testing event revoke with piped UUID ==="
let pipeline_event = (.append event "pipeline-test" --description "Event for pipeline revoke test")
let pipeline_revoke_result = ($pipeline_event.uu.0 | event revoke)
assert ($pipeline_revoke_result | columns | any {|col| $col == "is_revoked"}) "Pipeline revoke should return is_revoked status"
assert (($pipeline_revoke_result.is_revoked.0) == true) "Pipeline revoked event should be marked as revoked"
echo "✓ Event revoke with piped UUID verified"

echo "=== Testing metadata functionality ==="

# Test event creation with metadata
let metadata_result = (.append event "system-error" --description "Critical system failure detected" --metadata '{"urgency": "high", "component": "database", "user_id": 123}')
assert ($metadata_result | columns | any {|col| $col == "uu"}) "Metadata event creation should return UUID"
assert ($metadata_result.uu | is-not-empty) "Metadata event UUID should not be empty"
echo "✓ Event with metadata created, UUID:" ($metadata_result.uu)

echo "=== Verifying description field contains text content ==="
let metadata_event = ($metadata_result.uu.0 | event get)
assert (($metadata_event | length) == 1) "Should retrieve exactly one metadata event"
assert ($metadata_event.description.0 == "Critical system failure detected") "Description should contain the piped text content"
echo "✓ Description field verified: contains text content directly"

echo "=== Verifying record_json contains metadata ==="
let event_json = ($metadata_event.record_json.0)
assert ($event_json | columns | any {|col| $col == "urgency"}) "Metadata should contain urgency field"
assert ($event_json | columns | any {|col| $col == "component"}) "Metadata should contain component field"
assert ($event_json | columns | any {|col| $col == "user_id"}) "Metadata should contain user_id field"
assert ($event_json.urgency == "high") "Urgency should be 'high'"
assert ($event_json.component == "database") "Component should be 'database'"
assert ($event_json.user_id == 123) "User ID should be 123"
echo "✓ Metadata verified: record_json contains structured data"

echo "=== Testing event without metadata (default behavior) ==="
let no_meta_result = (.append event "basic-test" --description "Simple event without metadata")
let no_meta_event = ($no_meta_result.uu.0 | event get)
assert ($no_meta_event.description.0 == "Simple event without metadata") "Description should contain text content"
assert ($no_meta_event.record_json.0 == {}) "record_json should be empty object when no metadata provided"
echo "✓ Default behavior verified: empty metadata results in empty JSON object"

echo "=== Testing help example with metadata ==="
let auth_meta_result = (.append event "authentication" --description "User John logged in from mobile app" --metadata '{"user_id": 456, "ip": "192.168.1.100", "device": "mobile"}')
let auth_meta_event = ($auth_meta_result.uu.0 | event get)
assert ($auth_meta_event.description.0 == "User John logged in from mobile app") "Auth description should match input"
assert ($auth_meta_event.record_json.0.user_id == 456) "Auth metadata should contain user_id"
assert ($auth_meta_event.record_json.0.ip == "192.168.1.100") "Auth metadata should contain IP address"
assert ($auth_meta_event.record_json.0.device == "mobile") "Auth metadata should contain device info"
echo "✓ Help example with metadata verified"

echo "=== Testing event types command ==="
let types_result = (event types)
assert (($types_result | length) > 0) "Should return at least one event type"
assert ($types_result | columns | any {|col| $col == "type_enum"}) "Result should contain 'type_enum' field"
assert ($types_result | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($types_result | columns | any {|col| $col == "name"}) "Result should contain 'name' field"

# Check that expected types exist
let type_enums = ($types_result | get type_enum)
assert ($type_enums | any {|t| $t == "NONE"}) "Should have NONE type"
assert ($type_enums | any {|t| $t == "ACTION"}) "Should have ACTION type"
echo "✓ Event types verified successfully"

echo "=== Testing event list --detail command ==="
let detailed_events_list = (event list --detail)
assert (($detailed_events_list | length) >= 1) "Should return at least one detailed event"
assert ($detailed_events_list | columns | any {|col| $col == "type_enum"}) "Detailed list should contain 'type_enum' field"
assert ($detailed_events_list | columns | any {|col| $col == "type_name"}) "Detailed list should contain 'type_name' field"
echo "✓ Event list --detail verified successfully"

echo "=== Testing event get --detail command ==="
let first_event_uu = (event list | get uu.0)
let detailed_event = ($first_event_uu | event get --detail)
assert (($detailed_event | length) == 1) "Should return exactly one detailed event"
assert ($detailed_event | columns | any {|col| $col == "uu"}) "Detailed event should contain 'uu' field"
assert ($detailed_event | columns | any {|col| $col == "type_enum"}) "Detailed event should contain 'type_enum' field"
assert ($detailed_event | columns | any {|col| $col == "type_name"}) "Detailed event should contain 'type_name' field"
echo "✓ Event get --detail verified with type:" ($detailed_event.type_enum.0)

echo "=== All tests completed successfully ==="