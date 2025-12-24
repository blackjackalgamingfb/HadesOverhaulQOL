#!/bin/bash
# Test runner for BadgePrestige.lua
# This script runs the test suite using busted

cd "$(dirname "$0")"

echo "Running BadgePrestige.lua tests..."
echo "=================================="

# Check if busted is installed
if ! command -v busted &> /dev/null; then
    echo "Error: busted test framework is not installed"
    echo "Please install it using: sudo luarocks install busted"
    exit 1
fi

# Run the tests
busted badgeprestige_spec.lua --verbose

# Capture the exit code
TEST_EXIT_CODE=$?

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✓ All tests passed!"
else
    echo ""
    echo "✗ Some tests failed!"
fi

exit $TEST_EXIT_CODE
