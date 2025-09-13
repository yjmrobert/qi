#!/bin/bash

# test-utils.sh - Test utilities for qi test suite
# Provides common testing functions and test harness

# Test framework variables
declare -g TEST_COUNT=0
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g TEST_SUITE_NAME=""
declare -g TEST_VERBOSE=false

# Color codes for test output
readonly T_RED='\033[0;31m'
readonly T_GREEN='\033[0;32m'
readonly T_YELLOW='\033[1;33m'
readonly T_BLUE='\033[0;34m'
readonly T_NC='\033[0m' # No Color

# Test output functions
test_log() {
    if [[ "$TEST_VERBOSE" == "true" ]]; then
        echo "[TEST] $*" >&2
    fi
}

test_info() {
    echo -e "${T_BLUE}[INFO]${T_NC} $*" >&2
}

test_warn() {
    echo -e "${T_YELLOW}[WARN]${T_NC} $*" >&2
}

test_error() {
    echo -e "${T_RED}[ERROR]${T_NC} $*" >&2
}

test_success() {
    echo -e "${T_GREEN}[SUCCESS]${T_NC} $*" >&2
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    ((TEST_COUNT++))
    
    if [[ "$expected" == "$actual" ]]; then
        ((TEST_PASSED++))
        test_log "✓ PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_error "✗ FAIL: $message"
        test_error "  Expected: '$expected'"
        test_error "  Actual:   '$actual'"
        return 1
    fi
}

assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    ((TEST_COUNT++))
    
    if [[ "$expected" != "$actual" ]]; then
        ((TEST_PASSED++))
        test_log "✓ PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_error "✗ FAIL: $message"
        test_error "  Expected NOT: '$expected'"
        test_error "  Actual:       '$actual'"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-}"
    
    ((TEST_COUNT++))
    
    if [[ "$condition" == "true" ]] || [[ "$condition" == "0" ]]; then
        ((TEST_PASSED++))
        test_log "✓ PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_error "✗ FAIL: $message"
        test_error "  Expected: true"
        test_error "  Actual:   $condition"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-}"
    
    ((TEST_COUNT++))
    
    if [[ "$condition" == "false" ]] || [[ "$condition" == "1" ]]; then
        ((TEST_PASSED++))
        test_log "✓ PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_error "✗ FAIL: $message"
        test_error "  Expected: false"
        test_error "  Actual:   $condition"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    
    ((TEST_COUNT++))
    
    if [[ -f "$file" ]]; then
        ((TEST_PASSED++))
        test_log "✓ PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_error "✗ FAIL: $message"
        test_error "  File not found: $file"
        return 1
    fi
}

assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"
    
    ((TEST_COUNT++))
    
    if [[ ! -f "$file" ]]; then
        ((TEST_PASSED++))
        test_log "✓ PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_error "✗ FAIL: $message"
        test_error "  File exists: $file"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist: $dir}"
    
    ((TEST_COUNT++))
    
    if [[ -d "$dir" ]]; then
        ((TEST_PASSED++))
        test_log "✓ PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_error "✗ FAIL: $message"
        test_error "  Directory not found: $dir"
        return 1
    fi
}

assert_dir_not_exists() {
    local dir="$1"
    local message="${2:-Directory should not exist: $dir}"
    
    ((TEST_COUNT++))
    
    if [[ ! -d "$dir" ]]; then
        ((TEST_PASSED++))
        test_log "✓ PASS: $message"
        return 0
    else
        ((TEST_FAILED++))
        test_error "✗ FAIL: $message"
        test_error "  Directory exists: $dir"
        return 1
    fi
}

assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed: $command}"
    
    ((TEST_COUNT++))
    
    if eval "$command" >/dev/null 2>&1; then
        ((TEST_PASSED++))
        test_log "✓ PASS: $message"
        return 0
    else
        local exit_code=$?
        ((TEST_FAILED++))
        test_error "✗ FAIL: $message"
        test_error "  Command failed with exit code: $exit_code"
        return 1
    fi
}

assert_command_fails() {
    local command="$1"
    local message="${2:-Command should fail: $command}"
    
    ((TEST_COUNT++))
    
    if eval "$command" >/dev/null 2>&1; then
        ((TEST_FAILED++))
        test_error "✗ FAIL: $message"
        test_error "  Command succeeded unexpectedly"
        return 1
    else
        ((TEST_PASSED++))
        test_log "✓ PASS: $message"
        return 0
    fi
}

# Test setup and teardown
setup_test_environment() {
    local test_name="$1"
    
    TEST_SUITE_NAME="$test_name"
    
    # Create temporary test directory
    export TEST_DIR="/tmp/qi-test-$$"
    export TEST_CACHE_DIR="$TEST_DIR/cache"
    export TEST_CONFIG_DIR="$TEST_DIR/config"
    
    mkdir -p "$TEST_DIR" "$TEST_CACHE_DIR" "$TEST_CONFIG_DIR"
    
    # Set test environment variables
    export QI_CACHE_DIR="$TEST_CACHE_DIR"
    export QI_CONFIG_DIR="$TEST_CONFIG_DIR"
    export QI_CONFIG_FILE="$TEST_CONFIG_DIR/config"
    export QI_VERBOSE="false"
    export QI_DRY_RUN="false"
    export QI_FORCE="false"
    
    test_info "Test environment setup: $TEST_DIR"
}

teardown_test_environment() {
    if [[ -n "${TEST_DIR:-}" ]] && [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
        test_log "Test environment cleaned up: $TEST_DIR"
    fi
    
    # Unset test environment variables
    unset TEST_DIR TEST_CACHE_DIR TEST_CONFIG_DIR
    unset QI_CACHE_DIR QI_CONFIG_DIR QI_CONFIG_FILE
}

# Test runner functions
run_test_suite() {
    local test_file="$1"
    local suite_name
    
    suite_name=$(basename "$test_file" .sh)
    
    test_info "Running test suite: $suite_name"
    
    # Reset counters
    TEST_COUNT=0
    TEST_PASSED=0
    TEST_FAILED=0
    
    # Source and run the test file
    if source "$test_file"; then
        show_test_results "$suite_name"
        return $TEST_FAILED
    else
        test_error "Failed to source test file: $test_file"
        return 1
    fi
}

show_test_results() {
    local suite_name="$1"
    
    echo
    echo "Test Results for $suite_name:"
    echo "=========================="
    echo "Total tests:  $TEST_COUNT"
    echo -e "Passed:       ${T_GREEN}$TEST_PASSED${T_NC}"
    
    if [[ $TEST_FAILED -gt 0 ]]; then
        echo -e "Failed:       ${T_RED}$TEST_FAILED${T_NC}"
        echo -e "Success rate: ${T_YELLOW}$(( (TEST_PASSED * 100) / TEST_COUNT ))%${T_NC}"
    else
        echo -e "Failed:       ${T_GREEN}0${T_NC}"
        echo -e "Success rate: ${T_GREEN}100%${T_NC}"
    fi
    
    echo
}

# Mock functions for testing
create_mock_repo() {
    local repo_name="$1"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    mkdir -p "$repo_dir"
    
    # Initialize as git repository
    pushd "$repo_dir" >/dev/null
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
    
    # Create some test scripts
    mkdir -p scripts tools
    
    cat > scripts/deploy.bash << 'EOF'
#!/bin/bash
echo "Deploying application..."
EOF
    
    cat > tools/backup.bash << 'EOF'
#!/bin/bash
echo "Creating backup..."
EOF
    
    cat > test-script.bash << 'EOF'
#!/bin/bash
echo "Running test script with args: $@"
EOF
    
    chmod +x scripts/deploy.bash tools/backup.bash test-script.bash
    
    git add .
    git commit --quiet -m "Initial commit"
    
    popd >/dev/null
    
    # Create metadata file
    cat > "$repo_dir/.qi-repo-metadata" << EOF
name=$repo_name
url=https://github.com/test/$repo_name.git
added=$(date -Iseconds)
last_updated=$(date -Iseconds)
script_count=3
branch=main
EOF
    
    test_log "Created mock repository: $repo_name"
}

create_test_config() {
    local config_file="$TEST_CONFIG_DIR/config"
    
    cat > "$config_file" << EOF
cache_dir=$TEST_CACHE_DIR
default_branch=main
auto_update=false
verbose=false
EOF
    
    test_log "Created test configuration: $config_file"
}

# Export test functions
export -f test_log test_info test_warn test_error test_success
export -f assert_equals assert_not_equals assert_true assert_false
export -f assert_file_exists assert_file_not_exists
export -f assert_dir_exists assert_dir_not_exists
export -f assert_command_success assert_command_fails
export -f setup_test_environment teardown_test_environment
export -f run_test_suite show_test_results
export -f create_mock_repo create_test_config