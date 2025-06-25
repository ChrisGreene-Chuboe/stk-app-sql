#!/usr/bin/env nu

# Test script for stk_tag module
echo "=== Testing stk_tag Module ==="

# Test-specific suffix to ensure test isolation and idempotency
# Generate random 2-char suffix from letters (upper/lower) and numbers
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_sg($random_suffix)"  # sg for stk_tag + 2 random chars

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

echo "=== Testing tag types command ==="
let types_result = (tag types)
assert (($types_result | length) > 0) "Should return at least one tag type"
assert ($types_result | columns | any {|col| $col == "type_enum"}) "Result should contain 'type_enum' field"
assert ($types_result | columns | any {|col| $col == "name"}) "Result should contain 'name' field"
assert ($types_result | columns | any {|col| $col == "record_json"}) "Result should contain 'record_json' field (schema)"

# Check that expected types exist
let type_enums = ($types_result | get type_enum)
assert ($type_enums | any {|t| $t == "ADDRESS"}) "Should have ADDRESS type"
assert ($type_enums | any {|t| $t == "PHONE"}) "Should have PHONE type"
assert ($type_enums | any {|t| $t == "EMAIL"}) "Should have EMAIL type"
assert ($type_enums | any {|t| $t == "NONE"}) "Should have NONE type"
# Also verify name column exists in results
assert ($types_result | columns | any {|col| $col == "name"}) "Types should have name column"
echo "✓ Tag types verified successfully"

echo "=== Testing basic tag creation with NONE type ==="
# Create a project to tag
let test_project = (project new $"Tag Test Project($test_suffix)" --description "Project for testing tags")
let project_uuid = ($test_project.uu.0)

# Create a simple tag with NONE type
let simple_tag = ($project_uuid | .append tag --type-search-key NONE --description "Simple tag with no schema")
assert ($simple_tag | columns | any {|col| $col == "uu"}) "Tag creation should return UUID"
assert ($simple_tag.uu | is-not-empty) "Tag UUID should not be empty"
echo "✓ Basic tag creation verified with UUID:" ($simple_tag.uu)

echo "=== Testing tag creation with ADDRESS type and JSON data ==="
let address_json = '{"address1": "123 Main St", "city": "Austin", "state": "TX", "postal": "78701"}'
let address_tag = ($project_uuid | .append tag --search-key "headquarters" --type-search-key ADDRESS --json $address_json --description "Company headquarters")
assert ($address_tag | columns | any {|col| $col == "uu"}) "Address tag should return UUID"
assert ($address_tag.uu | is-not-empty) "Address tag UUID should not be empty"
echo "✓ Address tag creation verified"

echo "=== Testing tag creation with EMAIL type ==="
let email_tag = ($project_uuid | .append tag --type-search-key EMAIL --json '{"email": "test@example.com"}' --description "Contact email")
assert ($email_tag | columns | any {|col| $col == "uu"}) "Email tag should return UUID"
assert ($email_tag.uu | is-not-empty) "Email tag UUID should not be empty"
echo "✓ Tag creation with EMAIL type verified"

echo "=== Testing tag creation with type-uu parameter ==="
# Get EMAIL type UUID
let email_type = ($types_result | where type_enum == "EMAIL" | get 0)
let phone_tag = ($project_uuid | .append tag --type-uu $email_type.uu --json '{"email": "support@example.com"}' --search-key "support-email")
assert ($phone_tag | columns | any {|col| $col == "uu"}) "Tag with type-uu should return UUID"
assert ($phone_tag.uu | is-not-empty) "Tag UUID should not be empty"
echo "✓ Tag creation with type-uu verified"

echo "=== Testing tag list ==="
let tags = (tag list)
assert (($tags | length) >= 4) "Tag list should contain at least 4 tags (the ones we created)"
assert ($tags | columns | any {|col| $col == "uu"}) "Tag list should contain uu column"
assert ($tags | columns | any {|col| $col == "search_key"}) "Tag list should contain search_key column"
assert ($tags | columns | any {|col| $col == "description"}) "Tag list should contain description column"
assert ($tags | columns | any {|col| $col == "table_name_uu_json"}) "Tag list should contain table_name_uu_json column"
echo "✓ Tag list verified with" ($tags | length) "tags"

echo "=== Testing tag list --detail ==="
let detailed_tags = (tag list --detail)
assert (($detailed_tags | length) >= 4) "Detailed tag list should contain at least 4 tags"
assert ($detailed_tags | columns | any {|col| $col == "type_enum"}) "Detailed list should contain type_enum"
assert ($detailed_tags | columns | any {|col| $col == "type_name"}) "Detailed list should contain type_name"
assert ($detailed_tags | columns | any {|col| $col == "type_description"}) "Detailed list should contain type_description"
echo "✓ Tag list --detail verified"

echo "=== Testing tag get ==="
let tag_uuid = ($address_tag.uu.0)
let tag_detail = ($tag_uuid | tag get)
assert (($tag_detail | length) == 1) "Tag get should return exactly one record"
assert ($tag_detail.uu.0 == $tag_uuid) "Returned tag should have matching UUID"
assert ($tag_detail.search_key.0 == "headquarters") "Search key should match"
assert ($tag_detail | columns | any {|col| $col == "record_json"}) "Tag should contain record_json"

# Verify the JSON data (already parsed by psql exec)
let stored_json = $tag_detail.record_json.0
assert ($stored_json.address1 == "123 Main St") "Address1 should be preserved"
assert ($stored_json.city == "Austin") "City should be preserved"
assert ($stored_json.postal == "78701") "Postal code should be preserved"
echo "✓ Tag get verified with correct JSON data"

echo "=== Testing tag get --detail ==="
let detailed_tag = ($tag_uuid | tag get --detail)
assert (($detailed_tag | length) == 1) "Detailed tag get should return exactly one record"
assert ($detailed_tag | columns | any {|col| $col == "type_enum"}) "Detailed tag should include type_enum"
assert ($detailed_tag.type_enum.0 == "ADDRESS") "Type enum should be ADDRESS"
echo "✓ Tag get --detail verified"

echo "=== Testing tag filtering by search_key ==="
let headquarters_tags = (tag list | where search_key == "headquarters")
assert (($headquarters_tags | length) == 1) "Should find exactly one headquarters tag"
assert ($headquarters_tags.uu.0 == $tag_uuid) "Found tag should match our created tag"
echo "✓ Tag filtering by search_key verified"

echo "=== Testing elaborate command with tags ==="
let tags_with_elaborate = (tag list | elaborate)
assert ($tags_with_elaborate | columns | any {|col| $col == "table_name_uu_json_resolved"}) "Elaborate should add table_name_uu_json_resolved column"
# Check that we have tags for projects by examining the table_name_uu_json column
let project_tags = ($tags_with_elaborate | where {|row| $row.table_name_uu_json.table_name == "stk_project"})
assert (($project_tags | length) >= 4) "Should find at least 4 project tags"
echo "✓ Tag elaborate command verified"

echo "=== Testing tag on different table types ==="
# Create an event to tag
let test_event = (.append event "tag-test-event" --description "Event for tag testing")
let event_uuid = ($test_event.uu.0)

# Tag the event
let event_tag = ($event_uuid | .append tag --type-search-key NONE --search-key "event-metadata" --description "Metadata for event")
assert ($event_tag.uu | is-not-empty) "Event tag should be created"

# Verify table_name_uu_json contains correct table
let event_tag_detail = ($event_tag.uu.0 | tag get)
let table_json = $event_tag_detail.table_name_uu_json.0
assert ($table_json.table_name == "stk_event") "Table name should be stk_event"
assert ($table_json.uu == $event_uuid) "UUID should match event UUID"
echo "✓ Tag on different table types verified"

echo "=== Testing tag revoke ==="
let revoke_result = ($tag_uuid | tag revoke)
assert ($revoke_result | columns | any {|col| $col == "is_revoked"}) "Revoke should return is_revoked status"
assert ($revoke_result.is_revoked.0 == true) "Tag should be marked as revoked"

# Verify tag is excluded from default list
let active_tags = (tag list)
let revoked_tag_search = ($active_tags | where uu == $tag_uuid)
assert (($revoked_tag_search | length) == 0) "Revoked tag should not appear in default list"

# Verify tag appears in --all list
let all_tags = (tag list --all)
let revoked_in_all = ($all_tags | where uu == $tag_uuid)
assert (($revoked_in_all | length) == 1) "Revoked tag should appear in --all list"
assert ($revoked_in_all.is_revoked.0 == true) "Tag should show as revoked in --all list"
echo "✓ Tag revoke functionality verified"

echo "=== Testing error cases ==="
# Now that psql error handling is fixed, we can test error cases

# Test invalid column in tags command
# The tags command gracefully handles errors by returning an error object
let result_with_error = (project list | where name == $"Tag Test Project($test_suffix)" | tags invalid_column_name)
let first_result = ($result_with_error | get 0)
let tags_result = ($first_result | get tags)

# Verify that an error was caught and handled
assert ($tags_result | describe | str contains "record") "Tags should contain error record"
assert ("error" in ($tags_result | columns)) "Should have error field"
assert (($tags_result.error | str length) > 0) "Should have error message"

# Test tagging with invalid type
let invalid_type_result = (try {
    $project_uuid | .append tag --type-search-key "INVALID_TYPE_THAT_DOES_NOT_EXIST"
    false
} catch {
    true
})
assert $invalid_type_result "Should fail with invalid type"

echo "✓ Error cases verified"

echo "=== Testing edge cases ==="
# Create tag without search_key (should use UUID)
let no_search_key_tag = ($project_uuid | .append tag --type-search-key NONE)
assert ($no_search_key_tag.uu | is-not-empty) "Tag without search_key should be created"

# Create tag with empty JSON
let empty_json_tag = ($project_uuid | .append tag --type-search-key NONE --json '{}')
assert ($empty_json_tag.uu | is-not-empty) "Tag with empty JSON should be created"

# Create tag without description
let no_desc_tag = ($project_uuid | .append tag --type-search-key NONE --search-key "no-desc")
assert ($no_desc_tag.uu | is-not-empty) "Tag without description should be created"
echo "✓ Edge cases verified"

#print "=== Testing UUID input enhancement - .append tag with record ==="
# Get a project as a record to tag
let project_record = (project list | where uu == $project_uuid | get 0)
assert (("uu" in ($project_record | columns))) "Project record should have uu field"
assert (("table_name" in ($project_record | columns))) "Project record should have table_name field"

# Tag using record input (with table_name optimization)
let tag_from_record = ($project_record | .append tag --type-search-key NONE --search-key $"record-tag($test_suffix)" --description "Tagged from record")
assert (($tag_from_record | columns | any {|col| $col == "uu"})) "Should create tag from record"

# Verify the tag was created correctly
let record_tag_detail = ($tag_from_record.uu.0 | tag get)
assert (($record_tag_detail.table_name_uu_json.0.uu == $project_uuid)) "Tag should reference correct project"
assert (($record_tag_detail.table_name_uu_json.0.table_name == "stk_project")) "Tag should have correct table name"
#print "✓ .append tag accepts record input with table_name optimization"

#print "=== Testing UUID input enhancement - .append tag with table ==="
# Tag using table input (single row)
let tag_from_table = (project list | where uu == $project_uuid | .append tag --type-search-key NONE --search-key $"table-tag($test_suffix)")
assert (($tag_from_table | columns | any {|col| $col == "uu"})) "Should create tag from table"

# Verify the relationship
let table_tag_detail = ($tag_from_table.uu.0 | tag get)
assert (($table_tag_detail.table_name_uu_json.0.uu == $project_uuid)) "Table tag should reference project"
#print "✓ .append tag accepts table input"

#print "=== Testing UUID input enhancement - tag get with record ==="
# Get tag using record input
let tag_to_get = (tag list | where search_key =~ $"record-tag($test_suffix)" | get 0)
let get_from_record = ($tag_to_get | tag get)
assert (($get_from_record.uu.0 == $tag_to_get.uu)) "Should get correct tag from record"
#print "✓ tag get accepts record input"

#print "=== Testing UUID input enhancement - tag get with table ==="
# Get tag using table input
let get_from_table = (tag list | where search_key =~ $"table-tag($test_suffix)" | tag get)
assert (($get_from_table.search_key.0 | str contains $"table-tag($test_suffix)")) "Should get correct tag from table"
#print "✓ tag get accepts table input"

#print "=== Testing UUID input enhancement - tag revoke with record ==="
# Create a tag to revoke
let revoke_test = ($project_uuid | .append tag --type-search-key NONE --search-key $"to-revoke-record($test_suffix)")
let revoke_uuid = ($revoke_test.uu.0)

# Get as record and revoke
let revoke_record = (tag list | where uu == $revoke_uuid | get 0)
let revoked_result = ($revoke_record | tag revoke)
assert (($revoked_result.is_revoked.0 == true)) "Should revoke tag from record"
#print "✓ tag revoke accepts record input"

#print "=== Testing UUID input enhancement - tag revoke with table ==="
# Create another tag to revoke
let revoke_test2 = ($project_uuid | .append tag --type-search-key NONE --search-key $"to-revoke-table($test_suffix)")

# Revoke using table input
let revoked_result2 = (tag list | where search_key =~ $"to-revoke-table($test_suffix)" | tag revoke)
assert (($revoked_result2.is_revoked.0 == true)) "Should revoke tag from table"
#print "✓ tag revoke accepts table input"

#print "=== Testing UUID input enhancement - item tagging ==="
# Create an item to tag (different table than project)
let test_item = (item new $"Test Item($test_suffix)")
let item_uuid = ($test_item.uu.0)
let item_record = (item list | where uu == $item_uuid | get 0)

# Tag the item using record (tests table_name optimization with different table)
let item_tag = ($item_record | .append tag --type-search-key NONE --search-key $"item-tag($test_suffix)")
assert (($item_tag | columns | any {|col| $col == "uu"})) "Should create tag for item"

# Verify correct table reference
let item_tag_detail = ($item_tag.uu.0 | tag get)
assert (($item_tag_detail.table_name_uu_json.0.table_name == "stk_item")) "Tag should reference stk_item table"
assert (($item_tag_detail.table_name_uu_json.0.uu == $item_uuid)) "Tag should reference correct item"
#print "✓ Table name optimization works with different table types"

# Return success string as final expression
"=== All tests completed successfully ==="
