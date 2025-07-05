#!/usr/bin/env nu

# Test script for stk_address module
# Note: stk_address is a domain wrapper module that provides .append commands
# Template Version: 2025-01-05

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_sa($random_suffix)"

# Import modules and assert
use ../modules *
use std/assert

# Create test project for attaching addresses
let project = (project new $"Address Test Project($test_suffix)")
let project_uuid = ($project.uu.0)

# === Testing .append address (AI-powered) ===
# Note: This test assumes AI is available - run test-ai.nu first

# Basic address creation with AI
let ai_address = ($project_uuid | .append address "3508 Galena Hills Loop Round Rock TX 78681")
assert (($ai_address | length) > 0) "AI address tag should be created"
assert ($ai_address.uu.0 | is-not-empty) "AI address tag should have UUID"

# Verify AI-created address structure
let ai_tag_detail = ($ai_address.uu.0 | tag get)
assert (($ai_tag_detail | columns | any {|col| $col == "record_json"})) "AI tag should have record_json"
let ai_address_data = ($ai_tag_detail.record_json.0)
assert ("address1" in $ai_address_data) "AI address should have address1 field"
assert ("city" in $ai_address_data) "AI address should have city field"
assert ("postal" in $ai_address_data) "AI address should have postal field"
assert ($ai_tag_detail.search_key.0 == "ADDRESS") "AI tag should have ADDRESS search_key"

# === Testing .append address-json (Direct JSON) ===

# Test with minimal required fields
let min_json = '{"address1": "123 Main St", "city": "Austin", "postal": "78701"}'
let json_address1 = ($project_uuid | .append address --json $min_json)
assert (($json_address1 | length) > 0) "JSON address tag should be created"
assert ($json_address1.uu.0 | is-not-empty) "JSON address tag should have UUID"

# Verify minimal JSON address
let json_tag1 = ($json_address1.uu.0 | tag get)
let json_data1 = ($json_tag1.record_json.0)
assert ($json_data1.address1 == "123 Main St") "address1 should match"
assert ($json_data1.city == "Austin") "city should match"
assert ($json_data1.postal == "78701") "postal should match"

# Test with all fields
let full_json = '{"address1": "456 Oak Ave", "address2": "Suite 100", "city": "Dallas", "state": "TX", "postal": "75201", "country": "USA"}'
let json_address2 = ($project_uuid | .append address --json $full_json)
assert (($json_address2 | length) > 0) "Full JSON address tag should be created"

# Verify full JSON address
let json_tag2 = ($json_address2.uu.0 | tag get)
let json_data2 = ($json_tag2.record_json.0)
assert ($json_data2.address1 == "456 Oak Ave") "address1 should match"
assert ($json_data2.address2 == "Suite 100") "address2 should match"
assert ($json_data2.city == "Dallas") "city should match"
assert ($json_data2.state == "TX") "state should match"
assert ($json_data2.postal == "75201") "postal should match"
assert ($json_data2.country == "USA") "country should match"

# Test with nushell record converted to JSON
let address_record = {
    address1: "789 Elm St"
    city: "Houston"
    state: "TX"
    postal: "77001"
}
let record_json = ($address_record | to json)
let json_address3 = ($project_uuid | .append address --json $record_json)
assert (($json_address3 | length) > 0) "Record-based JSON address should be created"

# === Testing UUID input variations (adapted from uuid-input-pattern) ===

# Test with record input
let project_record = (project list | where uu == $project_uuid | get 0)
let record_address = ($project_record | .append address --json $min_json)
assert (($record_address | length) > 0) "Address tag should be created from record input"
assert ($record_address.uu.0 | is-not-empty) "Address tag from record should have UUID"

# Test with table input
let project_table = (project list | where uu == $project_uuid)
let table_address = ($project_table | .append address --json $min_json)
assert (($table_address | length) > 0) "Address tag should be created from table input"
assert ($table_address.uu.0 | is-not-empty) "Address tag from table should have UUID"

# Test with multi-row table (should use first row)
let bp = (bp new $"Test Company($test_suffix)")
let multi_table = [($project | first), ($bp | first)] | flatten
let multi_address = ($multi_table | .append address --json $min_json)
assert (($multi_address | length) > 0) "Should create address from multi-row table"

# === Testing error conditions ===

# Test invalid JSON
try {
    $project_uuid | .append address --json "not valid json"
    error make {msg: "Invalid JSON should have failed"}
} catch {
    # Expected to fail
}

# Test missing required fields
try {
    $project_uuid | .append address --json '{"address1": "123 Main St"}'
    error make {msg: "Missing required fields should have failed"}
} catch {
    # Expected to fail - missing city and postal
}

# Test with empty pipeline input
try {
    null | .append address --json $min_json
    error make {msg: "Empty pipeline should have failed"}
} catch {
    # Expected to fail
}

# === Testing custom type support ===

# Test custom address type (if ADDRESS_SHIP_TO exists)
let type_list = (tag types)
let has_ship_to = ($type_list | where search_key == "ADDRESS_SHIP_TO" | length) > 0

if $has_ship_to {
    let ship_address = ($project_uuid | .append address --json $min_json --type-search-key ADDRESS_SHIP_TO)
    assert (($ship_address | length) > 0) "Should create shipping address"
    let ship_tag = ($ship_address.uu.0 | tag get)
    assert ($ship_tag.search_key.0 == "ADDRESS_SHIP_TO") "Should have correct type"
}

# === Verify all addresses were created ===

# Get all tags for the project
let all_project_tags = (tag list | where table_name_uu_json.uu == $project_uuid)

# Filter for ADDRESS tags (including any custom types)
let address_tags = ($all_project_tags | where search_key =~ "ADDRESS")
let address_count = ($address_tags | length)

# We created at least 6 ADDRESS tags (1 AI + 5 JSON)
assert ($address_count >= 6) $"Should have at least 6 ADDRESS tags, found ($address_count)"

# Verify we have a mix of addresses
assert (($address_tags | where record_json.address1 == "3508 Galena Hills Loop" | length) >= 1) "Should have AI-created address"
assert (($address_tags | where record_json.address1 == "123 Main St" | length) >= 1) "Should have JSON-created addresses"

"=== All tests completed successfully ==="