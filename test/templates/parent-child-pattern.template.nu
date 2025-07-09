# === Testing parent-child pattern ===
# Template: Replace MODULE with your module name (e.g., project)
# Template Version: 2025-01-08

# print "=== Testing MODULE parent-child creation ==="
let parent = (MODULE new $"Parent($test_suffix)")

# print "=== Testing child creation with string UUID ==="
let child1 = ($parent.uu | MODULE new $"Child 1($test_suffix)")
assert ($child1.parent_uu == $parent.uu) "Child should have parent UUID"

# print "=== Testing child creation with table input ==="
# Need to convert record to table for this test
let child2 = ([$parent] | MODULE new $"Child 2($test_suffix)")
assert ($child2.parent_uu == $parent.uu) "Child should have parent UUID from table"

# print "=== Testing child creation with record input ==="
let child3 = ($parent | MODULE new $"Child 3($test_suffix)")
assert ($child3.parent_uu == $parent.uu) "Child should have parent UUID from record"

# print "=== Testing children enrichment ==="
let with_children = ($parent.uu | MODULE get | children)
assert (($with_children.children | where name =~ $test_suffix | length) >= 3) "Parent should have children"

# print "=== Testing invalid parent UUID ==="
try {
    "invalid-uuid" | MODULE new $"Invalid Child($test_suffix)"
    error make {msg: "Invalid parent UUID should have failed"}
} catch {
    # print "  ✓ Invalid parent UUID correctly rejected"
}