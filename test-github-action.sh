#!/bin/bash

# test-github-action.sh - Local simulation of GitHub Action
# This script simulates the key steps that the GitHub Action performs

set -e

echo "=== GitHub Action Local Test ==="
echo "Simulating GitHub Action workflow..."

# Step 1: Setup environment
echo "1. Setting up environment..."
BASH_CMD=bash
echo "Using bash: $($BASH_CMD --version | head -1)"

# Step 2: Verify permissions
echo "2. Checking file permissions..."
ls -la qi install.sh test.sh run_tests.sh | head -5

# Step 3: Syntax checks
echo "3. Running syntax checks..."
$BASH_CMD -n qi && echo "  ✓ qi syntax OK"
$BASH_CMD -n install.sh && echo "  ✓ install.sh syntax OK"
$BASH_CMD -n test.sh && echo "  ✓ test.sh syntax OK"
$BASH_CMD -n run_tests.sh && echo "  ✓ run_tests.sh syntax OK"

# Step 4: Basic functionality test
echo "4. Running basic functionality test..."
timeout 60 $BASH_CMD test.sh > /tmp/basic_test.log 2>&1
if [ $? -eq 0 ]; then
    echo "  ✓ Basic test PASSED"
else
    echo "  ✗ Basic test FAILED"
    echo "  Last 10 lines of output:"
    tail -10 /tmp/basic_test.log
    exit 1
fi

# Step 5: Comprehensive test suite
echo "5. Running comprehensive test suite..."
timeout 120 $BASH_CMD run_tests.sh --no-coverage > /tmp/comprehensive_test.log 2>&1
if [ $? -eq 0 ]; then
    echo "  ✓ Comprehensive test PASSED"
else
    echo "  ✗ Comprehensive test FAILED"
    echo "  Last 10 lines of output:"
    tail -10 /tmp/comprehensive_test.log
    exit 1
fi

# Step 6: Installation script test
echo "6. Testing installation script..."
$BASH_CMD -n install.sh && echo "  ✓ Installation script syntax OK"

echo ""
echo "=== All Tests Passed! ==="
echo "The GitHub Action should work correctly."
echo ""
echo "Test outputs saved to:"
echo "  - Basic test: /tmp/basic_test.log"
echo "  - Comprehensive test: /tmp/comprehensive_test.log"