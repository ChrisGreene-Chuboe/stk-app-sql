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

# Test 1: String UUID input
let string_uuid = "12345678-1234-5678-9012-123456789abc"
let string_result = ($string_uuid | extract-uu-table-name)
assert ((($string_result | describe) | str starts-with "table")) "Should return table"
assert (($string_result | length) == 1) "Should have one row"
assert (($string_result.0.uu == $string_uuid)) "UUID should match input"
assert (($string_result.0.table_name | is-empty)) "table_name should be null"
# Test 2: Record with uu field
let record_input = {uu: "87654321-4321-8765-2109-cba987654321", name: "Test Record", table_name: "stk_project"}
let record_result = ($record_input | extract-uu-table-name)
assert ((($record_result | describe) | str starts-with "table")) "Should return table"
assert (($record_result | length) == 1) "Should have one row"
assert (($record_result.0.uu == $record_input.uu)) "UUID should match"
assert (($record_result.0.table_name == "stk_project")) "table_name should match"
# Test 3: Record without table_name
let record_no_table = {uu: "11111111-1111-1111-1111-111111111111", other_field: "data"}
let record_no_table_result = ($record_no_table | extract-uu-table-name)
assert (($record_no_table_result | length) == 1) "Should have one row"
assert (($record_no_table_result.0.uu == $record_no_table.uu)) "UUID should match"
assert (($record_no_table_result.0.table_name | is-empty)) "table_name should be null"
# Test 4: Single-row table
let table_input = [[uu, name, table_name]; ["22222222-2222-2222-2222-222222222222", "Table Item", "stk_item"]]
let table_result = ($table_input | extract-uu-table-name)
assert (($table_result | length) == 1) "Should have one row"
assert (($table_result.0.uu == "22222222-2222-2222-2222-222222222222")) "UUID should match"
assert (($table_result.0.table_name == "stk_item")) "table_name should match"
# Test 5: Multi-row table
let multi_table = [
    [uu, name]; 
    ["33333333-3333-3333-3333-333333333333", "First"]
    ["44444444-4444-4444-4444-444444444444", "Second"]
    ["55555555-5555-5555-5555-555555555555", "Third"]
]
let multi_result = ($multi_table | extract-uu-table-name)
assert (($multi_result | length) == 3) "Should have three rows"
assert (($multi_result.0.uu == "33333333-3333-3333-3333-333333333333")) "First UUID should match"
assert (($multi_result.1.uu == "44444444-4444-4444-4444-444444444444")) "Second UUID should match"
assert (($multi_result.2.uu == "55555555-5555-5555-5555-555555555555")) "Third UUID should match"
# Test 6: Empty table
let empty_table = ([] | where false)  # Create empty table
let empty_result = ($empty_table | extract-uu-table-name)
assert (($empty_result | length) == 0) "Should return empty list"
# Empty list returns as list<any>, not table - this is expected behavior
assert ((($empty_result | describe) | str starts-with "list")) "Empty result is a list"
# Test 7: Null/empty input
let null_result = (null | extract-uu-table-name)
assert (($null_result | length) == 0) "Null should return empty list"
assert ((($null_result | describe) | str starts-with "list")) "Null result is a list"
# === Testing error cases ===
# Test 8: Record without uu field
let bad_record = {name: "No UUID", other: "data"}
try {
    $bad_record | extract-uu-table-name
    assert false "Should have thrown error for record without uu field"
} catch { |err|
    assert (($err.msg | str contains "Record must contain 'uu' field")) "Should show correct error message"
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
# Return success message for test harness
"=== All tests completed successfully ==="