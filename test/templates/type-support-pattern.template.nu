# === Testing type support ===
# Template: Replace MODULE with your module name (e.g., item, bp, project)
# Template Version: 2025-01-04

# print "=== Testing MODULE types ==="
let types = (MODULE types)
assert ($types | is-not-empty) "Should have types"
assert ($types | columns | any {|col| $col == "uu"}) "Types should have uu"
assert ($types | columns | any {|col| $col == "search_key"}) "Types should have search_key"

# Use first type for testing
let test_type = ($types | first)

# print "=== Testing MODULE creation with type ==="
let typed = (MODULE new $"Typed($test_suffix)" --type-search-key $test_type.search_key)
assert ($typed.type_uu.0 == $test_type.uu) "Should have correct type"

# print "=== Testing MODULE get --detail shows type ==="
let typed_detail = ($typed.uu.0 | MODULE get --detail)
assert ($typed_detail.type_name | is-not-empty) "Should show type name"
assert ($typed_detail.type_enum | is-not-empty) "Should show type enum"