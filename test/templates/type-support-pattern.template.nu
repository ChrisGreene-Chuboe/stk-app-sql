# === Testing type support ===
# Template: Replace MODULE with your module name (e.g., item, bp, project)
# Template Version: 2025-01-07
# Note: This pattern assumes MODULE new accepts type parameters
#       For modules like event that have types but don't accept them during creation,
#       just test the types command and verify get shows type info

# print "=== Testing MODULE types ==="
let types = (MODULE types)
assert ($types | is-not-empty) "Should have types"
assert ($types | columns | any {|col| $col == "uu"}) "Types should have uu"
assert ($types | columns | any {|col| $col == "search_key"}) "Types should have search_key"

# Use first type for testing
let test_type = ($types | first)

# print "=== Testing MODULE creation with type ==="
# Note: If your module doesn't accept type parameters during creation (e.g., event module),
#       comment out this section and add a note explaining why
let typed = (MODULE new $"Typed($test_suffix)" --type-search-key $test_type.search_key)
assert ($typed.type_uu.0 == $test_type.uu) "Should have correct type"

# print "=== Testing MODULE get shows type ==="
# Note: This should work even if types aren't settable during creation
let typed_get = ($typed.uu.0 | MODULE get)
assert ($typed_get.type_name | is-not-empty) "Should show type name"
assert ($typed_get.type_enum | is-not-empty) "Should show type enum"