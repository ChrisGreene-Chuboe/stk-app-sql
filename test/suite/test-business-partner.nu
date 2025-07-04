#!/usr/bin/env nu
# Test suite for stk_business_partner module

use ../modules *
use std/assert

# print "=== Starting stk_business_partner tests ==="

# Generate unique test suffix for data idempotency
let test_suffix = $"_sb(random chars --length 2)"
# print $"Using test suffix: ($test_suffix)"

# Test business partner creation with basic fields
# print "\n--- Testing business partner creation ---"

# First, get available types
let bp_types = bp types
assert (($bp_types | length) > 0) "Should have business partner types"
# print $"Found ($bp_types | length) business partner types"

# Create a basic organization
let org_name = $"Test Organization($test_suffix)"
let org_result = bp new $org_name --description "Test org description"
assert (($org_result | length) == 1) "Should create one business partner"
assert (($org_result.name.0 == $org_name)) "Name should match"
assert (($org_result.description.0 == "Test org description")) "Description should match"
# print "✓ Basic organization creation successful"

# Store the UUID for later tests
let org_uu = $org_result.uu.0

# Test business partner type resolution
# print "\n--- Testing type resolution ---"

# Create with type-search-key
let individual_name = $"Test Individual($test_suffix)"
let individual_result = bp new $individual_name --type-search-key "INDIVIDUAL"
assert (($individual_result | length) == 1) "Should create individual with type-search-key"
let individual_uu = $individual_result.uu.0

# Create with type-uu
let org_type = $bp_types | where search_key == "ORGANIZATION" | first
let group_name = $"Test Group($test_suffix)"
let group_result = bp new $group_name --type-uu $org_type.uu
assert (($group_result | length) == 1) "Should create with type-uu"
# print "✓ Type resolution working correctly"

# Test listing functionality
# print "\n--- Testing listing functionality ---"

# Basic list
let basic_list = bp list
let filtered_list = $basic_list | where name =~ $test_suffix
assert (($filtered_list | length) >= 3) "Should have at least 3 test BPs"
# print $"✓ Basic list shows ($filtered_list | length) test BPs"

# List with detail
let detail_list = bp list --detail
let detail_filtered = $detail_list | where name =~ $test_suffix
assert (($detail_filtered | length) >= 3) "Detail list should show test BPs"
assert (("type_name" in ($detail_filtered | columns))) "Detail list should include type_name"
# print "✓ Detail list includes type information"

# Test get command with various UUID input methods
# print "\n--- Testing get command ---"

# Get by piped UUID string
let get_by_pipe = $org_uu | bp get
assert (($get_by_pipe | length) == 1) "Should get BP by piped UUID"
assert (($get_by_pipe.name.0 == $org_name)) "Should get correct BP"
# print "✓ Get by piped UUID string works"

# Get by parameter
let get_by_param = bp get --uu $individual_uu
assert (($get_by_param | length) == 1) "Should get BP by --uu parameter"
assert (($get_by_param.name.0 == $individual_name)) "Should get correct BP"
# print "✓ Get by --uu parameter works"

# Get by piped record
let get_by_record = bp list | where name == $org_name | bp get
assert (($get_by_record | length) == 1) "Should get BP by piped record"
assert (($get_by_record.name.0 == $org_name)) "Should get correct BP"
# print "✓ Get by piped record works"

# Get with detail
let get_detail = $org_uu | bp get --detail
assert (($get_detail | length) == 1) "Should get BP with detail"
assert (("type_name" in ($get_detail | columns))) "Detail get should include type_name"
# print "✓ Get with --detail works"

# Test revoke functionality
# print "\n--- Testing revoke functionality ---"

# Create a BP to revoke
let revoke_name = $"Test Revoke($test_suffix)"
let revoke_bp = bp new $revoke_name
let revoke_uu = $revoke_bp.uu.0

# Revoke by piped UUID
let revoke_result = $revoke_uu | bp revoke
assert (($revoke_result | length) == 1) "Should revoke one BP"
assert (($revoke_result.uu.0 == $revoke_uu)) "Should revoke correct BP"

# Verify it's not in normal list
let list_after_revoke = bp list | where name == $revoke_name
assert (($list_after_revoke | length) == 0) "Revoked BP should not appear in normal list"

# Verify it appears in --all list
let list_all = bp list --all | where name == $revoke_name
assert (($list_all | length) == 1) "Revoked BP should appear in --all list"
assert (($list_all.is_revoked.0 == true)) "Should be marked as revoked"
# print "✓ Revoke functionality works correctly"

# Test parent-child relationships
# print "\n--- Testing parent-child relationships ---"

# Create parent BP
let parent_name = $"Parent Corp($test_suffix)"
let parent_bp = bp new $parent_name
let parent_uu = $parent_bp.uu.0

# Create child by piping parent UUID
let child_name = $"Child Subsidiary($test_suffix)"
let child_result = $parent_uu | bp new $child_name --description "Subsidiary of parent"
assert (($child_result | length) == 1) "Should create child BP"
assert (($child_result.parent_uu.0 == $parent_uu)) "Child should have correct parent_uu"
# print "✓ Parent-child creation via piped UUID works"

# Create another child using parent record
let child2_name = $"Child Division($test_suffix)"
let child2_result = $parent_bp | bp new $child2_name
assert (($child2_result | length) == 1) "Should create child from parent record"
assert (($child2_result.parent_uu.0 == $parent_uu)) "Child should have correct parent_uu"
# print "✓ Parent-child creation via piped record works"

# Test JSON parameter functionality
# print "\n--- Testing JSON functionality ---"

# Create BP with JSON data
let json_name = $"JSON Test BP($test_suffix)"
let json_data = {
    website: "https://example.com"
    employees: 50
    tags: ["tech", "startup"]
}
let json_result = bp new $json_name --json ($json_data | to json)
assert (($json_result | length) == 1) "Should create BP with JSON"

# Verify JSON was stored (would need to query DB directly to fully verify)
# print "✓ BP creation with JSON parameter works"

# Create BP without JSON (should default to empty object)
let no_json_name = $"No JSON BP($test_suffix)"
let no_json_result = bp new $no_json_name
assert (($no_json_result | length) == 1) "Should create BP without JSON"
# print "✓ BP creation without JSON works (defaults to empty object)"

# Test template functionality
# print "\n--- Testing template functionality ---"

# Create a template BP
let template_name = $"Template BP($test_suffix)"
let template_result = bp new $template_name --template
assert (($template_result | length) == 1) "Should create template BP"
assert (($template_result.is_template.0 == true)) "Should be marked as template"
# print "✓ Template creation works"

# List templates
let template_list = bp list --templates
let test_templates = $template_list | where name =~ $test_suffix
assert (($test_templates | length) >= 1) "Should find at least one test template"
assert (($test_templates | where name == $template_name | length) == 1) "Should find specific template"
# print "✓ Template listing works"

# Verify templates don't appear in regular list
let regular_list = bp list | where name == $template_name
assert (($regular_list | length) == 0) "Templates should not appear in regular list"
# print "✓ Templates properly filtered from regular list"

# Test bp types command
# print "\n--- Testing types command ---"

let types_list = bp types
assert (($types_list | length) >= 3) "Should have at least 3 BP types"
assert (($types_list | where search_key == "ORGANIZATION" | length) == 1) "Should have ORGANIZATION type"
assert (($types_list | where search_key == "INDIVIDUAL" | length) == 1) "Should have INDIVIDUAL type"
assert (($types_list | where search_key == "GROUP" | length) == 1) "Should have GROUP type"
# print "✓ Types command returns expected types"

# print "\n=== All tests completed successfully ==="
"=== All tests completed successfully ==="