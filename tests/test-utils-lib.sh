#!/bin/bash

# test-utils-lib.sh - Unit tests for utilities library
# Tests lib/utils.sh functionality

# Source the test utilities and library under test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/tests/test-utils.sh"
source "$SCRIPT_DIR/lib/utils.sh"

# Test URL validation
test_url_validation() {
    test_info "Testing URL validation"
    
    setup_test_environment "utils-url"
    
    # Test valid URLs
    assert_command_success "validate_url 'https://github.com/user/repo.git'" "HTTPS URL should be valid"
    assert_command_success "validate_url 'git@github.com:user/repo.git'" "SSH URL should be valid"
    assert_command_success "validate_url 'git://github.com/user/repo.git'" "Git protocol URL should be valid"
    
    # Test invalid URLs
    assert_command_fails "validate_url 'not-a-url'" "Invalid URL should fail"
    assert_command_fails "validate_url 'https://github.com/user/repo'" "URL without .git should fail"
    assert_command_fails "validate_url ''" "Empty URL should fail"
    
    teardown_test_environment
}

# Test name validation
test_name_validation() {
    test_info "Testing name validation"
    
    setup_test_environment "utils-name"
    
    # Test valid names
    assert_command_success "validate_name 'valid-name'" "Name with hyphens should be valid"
    assert_command_success "validate_name 'valid_name'" "Name with underscores should be valid"
    assert_command_success "validate_name 'validName123'" "Name with numbers should be valid"
    assert_command_success "validate_name 'a'" "Single character name should be valid"
    
    # Test invalid names
    assert_command_fails "validate_name 'invalid name'" "Name with spaces should be invalid"
    assert_command_fails "validate_name 'invalid@name'" "Name with special characters should be invalid"
    assert_command_fails "validate_name ''" "Empty name should be invalid"
    assert_command_fails "validate_name '123-name'" "Name starting with number should be invalid"
    
    teardown_test_environment
}

# Test file validation functions
test_file_validation() {
    test_info "Testing file validation functions"
    
    setup_test_environment "utils-file"
    
    # Create test file
    local test_file="$TEST_DIR/test-file.txt"
    echo "test content" > "$test_file"
    
    # Test file existence validation
    assert_command_success "validate_file_exists '$test_file'" "Existing file should validate"
    assert_command_fails "validate_file_exists '/nonexistent/file'" "Non-existent file should fail validation"
    
    # Create test directory
    local test_dir="$TEST_DIR/test-dir"
    mkdir -p "$test_dir"
    
    # Test directory existence validation
    assert_command_success "validate_dir_exists '$test_dir'" "Existing directory should validate"
    assert_command_fails "validate_dir_exists '/nonexistent/dir'" "Non-existent directory should fail validation"
    
    teardown_test_environment
}

# Test string utilities
test_string_utilities() {
    test_info "Testing string utilities"
    
    setup_test_environment "utils-string"
    
    # Test trim function
    local trimmed
    trimmed=$(trim "  hello world  ")
    assert_equals "hello world" "$trimmed" "Should trim leading and trailing whitespace"
    
    trimmed=$(trim "no-whitespace")
    assert_equals "no-whitespace" "$trimmed" "Should handle string without whitespace"
    
    trimmed=$(trim "   ")
    assert_equals "" "$trimmed" "Should trim whitespace-only string to empty"
    
    teardown_test_environment
}

# Test directory utilities
test_directory_utilities() {
    test_info "Testing directory utilities"
    
    setup_test_environment "utils-directory"
    
    # Test ensure_directory
    local new_dir="$TEST_DIR/new/nested/directory"
    assert_command_success "ensure_directory '$new_dir'" "Should create nested directory"
    assert_dir_exists "$new_dir" "Directory should exist after creation"
    
    # Test ensure_directory with existing directory
    assert_command_success "ensure_directory '$new_dir'" "Should handle existing directory"
    
    # Test safe_remove_directory
    assert_command_success "safe_remove_directory '$new_dir'" "Should remove directory safely"
    assert_dir_not_exists "$new_dir" "Directory should not exist after removal"
    
    # Test removing non-existent directory
    assert_command_fails "safe_remove_directory '/nonexistent/directory'" "Should fail for non-existent directory"
    
    teardown_test_environment
}

# Test command availability check
test_command_availability() {
    test_info "Testing command availability check"
    
    setup_test_environment "utils-command"
    
    # Test with commands that should exist
    assert_command_success "is_command_available 'bash'" "bash should be available"
    assert_command_success "is_command_available 'ls'" "ls should be available"
    
    # Test with command that shouldn't exist
    assert_command_fails "is_command_available 'nonexistent-command-xyz'" "Non-existent command should not be available"
    
    teardown_test_environment
}

# Test lock file utilities
test_lock_utilities() {
    test_info "Testing lock file utilities"
    
    setup_test_environment "utils-lock"
    
    local lock_file="$TEST_DIR/test.lock"
    
    # Test creating lock
    assert_command_success "create_lock '$lock_file' 5" "Should create lock successfully"
    assert_file_exists "$lock_file" "Lock file should exist"
    
    # Test releasing lock
    assert_command_success "release_lock '$lock_file'" "Should release lock successfully"
    assert_file_not_exists "$lock_file" "Lock file should not exist after release"
    
    # Test lock timeout
    echo "$$" > "$lock_file"  # Create existing lock
    assert_command_fails "create_lock '$lock_file' 1" "Should fail to acquire lock when already exists"
    
    # Clean up
    rm -f "$lock_file"
    
    teardown_test_environment
}

# Test array utilities
test_array_utilities() {
    test_info "Testing array utilities"
    
    setup_test_environment "utils-array"
    
    # Test array_contains function
    local test_array=("apple" "banana" "cherry")
    
    assert_command_success "array_contains 'banana' '${test_array[@]}'" "Should find existing element"
    assert_command_fails "array_contains 'grape' '${test_array[@]}'" "Should not find non-existent element"
    assert_command_fails "array_contains 'banana'" "Should handle empty array"
    
    teardown_test_environment
}

# Test formatting utilities
test_formatting_utilities() {
    test_info "Testing formatting utilities"
    
    setup_test_environment "utils-formatting"
    
    # Test format_list_item
    local formatted
    formatted=$(format_list_item "•" "Test item")
    assert_equals "  • Test item" "$formatted" "Should format list item correctly"
    
    # Test format_table_row with 2 columns
    formatted=$(format_table_row "Column1" "Column2")
    assert_command_success "echo '$formatted' | grep -q 'Column1.*Column2'" "Should format table row with 2 columns"
    
    # Test format_table_row with 3 columns
    formatted=$(format_table_row "Col1" "Col2" "Col3")
    assert_command_success "echo '$formatted' | grep -q 'Col1.*Col2.*Col3'" "Should format table row with 3 columns"
    
    teardown_test_environment
}

# Test error code constants
test_error_codes() {
    test_info "Testing error code constants"
    
    setup_test_environment "utils-errors"
    
    # Test that error codes are defined
    assert_equals "0" "$E_SUCCESS" "E_SUCCESS should be 0"
    assert_equals "1" "$E_GENERAL_ERROR" "E_GENERAL_ERROR should be 1"
    assert_equals "2" "$E_INVALID_USAGE" "E_INVALID_USAGE should be 2"
    assert_equals "7" "$E_NOT_FOUND" "E_NOT_FOUND should be 7"
    
    teardown_test_environment
}

# Test logging functions
test_logging_functions() {
    test_info "Testing logging functions"
    
    setup_test_environment "utils-logging"
    
    # Test that logging functions exist and can be called
    assert_command_success "info 'Test info message'" "info function should work"
    assert_command_success "warn 'Test warning message'" "warn function should work"
    assert_command_success "error 'Test error message'" "error function should work"
    assert_command_success "success 'Test success message'" "success function should work"
    assert_command_success "debug 'Test debug message'" "debug function should work"
    
    teardown_test_environment
}

# Run all utility tests
main() {
    test_info "Starting utility library tests"
    
    test_url_validation
    test_name_validation
    test_file_validation
    test_string_utilities
    test_directory_utilities
    test_command_availability
    test_lock_utilities
    test_array_utilities
    test_formatting_utilities
    test_error_codes
    test_logging_functions
    
    test_success "Utility library tests completed"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi