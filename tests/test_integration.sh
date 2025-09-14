#!/bin/bash

# test_integration.sh - Integration tests for qi using shunit2
# Tests core functionality end-to-end to ensure everything works correctly

# Set up test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
QI_SCRIPT="$PROJECT_ROOT/qi"

# Test fixtures and setup
setUp() {
    # Create temporary directory for tests
    TEST_TEMP_DIR=$(mktemp -d -t qi_integration_test.XXXXXX)
    export TEST_TEMP_DIR
    
    # Use temporary cache directory for testing
    TEST_CACHE_DIR="$TEST_TEMP_DIR/cache"
    export QI_CACHE_DIR="$TEST_CACHE_DIR"
    
    # Ensure qi script is executable
    if [[ -f "$QI_SCRIPT" ]]; then
        chmod +x "$QI_SCRIPT"
    fi
}

tearDown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    
    # Unset environment variables
    unset QI_CACHE_DIR
}

# Tests for basic command functionality
test_qi_help_command() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertTrue "Help command should work" "$QI_SCRIPT --help >/dev/null 2>&1"
    assertTrue "Help command with 'help' should work" "$QI_SCRIPT help >/dev/null 2>&1"
}

test_qi_version_command() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertTrue "Version command should work" "$QI_SCRIPT --version >/dev/null 2>&1"
    assertTrue "Version command with 'version' should work" "$QI_SCRIPT version >/dev/null 2>&1"
}

test_qi_config_command() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertTrue "Config command should work" "$QI_SCRIPT config >/dev/null 2>&1"
}

# Tests for repository management
test_qi_add_repository_invalid_url() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertFalse "Should reject invalid repository URL" "$QI_SCRIPT add invalid-url >/dev/null 2>&1"
}

test_qi_list_repos_empty() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertTrue "Should handle empty repository list" "$QI_SCRIPT list-repos >/dev/null 2>&1"
}

test_qi_status_empty() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertTrue "Status command should work with empty cache" "$QI_SCRIPT status >/dev/null 2>&1"
}

test_qi_list_scripts_empty() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertTrue "Should handle empty script list" "$QI_SCRIPT list >/dev/null 2>&1"
}

# Tests for error handling
test_qi_remove_nonexistent_repo() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertFalse "Should fail to remove non-existent repository" "$QI_SCRIPT remove non-existent-repo >/dev/null 2>&1"
}

test_qi_execute_nonexistent_script() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertFalse "Should fail to execute non-existent script" "$QI_SCRIPT non-existent-script >/dev/null 2>&1"
}

test_qi_update_nonexistent_repo() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertFalse "Should fail to update non-existent repository" "$QI_SCRIPT update non-existent-repo >/dev/null 2>&1"
}

# Tests for argument parsing
test_qi_invalid_option() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertFalse "Should reject invalid options" "$QI_SCRIPT --invalid-option >/dev/null 2>&1"
}

test_qi_missing_arguments() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertFalse "Add command should require URL" "$QI_SCRIPT add >/dev/null 2>&1"
    assertFalse "Remove command should require name" "$QI_SCRIPT remove >/dev/null 2>&1"
}

# Tests for dry-run mode
test_qi_dry_run_mode() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    # Test dry-run with various commands
    assertTrue "Dry-run should work with add command" "$QI_SCRIPT --dry-run add https://github.com/user/repo.git >/dev/null 2>&1"
    assertTrue "Dry-run should work with update command" "$QI_SCRIPT --dry-run update >/dev/null 2>&1"
}

# Tests for verbose mode
test_qi_verbose_mode() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    assertTrue "Verbose mode should work" "$QI_SCRIPT --verbose config >/dev/null 2>&1"
}

# Tests for cache directory creation
test_qi_cache_directory_creation() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    # Run a command that should initialize cache
    "$QI_SCRIPT" config >/dev/null 2>&1
    
    assertTrue "Cache directory should be created" "[[ -d '$TEST_CACHE_DIR' ]]"
}

# Tests for configuration handling
test_qi_environment_variables() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    # Test with custom cache directory
    local custom_cache="$TEST_TEMP_DIR/custom_cache"
    export QI_CACHE_DIR="$custom_cache"
    
    "$QI_SCRIPT" config >/dev/null 2>&1
    
    assertTrue "Should use custom cache directory" "[[ -d '$custom_cache' ]]"
    
    unset QI_CACHE_DIR
}

# Tests for library loading
test_qi_library_loading() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    # Test that the script can load its libraries
    assertTrue "Should load libraries successfully" "$QI_SCRIPT config >/dev/null 2>&1"
}

# Tests for concurrent access
test_qi_concurrent_access() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    # Start two qi processes simultaneously
    "$QI_SCRIPT" config >/dev/null 2>&1 &
    local pid1=$!
    "$QI_SCRIPT" status >/dev/null 2>&1 &
    local pid2=$!
    
    # Wait for both to complete
    wait $pid1
    local exit1=$?
    wait $pid2
    local exit2=$?
    
    # At least one should succeed (they might conflict on cache lock)
    assertTrue "At least one concurrent process should succeed" "[[ $exit1 -eq 0 || $exit2 -eq 0 ]]"
}

# Test for script syntax validation
test_qi_script_syntax() {
    assertTrue "qi script should have valid bash syntax" "bash -n '$QI_SCRIPT'"
}

# Test for required dependencies
test_qi_dependencies() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    # Test that required commands are available
    assertTrue "git should be available" "command -v git >/dev/null"
    assertTrue "find should be available" "command -v find >/dev/null"
    assertTrue "grep should be available" "command -v grep >/dev/null"
    assertTrue "sed should be available" "command -v sed >/dev/null"
}

# Test for file permissions
test_qi_file_permissions() {
    assertTrue "qi script should be executable" "[[ -x '$QI_SCRIPT' ]]"
    
    # Check library files exist
    local lib_dir="$PROJECT_ROOT/lib"
    assertTrue "lib directory should exist" "[[ -d '$lib_dir' ]]"
    
    for lib in utils.sh config.sh cache.sh git-ops.sh script-ops.sh; do
        assertTrue "$lib should exist" "[[ -f '$lib_dir/$lib' ]]"
    done
}

# Test for proper cleanup
test_qi_cleanup_on_error() {
    if [[ ! -x "$QI_SCRIPT" ]]; then
        startSkipping
    fi
    
    # Test that failed operations don't leave partial state
    "$QI_SCRIPT" add invalid-url test-repo >/dev/null 2>&1 || true
    
    # Check that no partial repository was created
    assertFalse "Should not create partial repository on error" "[[ -d '$TEST_CACHE_DIR/test-repo' ]]"
}

# Load and run shunit2
# shellcheck source=../shunit2
. "$PROJECT_ROOT/shunit2"