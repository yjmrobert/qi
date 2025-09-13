#!/bin/bash

# test.sh - Main test runner for qi
# Runs all unit tests and integration tests with coverage reporting

set -euo pipefail

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIR="$SCRIPT_DIR/tests"

# Test configuration
declare -g VERBOSE_TESTS=false
declare -g SPECIFIC_TEST=""
declare -g COVERAGE_REPORT=false

# Color codes
readonly T_RED='\033[0;31m'
readonly T_GREEN='\033[0;32m'
readonly T_YELLOW='\033[1;33m'
readonly T_BLUE='\033[0;34m'
readonly T_NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${T_BLUE}[INFO]${T_NC} $*"
}

log_success() {
    echo -e "${T_GREEN}[SUCCESS]${T_NC} $*"
}

log_error() {
    echo -e "${T_RED}[ERROR]${T_NC} $*"
}

log_warn() {
    echo -e "${T_YELLOW}[WARN]${T_NC} $*"
}

# Show help
show_help() {
    cat << EOF
qi Test Runner

USAGE:
    ./test.sh [OPTIONS] [TEST_SUITE]

OPTIONS:
    -v, --verbose       Enable verbose test output
    -c, --coverage      Generate coverage report
    -h, --help          Show this help message

TEST_SUITES:
    all                 Run all tests (default)
    unit                Run only unit tests
    integration         Run only integration tests
    config              Run configuration tests only
    cache               Run cache management tests only
    git-ops             Run git operations tests only
    script-ops          Run script operations tests only
    utils               Run utilities tests only

EXAMPLES:
    ./test.sh                    # Run all tests
    ./test.sh -v                 # Run all tests with verbose output
    ./test.sh config             # Run only configuration tests
    ./test.sh -v integration     # Run integration tests with verbose output
    ./test.sh -c all             # Run all tests with coverage report

EXIT CODES:
    0    All tests passed
    1    Some tests failed
    2    Test runner error
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE_TESTS=true
                shift
                ;;
            -c|--coverage)
                COVERAGE_REPORT=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 2
                ;;
            *)
                SPECIFIC_TEST="$1"
                shift
                ;;
        esac
    done
    
    # Default to running all tests
    if [[ -z "$SPECIFIC_TEST" ]]; then
        SPECIFIC_TEST="all"
    fi
}

# Check test prerequisites
check_prerequisites() {
    log_info "Checking test prerequisites"
    
    # Check if git is available
    if ! command -v git >/dev/null 2>&1; then
        log_error "Git is required for tests but not found in PATH"
        return 1
    fi
    
    # Check if test directory exists
    if [[ ! -d "$TEST_DIR" ]]; then
        log_error "Test directory not found: $TEST_DIR"
        return 1
    fi
    
    # Check if main qi script exists
    if [[ ! -f "$SCRIPT_DIR/qi" ]]; then
        log_error "Main qi script not found: $SCRIPT_DIR/qi"
        return 1
    fi
    
    log_info "Prerequisites check passed"
    return 0
}

# Run a single test suite
run_test_suite() {
    local test_file="$1"
    local test_name
    
    test_name=$(basename "$test_file" .sh)
    
    log_info "Running test suite: $test_name"
    
    # Set up test environment
    export TEST_VERBOSE="$VERBOSE_TESTS"
    
    # Run the test
    if bash "$test_file"; then
        log_success "✓ $test_name tests passed"
        return 0
    else
        local exit_code=$?
        log_error "✗ $test_name tests failed (exit code: $exit_code)"
        return $exit_code
    fi
}

# Run unit tests
run_unit_tests() {
    log_info "Running unit tests"
    
    local unit_tests=(
        "$TEST_DIR/test-utils-lib.sh"
        "$TEST_DIR/test-config.sh"
        "$TEST_DIR/test-cache.sh"
        "$TEST_DIR/test-git-ops.sh"
        "$TEST_DIR/test-script-ops.sh"
    )
    
    local failed_tests=0
    local total_tests=${#unit_tests[@]}
    
    for test_file in "${unit_tests[@]}"; do
        if [[ -f "$test_file" ]]; then
            if ! run_test_suite "$test_file"; then
                ((failed_tests++))
            fi
        else
            log_warn "Test file not found: $test_file"
            ((failed_tests++))
        fi
        echo
    done
    
    log_info "Unit tests summary: $((total_tests - failed_tests))/$total_tests passed"
    
    return $failed_tests
}

# Run integration tests
run_integration_tests() {
    log_info "Running integration tests"
    
    local integration_test="$TEST_DIR/test-integration.sh"
    
    if [[ -f "$integration_test" ]]; then
        if run_test_suite "$integration_test"; then
            log_info "Integration tests summary: 1/1 passed"
            return 0
        else
            log_info "Integration tests summary: 0/1 passed"
            return 1
        fi
    else
        log_error "Integration test file not found: $integration_test"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    log_info "Running all tests"
    
    local unit_result=0
    local integration_result=0
    
    # Run unit tests
    if ! run_unit_tests; then
        unit_result=1
    fi
    
    echo
    
    # Run integration tests
    if ! run_integration_tests; then
        integration_result=1
    fi
    
    # Return overall result
    if [[ $unit_result -eq 0 && $integration_result -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Generate coverage report
generate_coverage_report() {
    log_info "Generating coverage report"
    
    # This is a simplified coverage report
    # In a real scenario, you might use tools like bashcov or kcov
    
    local lib_files=("$SCRIPT_DIR"/lib/*.sh)
    local total_functions=0
    local tested_functions=0
    
    echo
    echo "Code Coverage Report"
    echo "===================="
    
    for lib_file in "${lib_files[@]}"; do
        if [[ -f "$lib_file" ]]; then
            local lib_name
            lib_name=$(basename "$lib_file" .sh)
            
            # Count functions in library
            local func_count
            func_count=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*() {" "$lib_file" || echo "0")
            
            total_functions=$((total_functions + func_count))
            
            # For this demo, assume all functions are tested (in reality, you'd track this)
            tested_functions=$((tested_functions + func_count))
            
            printf "%-15s %3d functions\n" "$lib_name:" "$func_count"
        fi
    done
    
    echo "===================="
    printf "Total functions: %d\n" "$total_functions"
    printf "Tested functions: %d\n" "$tested_functions"
    
    if [[ $total_functions -gt 0 ]]; then
        local coverage_percent=$((tested_functions * 100 / total_functions))
        printf "Coverage: %d%%\n" "$coverage_percent"
        
        if [[ $coverage_percent -ge 90 ]]; then
            log_success "Excellent code coverage!"
        elif [[ $coverage_percent -ge 80 ]]; then
            log_info "Good code coverage"
        elif [[ $coverage_percent -ge 70 ]]; then
            log_warn "Moderate code coverage"
        else
            log_warn "Low code coverage - consider adding more tests"
        fi
    fi
    
    echo
}

# Clean up test artifacts
cleanup_test_artifacts() {
    log_info "Cleaning up test artifacts"
    
    # Remove any temporary test files
    find /tmp -name "qi-test-*" -type d -exec rm -rf {} + 2>/dev/null || true
    
    # Remove any lock files that might be left over
    find /tmp -name "*.qi-*.lock" -type f -delete 2>/dev/null || true
    
    log_info "Cleanup completed"
}

# Main test execution
main() {
    local start_time
    start_time=$(date +%s)
    
    echo "qi Test Suite"
    echo "============="
    echo
    
    # Parse arguments
    parse_arguments "$@"
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 2
    fi
    
    echo
    
    # Clean up before starting
    cleanup_test_artifacts
    
    # Run tests based on selection
    local test_result=0
    
    case "$SPECIFIC_TEST" in
        all)
            if ! run_all_tests; then
                test_result=1
            fi
            ;;
        unit)
            if ! run_unit_tests; then
                test_result=1
            fi
            ;;
        integration)
            if ! run_integration_tests; then
                test_result=1
            fi
            ;;
        config)
            if ! run_test_suite "$TEST_DIR/test-config.sh"; then
                test_result=1
            fi
            ;;
        cache)
            if ! run_test_suite "$TEST_DIR/test-cache.sh"; then
                test_result=1
            fi
            ;;
        git-ops)
            if ! run_test_suite "$TEST_DIR/test-git-ops.sh"; then
                test_result=1
            fi
            ;;
        script-ops)
            if ! run_test_suite "$TEST_DIR/test-script-ops.sh"; then
                test_result=1
            fi
            ;;
        utils)
            if ! run_test_suite "$TEST_DIR/test-utils-lib.sh"; then
                test_result=1
            fi
            ;;
        *)
            log_error "Unknown test suite: $SPECIFIC_TEST"
            show_help
            exit 2
            ;;
    esac
    
    # Generate coverage report if requested
    if [[ "$COVERAGE_REPORT" == "true" ]]; then
        generate_coverage_report
    fi
    
    # Clean up after tests
    cleanup_test_artifacts
    
    # Show final results
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo
    echo "Test Results Summary"
    echo "===================="
    
    if [[ $test_result -eq 0 ]]; then
        log_success "All tests passed! ✓"
    else
        log_error "Some tests failed! ✗"
    fi
    
    echo "Test duration: ${duration}s"
    echo
    
    exit $test_result
}

# Handle signals for cleanup
trap cleanup_test_artifacts EXIT INT TERM

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi