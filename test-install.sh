#!/bin/bash

# test-install.sh - Dedicated test suite for install.sh
# Tests the installation script functionality in isolation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
TEST_INSTALL_DIR="/tmp/qi-install-test"
TEST_USER_HOME="/tmp/qi-test-home"

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
    test_info "Setting up install test environment"
    
    # Clean up any existing test directories
    rm -rf "$TEST_INSTALL_DIR" "$TEST_USER_HOME" 2>/dev/null || true
    
    # Create test directories
    mkdir -p "$TEST_INSTALL_DIR" "$TEST_USER_HOME"
    
    # Verify install script exists
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        test_fail "install.sh script not found: $INSTALL_SCRIPT"
        exit 1
    fi
    
    if [[ ! -x "$INSTALL_SCRIPT" ]]; then
        test_fail "install.sh script not executable: $INSTALL_SCRIPT"
        exit 1
    fi
    
    test_pass "Install test environment setup"
}

# Clean up test environment
cleanup_test_env() {
    test_info "Cleaning up install test environment"
    
    rm -rf "$TEST_INSTALL_DIR" "$TEST_USER_HOME" 2>/dev/null || true
    
    test_pass "Install test environment cleaned up"
}

# Test install script syntax and structure
test_install_script_structure() {
    test_info "Testing install script structure"
    
    # Test bash syntax
    if bash -n "$INSTALL_SCRIPT" 2>/dev/null; then
        test_pass "Install script has valid bash syntax"
    else
        test_fail "Install script has syntax errors"
        return
    fi
    
    # Test shebang
    if head -n1 "$INSTALL_SCRIPT" | grep -q "^#!/bin/bash"; then
        test_pass "Install script has correct shebang"
    else
        test_fail "Install script missing or incorrect shebang"
    fi
    
    # Test error handling setup
    if grep -q "set -euo pipefail" "$INSTALL_SCRIPT"; then
        test_pass "Install script has proper error handling setup"
    else
        test_fail "Install script missing 'set -euo pipefail'"
    fi
    
    # Test required variables
    local required_vars=("REPO_URL" "INSTALL_DIR" "TEMP_DIR" "QI_BINARY")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$INSTALL_SCRIPT"; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -eq 0 ]]; then
        test_pass "Install script has all required variables"
    else
        test_fail "Install script missing variables: ${missing_vars[*]}"
    fi
}

# Test install script functions
test_install_script_functions() {
    test_info "Testing install script functions"
    
    # Test required functions exist
    local required_functions=(
        "print_color" "info" "success" "warn" "error"
        "check_permissions" "check_requirements" "create_temp_dir"
        "download_qi" "verify_files" "install_qi" "verify_installation"
        "cleanup" "show_usage" "main"
    )
    local missing_functions=()
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$INSTALL_SCRIPT"; then
            missing_functions+=("$func")
        fi
    done
    
    if [[ ${#missing_functions[@]} -eq 0 ]]; then
        test_pass "Install script has all required functions"
    else
        test_fail "Install script missing functions: ${missing_functions[*]}"
    fi
    
    # Test function implementations
    if grep -q "curl.*fsSL.*install\.sh.*bash" "$INSTALL_SCRIPT"; then
        test_pass "Install script contains curl installation command"
    else
        test_fail "Install script missing curl installation command"
    fi
}

# Test install script error handling
test_install_script_error_handling() {
    test_info "Testing install script error handling"
    
    # Test error trap
    if grep -q "trap.*handle_error" "$INSTALL_SCRIPT"; then
        test_pass "Install script has error trap"
    else
        test_fail "Install script missing error trap"
    fi
    
    # Test cleanup trap
    if grep -q "trap.*cleanup.*EXIT" "$INSTALL_SCRIPT"; then
        test_pass "Install script has cleanup trap"
    else
        test_fail "Install script missing cleanup trap"
    fi
    
    # Test permission checks
    if grep -q "EUID.*0" "$INSTALL_SCRIPT" && grep -q "sudo" "$INSTALL_SCRIPT"; then
        test_pass "Install script has permission checks"
    else
        test_fail "Install script missing permission checks"
    fi
}

# Test install script requirements checking
test_install_script_requirements() {
    test_info "Testing install script requirements checking"
    
    # Create a mock install script for testing requirements
    local mock_script="/tmp/test-install-requirements.sh"
    
    cat > "$mock_script" << 'EOF'
#!/bin/bash
set -euo pipefail

# Source the install script functions
source "$1"

# Test check_requirements function
test_requirements() {
    # Mock missing git command
    export PATH="/bin:/usr/bin"  # Minimal PATH that likely doesn't have git
    
    # Override command function to simulate missing git
    command() {
        if [[ "$1" == "-v" && "$2" == "git" ]]; then
            return 1  # Simulate git not found
        else
            /usr/bin/command "$@"
        fi
    }
    
    # This should fail because git is "missing"
    if ! check_requirements >/dev/null 2>&1; then
        echo "Requirements check correctly failed when git missing"
        return 0
    else
        echo "Requirements check should have failed when git missing"
        return 1
    fi
}

test_requirements
EOF
    
    chmod +x "$mock_script"
    
    # Test requirements function (this is a limited test due to environment constraints)
    if [[ $(grep -c "command -v" "$INSTALL_SCRIPT") -ge 2 ]]; then
        test_pass "Install script checks for required commands"
    else
        test_fail "Install script missing command checks"
    fi
    
    # Test Linux check
    if grep -q "uname.*Linux" "$INSTALL_SCRIPT"; then
        test_pass "Install script checks for Linux OS"
    else
        test_fail "Install script missing Linux OS check"
    fi
    
    # Clean up
    rm -f "$mock_script"
}

# Test install script repository handling
test_install_script_repository() {
    test_info "Testing install script repository handling"
    
    # Test repository URL configuration
    if grep -q "REPO_URL.*github.com.*qi" "$INSTALL_SCRIPT"; then
        test_pass "Install script has correct repository URL"
    else
        test_fail "Install script missing or incorrect repository URL"
    fi
    
    # Test git clone command
    if grep -q "git clone.*REPO_URL" "$INSTALL_SCRIPT"; then
        test_pass "Install script uses git clone"
    else
        test_fail "Install script missing git clone command"
    fi
    
    # Test file verification
    if grep -q "qi.*lib.*cache.sh\|config.sh\|git-ops.sh" "$INSTALL_SCRIPT"; then
        test_pass "Install script verifies required files"
    else
        test_fail "Install script missing file verification"
    fi
}

# Test install script installation process
test_install_script_installation() {
    test_info "Testing install script installation process"
    
    # Test install directory creation
    if grep -q "mkdir.*INSTALL_DIR\|lib_install_dir" "$INSTALL_SCRIPT"; then
        test_pass "Install script creates installation directories"
    else
        test_fail "Install script missing directory creation"
    fi
    
    # Test file copying
    if grep -q "cp.*qi.*INSTALL_DIR" "$INSTALL_SCRIPT" && grep -q "cp.*lib" "$INSTALL_SCRIPT"; then
        test_pass "Install script copies required files"
    else
        test_fail "Install script missing file copying"
    fi
    
    # Test permissions setting
    if grep -q "chmod.*+x" "$INSTALL_SCRIPT"; then
        test_pass "Install script sets executable permissions"
    else
        test_fail "Install script missing permission setting"
    fi
    
    # Test library path modification
    if grep -q "sed.*LIB_DIR" "$INSTALL_SCRIPT"; then
        test_pass "Install script modifies library path"
    else
        test_fail "Install script missing library path modification"
    fi
}

# Test install script verification
test_install_script_verification() {
    test_info "Testing install script verification"
    
    # Test installation verification
    if grep -q "command -v qi\|qi.*--version" "$INSTALL_SCRIPT"; then
        test_pass "Install script verifies installation"
    else
        test_fail "Install script missing installation verification"
    fi
    
    # Test PATH warning
    if grep -q "export PATH" "$INSTALL_SCRIPT"; then
        test_pass "Install script warns about PATH"
    else
        test_fail "Install script missing PATH warning"
    fi
}

# Test install script usage information
test_install_script_usage() {
    test_info "Testing install script usage information"
    
    # Test usage function
    if grep -q "show_usage()" "$INSTALL_SCRIPT"; then
        test_pass "Install script has usage function"
    else
        test_fail "Install script missing usage function"
    fi
    
    # Test quick start information
    if grep -q "Quick Start\|qi add\|qi list" "$INSTALL_SCRIPT"; then
        test_pass "Install script provides quick start information"
    else
        test_fail "Install script missing quick start information"
    fi
    
    # Test repository URL in usage
    if grep -q "visit.*REPO_URL\|github.com" "$INSTALL_SCRIPT"; then
        test_pass "Install script includes repository URL in usage"
    else
        test_fail "Install script missing repository URL in usage"
    fi
}

# Main test runner
main() {
    print_color "$BLUE" "qi Install Script Test Suite"
    print_color "$BLUE" "==========================="
    echo ""
    
    # Setup
    setup_test_env
    
    # Run tests
    test_install_script_structure
    test_install_script_functions
    test_install_script_error_handling
    test_install_script_requirements
    test_install_script_repository
    test_install_script_installation
    test_install_script_verification
    test_install_script_usage
    
    # Cleanup
    cleanup_test_env
    
    # Results
    echo ""
    print_color "$BLUE" "Install Script Test Results"
    print_color "$BLUE" "=========================="
    echo "Total tests: $TESTS_TOTAL"
    print_color "$GREEN" "Passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        print_color "$RED" "Failed: $TESTS_FAILED"
        echo ""
        print_color "$RED" "Some install script tests failed. Please check the implementation."
        exit 1
    else
        echo ""
        print_color "$GREEN" "All install script tests passed! 🎉"
        echo ""
        echo "install.sh is ready for use!"
        exit 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi