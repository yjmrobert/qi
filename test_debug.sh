#!/bin/bash
source lib/utils.sh
source lib/config.sh

# Mock the shunit2 functions
assertEquals() {
    local msg="$1"
    local expected="$2" 
    local actual="$3"
    echo "TEST: $msg"
    echo "  Expected: '$expected'"
    echo "  Actual: '$actual'"
    if [[ "$expected" == "$actual" ]]; then
        echo "  PASS"
    else
        echo "  FAIL"
    fi
    echo
}

# Simulate the test
TEST_CONFIG_FILE=$(mktemp)
cat > "$TEST_CONFIG_FILE" << 'CONFIG_EOF'
cache_dir=/tmp/test_cache
default_branch=develop
auto_update=true
verbose=false
max_cache_size=2G
CONFIG_EOF

echo "=== Loading config ==="
load_config "$TEST_CONFIG_FILE"

echo "=== After loading ==="
for key in "${!QI_CONFIG[@]}"; do
    echo "$key = ${QI_CONFIG[$key]}"
done | sort

echo "=== Running tests ==="
assertEquals "Should load cache_dir" "/tmp/test_cache" "${QI_CONFIG[cache_dir]}"
assertEquals "Should load default_branch" "develop" "${QI_CONFIG[default_branch]}"

rm "$TEST_CONFIG_FILE"
