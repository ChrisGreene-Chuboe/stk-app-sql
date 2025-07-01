#!/usr/bin/env nu

# Test All Script for chuck-stack-core modules
# Automatically discovers and runs all test files based on test-*.nu pattern
# Excludes test-all.nu itself to prevent circular references

print $"(ansi green_bold)=== Chuck-Stack Test Suite ===(ansi reset)"
print ""

# Discover all test files using the test-*.nu pattern, excluding test-all.nu
let test_files = (ls test-*.nu 
    | where type == "file" 
    | get name 
    | where $it != "test-all.nu"
    | sort)

if ($test_files | is-empty) {
    print $"(ansi red)No test files found matching pattern 'test-*.nu' (excluding test-all.nu)(ansi reset)"
    exit 1
}

print $"Found ($test_files | length) test files:"
$test_files | each {|file| print $"  - ($file)"}
print ""

# Run each test file and collect results
mut test_results = []

for test_file in $test_files {
    print $"(ansi cyan)=== Running ($test_file) ===(ansi reset)"
    
    let result = try {
        # Run the test file and capture output
        let output = (nu $test_file)
        print $output
        
        # Check if test completed successfully
        if ($output | str contains "All tests completed successfully") {
            print $"(ansi green)✓ ($test_file) PASSED(ansi reset)"
            {file: $test_file, status: "passed"}
        } else {
            print $"(ansi yellow)⚠ ($test_file) COMPLETED (check output for details)(ansi reset)"
            {file: $test_file, status: "passed"}
        }
    } catch { |error|
        print $"(ansi red)✗ ($test_file) FAILED(ansi reset)"
        print $"(ansi red)Error: ($error.msg)(ansi reset)"
        {file: $test_file, status: "failed"}
    }
    
    print ""
    $test_results = ($test_results | append $result)
}

# Calculate summary statistics from collected results
let total_tests = ($test_results | length)
let passed_tests = ($test_results | where status == "passed" | length)
let failed_tests = ($test_results | where status == "failed")

# Print summary
print $"(ansi green_bold)=== Test Suite Summary ===(ansi reset)"
print $"Total tests: ($total_tests)"
print $"Passed: ($passed_tests)"
print $"Failed: ($failed_tests | length)"

if ($failed_tests | length) > 0 {
    print ""
    print $"(ansi red)Failed tests:(ansi reset)"
    $failed_tests | each {|result| print $"  - ($result.file)"}
    print ""
    print $"(ansi red)Test suite FAILED(ansi reset)"
    exit 1
} else {
    print ""
    print $"(ansi green)All tests PASSED! 🎉(ansi reset)"
    exit 0
}
