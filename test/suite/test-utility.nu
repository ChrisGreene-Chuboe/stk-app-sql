#!/usr/bin/env nu

# Test script for stk_utility module
# Test script for stk_utility module

# Test-specific suffix to ensure test isolation and idempotency
# Generate random 2-char suffix from letters (upper/lower) and numbers
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_su($random_suffix)"  # su for stk_utility + 2 random chars

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

# === Testing extract-uu-table-name function ===

# Create a real record to test with
let test_item = (item new $"Test Item($test_suffix)" --description "For utility testing")
let real_uuid = $test_item.uu

# Test 1: String UUID input (now with real UUID that exists in database)
let string_result = ($real_uuid | extract-uu-table-name)
assert ((($string_result | describe) | str starts-with "record")) "Should return record for single input"
assert (($string_result.uu == $real_uuid)) "UUID should match input"
assert (($string_result.table_name == "stk_item")) "table_name should be looked up"
# Test 2: Record with uu field and table_name already provided
let record_input = {uu: $real_uuid, name: "Test Record", table_name: "stk_project"}
let record_result = ($record_input | extract-uu-table-name)
assert ((($record_result | describe) | str starts-with "record")) "Should return record for single input"
assert (($record_result.uu == $record_input.uu)) "UUID should match"
assert (($record_result.table_name == "stk_project")) "table_name should be preserved"
# Test 3: Record without table_name (should lookup)
let record_no_table = {uu: $real_uuid, other_field: "data"}
let record_no_table_result = ($record_no_table | extract-uu-table-name)
assert ((($record_no_table_result | describe) | str starts-with "record")) "Should return record for single input"
assert (($record_no_table_result.uu == $record_no_table.uu)) "UUID should match"
assert (($record_no_table_result.table_name == "stk_item")) "table_name should be looked up"
# Test 4: Single-row table with table_name provided
let table_input = [[uu, name, table_name]; [$real_uuid, "Table Item", "stk_item"]]
let table_result = ($table_input | extract-uu-table-name)
assert (($table_result | length) == 1) "Should have one row"
assert (($table_result.0.uu == $real_uuid)) "UUID should match"
assert (($table_result.0.table_name == "stk_item")) "table_name should match"
# Test 5: Multi-row table with real items
# Create additional test records
let test_item2 = (item new $"Test Item 2($test_suffix)")
let test_item3 = (item new $"Test Item 3($test_suffix)")
let multi_table = [
    [uu, name]; 
    [$real_uuid, "First"]
    [$test_item2.uu, "Second"]
    [$test_item3.uu, "Third"]
]
let multi_result = ($multi_table | extract-uu-table-name)
assert (($multi_result | length) == 3) "Should have three rows"
assert (($multi_result.0.uu == $real_uuid)) "First UUID should match"
assert (($multi_result.0.table_name == "stk_item")) "First table_name should be looked up"
assert (($multi_result.1.uu == $test_item2.uu)) "Second UUID should match"
assert (($multi_result.1.table_name == "stk_item")) "Second table_name should be looked up"
assert (($multi_result.2.uu == $test_item3.uu)) "Third UUID should match"
assert (($multi_result.2.table_name == "stk_item")) "Third table_name should be looked up"
# Test 6: Empty table should now throw error
let empty_table = ([] | where false)  # Create empty table
try {
    $empty_table | extract-uu-table-name
    assert false "Should have thrown error for empty table"
} catch { |err|
    assert (($err.msg | str contains "Input required")) "Should show correct error message for empty table"
}
# Test 7: Null/empty input should now throw error
try {
    null | extract-uu-table-name
    assert false "Should have thrown error for null input"
} catch { |err|
    assert (($err.msg | str contains "Input required")) "Should show correct error message"
}
# === Testing error cases ===
# Test 8: Record without uu field
let bad_record = {name: "No UUID", other: "data"}
try {
    $bad_record | extract-uu-table-name
    assert false "Should have thrown error for record without uu field"
} catch { |err|
    # Error is wrapped in pipeline error, check either in main message or debug field
    let has_error = (($err.msg | str contains "pipeline input") or ($err.debug? | str contains "Record must contain 'uu' field") or ($err.rendered? | str contains "Record must contain 'uu' field"))
    assert $has_error "Should show error about missing uu field"
}
# Test 9: Invalid input type
let invalid_input = 42  # Number instead of string/record/table
try {
    $invalid_input | extract-uu-table-name
    assert false "Should have thrown error for invalid input type"
} catch { |err|
    assert (($err.msg | str contains "Input must be a string UUID, record, or table")) "Should show correct error message"
}
# Test 10: Table row without uu field
let bad_table = [[name, value]; ["Missing UUID", 123]]
let result = ($bad_table | extract-uu-table-name)
# When using 'each' with tables, errors become part of the result
assert ((($result | describe) | str contains "error")) "Should have produced an error for table without uu field"
# === Testing new --first and --table parameters ===
# print "=== Testing new --first and --table parameters ===" # COMMENTED OUT - uncomment only for debugging

# Test 11: String input with --table flag
let string_table_result = ($real_uuid | extract-uu-table-name --table)
assert ((($string_table_result | describe) | str starts-with "table")) "String with --table should return table"
assert (($string_table_result | length) == 1) "Should have one row"
assert (($string_table_result.0.uu == $real_uuid)) "UUID should match"
assert (($string_table_result.0.table_name == "stk_item")) "table_name should be looked up"

# Test 12: Record input with --table flag
let record_table_result = ($record_input | extract-uu-table-name --table)
assert ((($record_table_result | describe) | str starts-with "table")) "Record with --table should return table"
assert (($record_table_result | length) == 1) "Should have one row"
assert (($record_table_result.0.uu == $record_input.uu)) "UUID should match"

# Test 13: Table input with --first flag
let table_first_result = ($multi_table | extract-uu-table-name --first)
assert ((($table_first_result | describe) | str starts-with "record")) "Table with --first should return single record"
assert (($table_first_result.uu == $real_uuid)) "Should return first record's UUID"
assert (($table_first_result.table_name == "stk_item")) "Should return first record's table_name"

# Test 14: Table input with --first --table flags
let table_first_table_result = ($multi_table | extract-uu-table-name --first --table)
assert ((($table_first_table_result | describe) | str starts-with "table")) "Table with --first --table should return table"
assert (($table_first_table_result | length) == 1) "Should have exactly one row"
assert (($table_first_table_result.0.uu == $real_uuid)) "Should contain first record's UUID"

# Test 15: Verify extract-single-uu uses new --first parameter
let single_uu_result = ($multi_table | extract-single-uu)
assert (($single_uu_result | describe) == "string") "extract-single-uu should return string"
assert (($single_uu_result == $real_uuid)) "Should return first UUID"

# Test 16: Verify extract-attach-from-input uses new --first parameter
let attach_result = ($multi_table | extract-attach-from-input)
assert ((($attach_result | describe) | str starts-with "record")) "extract-attach-from-input should return single record"
assert (($attach_result.uu == $real_uuid)) "Should return first record's UUID"
assert (($attach_result.table_name == "stk_item")) "Should return first record's table_name"

# Return success message for test harness
"=== All tests completed successfully ==="