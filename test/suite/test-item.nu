#!/usr/bin/env nu

# Test script for stk_item module
#print "=== Testing stk_item Module ==="

# Test-specific suffix to ensure test isolation and idempotency
# Generate random 2-char suffix from letters (upper/lower) and numbers
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_si($random_suffix)"  # si for stk_item + 2 random chars

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

#print "=== Testing item types command ==="
let types_result = (item types)

#print "=== Verifying item types were returned ==="
assert (($types_result | length) > 0) "Should return at least one item type"
assert ($types_result | columns | any {|col| $col == "type_enum"}) "Result should contain 'type_enum' field"
assert ($types_result | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($types_result | columns | any {|col| $col == "name"}) "Result should contain 'name' field"

# Check that expected types exist
let type_enums = ($types_result | get type_enum)
assert ($type_enums | any {|t| $t == "SERVICE"}) "Should have SERVICE type"
assert ($type_enums | any {|t| $t == "PRODUCT-STOCKED"}) "Should have PRODUCT-STOCKED type"
assert ($type_enums | any {|t| $t == "ACCOUNT"}) "Should have ACCOUNT type"
#print "✓ Item types verified successfully"

#print "=== Testing basic item creation (default type) ==="
let simple_item = (item new $"Test Laptop Computer($test_suffix)")

#print "=== Verifying basic item creation ==="
assert ($simple_item | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($simple_item.uu | is-not-empty) "UUID field should not be empty"
assert ($simple_item | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
assert ($simple_item.name.0 | str contains $"Test Laptop Computer($test_suffix)") "Name should match input"
#print "✓ Basic item creation verified with UUID:" ($simple_item.uu)

#print "=== Testing item creation with description ==="
let described_item = (item new "Consulting Service" --description "Professional IT consulting")

#print "=== Verifying item with description ==="
assert ($described_item | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($described_item.uu | is-not-empty) "UUID field should not be empty"
assert ($described_item | columns | any {|col| $col == "description"}) "Result should contain 'description' field"
assert ($described_item.description.0 | str contains "Professional IT consulting") "Description should match input"
#print "✓ Item with description verified with UUID:" ($described_item.uu)

#print "=== Testing item creation with specific type ==="
let typed_item = (item new "Shipping Fee" --type-search-key "ACCOUNT" --description "Standard shipping charge")

#print "=== Verifying typed item creation ==="
assert ($typed_item | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($typed_item.uu | is-not-empty) "UUID field should not be empty"
assert ($typed_item.name.0 | str contains "Shipping Fee") "Name should match input"
#print "✓ Typed item creation verified with UUID:" ($typed_item.uu)

#print "=== Testing item list command ==="
let items_list = (item list)

#print "=== Verifying item list results ==="
assert (($items_list | length) >= 3) "Should return at least the 3 items we created"
assert ($items_list | columns | any {|col| $col == "uu"}) "List should contain 'uu' field"
assert ($items_list | columns | any {|col| $col == "name"}) "List should contain 'name' field"
assert ($items_list | columns | any {|col| $col == "created"}) "List should contain 'created' field"
assert ($items_list | columns | any {|col| $col == "is_revoked"}) "List should contain 'is_revoked' field"

# Check that our created items are in the list
let item_names = ($items_list | get name)
assert ($item_names | any {|name| $name | str contains "Test Laptop Computer"}) "Should find our laptop item in list"
assert ($item_names | any {|name| $name | str contains "Consulting Service"}) "Should find our consulting item in list"
assert ($item_names | any {|name| $name | str contains "Shipping Fee"}) "Should find our shipping item in list"
#print "✓ Item list verified successfully"

#print "=== Testing item get command ==="
let first_item_uu = ($items_list | get uu.0)
let retrieved_item = ($first_item_uu | item get)

#print "=== Verifying item get results ==="
assert (($retrieved_item | length) == 1) "Should return exactly one item"
assert ($retrieved_item | columns | any {|col| $col == "uu"}) "Retrieved item should contain 'uu' field"
assert ($retrieved_item.uu.0 == $first_item_uu) "Retrieved UUID should match requested UUID"
assert ($retrieved_item | columns | any {|col| $col == "name"}) "Retrieved item should contain 'name' field"
#print "✓ Item get verified for UUID:" $first_item_uu

#print "=== Testing NEW: item get with --uu parameter ==="
let param_retrieved_item = (item get --uu $first_item_uu)
assert (($param_retrieved_item | length) == 1) "Should return exactly one item with --uu"
assert ($param_retrieved_item.uu.0 == $first_item_uu) "Retrieved UUID should match requested UUID"
#print "✓ NEW: Item get --uu parameter verified"

#print "=== Testing NEW: item get with piped record ==="
let first_item_record = ($items_list | get 0)
let record_retrieved_item = ($first_item_record | item get)
assert (($record_retrieved_item | length) == 1) "Should return exactly one item from record"
assert ($record_retrieved_item.uu.0 == $first_item_record.uu) "Retrieved UUID should match record UUID"
#print "✓ NEW: Item get with piped record verified"

#print "=== Testing NEW: item get with piped single-row table ==="
let test_items = ($items_list | where name =~ $test_suffix)
let filtered_table = ($test_items | where name =~ "Laptop" | take 1)
let table_retrieved_item = ($filtered_table | item get)
assert (($table_retrieved_item | length) == 1) "Should return exactly one item from table"
assert ($table_retrieved_item.name.0 | str contains "Laptop") "Retrieved item should be the laptop"
#print "✓ NEW: Item get with piped table verified"

#print "=== Testing item get --detail command ==="
let detailed_item = ($first_item_uu | item get --detail)

#print "=== Verifying item get --detail results ==="
assert (($detailed_item | length) == 1) "Should return exactly one detailed item"
assert ($detailed_item | columns | any {|col| $col == "uu"}) "Detailed item should contain 'uu' field"
assert ($detailed_item | columns | any {|col| $col == "type_enum"}) "Detailed item should contain 'type_enum' field"
assert ($detailed_item | columns | any {|col| $col == "type_name"}) "Detailed item should contain 'type_name' field"
assert ($detailed_item.uu.0 == $first_item_uu) "Detailed UUID should match requested UUID"
#print "✓ Item get --detail verified with type:" ($detailed_item.type_enum.0)

#print "=== Testing item revoke command ==="
let revoke_result = ($first_item_uu | item revoke)

#print "=== Verifying item revoke results ==="
assert ($revoke_result | columns | any {|col| $col == "uu"}) "Revoke result should contain 'uu' field"
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke result should contain 'is_revoked' field"
assert ($revoke_result.uu.0 == $first_item_uu) "Revoked UUID should match requested UUID"
assert ($revoke_result.is_revoked.0) "Item should be marked as revoked"
#print "✓ Item revoke verified for UUID:" $first_item_uu

#print "=== Testing item revoke with piped UUID ==="
let pipeline_item = (item new $"Pipeline Revoke Test Item($test_suffix)")
let pipeline_revoke_result = ($pipeline_item.uu.0 | item revoke)
assert ($pipeline_revoke_result | columns | any {|col| $col == "is_revoked"}) "Pipeline revoke should return is_revoked status"
assert (($pipeline_revoke_result.is_revoked.0) == true) "Pipeline revoked item should be marked as revoked"
#print "✓ Item revoke with piped UUID verified"

#print "=== Testing NEW: item revoke with --uu parameter ==="
let param_item = (item new $"Parameter Revoke Test($test_suffix)")
let param_revoke_result = (item revoke --uu $param_item.uu.0)
assert ($param_revoke_result | columns | any {|col| $col == "is_revoked"}) "Parameter revoke should return is_revoked status"
assert (($param_revoke_result.is_revoked.0) == true) "Parameter revoked item should be marked as revoked"
#print "✓ NEW: Item revoke --uu parameter verified"

#print "=== Testing NEW: item revoke with piped record ==="
let record_item = (item new $"Record Revoke Test($test_suffix)")
let record_for_revoke = (item list | where uu == $record_item.uu.0 | get 0)
let record_revoke_result = ($record_for_revoke | item revoke)
assert ($record_revoke_result | columns | any {|col| $col == "is_revoked"}) "Record revoke should return is_revoked status"
assert (($record_revoke_result.is_revoked.0) == true) "Record revoked item should be marked as revoked"
#print "✓ NEW: Item revoke with piped record verified"

#print "=== Testing NEW: item revoke with piped table ==="
let table_item = (item new $"Table Revoke Test($test_suffix)")
let table_for_revoke = (item list | where uu == $table_item.uu.0)
let table_revoke_result = ($table_for_revoke | item revoke)
assert ($table_revoke_result | columns | any {|col| $col == "is_revoked"}) "Table revoke should return is_revoked status"
assert (($table_revoke_result.is_revoked.0) == true) "Table revoked item should be marked as revoked"
#print "✓ NEW: Item revoke with piped table verified"

#print "=== Testing .append event with item UUID ==="
let active_item_uu = ($described_item.uu.0)  # Use an unrevoked item
let item_event_result = ($active_item_uu | .append event "item-price-updated" --description "item price has been updated")
assert ($item_event_result | columns | any {|col| $col == "uu"}) "Item event should return UUID"
assert ($item_event_result.uu | is-not-empty) "Item event UUID should not be empty"
#print "✓ .append event with piped item UUID verified"

#print "=== Testing .append request with item UUID ==="
let item_request_result = ($active_item_uu | .append request "item-inventory-check" --description "need to verify inventory levels")
assert ($item_request_result | columns | any {|col| $col == "uu"}) "Item request should return UUID"
assert ($item_request_result.uu | is-not-empty) "Item request UUID should not be empty"
#print "✓ .append request with piped item UUID verified"

#print "=== Testing help examples ==="

#print "=== Example: Create a simple item ==="
let example_item1 = (item new "Consulting Hours")
assert ($example_item1 | columns | any {|col| $col == "uu"}) "Example item should be created successfully"
#print "✓ Help example 1 verified"

#print "=== Example: Create item with type and description ==="
let example_item2 = (item new "Software License" --type-search-key "PRODUCT-NONSTOCKED")
assert ($example_item2 | columns | any {|col| $col == "uu"}) "Example typed item should be created successfully"
#print "✓ Help example 2 verified"

#print "=== Example: List and filter items ==="
let filtered_items = (item list | where name =~ "Consulting")
assert (($filtered_items | length) >= 1) "Should find at least one consulting item"
#print "✓ Help example filtering verified"

#print "=== Example: Get item details ==="
let latest_uu = (item list | get uu.0)
let example_detail = ($latest_uu | item get --detail)
assert ($example_detail | columns | any {|col| $col == "type_enum"}) "Example detail should include type information"
#print "✓ Help example detail verified"

#print "=== Testing item list --detail command ==="
let detailed_list = (item list --detail)
assert (($detailed_list | length) >= 3) "Should return at least the items we created"
assert ($detailed_list | columns | any {|col| $col == "type_enum"}) "Detailed list should contain 'type_enum' field"
assert ($detailed_list | columns | any {|col| $col == "type_name"}) "Detailed list should contain 'type_name' field"
#print "✓ Item list --detail verified"

#print "=== Testing item creation with JSON data ==="
let json_item = (item new "Premium Service Package" --json '{"features": ["24/7 support", "priority access", "dedicated account manager"], "sla": "99.9%"}' --description "Premium tier service")
assert ($json_item | columns | any {|col| $col == "uu"}) "JSON item creation should return UUID"
assert ($json_item.uu | is-not-empty) "JSON item UUID should not be empty"
#print "✓ Item with JSON created, UUID:" ($json_item.uu)

#print "=== Verifying item's record_json field ==="
let json_item_detail = ($json_item.uu.0 | item get)
assert (($json_item_detail | length) == 1) "Should retrieve exactly one item"
assert ($json_item_detail | columns | any {|col| $col == "record_json"}) "Item should have record_json column"
let stored_json = ($json_item_detail.record_json.0)
assert ($stored_json | columns | any {|col| $col == "features"}) "JSON should contain features field"
assert ($stored_json | columns | any {|col| $col == "sla"}) "JSON should contain sla field"
assert (($stored_json.features | length) == 3) "Features array should have 3 items"
assert ($stored_json.sla == "99.9%") "SLA should be 99.9%"
#print "✓ JSON data verified: record_json contains structured data"

#print "=== Testing item creation without JSON (default behavior) ==="
let no_json_item = (item new "Basic Service" --description "Standard service offering")
let no_json_detail = ($no_json_item.uu.0 | item get)
assert ($no_json_detail.record_json.0 == {}) "record_json should be empty object when no JSON provided"
#print "✓ Default behavior verified: no JSON parameter results in empty JSON object"

#print "=== Testing item creation with complex JSON ==="
let complex_json = '{"pricing": {"monthly": 99.99, "annual": 999.99, "currency": "USD"}, "availability": {"regions": ["US", "EU", "APAC"], "uptime_guarantee": 0.999}}'
let complex_item = (item new "Enterprise Solution" --json $complex_json --type-search-key "SERVICE")
let complex_detail = ($complex_item.uu.0 | item get)
let complex_stored = ($complex_detail.record_json.0)
assert ($complex_stored.pricing.monthly == 99.99) "Monthly pricing should be 99.99"
assert ($complex_stored.pricing.currency == "USD") "Currency should be USD"
assert (($complex_stored.availability.regions | length) == 3) "Should have 3 regions"
assert ($complex_stored.availability.uptime_guarantee == 0.999) "Uptime guarantee should be 0.999"
#print "✓ Complex JSON structure verified"

"=== All tests completed successfully ==="
