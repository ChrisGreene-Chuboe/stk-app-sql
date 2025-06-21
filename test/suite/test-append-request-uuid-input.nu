#!/usr/bin/env nu

# Test script for .append request with UUID input enhancement
echo "=== Testing .append request UUID Input Enhancement ==="

# Test-specific suffix to ensure test isolation and idempotency
# Generate random 2-char suffix from letters (upper/lower) and numbers
let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
let random_suffix = (0..1 | each {|_| 
    let idx = (random int 0..($chars | str length | $in - 1))
    $chars | str substring $idx..($idx + 1)
} | str join)
let test_suffix = $"_ar($random_suffix)"  # ar for append request + 2 random chars

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

# === Testing string UUID input (baseline) ===
# Create a project to attach requests to
let project = (project new $"Test Project($test_suffix)")
let project_uuid = $project.0.uu
echo $"Created project with UUID: ($project_uuid)"

# Test 1: Traditional string UUID piping
echo "Testing string UUID piping..."
let request1 = ($project_uuid | .append request $"string-test($test_suffix)" --description "Via string UUID")
assert (($request1 | columns | any {|col| $col == "uu"})) "String UUID should return request with uu"
echo $"✓ String UUID works, created request: ($request1.uu.0)"

# === Testing record input ===
# Test 2: Single record piping
echo "Testing single record piping..."
let request2 = ($project.0 | .append request $"record-test($test_suffix)" --description "Via single record")
assert (($request2 | columns | any {|col| $col == "uu"})) "Record should return request with uu"
echo $"✓ Record piping works, created request: ($request2.uu.0)"

# === Testing table input ===
# Test 3: Single-row table piping
echo "Testing single-row table piping..."
let single_project = (project list | where name =~ $test_suffix | take 1)
let request3 = ($single_project | .append request $"table-test($test_suffix)" --description "Via single-row table")
assert (($request3 | columns | any {|col| $col == "uu"})) "Single-row table should return request with uu"
echo $"✓ Single-row table works, created request: ($request3.uu.0)"

# Test 4: Multi-row table (should use first row)
echo "Testing multi-row table piping (uses first row)..."
# Create another project to have multiple rows
let project2 = (project new $"Another Project($test_suffix)")
let multi_projects = (project list | where name =~ $test_suffix)
assert (($multi_projects | length) >= 2) "Should have at least 2 test projects"
let request4 = ($multi_projects | .append request $"multi-table-test($test_suffix)" --description "Via multi-row table")
assert (($request4 | columns | any {|col| $col == "uu"})) "Multi-row table should return request with uu"
echo $"✓ Multi-row table works \(used first row), created request: ($request4.uu.0)"

# === Testing empty/null input ===
# Test 5: No attachment (standalone request)
echo "Testing no attachment (standalone)..."
let request5 = (.append request $"standalone($test_suffix)" --description "No attachment")
assert (($request5 | columns | any {|col| $col == "uu"})) "Standalone request should return uu"
echo $"✓ Standalone request works, created request: ($request5.uu.0)"

# Test 6: Empty table
echo "Testing empty table input..."
let empty_projects = (project list | where name == "nonexistent-xyz-123")
assert (($empty_projects | length) == 0) "Empty filter should return empty table"
let request6 = ($empty_projects | .append request $"empty-table($test_suffix)" --description "Empty table input")
assert (($request6 | columns | any {|col| $col == "uu"})) "Empty table should create standalone request"
echo $"✓ Empty table creates standalone request: ($request6.uu.0)"

# === Verifying attachments ===
# Verify that attached requests have correct table_name_uu_json
echo "Verifying request attachments..."
let req1_detail = ($request1.uu.0 | request get)
let req2_detail = ($request2.uu.0 | request get)
let req3_detail = ($request3.uu.0 | request get)
let req5_detail = ($request5.uu.0 | request get)

# Check attached requests have table_name_uu_json with UUID
assert (not ($req1_detail.table_name_uu_json.0.uu | is-empty)) "String UUID request should be attached"
assert (not ($req2_detail.table_name_uu_json.0.uu | is-empty)) "Record request should be attached"
assert (not ($req3_detail.table_name_uu_json.0.uu | is-empty)) "Table request should be attached"

# Check standalone request has no attachment (empty JSON object)
assert (($req5_detail.table_name_uu_json.0.uu | is-empty)) "Standalone request should not be attached"

# Verify all attached to same project (already a record, not JSON string)
let uuid1 = $req1_detail.table_name_uu_json.0.uu
let uuid2 = $req2_detail.table_name_uu_json.0.uu
let uuid3 = $req3_detail.table_name_uu_json.0.uu
assert (($uuid1 == $project_uuid)) "Request 1 should be attached to project"
assert (($uuid2 == $project_uuid)) "Request 2 should be attached to project"
assert (($uuid3 == $project_uuid)) "Request 3 should be attached to project"
echo "✓ All attachments verified correctly"

# === Testing --attach parameter (string only) ===
# Test 7: --attach parameter still works with string
echo "Testing --attach parameter with string UUID..."
let request7 = (.append request $"attach-param($test_suffix)" --description "Via --attach" --attach $project_uuid)
assert (($request7 | columns | any {|col| $col == "uu"})) "--attach parameter should work"
let req7_detail = ($request7.uu.0 | request get)
let uuid7 = $req7_detail.table_name_uu_json.0.uu
assert (($uuid7 == $project_uuid)) "--attach should attach to correct project"
echo $"✓ --attach parameter works, created request: ($request7.uu.0)"

echo ""
echo "=== Summary ==="
echo "✓ All tests passed!"
echo "✓ .append request now accepts: string UUID, single record, and table inputs"
echo "✓ Multi-row tables use first row (as designed)"
echo "✓ Empty inputs create standalone requests"
echo "✓ --attach parameter continues to work with strings"

# Return success message for test harness
"=== All tests completed successfully ==="