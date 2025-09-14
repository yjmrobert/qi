#!/bin/bash

# run_tests.sh - Comprehensive test runner for qi project
# Runs all unit tests using shunit2 and generates coverage reports

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
TESTS_DIR="$PROJECT_ROOT/tests"
TOOLS_DIR="$PROJECT_ROOT/tools"
COVERAGE_TOOL="$TOOLS_DIR/bash_coverage.sh"
COVERAGE_DIR="$PROJECT_ROOT/coverage"
SHUNIT2="$PROJECT_ROOT/shunit2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
# PURPLE='\033[0;35m'  # Unused color variable
CYAN='\033[0;36m'
# WHITE='\033[1;37m'  # Unused color variable
NC='\033[0m'

# Test configuration
ENABLE_COVERAGE="${ENABLE_COVERAGE:-true}"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"
VERBOSE="${VERBOSE:-false}"
PARALLEL="${PARALLEL:-false}"
FILTER="${FILTER:-}"

# Test statistics
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

print_color() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

print_header() {
    print_color "$CYAN" "================================"
    print_color "$CYAN" "$*"
    print_color "$CYAN" "================================"
}

print_section() {
    print_color "$BLUE" ""
    print_color "$BLUE" "--- $* ---"
}

print_success() {
    print_color "$GREEN" "✓ $*"
}

print_error() {
    print_color "$RED" "✗ $*"
}

print_warning() {
    print_color "$YELLOW" "⚠ $*"
}

print_info() {
    print_color "$BLUE" "ℹ $*"
}

# Check prerequisites
check_prerequisites() {
    print_section "Checking Prerequisites"
    
    local missing_deps=()
    
    # Check for shunit2
    if [[ ! -f "$SHUNIT2" ]]; then
        missing_deps+=("shunit2 (expected at $SHUNIT2)")
    else
        print_success "shunit2 found"
    fi
    
    # Check for coverage tool
    if [[ "$ENABLE_COVERAGE" == "true" && ! -f "$COVERAGE_TOOL" ]]; then
        missing_deps+=("coverage tool (expected at $COVERAGE_TOOL)")
    elif [[ "$ENABLE_COVERAGE" == "true" ]]; then
        print_success "Coverage tool found"
    fi
    
    # Check for test directory
    if [[ ! -d "$TESTS_DIR" ]]; then
        missing_deps+=("tests directory (expected at $TESTS_DIR)")
    else
        print_success "Tests directory found"
    fi
    
    # Check for required commands
    local required_commands=("bash" "find" "grep" "sort" "wc")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd command")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing prerequisites:"
        for dep in "${missing_deps[@]}"; do
            print_error "  - $dep"
        done
        return 1
    fi
    
    print_success "All prerequisites satisfied"
    return 0
}

# Find all test files
find_test_files() {
    local test_files=()
    
    if [[ -n "$FILTER" ]]; then
        print_info "Filtering tests with pattern: $FILTER" >&2
        mapfile -t test_files < <(find "$TESTS_DIR" -name "test_*.sh" -executable | grep "$FILTER" | sort)
    else
        mapfile -t test_files < <(find "$TESTS_DIR" -name "test_*.sh" -executable | sort)
    fi
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        print_error "No test files found in $TESTS_DIR" >&2
        return 1
    fi
    
    print_info "Found ${#test_files[@]} test files:" >&2
    for test_file in "${test_files[@]}"; do
        print_info "  - $(basename "$test_file")" >&2
    done
    
    printf '%s\n' "${test_files[@]}"
}

# Run a single test file
run_test_file() {
    local test_file="$1"
    local test_name
    test_name="$(basename "$test_file" .sh)"
    
    print_section "Running $test_name"
    
    local start_time
    start_time=$(date +%s)
    
    local output_file="$COVERAGE_DIR/${test_name}.out"
    local error_file="$COVERAGE_DIR/${test_name}.err"
    
    # Run test with or without coverage
    local exit_code=0
    if [[ "$ENABLE_COVERAGE" == "true" ]]; then
        if [[ "$VERBOSE" == "true" ]]; then
            "$COVERAGE_TOOL" run "$test_file" 2>&1 | tee "$output_file"
            exit_code=${PIPESTATUS[0]}
        else
            "$COVERAGE_TOOL" run "$test_file" > "$output_file" 2> "$error_file"
            exit_code=$?
        fi
    else
        if [[ "$VERBOSE" == "true" ]]; then
            bash "$test_file" 2>&1 | tee "$output_file"
            exit_code=${PIPESTATUS[0]}
        else
            bash "$test_file" > "$output_file" 2> "$error_file"
            exit_code=$?
        fi
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Parse shunit2 output for statistics
    local test_output
    if [[ -f "$output_file" ]]; then
        test_output=$(cat "$output_file")
    else
        test_output=""
    fi
    
    # Extract test results from shunit2 output
    local ran_tests=0
    local failures=0
    local errors=0
    local skipped=0
    
    if [[ "$test_output" =~ Ran\ ([0-9]+)\ test ]]; then
        ran_tests="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$test_output" =~ FAILED.*failures=([0-9]+) ]]; then
        failures="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$test_output" =~ errors=([0-9]+) ]]; then
        errors="${BASH_REMATCH[1]}"
    fi
    
    if [[ "$test_output" =~ skipped=([0-9]+) ]]; then
        skipped="${BASH_REMATCH[1]}"
    fi
    
    # Update global statistics
    TOTAL_TESTS=$((TOTAL_TESTS + ran_tests))
    FAILED_TESTS=$((FAILED_TESTS + failures + errors))
    SKIPPED_TESTS=$((SKIPPED_TESTS + skipped))
    PASSED_TESTS=$((PASSED_TESTS + ran_tests - failures - errors - skipped))
    
    # Report results
    if [[ $exit_code -eq 0 && $failures -eq 0 && $errors -eq 0 ]]; then
        print_success "$test_name completed successfully ($ran_tests tests, ${duration}s)"
    else
        print_error "$test_name failed ($failures failures, $errors errors, ${duration}s)"
        
        # Show error output if not verbose
        if [[ "$VERBOSE" != "true" && -f "$error_file" && -s "$error_file" ]]; then
            print_error "Error output:"
            sed 's/^/  /' "$error_file"
        fi
        
        # Show failed test details
        if [[ "$VERBOSE" != "true" && -f "$output_file" ]]; then
            print_error "Test output:"
            grep -E "FAIL|ERROR|ASSERT" "$output_file" | sed 's/^/  /' || true
        fi
    fi
    
    return "$exit_code"
}

# Run all tests
run_all_tests() {
    print_header "Running All Tests"
    
    # Initialize coverage if enabled
    if [[ "$ENABLE_COVERAGE" == "true" ]]; then
        print_section "Initializing Coverage"
        "$COVERAGE_TOOL" init
    fi
    
    # Create output directory
    mkdir -p "$COVERAGE_DIR"
    
    # Find test files
    local test_files
    mapfile -t test_files < <(find_test_files)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        return 1
    fi
    
    # Run tests
    local failed_files=()
    
    if [[ "$PARALLEL" == "true" && ${#test_files[@]} -gt 1 ]]; then
        print_info "Running tests in parallel..."
        local pids=()
        
        for test_file in "${test_files[@]}"; do
            run_test_file "$test_file" &
            pids+=($!)
        done
        
        # Wait for all tests to complete
        for pid in "${pids[@]}"; do
            if ! wait "$pid"; then
                failed_files+=("$pid")
            fi
        done
    else
        for test_file in "${test_files[@]}"; do
            if ! run_test_file "$test_file"; then
                failed_files+=("$(basename "$test_file")")
            fi
        done
    fi
    
    # Report overall results
    print_section "Test Results Summary"
    
    print_info "Total tests run: $TOTAL_TESTS"
    
    if [[ $PASSED_TESTS -gt 0 ]]; then
        print_success "Passed: $PASSED_TESTS"
    fi
    
    if [[ $FAILED_TESTS -gt 0 ]]; then
        print_error "Failed: $FAILED_TESTS"
    fi
    
    if [[ $SKIPPED_TESTS -gt 0 ]]; then
        print_warning "Skipped: $SKIPPED_TESTS"
    fi
    
    if [[ ${#failed_files[@]} -gt 0 ]]; then
        print_error "Failed test files:"
        for file in "${failed_files[@]}"; do
            print_error "  - $file"
        done
        return 1
    fi
    
    print_success "All tests passed!"
    return 0
}

# Generate coverage report
generate_coverage_report() {
    if [[ "$ENABLE_COVERAGE" != "true" ]]; then
        print_info "Coverage reporting disabled"
        return 0
    fi
    
    print_header "Coverage Report"
    
    # Generate coverage analysis
    local coverage_exit_code=0
    "$COVERAGE_TOOL" analyze || coverage_exit_code=$?
    
    # Generate HTML report
    "$COVERAGE_TOOL" html
    
    print_info "Coverage reports generated in $COVERAGE_DIR/"
    
    if [[ $coverage_exit_code -ne 0 ]]; then
        print_warning "Coverage is below $COVERAGE_THRESHOLD% threshold"
        return 1
    fi
    
    return 0
}

# Clean up test artifacts
cleanup() {
    if [[ -d "$COVERAGE_DIR" ]]; then
        print_section "Cleaning up test artifacts"
        find "$COVERAGE_DIR" -name "*.out" -delete 2>/dev/null || true
        find "$COVERAGE_DIR" -name "*.err" -delete 2>/dev/null || true
        print_info "Test artifacts cleaned"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [options] [command]

Commands:
    run         Run all tests (default)
    coverage    Run tests and generate coverage report
    clean       Clean test artifacts and coverage data
    list        List available test files

Options:
    --no-coverage       Disable coverage reporting
    --coverage-threshold N  Set coverage threshold (default: $COVERAGE_THRESHOLD)
    --verbose, -v       Enable verbose output
    --parallel, -p      Run tests in parallel
    --filter PATTERN    Filter tests by pattern
    --help, -h          Show this help

Environment Variables:
    ENABLE_COVERAGE     Enable/disable coverage (true/false)
    COVERAGE_THRESHOLD  Coverage threshold percentage
    VERBOSE            Enable verbose output (true/false)
    PARALLEL           Enable parallel test execution (true/false)
    FILTER             Pattern to filter test files

Examples:
    $0                          # Run all tests with coverage
    $0 --no-coverage           # Run tests without coverage
    $0 --filter utils          # Run only utils tests
    $0 --verbose --parallel    # Run tests verbosely in parallel
    $0 coverage                # Generate coverage report only
    $0 clean                   # Clean test artifacts
EOF
}

# Main function
main() {
    local command="run"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-coverage)
                ENABLE_COVERAGE="false"
                shift
                ;;
            --coverage-threshold)
                COVERAGE_THRESHOLD="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE="true"
                shift
                ;;
            --parallel|-p)
                PARALLEL="true"
                shift
                ;;
            --filter)
                FILTER="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            run|coverage|clean|list)
                command="$1"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Set environment variables
    export COVERAGE_DIR
    export COVERAGE_THRESHOLD
    
    # Execute command
    case "$command" in
        "run")
            if ! check_prerequisites; then
                exit 1
            fi
            
            local test_exit_code=0
            run_all_tests || test_exit_code=$?
            
            local coverage_exit_code=0
            generate_coverage_report || coverage_exit_code=$?
            
            if [[ $test_exit_code -ne 0 ]]; then
                print_error "Some tests failed"
                exit 1
            elif [[ $coverage_exit_code -ne 0 ]]; then
                print_warning "Tests passed but coverage is below threshold"
                exit 1
            else
                print_success "All tests passed and coverage requirements met"
                exit 0
            fi
            ;;
        "coverage")
            if [[ "$ENABLE_COVERAGE" != "true" ]]; then
                print_error "Coverage is disabled"
                exit 1
            fi
            generate_coverage_report
            ;;
        "clean")
            cleanup
            if [[ "$ENABLE_COVERAGE" == "true" && -f "$COVERAGE_TOOL" ]]; then
                "$COVERAGE_TOOL" clean
            fi
            print_success "All test artifacts cleaned"
            ;;
        "list")
            print_header "Available Test Files"
            find_test_files | while read -r test_file; do
                print_info "$(basename "$test_file")"
            done
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Set up signal handlers
trap cleanup EXIT

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi