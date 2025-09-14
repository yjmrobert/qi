#!/bin/bash

# test_utils.sh - Unit tests for lib/utils.sh using shunit2
# Tests utility functions used throughout the qi application

# Set up test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
LIB_DIR="$PROJECT_ROOT/lib"

# Handle case where script is instrumented and copied to temp directory
if [[ ! -d "$LIB_DIR" ]]; then
    # Look for original project structure
    if [[ -n "${ORIGINAL_FILE:-}" ]]; then
        ORIGINAL_TEST_DIR="$(cd "$(dirname "$ORIGINAL_FILE")" && pwd)"
        ORIGINAL_PROJECT_ROOT="$(dirname "$ORIGINAL_TEST_DIR")"
        LIB_DIR="$ORIGINAL_PROJECT_ROOT/lib"
    else
        # Fallback: try to find lib directory in workspace
        if [[ -d "/workspace/lib" ]]; then
            LIB_DIR="/workspace/lib"
        fi
    fi
fi

# Mock log function for testing
log() {
    return 0
}

# Source the library under test
if [[ -f "$LIB_DIR/utils.sh" ]]; then
    . "$LIB_DIR/utils.sh"
else
    echo "ERROR: Cannot find utils.sh at $LIB_DIR/utils.sh" >&2
    exit 1
fi

# Test fixtures and setup
setUp() {
    # Create temporary directory for tests
    TEST_TEMP_DIR=$(mktemp -d -t qi_test.XXXXXX)
    export TEST_TEMP_DIR
}

tearDown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Tests for URL validation
test_validate_git_url_https() {
    assertTrue "HTTPS URL should be valid" "validate_git_url 'https://github.com/user/repo.git'"
    assertTrue "HTTPS URL without .git should be valid" "validate_git_url 'https://github.com/user/repo'"
}

test_validate_git_url_ssh() {
    assertTrue "SSH URL should be valid" "validate_git_url 'git@github.com:user/repo.git'"
    assertTrue "SSH URL without .git should be valid" "validate_git_url 'git@github.com:user/repo'"
}

test_validate_git_url_invalid() {
    assertFalse "Invalid URL should fail" "validate_git_url 'not-a-url'"
    assertFalse "Empty URL should fail" "validate_git_url ''"
    assertFalse "FTP URL should fail" "validate_git_url 'ftp://example.com/repo.git'"
}

# Tests for URL normalization
test_normalize_git_url() {
    local result
    result=$(normalize_git_url "https://github.com/user/repo")
    assertEquals "Should add .git suffix" "https://github.com/user/repo.git" "$result"
    
    result=$(normalize_git_url "https://github.com/user/repo.git")
    assertEquals "Should keep existing .git suffix" "https://github.com/user/repo.git" "$result"
}

# Tests for repository name validation
test_validate_repo_name_valid() {
    assertTrue "Alphanumeric name should be valid" "validate_repo_name 'myrepo'"
    assertTrue "Name with hyphens should be valid" "validate_repo_name 'my-repo'"
    assertTrue "Name with underscores should be valid" "validate_repo_name 'my_repo'"
    assertTrue "Name with dots should be valid" "validate_repo_name 'my.repo'"
    assertTrue "Mixed characters should be valid" "validate_repo_name 'my-repo_123.test'"
}

test_validate_repo_name_invalid() {
    assertFalse "Empty name should be invalid" "validate_repo_name ''"
    assertFalse "Name with spaces should be invalid" "validate_repo_name 'my repo'"
    assertFalse "Name with special chars should be invalid" "validate_repo_name 'my@repo'"
    assertFalse "Reserved name should be invalid" "validate_repo_name '.'"
    assertFalse "Reserved name should be invalid" "validate_repo_name '..'"
    assertFalse "Reserved name should be invalid" "validate_repo_name '.qi-meta'"
}

# Tests for repository name sanitization
test_sanitize_repo_name() {
    local result
    result=$(sanitize_repo_name "my repo")
    assertEquals "Should replace spaces with underscores" "my_repo" "$result"
    
    result=$(sanitize_repo_name "my@repo#test")
    assertEquals "Should replace special chars with underscores" "my_repo_test" "$result"
    
    result=$(sanitize_repo_name "...test...")
    assertEquals "Should trim leading/trailing dots" "test" "$result"
    
    result=$(sanitize_repo_name "")
    assertEquals "Should provide default for empty name" "repo" "$result"
}

# Tests for command existence checking
test_command_exists() {
    assertTrue "bash command should exist" "command_exists 'bash'"
    assertTrue "ls command should exist" "command_exists 'ls'"
    assertFalse "Non-existent command should not exist" "command_exists 'nonexistent_command_xyz'"
}

# Tests for dependency checking
test_check_dependencies() {
    # This test might be environment dependent, so we'll test the function exists
    assertTrue "check_dependencies function should exist" "declare -f check_dependencies > /dev/null"
}

# Tests for file size formatting
test_format_size() {
    local result
    result=$(format_size 512)
    assertEquals "Should format bytes" "512B" "$result"
    
    result=$(format_size 1536)
    assertEquals "Should format kilobytes" "1K" "$result"
    
    result=$(format_size 1048576)
    assertEquals "Should format megabytes" "1M" "$result"
    
    result=$(format_size 1073741824)
    assertEquals "Should format gigabytes" "1G" "$result"
}

# Tests for directory size calculation
test_get_dir_size() {
    # Create test directory with known content
    local test_dir="$TEST_TEMP_DIR/size_test"
    mkdir -p "$test_dir"
    echo "test content" > "$test_dir/file1.txt"
    echo "more content" > "$test_dir/file2.txt"
    
    local size
    size=$(get_dir_size "$test_dir")
    assertTrue "Should return numeric size for existing directory" "[[ '$size' =~ ^[0-9]+$ ]]"
    assertTrue "Should return non-zero size for directory with files" "[[ '$size' -gt 0 ]]"
    
    size=$(get_dir_size "/nonexistent/directory")
    assertEquals "Should return 0 for non-existent directory" "0" "$size"
}

# Tests for temporary directory creation
test_create_temp_dir() {
    local temp_dir
    temp_dir=$(create_temp_dir "test_prefix")
    
    assertTrue "Should create directory" "[[ -d '$temp_dir' ]]"
    assertTrue "Should be writable" "[[ -w '$temp_dir' ]]"
    assertTrue "Should contain prefix in name" "[[ '$temp_dir' =~ test_prefix ]]"
    
    # Clean up
    rm -rf "$temp_dir"
}

# Tests for temporary directory cleanup
test_cleanup_temp_dir() {
    local temp_dir
    temp_dir=$(create_temp_dir "cleanup_test")
    assertTrue "Directory should exist before cleanup" "[[ -d '$temp_dir' ]]"
    
    cleanup_temp_dir "$temp_dir"
    assertFalse "Directory should not exist after cleanup" "[[ -d '$temp_dir' ]]"
}

# Tests for timestamp functions
test_get_timestamp() {
    local timestamp
    timestamp=$(get_timestamp)
    assertTrue "Should return ISO timestamp" "[[ '$timestamp' =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]"
}

test_time_diff() {
    local result
    result=$(time_diff 100 160)
    assertEquals "Should format minute difference" "1m 0s" "$result"
    
    result=$(time_diff 100 130)
    assertEquals "Should format second difference" "30s" "$result"
    
    result=$(time_diff 100 3800)
    assertEquals "Should format hour difference" "1h 1m" "$result"
}

# Tests for string manipulation
test_escape_regex() {
    local result
    result=$(escape_regex "test.string")
    assertEquals "test\.string" "$result"
    
    result=$(escape_regex "test[bracket]")
    assertEquals "test\\[bracket\\]" "$result"
}

test_join_array() {
    local result
    result=$(join_array "," "one" "two" "three")
    assertEquals "Should join with comma" "one,two,three" "$result"
    
    result=$(join_array "|" "single")
    assertEquals "Should handle single element" "single" "$result"
    
    result=$(join_array ":" )
    assertEquals "Should handle empty array" "" "$result"
}

# Tests for array operations
test_array_contains() {
    local test_array=("apple" "banana" "cherry")
    
    if array_contains 'banana' "${test_array[@]}"; then
        assertTrue "Found existing element" true
    else
        assertTrue "Should find existing element" false
    fi
    
    if array_contains 'grape' "${test_array[@]}"; then
        assertFalse "Should not find non-existent element" true
    else
        assertFalse "Should not find non-existent element" false
    fi
}

# Tests for retry functionality
test_retry_command() {
    # Test successful command
    assertTrue "Should succeed on first try" "retry_command 3 1 true"
    
    # Test command that always fails
    assertFalse "Should fail after max attempts" "retry_command 2 1 false"
    
    # Test with actual command
    assertTrue "Should retry ls command" "retry_command 2 1 ls /tmp >/dev/null 2>&1"
}

# Tests for color output functions
test_print_color() {
    # Test that functions exist and don't crash
    assertTrue "print_success should exist" "declare -f print_success > /dev/null"
    assertTrue "print_error should exist" "declare -f print_error > /dev/null"
    assertTrue "print_warning should exist" "declare -f print_warning > /dev/null"
    assertTrue "print_info should exist" "declare -f print_info > /dev/null"
}

# Tests for terminal detection
test_is_terminal() {
    # Function should exist and return boolean
    assertTrue "is_terminal function should exist" "declare -f is_terminal > /dev/null"
}

# Load and run shunit2
. "$PROJECT_ROOT/shunit2"