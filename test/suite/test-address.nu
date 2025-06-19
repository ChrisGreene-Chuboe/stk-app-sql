#!/usr/bin/env nu

# === Testing stk_address module functionality ===

# Import modules and assertions
use ../modules *
use std/assert

echo "=== Testing .append address command ==="

# Note: This test assumes AI is available and working
# Run test-ai.nu first to verify AI functionality

# Create a test project
let project = (project new "Address Test Project")
let project_uuid = ($project.uu.0)
echo "✓ Test project created"

# Test 1: Basic address creation (minimal AI call to save costs)
echo "=== Testing basic address creation ==="
let address_tag = ($project_uuid | .append address "123 Main St Austin TX 78701")
assert (($address_tag | length) > 0) "Address tag should be created"
assert ($address_tag.uu.0 | is-not-empty) "Address tag should have UUID"
echo "✓ Address tag created, UUID:" ($address_tag.uu.0)

# Verify the stored data structure
let tag_detail = ($address_tag.uu.0 | tag get)
assert (($tag_detail | columns | any {|col| $col == "record_json"})) "Tag should have record_json"
let address_data = ($tag_detail.record_json.0)
assert ("address1" in $address_data) "Address should have address1 field"
assert ("city" in $address_data) "Address should have city field"
assert ("state" in $address_data) "Address should have state field"  
assert ("postal" in $address_data) "Address should have postal field"
echo "✓ Address data structure verified"

# Verify it's attached to the project
let project_tags = ($project | tags)
assert (($project_tags.tags | length) > 0) "Project should have tags"

let found_address = ($project_tags.tags | where search_key.0 == "ADDRESS" | length)
assert ($found_address > 0) "Project should have ADDRESS tag"
echo "✓ Address tag attached to project"

# Test 2: Verify tag type
assert ($tag_detail.search_key.0 == "ADDRESS") "Tag should have ADDRESS search_key"
echo "✓ Tag type verified"

# Return success message for test harness
"=== All tests completed successfully ===="