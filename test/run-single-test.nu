#\!/usr/bin/env nu

# Run a single test in isolation
def main [test_file: string] {
    print $"Running ($test_file) in isolation..."
    
    # Set up environment
    let test_dir = $env.STK_TEST_DIR
    cd $test_dir
    
    # Run the test
    try {
        nu -l -c $"cd suite && ./($test_file)"
        print "Test passed\!"
    } catch {|e|
        print $"Test failed with error: ($e.msg)"
        exit 1
    }
}
EOF < /dev/null
