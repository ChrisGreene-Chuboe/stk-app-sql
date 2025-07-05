# === Testing UUID input variations ===
# Template: Replace MODULE with your module name (e.g., item, bp, project)
# Template Version: 2025-01-04

# print "=== Testing MODULE get with string UUID ==="
let get_string = ($parent_uu | MODULE get)
assert ($get_string.uu == $parent_uu) "Should get correct record with string UUID"

# print "=== Testing MODULE get with record input ==="
let get_record = ($parent | first | MODULE get)
assert ($get_record.uu == $parent_uu) "Should get correct record from record input"

# print "=== Testing MODULE get with table input ==="
let get_table = ($parent | MODULE get)
assert ($get_table.uu == $parent_uu) "Should get correct record from table input"

# print "=== Testing MODULE get with --uu parameter ==="
let get_param = (MODULE get --uu $parent_uu)
assert ($get_param.uu == $parent_uu) "Should get correct record with --uu parameter"

# print "=== Testing MODULE get with empty table (should fail) ==="
try {
    [] | MODULE get
    error make {msg: "Empty table should have failed"}
} catch {
    # print "  ✓ Empty table correctly rejected"
}

# print "=== Testing MODULE get with multi-row table ==="
let multi_table = [$parent, $parent] | flatten
let get_multi = ($multi_table | MODULE get)
assert ($get_multi.uu == $parent_uu) "Should use first row from multi-row table"

# print "=== Testing MODULE revoke with string UUID ==="
let revoke_item = (MODULE new $"Revoke Test($test_suffix)")
let revoke_string = ($revoke_item.uu.0 | MODULE revoke)
assert ($revoke_string.is_revoked.0 == true) "Should revoke with string UUID"

# print "=== Testing MODULE revoke with --uu parameter ==="
let revoke_item2 = (MODULE new $"Revoke Test 2($test_suffix)")
let revoke_param = (MODULE revoke --uu $revoke_item2.uu.0)
assert ($revoke_param.is_revoked.0 == true) "Should revoke with --uu parameter"

# print "=== Testing MODULE revoke with record input ==="
let revoke_item3 = (MODULE new $"Revoke Test 3($test_suffix)")
let revoke_record = ($revoke_item3 | first | MODULE revoke)
assert ($revoke_record.is_revoked.0 == true) "Should revoke from record input"

# print "=== Testing MODULE revoke with table input ==="
let revoke_item4 = (MODULE new $"Revoke Test 4($test_suffix)")
let revoke_table = ($revoke_item4 | MODULE revoke)
assert ($revoke_table.is_revoked.0 == true) "Should revoke from table input"