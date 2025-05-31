#!/usr/bin/env nu

# Simple test script
echo "=== Testing basic functionality ==="

# Import the modules  
use ../modules *

echo "=== Creating a simple standalone request ==="
"Test standalone request" | .append request "test-standalone"