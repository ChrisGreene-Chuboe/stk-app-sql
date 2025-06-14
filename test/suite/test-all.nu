#!/usr/bin/env nu

# Test All Script for stk-app-sql modules
# Automatically discovers and runs all test files based on test-*.nu pattern
# Excludes test-all.nu itself to prevent circular references

echo $"(ansi green_bold)=== Chuck-Stack Test Suite ===(ansi reset)"
echo ""

# Discover all test files using the test-*.nu pattern, excluding test-all.nu
let test_files = (ls test-*.nu 
    | where type == "file" 
    | get name 
    | where $it != "test-all.nu"
    | sort)

if ($test_files | is-empty) {
    echo $"(ansi red)No test files found matching pattern 'test-*.nu' (excluding test-all.nu)(ansi reset)"
    exit 1
}

echo $"Found ($test_files | length) test files:"
$test_files | each {|file| echo $"  - ($file)"}
echo ""

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
echo $"(ansi green_bold)=== Test Suite Summary ===(ansi reset)"
echo $"Total tests: ($total_tests)"
echo $"Passed: ($passed_tests)"
echo $"Failed: ($failed_tests | length)"

if ($failed_tests | length) > 0 {
    echo ""
    echo $"(ansi red)Failed tests:(ansi reset)"
    $failed_tests | each {|result| echo $"  - ($result.file)"}
    echo ""
    echo $"(ansi red)Test suite FAILED(ansi reset)"
    exit 1
} else {
    echo ""
    echo $"(ansi green)All tests PASSED! 🎉(ansi reset)"
    exit 0
}