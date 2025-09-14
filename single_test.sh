#!/bin/bash

# Set up test environment exactly like the test file
TEST_DIR="$(pwd)"
PROJECT_ROOT="$TEST_DIR"
LIB_DIR="$PROJECT_ROOT/lib"

echo "Paths: TEST_DIR=$TEST_DIR, PROJECT_ROOT=$PROJECT_ROOT, LIB_DIR=$LIB_DIR"
echo "Checking files:"
ls -la "$LIB_DIR/utils.sh" "$LIB_DIR/config.sh"

# Source required libraries
. "$LIB_DIR/utils.sh"
. "$LIB_DIR/config.sh"

echo "=== After sourcing libraries ==="
echo "Functions available:"
declare -F | grep -E "(load_config|log)"

# Set up like setUp function
TEST_TEMP_DIR=$(mktemp -d -t qi_config_test.XXXXXX)
TEST_CONFIG_FILE="$TEST_TEMP_DIR/test_config"

echo "=== Initial config state ==="
for key in "${!QI_CONFIG[@]}"; do
    echo "$key = ${QI_CONFIG[$key]}"
done | sort

# Replicate the exact test
cat > "$TEST_CONFIG_FILE" << 'TESTEOF'
cache_dir=/tmp/test_cache
default_branch=develop
auto_update=true
verbose=false
max_cache_size=2G
TESTEOF

echo "=== Loading config file ==="
load_config "$TEST_CONFIG_FILE"

echo "=== After loading ==="
for key in "${!QI_CONFIG[@]}"; do
    echo "$key = ${QI_CONFIG[$key]}"
done | sort

echo "=== Testing individual values ==="
echo "cache_dir: '${QI_CONFIG[cache_dir]}'"
echo "default_branch: '${QI_CONFIG[default_branch]}'"

# Cleanup
rm -rf "$TEST_TEMP_DIR"
