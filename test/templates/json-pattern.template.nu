# === Testing JSON parameter ===
# Template: Replace MODULE with your module name (e.g., item, bp, project)
# Template Version: 2025-01-04

# print "=== Testing MODULE creation with JSON ==="
let json_created = (MODULE new $"JSON Test($test_suffix)" --json '{"test": true, "value": 42}')
assert ($json_created | is-not-empty) "Should create with JSON"

# print "=== Verifying stored JSON ==="
let json_detail = ($json_created.uu.0 | MODULE get)
assert ($json_detail.record_json.test == true) "Should store JSON test field"
assert ($json_detail.record_json.value == 42) "Should store JSON value field"

# print "=== Testing MODULE creation without JSON (default) ==="
let no_json = (MODULE new $"No JSON Test($test_suffix)")
let no_json_detail = ($no_json.uu.0 | MODULE get)
assert ($no_json_detail.record_json == {}) "Should default to empty object"

# print "=== Testing MODULE creation with complex JSON ==="
let complex_json = '{"nested": {"deep": {"value": "found"}}, "array": [1, 2, 3]}'
let complex_created = (MODULE new $"Complex JSON($test_suffix)" --json $complex_json)
let complex_detail = ($complex_created.uu.0 | MODULE get)
assert ($complex_detail.record_json.nested.deep.value == "found") "Should store nested JSON"
assert (($complex_detail.record_json.array | length) == 3) "Should store JSON arrays"