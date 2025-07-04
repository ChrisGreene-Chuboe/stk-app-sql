# === Testing parent-child pattern ===
# Template: Replace MODULE with your module name (e.g., project)
# Template Version: 2025-01-04

print "=== Testing MODULE parent-child creation ==="
let parent = (MODULE new $"Parent($test_suffix)")

print "=== Testing child creation with string UUID ==="
let child1 = ($parent.uu.0 | MODULE new $"Child 1($test_suffix)")
assert ($child1.parent_uu.0 == $parent.uu.0) "Child should have parent UUID"

print "=== Testing child creation with table input ==="
let child2 = ($parent | MODULE new $"Child 2($test_suffix)")
assert ($child2.parent_uu.0 == $parent.uu.0) "Child should have parent UUID from table"

print "=== Testing child creation with record input ==="
let child3 = ($parent | first | MODULE new $"Child 3($test_suffix)")
assert ($child3.parent_uu.0 == $parent.uu.0) "Child should have parent UUID from record"

print "=== Testing children enrichment ==="
let with_children = ($parent.uu.0 | MODULE get | children)
assert (($with_children.children | where name =~ $test_suffix | length) >= 3) "Parent should have children"

print "=== Testing invalid parent UUID ==="
try {
    "invalid-uuid" | MODULE new $"Invalid Child($test_suffix)"
    error make {msg: "Invalid parent UUID should have failed"}
} catch {
    print "  ✓ Invalid parent UUID correctly rejected"
}