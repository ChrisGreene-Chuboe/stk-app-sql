#!/usr/bin/env nu

#print "=== Testing elaborate command ==="

# Import modules and assert
use ../modules *
use std/assert

#print "=== Setting up test data ==="

# Create some test items
let item1 = (item new "Consulting Service" --description "Professional IT consulting")
let item2 = (item new "Product Item" --description "Physical product")

#print "Created test items:"
#print $item1
#print $item2

# Create events that reference the items
let event1 = ($item1.uu.0 | .append event "item-price-updated" --description "Price updated to $150/hr")
let event2 = ($item2.uu.0 | .append event "item-stock-updated" --description "Stock increased to 100 units")

#print "Created test events:"
#print $event1
#print $event2

#print "=== Testing elaborate with table_name_uu_json column ==="

# Test elaborate on event list
let events = (event list | elaborate)

#print "Events with elaboration:"
#print $events

# Verify table_name_uu_json_resolved column was added
assert ("table_name_uu_json_resolved" in ($events | columns)) "Should have table_name_uu_json_resolved column"

# Check that the resolved data contains item information
let first_event_resolved = ($events.table_name_uu_json_resolved.0)
#print "First event resolved data:"
#print $first_event_resolved

# Verify the resolved record has expected fields (default columns: name, description, search_key)
assert ($first_event_resolved.name? != null) "Resolved item should have name"
assert ($first_event_resolved.description? != null) "Resolved item should have description"
# Note: uu is no longer in default columns, and search_key may not exist in all tables

#print "=== Testing elaborate with xxx_uu columns ==="

# Create a request that has stk_entity_uu column
let request1 = (.append request "Test Request" --description "Testing elaborate on entity_uu")

#print "Created test request:"
#print $request1

# Get requests and elaborate
let requests = (request list | elaborate)

#print "Requests with elaboration:"
#print $requests

# Check if stk_entity_uu_resolved was added
if ("stk_entity_uu_resolved" in ($requests | columns)) {
    #print "Found stk_entity_uu_resolved column"
    let entity_resolved = ($requests.stk_entity_uu_resolved.0)
    #print "Entity resolved data:"
    #print $entity_resolved
}

#print "=== Testing elaborate with non-existent UUID ==="

# Create a record with an invalid UUID reference to test error handling
# This would require database manipulation, so we'll skip for now

#print "=== Testing elaborate with empty table ==="

# Test that elaborate handles empty input gracefully
let empty_result = ([] | elaborate)
assert ($empty_result | is-empty) "Elaborate should return empty for empty input"

#print "=== Testing elaborate preserves original columns ==="

# Verify all original columns are preserved
let original_cols = (event list | columns)
let elaborated_cols = (event list | elaborate | columns)

for col in $original_cols {
    assert ($col in $elaborated_cols) $"Original column ($col) should be preserved"
}

#print "=== Testing elaborate with column selection ==="

# Test default columns (no arguments)
let default_elaborate = (event list | elaborate)
let default_resolved = ($default_elaborate.table_name_uu_json_resolved.0)
if $default_resolved != null {
    let default_cols = ($default_resolved | columns)
    #print $"Default elaborate columns: ($default_cols)"
    # Should have the default columns (same as lines command)
    assert ("name" in $default_cols) "Default should include name"
    assert ("description" in $default_cols) "Default should include description"
    # Only check for search_key if it exists in the table
    # Note: Not all tables have search_key column
}

# Test specific column selection
let specific_elaborate = (event list | elaborate name type_uu)
let specific_resolved = ($specific_elaborate.table_name_uu_json_resolved.0)
if $specific_resolved != null {
    let specific_cols = ($specific_resolved | columns)
    #print $"Specific elaborate columns: ($specific_cols)"
    assert ($specific_cols == ["name", "type_uu"]) "Should have only requested columns"
}

# Test --all flag
let all_elaborate = (event list | elaborate --all)
let all_resolved = ($all_elaborate.table_name_uu_json_resolved.0)
if $all_resolved != null {
    let all_cols = ($all_resolved | columns)
    #print $"All elaborate columns count: ($all_cols | length)"
    # Should have many more columns than default
    assert (($all_cols | length) > 5) "Should have many columns with --all"
    assert ("table_name" in $all_cols) "Should include table_name with --all"
    assert ("is_revoked" in $all_cols) "Should include is_revoked with --all"
}

"=== All tests completed successfully ==="
