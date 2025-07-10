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

# From project side - by default only sees outgoing links + incoming bidirectional
let project_links2 = ($project | links)
# The project has 1 outgoing bidirectional link to item (no incoming shown by default)
assert ((($project_links2 | first).links | length) == 1) "Project should see only bidirectional link by default"

# With --incoming flag, should see incoming links
let project_incoming = ($project | links --incoming)
# Should see at least the incoming unidirectional link
assert ((($project_incoming | first).links | length) >= 1) "Project should see at least 1 incoming link"

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

"=== All tests completed successfully ==="