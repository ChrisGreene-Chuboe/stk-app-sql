#!/usr/bin/env nu

# Test script for stk_item module
echo "=== Testing stk_item Module ==="

# REQUIRED: Import modules and assert
use ./modules *
use std/assert

echo "=== Testing item types command ==="
let types_result = (item types)

echo "=== Verifying item types were returned ==="
assert (($types_result | length) > 0) "Should return at least one item type"
assert ($types_result | columns | any {|col| $col == "type_enum"}) "Result should contain 'type_enum' field"
assert ($types_result | columns | any {|col| $col == "uu"}) "Result should contain 'uu' field"
assert ($types_result | columns | any {|col| $col == "name"}) "Result should contain 'name' field"

# Check that expected types exist
let type_enums = ($types_result | get type_enum)
assert ($type_enums | any {|t| $t == "SERVICE"}) "Should have SERVICE type"
assert ($type_enums | any {|t| $t == "PRODUCT-STOCKED"}) "Should have PRODUCT-STOCKED type"
assert ($type_enums | any {|t| $t == "ACCOUNT"}) "Should have ACCOUNT type"
echo "✓ Item types verified successfully"

echo "=== Testing basic item creation (default type) ==="
let simple_item = (item new "Test Laptop Computer")

echo "=== Verifying basic item creation ==="
assert ($simple_item | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($simple_item.uu | is-not-empty) "UUID field should not be empty"
assert ($simple_item | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
assert ($simple_item.name.0 | str contains "Test Laptop Computer") "Name should match input"
echo "✓ Basic item creation verified with UUID:" ($simple_item.uu)

echo "=== Testing item creation with description ==="
let described_item = (item new "Consulting Service" --description "Professional IT consulting")

echo "=== Verifying item with description ==="
assert ($described_item | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($described_item.uu | is-not-empty) "UUID field should not be empty"
assert ($described_item | columns | any {|col| $col == "description"}) "Result should contain 'description' field"
assert ($described_item.description.0 | str contains "Professional IT consulting") "Description should match input"
echo "✓ Item with description verified with UUID:" ($described_item.uu)

echo "=== Testing item creation with specific type ==="
let typed_item = (item new "Shipping Fee" --type "ACCOUNT" --description "Standard shipping charge")

echo "=== Verifying typed item creation ==="
assert ($typed_item | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($typed_item.uu | is-not-empty) "UUID field should not be empty"
assert ($typed_item.name.0 | str contains "Shipping Fee") "Name should match input"
echo "✓ Typed item creation verified with UUID:" ($typed_item.uu)

echo "=== Testing item list command ==="
let items_list = (item list)

echo "=== Verifying item list results ==="
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
echo "✓ Item list verified successfully"

echo "=== Testing item get command ==="
let first_item_uu = ($items_list | get uu.0)
let retrieved_item = (item get $first_item_uu)

echo "=== Verifying item get results ==="
assert (($retrieved_item | length) == 1) "Should return exactly one item"
assert ($retrieved_item | columns | any {|col| $col == "uu"}) "Retrieved item should contain 'uu' field"
assert ($retrieved_item.uu.0 == $first_item_uu) "Retrieved UUID should match requested UUID"
assert ($retrieved_item | columns | any {|col| $col == "name"}) "Retrieved item should contain 'name' field"
echo "✓ Item get verified for UUID:" $first_item_uu

echo "=== Testing item detail command ==="
let detailed_item = (item detail $first_item_uu)

echo "=== Verifying item detail results ==="
assert (($detailed_item | length) == 1) "Should return exactly one detailed item"
assert ($detailed_item | columns | any {|col| $col == "uu"}) "Detailed item should contain 'uu' field"
assert ($detailed_item | columns | any {|col| $col == "type_enum"}) "Detailed item should contain 'type_enum' field"
assert ($detailed_item | columns | any {|col| $col == "type_name"}) "Detailed item should contain 'type_name' field"
assert ($detailed_item.uu.0 == $first_item_uu) "Detailed UUID should match requested UUID"
echo "✓ Item detail verified with type:" ($detailed_item.type_enum.0)

echo "=== Testing item revoke command ==="
let revoke_result = (item revoke $first_item_uu)

echo "=== Verifying item revoke results ==="
assert ($revoke_result | columns | any {|col| $col == "uu"}) "Revoke result should contain 'uu' field"
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke result should contain 'is_revoked' field"
assert ($revoke_result.uu.0 == $first_item_uu) "Revoked UUID should match requested UUID"
assert ($revoke_result.is_revoked.0) "Item should be marked as revoked"
echo "✓ Item revoke verified for UUID:" $first_item_uu

echo "=== Testing help examples ==="

echo "=== Example: Create a simple item ==="
let example_item1 = (item new "Consulting Hours")
assert ($example_item1 | columns | any {|col| $col == "uu"}) "Example item should be created successfully"
echo "✓ Help example 1 verified"

echo "=== Example: Create item with type and description ==="
let example_item2 = (item new "Software License" --type "PRODUCT-NONSTOCKED")
assert ($example_item2 | columns | any {|col| $col == "uu"}) "Example typed item should be created successfully"
echo "✓ Help example 2 verified"

echo "=== Example: List and filter items ==="
let filtered_items = (item list | where name =~ "Consulting")
assert (($filtered_items | length) >= 1) "Should find at least one consulting item"
echo "✓ Help example filtering verified"

echo "=== Example: Get item details ==="
let latest_uu = (item list | get uu.0)
let example_detail = (item detail $latest_uu)
assert ($example_detail | columns | any {|col| $col == "type_enum"}) "Example detail should include type information"
echo "✓ Help example detail verified"

echo "=== All tests completed successfully ==="