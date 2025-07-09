# === Testing header-line pattern ===
# Template: Replace HEADER with header module (e.g., project)
#          Replace LINE with line suffix (e.g., line)
# Template Version: 2025-01-08
# Example: project/project_line => HEADER=project, LINE=line

# print "=== Testing HEADER LINE creation ==="
let header = (HEADER new $"Test Header($test_suffix)")

# Create lines with different input methods
# print "=== Testing HEADER LINE with string UUID ==="
let line1 = ($header.uu | HEADER LINE new $"Line 1($test_suffix)")
assert (($line1 | describe | str starts-with "record")) "Should return a record"

# print "=== Testing HEADER LINE with table input ==="
# Need to convert record to table for this test
let line2 = ([$header] | HEADER LINE new $"Line 2($test_suffix)")
assert (($line2 | describe | str starts-with "record")) "Should return a record"

# print "=== Testing HEADER LINE with record input ==="
let line3 = ($header | HEADER LINE new $"Line 3($test_suffix)")
assert (($line3 | describe | str starts-with "record")) "Should return a record"

# print "=== Testing HEADER LINE list ==="
let lines = ($header.uu | HEADER LINE list)
assert (($lines | where name =~ $test_suffix | length) >= 3) "Should list all lines"

# print "=== Testing HEADER LINE get ==="
let get_line = ($line1.uu | HEADER LINE get)
assert ($get_line.name | str contains "Line 1") "Should get specific line"

# print "=== Testing HEADER LINE revoke ==="
let revoked = ($line1.uu | HEADER LINE revoke)
assert ($revoked.is_revoked.0 == true) "Should revoke line"

# print "=== Testing HEADER LINE list --all ==="
let all_lines = ($header.uu | HEADER LINE list --all)
assert ($all_lines | where is_revoked == true | where name =~ $test_suffix | is-not-empty) "Should show revoked lines"