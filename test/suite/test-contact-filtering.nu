#!/usr/bin/env nu

# Test script for contact list filtering and enrichment
# Tests the new piped input and contacts enrichment functionality

# Test-specific suffix to ensure test isolation
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_cf($random_suffix)"  # cf for contact filtering

# Import modules and assert
use ../modules *
use std/assert

# print "=== Testing contact list with piped business partner input ==="

# Create test data
let test_bp1 = (bp new $"Acme Corp($test_suffix)")
let test_bp2 = (bp new $"Widget Inc($test_suffix)")

# Create contacts for each business partner
let contact1_1 = ($test_bp1 | contact new $"John Doe($test_suffix)")
let contact1_2 = ($test_bp1 | contact new $"Jane Smith($test_suffix)")
let contact2_1 = ($test_bp2 | contact new $"Bob Wilson($test_suffix)")

# Create a contact without business partner
let contact_orphan = (contact new $"Orphan Contact($test_suffix)")

# Test 1: Pipe business partner record to contact list
let filtered_by_record = ($test_bp1 | contact list)
assert (($filtered_by_record | length) >= 2) "Should find at least 2 contacts for BP1"
assert (($filtered_by_record | all {|c| $c.stk_business_partner_uu == $test_bp1.uu})) "All contacts should belong to BP1"
assert (($filtered_by_record | any {|c| $c.name == $contact1_1.name})) "Should find John Doe"
assert (($filtered_by_record | any {|c| $c.name == $contact1_2.name})) "Should find Jane Smith"
#print "✓ Piped business partner record filtering verified"

# Test 2: Pipe business partner table to contact list
let filtered_by_table = (bp list | where name == $test_bp2.name | contact list)
assert (($filtered_by_table | length) >= 1) "Should find at least 1 contact for BP2"
assert (($filtered_by_table | all {|c| $c.stk_business_partner_uu == $test_bp2.uu})) "All contacts should belong to BP2"
assert (($filtered_by_table | any {|c| $c.name == $contact2_1.name})) "Should find Bob Wilson"
#print "✓ Piped business partner table filtering verified"

# Test 3: Contact list without piped input (should return all recent contacts)
let all_contacts = (contact list)
# Since contact list only returns 10 most recent, we might not see the orphan contact
# Let's just verify it returns results
assert (($all_contacts | length) > 0) "Should return some contacts"
#print "✓ Contact list without filter verified"

# print "=== Testing contacts enrichment command ==="

# Test 4: Basic contacts enrichment
let enriched_bps = (bp list | where name =~ $test_suffix | contacts)
assert (($enriched_bps | all {|bp| "contacts" in ($bp | columns)})) "All BPs should have contacts column"

# Find our test BPs in the enriched results
let bp1_enriched = ($enriched_bps | where name == $test_bp1.name | first)
let bp2_enriched = ($enriched_bps | where name == $test_bp2.name | first)

assert (($bp1_enriched.contacts | length) >= 2) "BP1 should have at least 2 contacts"
assert (($bp2_enriched.contacts | length) >= 1) "BP2 should have at least 1 contact"
#print "✓ Basic contacts enrichment verified"

# Test 5: Contacts enrichment with specific columns
let enriched_specific = (bp list | where name =~ $test_suffix | contacts name)
let bp1_specific = ($enriched_specific | where name == $test_bp1.name | first)
# When specific columns are requested, they appear first in the output
assert (("name" in ($bp1_specific.contacts.0 | columns))) "Should have name column"
let first_columns = ($bp1_specific.contacts.0 | columns | first 1)
assert ($first_columns.0 == "name") "Name should be the first column when specifically requested"
#print "✓ Specific column enrichment verified"

# Test 6: Contacts enrichment with --detail
let enriched_detail = (bp list | where name =~ $test_suffix | contacts --detail)
let bp1_detail = ($enriched_detail | where name == $test_bp1.name | first)
assert (("record_json" in ($bp1_detail.contacts.0 | columns))) "Detail should include all columns"
#print "✓ Detail enrichment verified"

# Test 7: Table without foreign key relationship (should get empty contacts)
let items_enriched = (item list | contacts)
assert (($items_enriched | all {|item| $item.contacts == []})) "Items should have empty contacts array"
#print "✓ Non-related table enrichment verified"

# Return success string
"=== All contact filtering tests completed successfully ==="