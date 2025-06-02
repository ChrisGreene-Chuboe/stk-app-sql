#!/usr/bin/env nu

# Test script for stk_event module
echo "=== Testing stk_event Module ==="

# Import the modules and assert functionality
use ../modules *
use std/assert

echo "=== Testing event creation ==="
let event_result = ("Test event with constants" | .append event "test-constants")
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
let event_detail = (event get $event_uu)
assert (($event_detail | length) == 1) "Event get should return exactly one record"
assert (($event_detail.uu.0) == $event_uu) "Returned event should have matching UUID"
assert ($event_detail | columns | any {|col| $col == "record_json"}) "Event detail should contain record_json"
echo "✓ Event get verified for UUID:" $event_uu

echo "=== Testing event request functionality ==="
let request_result = ("investigate this event" | event request $event_uu)
assert ($request_result | columns | any {|col| $col == "uu"}) "Event request should return UUID"
assert ($request_result.uu | is-not-empty) "Request UUID should not be empty"

echo "=== Verifying request was created ==="
let requests = (request list)
let event_requests = ($requests | where name == "event-request")
assert (($event_requests | length) > 0) "Should find at least one event-request"
echo "✓ Event request functionality verified"

echo "=== Testing event revoke ==="
let revoke_result = (event revoke $event_uu)
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
assert (($revoke_result.is_revoked.0) == true) "Event should be marked as revoked"

echo "=== Verifying revoked status ==="
let revoked_event = (event get $event_uu)
assert (($revoked_event.is_revoked.0) == true) "Retrieved event should show revoked status"
echo "✓ Event revoke functionality verified"

echo "=== Testing help examples ==="

# Test example: "User login successful" | .append event "authentication"
let auth_result = ("User login successful" | .append event "authentication")
assert ($auth_result | columns | any {|col| $col == "uu"}) "Auth event creation should return UUID"
assert ($auth_result.uu | is-not-empty) "Auth event UUID should not be empty"
echo "✓ Help example verified: event creation with authentication"

# Test example: event list | where name == "authentication"
let auth_events = (event list | where name == "authentication")
assert (($auth_events | length) > 0) "Should find authentication events"
assert ($auth_events | all {|row| $row.name == "authentication"}) "All returned events should be authentication type"
echo "✓ Help example verified: filtering events by name"

# Test example: event list | get uu.0 | event get $in
let first_event_uu = (event list | get uu.0)
let retrieved_event = (event get $first_event_uu)
assert (($retrieved_event | length) == 1) "Pipeline example should return one event"
assert (($retrieved_event.uu.0) == $first_event_uu) "Pipeline should retrieve correct event"
echo "✓ Help example verified: pipeline usage for event retrieval"

# Test example: "investigate this error" | event request $error_event_uuid
let error_event = ("Critical system error detected" | .append event "system-error")
let investigation_request = ("investigate this error" | event request $error_event.uu.0)
assert ($investigation_request | columns | any {|col| $col == "uu"}) "Investigation request should return UUID"
let investigation_requests = (request list | where name == "event-request")
assert (($investigation_requests | length) > 0) "Should find event-request records"
echo "✓ Help example verified: creating request attached to event"

echo "=== All tests completed successfully ==="