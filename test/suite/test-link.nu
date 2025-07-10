#!/usr/bin/env nu

# Test script for stk_link module
# Tests many-to-many linking functionality with bidirectional and unidirectional links

# Import modules and assert
use ../modules *
use std/assert

# Create test records for linking
let project = project new "Test Project for Links"
let item = item new "Test Item for Links"

# === Test 1: Create bidirectional link (default) ===
let link1 = ($project | link new $item --description "Project uses item")
assert ($link1.uu | is-not-empty) "Bidirectional link should have UUID"
assert ($link1.description == "Project uses item") "Description should match"
assert ($link1.type_name == "BIDIRECTIONAL") "Default type should be BIDIRECTIONAL"

# === Test 2: Verify bidirectional link appears from both sides ===
# From project side
let project_links = ($project | links)
assert ((($project_links | first).links | length) == 1) "Project should have 1 link"
let plink = (($project_links | first).links | first)
assert ($plink.name == "Test Item for Links") "Link should show item name"
assert ($plink.linked_table == "stk_item") "Link should reference item table"

# From item side (bidirectional should appear)
let item_links = ($item | links)
assert ((($item_links | first).links | length) == 1) "Item should see bidirectional link"
let ilink = (($item_links | first).links | first)
assert ($ilink.name == "Test Project for Links") "Link should show project name"
assert ($ilink.linked_table == "stk_project") "Link should reference project table"

# === Test 3: Create unidirectional link ===
let business_partner = bp new "Test Business Partner"
let link2 = ($business_partner | link new $project --type-search-key "UNIDIRECTIONAL" --description "BP references project")
assert ($link2.type_name == "UNIDIRECTIONAL") "Type should be UNIDIRECTIONAL"

# === Test 4: Verify unidirectional link behavior ===
# From business partner side (source)
let bp_links = ($business_partner | links)
assert ((($bp_links | first).links | length) == 1) "Business partner should have 1 link"
assert ((($bp_links | first).links | first).name == "Test Project for Links") "Should see project"

# From project side - default now shows all relationships
let project_links2 = ($project | links)
# The project has 1 outgoing bidirectional link to item + 1 incoming unidirectional from BP
assert ((($project_links2 | first).links | length) == 2) "Project should see both relationships by default"

# With --incoming flag, should see incoming links
let project_incoming = ($project | links --incoming)
# Should see incoming unidirectional from BP + bidirectional from item (flipped)
assert ((($project_incoming | first).links | length) == 2) "Project should see 2 incoming links"

# With --outgoing flag, should see only outgoing
let project_outgoing = ($project | links --outgoing)
assert ((($project_outgoing | first).links | length) == 1) "Project should see 1 outgoing link"
assert ((($project_outgoing | first).links | first).name == "Test Item for Links") "Should be the item"

# === Test 5: Test link list command ===
let all_links = link list
assert (($all_links | length) >= 2) "Should have at least 2 links"
assert (($all_links | where description == "Project uses item" | length) == 1) "Should find specific link"

# === Test 6: Test link get command ===
let fetched_link = link get --uu $link1.uu
assert ($fetched_link.uu == $link1.uu) "Should fetch correct link"
assert ($fetched_link.description == "Project uses item") "Fetched link should have correct description"

# === Test 7: Test link revoke ===
link revoke --uu $link2.uu
let active_links = link list
assert ((($active_links | where uu == $link2.uu | length) == 0)) "Revoked link should not appear in list"

# Test that revoked links appear with --all
let all_links_including_revoked = link list --all
assert ((($all_links_including_revoked | where uu == $link2.uu | length) == 1)) "Revoked link should appear with --all"

# === Test 8: Test link types command ===
let types = link types
assert (($types | length) == 2) "Should have 2 link types"
assert (($types | where type_enum == "BIDIRECTIONAL" | length) == 1) "Should have BIDIRECTIONAL type"
assert (($types | where type_enum == "UNIDIRECTIONAL" | length) == 1) "Should have UNIDIRECTIONAL type"

# === Test 9: Test links with --detail flag ===
let detailed_links = ($project | links --detail)
assert (($detailed_links | first).links | first | columns | "uu" in $in) "Detailed links should include uu"

# === Test 10: Test multiple links from same source ===
let another_item = item new "Another Test Item"
let link3 = ($business_partner | link new $another_item --description "BP supplies item")
let bp_multi_links = ($business_partner | links)
assert ((($bp_multi_links | first).links | length) == 1) "Should only see active links (one was revoked)"

# === Test 11: Comprehensive bidirectional symmetry ===
# Create fresh records for isolated testing
let proj2 = project new "Test Project 2"
let item2 = item new "Test Item 2"

# Create bidirectional link: proj2 -> item2
let bilink = ($proj2 | link new $item2 --type-search-key BIDIRECTIONAL --description "proj-item bidirectional")

# Both sides should see each other by default
let proj2_links = ($proj2 | links)
assert ((($proj2_links | first).links | length) == 1) "Project 2 should see item 2"
assert ((($proj2_links | first).links | first).name == "Test Item 2") "Should be item 2"

let item2_links = ($item2 | links)
assert ((($item2_links | first).links | length) == 1) "Item 2 should see project 2"
assert ((($item2_links | first).links | first).name == "Test Project 2") "Should be project 2"

# === Test 12: Direction flags with pure bidirectional ===
# Item2 --outgoing: should see project (bidirectional flipped as outgoing)
let item2_out = ($item2 | links --outgoing)
assert ((($item2_out | first).links | length) == 1) "Item --outgoing should see 1 link"
assert ((($item2_out | first).links | first).name == "Test Project 2") "Should see project as outgoing"

# Item2 --incoming: should see project (bidirectional as incoming)
let item2_in = ($item2 | links --incoming)
assert ((($item2_in | first).links | length) == 1) "Item --incoming should see 1 link"
assert ((($item2_in | first).links | first).name == "Test Project 2") "Should see project as incoming"

# === Test 13: Multiple bidirectional links ===
let bp2 = bp new "Test Business Partner 2"

# Create another bidirectional link: item2 -> bp2
let bilink2 = ($item2 | link new $bp2 --type-search-key BIDIRECTIONAL --description "item-bp bidirectional")

# Item2 should now see 2 links by default
let item2_final = ($item2 | links)
assert ((($item2_final | first).links | length) == 2) "Item should see 2 links"
let item2_link_names = (($item2_final | first).links | get name | sort)
assert ($item2_link_names == ["Test Business Partner 2", "Test Project 2"]) "Item should see both project and BP"

# BP2 should see item2 (bidirectional works from both sides)
let bp2_links = ($bp2 | links)
assert ((($bp2_links | first).links | length) == 1) "BP2 should see 1 link"
assert ((($bp2_links | first).links | first).name == "Test Item 2") "BP2 should see item"

"=== All tests completed successfully ==="