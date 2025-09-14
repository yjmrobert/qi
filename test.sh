#!/bin/bash

# test.sh - Basic test suite for qi
# Tests core functionality to ensure everything works correctly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QI_SCRIPT="$SCRIPT_DIR/qi"
TEST_CACHE_DIR="/tmp/qi-test-cache"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Print colored output
print_color() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

# Test result functions
test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_color "$GREEN" "✓ PASS: $*"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_color "$RED" "✗ FAIL: $*"
}

test_info() {
    print_color "$BLUE" "ℹ INFO: $*"
}

test_warn() {
    print_color "$YELLOW" "⚠ WARN: $*"
}

# Setup test environment
setup_test_env() {
    test_info "Setting up test environment"

    # Use temporary cache directory for testing
    export QI_CACHE_DIR="$TEST_CACHE_DIR"

    # Clean up any existing test cache
    if [[ -d "$TEST_CACHE_DIR" ]]; then
        rm -rf "$TEST_CACHE_DIR"
    fi

    # Verify qi script exists
    if [[ ! -x "$QI_SCRIPT" ]]; then
        test_fail "qi script not found or not executable: $QI_SCRIPT"
        exit 1
    fi

    test_pass "Test environment setup"
}

# Clean up test environment
cleanup_test_env() {
    test_info "Cleaning up test environment"

    if [[ -d "$TEST_CACHE_DIR" ]]; then
        rm -rf "$TEST_CACHE_DIR"
        test_pass "Test cache cleaned up"
    fi
}

# Test basic commands
test_basic_commands() {
    test_info "Testing basic commands"

    # Test help command
    if "$QI_SCRIPT" --help >/dev/null 2>&1; then
        test_pass "Help command works"
    else
        test_fail "Help command failed"
    fi

    # Test version command
    if "$QI_SCRIPT" --version >/dev/null 2>&1; then
        test_pass "Version command works"
    else
        test_fail "Version command failed"
    fi

    # Test config command
    if "$QI_SCRIPT" config >/dev/null 2>&1; then
        test_pass "Config command works"
    else
        test_fail "Config command failed"
    fi
}

# Test repository management
test_repository_management() {
    test_info "Testing repository management"

    # Test adding repository
    if "$QI_SCRIPT" add https://github.com/octocat/Hello-World.git test-repo >/dev/null 2>&1; then
        test_pass "Repository add works"
    else
        test_fail "Repository add failed"
    fi

    # Test listing repositories
    if "$QI_SCRIPT" list-repos | grep -q "test-repo"; then
        test_pass "Repository listing works"
    else
        test_fail "Repository listing failed"
    fi

    # Test repository status
    if "$QI_SCRIPT" status >/dev/null 2>&1; then
        test_pass "Status command works"
    else
        test_fail "Status command failed"
    fi

    # Test removing repository
    if echo "y" | "$QI_SCRIPT" remove test-repo >/dev/null 2>&1; then
        test_pass "Repository remove works"
    else
        test_fail "Repository remove failed"
    fi
}

# Test script discovery and execution
test_script_functionality() {
    test_info "Testing script functionality"

    # Add repository with scripts
    "$QI_SCRIPT" add https://github.com/octocat/Hello-World.git test-scripts >/dev/null 2>&1

    # Create test script in qi directory
    local test_script_dir="$TEST_CACHE_DIR/test-scripts/qi"
    mkdir -p "$test_script_dir"
    cat >"$test_script_dir/test.bash" <<'EOF'
#!/bin/bash
echo "Test script executed successfully"
echo "Arguments: $*"
EOF
    chmod +x "$test_script_dir/test.bash"

    # Test script listing
    if "$QI_SCRIPT" list | grep -q "test"; then
        test_pass "Script discovery works"
    else
        test_fail "Script discovery failed"
    fi

    # Test script execution
    local output
    output=$("$QI_SCRIPT" test arg1 arg2 2>/dev/null)
    if [[ "$output" =~ "Test script executed successfully" ]] && [[ "$output" =~ "arg1 arg2" ]]; then
        test_pass "Script execution works"
    else
        test_fail "Script execution failed"
    fi

    # Test dry-run mode
    if "$QI_SCRIPT" --dry-run test >/dev/null 2>&1; then
        test_pass "Dry-run mode works"
    else
        test_fail "Dry-run mode failed"
    fi

    # Clean up
    echo "y" | "$QI_SCRIPT" remove test-scripts >/dev/null 2>&1
}

# Test error handling
test_error_handling() {
    test_info "Testing error handling"

    # Test invalid repository URL
    if ! "$QI_SCRIPT" add invalid-url 2>/dev/null; then
        test_pass "Invalid URL rejection works"
    else
        test_fail "Invalid URL rejection failed"
    fi

    # Test non-existent repository removal
    if ! "$QI_SCRIPT" remove non-existent-repo 2>/dev/null; then
        test_pass "Non-existent repository rejection works"
    else
        test_fail "Non-existent repository rejection failed"
    fi

    # Test non-existent script execution
    if ! "$QI_SCRIPT" non-existent-script 2>/dev/null; then
        test_pass "Non-existent script rejection works"
    else
        test_fail "Non-existent script rejection failed"
    fi
}

# Test install script functionality
test_install_script() {
    test_info "Testing install script functionality"

    local install_script="$SCRIPT_DIR/install.sh"

    # Check if install script exists
    if [[ ! -f "$install_script" ]]; then
        test_fail "install.sh script not found"
        return
    fi

    # Check if install script is executable
    if [[ ! -x "$install_script" ]]; then
        test_fail "install.sh script is not executable"
        return
    fi

    test_pass "install.sh script exists and is executable"

    # Test install script syntax
    if bash -n "$install_script" 2>/dev/null; then
        test_pass "install.sh script has valid bash syntax"
    else
        test_fail "install.sh script has syntax errors"
        return
    fi

    # Test install script functions (source and test individual functions)
    local temp_test_script="/tmp/test-install-functions.sh"

    cat >"$temp_test_script" <<'EOF'
#!/bin/bash
set -euo pipefail

# Source the install script to test functions
source "$1"

# Test check_requirements function
test_check_requirements() {
    # This should pass on most Linux systems
    if check_requirements >/dev/null 2>&1; then
        echo "check_requirements: PASS"
        return 0
    else
        echo "check_requirements: FAIL"
        return 1
    fi
}

# Test create_temp_dir function  
test_create_temp_dir() {
    local old_temp_dir="$TEMP_DIR"
    TEMP_DIR="/tmp/test-qi-install-$$"
    
    if create_temp_dir >/dev/null 2>&1 && [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR" 2>/dev/null || true
        TEMP_DIR="$old_temp_dir"
        echo "create_temp_dir: PASS"
        return 0
    else
        TEMP_DIR="$old_temp_dir"
        echo "create_temp_dir: FAIL"
        return 1
    fi
}

# Test utility functions
test_print_functions() {
    # Test that print functions don't crash
    if info "test" >/dev/null 2>&1 && success "test" >/dev/null 2>&1 && warn "test" >/dev/null 2>&1; then
        echo "print_functions: PASS"
        return 0
    else
        echo "print_functions: FAIL"
        return 1
    fi
}

# Run function tests
main() {
    local tests_passed=0
    local tests_total=0
    
    for test_func in test_check_requirements test_create_temp_dir test_print_functions; do
        tests_total=$((tests_total + 1))
        if $test_func; then
            tests_passed=$((tests_passed + 1))
        fi
    done
    
    echo "Function tests: $tests_passed/$tests_total passed"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
EOF

    chmod +x "$temp_test_script"

    # Run function tests
    if "$temp_test_script" "$install_script" 2>/dev/null; then
        test_pass "install.sh script functions work correctly"
    else
        test_fail "install.sh script functions failed"
    fi

    # Clean up
    rm -f "$temp_test_script"

    # Test install script help/usage information
    if grep -q "Usage:" "$install_script" && grep -q "curl.*bash" "$install_script"; then
        test_pass "install.sh script contains usage information"
    else
        test_fail "install.sh script missing usage information"
    fi

    # Test install script has proper error handling
    if grep -q "set -euo pipefail" "$install_script" && grep -q "trap.*handle_error" "$install_script"; then
        test_pass "install.sh script has proper error handling"
    else
        test_fail "install.sh script missing proper error handling"
    fi

    # Test install script has all required functions
    local required_functions=("check_permissions" "check_requirements" "download_qi" "install_qi" "verify_installation")
    local missing_functions=()

    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$install_script"; then
            missing_functions+=("$func")
        fi
    done

    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        test_pass "install.sh script has all required functions"
    else
        test_fail "install.sh script missing functions: ${missing_functions[*]}"
    fi
}

# Main test runner
main() {
    print_color "$BLUE" "qi Test Suite"
    print_color "$BLUE" "============="
    echo ""

    # Setup
    setup_test_env

    # Run tests
    test_basic_commands
    test_repository_management
    test_script_functionality
    test_error_handling
    test_install_script

    # Cleanup
    cleanup_test_env

    # Results
    echo ""
    print_color "$BLUE" "Test Results"
    print_color "$BLUE" "============"
    echo "Total tests: $TESTS_TOTAL"
    print_color "$GREEN" "Passed: $TESTS_PASSED"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        print_color "$RED" "Failed: $TESTS_FAILED"
        echo ""
        print_color "$RED" "Some tests failed. Please check the implementation."
        exit 1
    else
        echo ""
        print_color "$GREEN" "All tests passed! 🎉"
        echo ""
        echo "qi is ready to use!"
        exit 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
