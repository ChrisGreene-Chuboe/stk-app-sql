#!/usr/bin/env nu

echo "=== Debug elaborate command ==="

# Import modules
use modules *

echo "=== Creating test data ==="

# Create a test item
let item1 = (item new "Consulting Service" --description "Professional IT consulting")
echo "Created item:"
echo $item1

# Create an event that references the item
let event1 = ($item1.uu.0 | .append event "item-price-updated" --description "Price updated to $150/hr")
echo "Created event:"
echo $event1

echo "=== Testing elaborate ==="

# Get events without elaborate
let events_plain = (event list)
echo "Events without elaborate:"
echo $events_plain

# Get events with elaborate
let events_elaborated = (event list | elaborate)
echo "Events with elaborate:"
echo $events_elaborated

# Check columns
echo "Plain columns:"
echo ($events_plain | columns)
echo "Elaborated columns:"
echo ($events_elaborated | columns)

# Check first event's table_name_uu_json_resolved
if ("table_name_uu_json_resolved" in ($events_elaborated | columns)) {
    echo "Found table_name_uu_json_resolved column"
    let resolved = ($events_elaborated.table_name_uu_json_resolved.0)
    echo "Resolved value:"
    echo $resolved
    echo "Type of resolved:"
    echo ($resolved | describe)
}

echo "=== Debug complete ==="