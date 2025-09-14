#!/bin/bash

# test_config.sh - Unit tests for lib/config.sh using shunit2
# Tests configuration management functionality

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

# Source required libraries
# shellcheck source=lib/utils.sh
# shellcheck disable=SC1091
. "$LIB_DIR/utils.sh"
# shellcheck source=lib/config.sh
# shellcheck disable=SC1091
. "$LIB_DIR/config.sh"

# Test fixtures and setup
setUp() {
    # Create temporary directory for tests
    TEST_TEMP_DIR=$(mktemp -d -t qi_config_test.XXXXXX)
    export TEST_TEMP_DIR
    
    # Set up test config file
    TEST_CONFIG_FILE="$TEST_TEMP_DIR/test_config"
    export TEST_CONFIG_FILE
    
    # Mock log function to avoid output during tests
    # shellcheck disable=SC2317  # Function called by test framework
    log() {
        return 0
    }
}

tearDown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    
    # Reset config array with defaults (preserve the original array)
    # shellcheck disable=SC2154  # QI_CONFIG is an associative array
    QI_CONFIG[cache_dir]="${QI_CACHE_DIR:-$HOME/.qi/cache}"
    # shellcheck disable=SC2154  # QI_CONFIG is an associative array
    QI_CONFIG[config_file]="${QI_CONFIG_FILE:-$HOME/.qi/config}"
    # shellcheck disable=SC2154  # QI_CONFIG is an associative array
    QI_CONFIG[default_branch]="${QI_DEFAULT_BRANCH:-main}"
    # shellcheck disable=SC2154  # QI_CONFIG is an associative array
    QI_CONFIG[auto_update]="${QI_AUTO_UPDATE:-false}"
    # shellcheck disable=SC2154  # QI_CONFIG is an associative array
    QI_CONFIG[verbose]="${QI_VERBOSE:-false}"
    # shellcheck disable=SC2154  # QI_CONFIG is an associative array
    QI_CONFIG[max_cache_size]="${QI_MAX_CACHE_SIZE:-1G}"
}

# Tests for configuration loading
test_load_config_nonexistent() {
    # Test loading non-existent config file
    assertTrue "Should handle non-existent config file" "load_config '/nonexistent/config'"
}

test_load_config_valid() {
    # Create test config file
    cat > "$TEST_CONFIG_FILE" << 'EOF'
# Test configuration
cache_dir=/tmp/test_cache
default_branch=develop
auto_update=true
verbose=false
max_cache_size=2G
EOF
    
    # Load config
    assertTrue "Should load valid config file" "load_config '$TEST_CONFIG_FILE'"
    
    # Verify values were loaded
    assertEquals "Should load cache_dir" "/tmp/test_cache" "${QI_CONFIG[cache_dir]}"
    assertEquals "Should load default_branch" "develop" "${QI_CONFIG[default_branch]}"
    assertEquals "Should load auto_update" "true" "${QI_CONFIG[auto_update]}"
    assertEquals "Should load verbose" "false" "${QI_CONFIG[verbose]}"
    assertEquals "Should load max_cache_size" "2G" "${QI_CONFIG[max_cache_size]}"
}

test_load_config_with_quotes() {
    # Create test config file with quoted values
    cat > "$TEST_CONFIG_FILE" << 'EOF'
cache_dir="/tmp/quoted cache"
default_branch='feature-branch'
EOF
    
    assertTrue "Should load config with quotes" "load_config '$TEST_CONFIG_FILE'"
    assertEquals "Should handle quoted cache_dir" "/tmp/quoted cache" "${QI_CONFIG[cache_dir]}"
    assertEquals "Should handle single-quoted branch" "feature-branch" "${QI_CONFIG[default_branch]}"
}

test_load_config_with_comments() {
    # Create test config file with comments
    cat > "$TEST_CONFIG_FILE" << 'EOF'
# This is a comment
cache_dir=/tmp/test
# Another comment
default_branch=main
    # Indented comment
verbose=true
EOF
    
    assertTrue "Should load config ignoring comments" "load_config '$TEST_CONFIG_FILE'"
    assertEquals "Should load cache_dir" "/tmp/test" "${QI_CONFIG[cache_dir]}"
    assertEquals "Should load default_branch" "main" "${QI_CONFIG[default_branch]}"
    assertEquals "Should load verbose" "true" "${QI_CONFIG[verbose]}"
}

# Tests for configuration saving
test_save_config() {
    # Set up test config values
    QI_CONFIG[cache_dir]="/tmp/save_test"
    QI_CONFIG[default_branch]="test_branch"
    QI_CONFIG[auto_update]="false"
    QI_CONFIG[verbose]="true"
    QI_CONFIG[max_cache_size]="500M"
    
    assertTrue "Should save config file" "save_config '$TEST_CONFIG_FILE'"
    assertTrue "Config file should exist" "[[ -f '$TEST_CONFIG_FILE' ]]"
    
    # Verify content
    assertTrue "Should contain cache_dir" "grep -q 'cache_dir=/tmp/save_test' '$TEST_CONFIG_FILE'"
    assertTrue "Should contain default_branch" "grep -q 'default_branch=test_branch' '$TEST_CONFIG_FILE'"
    assertTrue "Should contain auto_update" "grep -q 'auto_update=false' '$TEST_CONFIG_FILE'"
    assertTrue "Should contain verbose" "grep -q 'verbose=true' '$TEST_CONFIG_FILE'"
    assertTrue "Should contain max_cache_size" "grep -q 'max_cache_size=500M' '$TEST_CONFIG_FILE'"
}

# Tests for configuration getters and setters
test_get_config() {
    # shellcheck disable=SC2154  # QI_CONFIG is an associative array
    QI_CONFIG[test_key]="test_value"
    
    local result
    result=$(get_config "test_key")
    assertEquals "Should return existing config value" "test_value" "$result"
    
    result=$(get_config "nonexistent_key" "default_val")
    assertEquals "Should return default for nonexistent key" "default_val" "$result"
    
    result=$(get_config "nonexistent_key")
    assertEquals "Should return empty for nonexistent key without default" "" "$result"
}

test_set_config() {
    set_config "test_setting" "test_value" false
    assertEquals "Should set config value" "test_value" "${QI_CONFIG[test_setting]}"
}

# Tests for configuration validation
test_validate_config_valid() {
    # Set up valid config
    QI_CONFIG[cache_dir]="/tmp/valid_cache"
    QI_CONFIG[default_branch]="main"
    QI_CONFIG[auto_update]="true"
    QI_CONFIG[verbose]="false"
    QI_CONFIG[max_cache_size]="1G"
    
    # Create parent directory to make it valid
    mkdir -p "/tmp"
    
    assertTrue "Should validate correct config" "validate_config"
}

test_validate_config_invalid_boolean() {
    # Set up config with invalid boolean
    QI_CONFIG[cache_dir]="/tmp/test"
    QI_CONFIG[default_branch]="main"
    QI_CONFIG[auto_update]="maybe"  # Invalid boolean
    QI_CONFIG[verbose]="yes"        # Invalid boolean
    QI_CONFIG[max_cache_size]="1G"
    
    mkdir -p "/tmp"
    
    # Should still pass but fix the values
    assertTrue "Should fix invalid boolean values" "validate_config"
    assertEquals "Should fix auto_update to false" "false" "${QI_CONFIG[auto_update]}"
    assertEquals "Should fix verbose to false" "false" "${QI_CONFIG[verbose]}"
}

test_validate_config_invalid_cache_size() {
    QI_CONFIG[cache_dir]="/tmp/test"
    QI_CONFIG[default_branch]="main"
    QI_CONFIG[auto_update]="true"
    QI_CONFIG[verbose]="false"
    QI_CONFIG[max_cache_size]="invalid_size"
    
    mkdir -p "/tmp"
    
    assertTrue "Should fix invalid cache size" "validate_config"
    assertEquals "Should fix max_cache_size to 1G" "1G" "${QI_CONFIG[max_cache_size]}"
}

# Tests for size conversion
test_size_to_bytes() {
    local result
    
    result=$(size_to_bytes "100")
    assertEquals "Should convert plain number" "100" "$result"
    
    result=$(size_to_bytes "5K")
    assertEquals "Should convert kilobytes" "5120" "$result"
    
    result=$(size_to_bytes "2M")
    assertEquals "Should convert megabytes" "2097152" "$result"
    
    result=$(size_to_bytes "1G")
    assertEquals "Should convert gigabytes" "1073741824" "$result"
}

# Tests for default config creation
test_create_default_config() {
    assertTrue "Should create default config" "create_default_config '$TEST_CONFIG_FILE'"
    assertTrue "Config file should exist" "[[ -f '$TEST_CONFIG_FILE' ]]"
    assertTrue "Should contain default values" "grep -q 'cache_dir=' '$TEST_CONFIG_FILE'"
}

test_create_default_config_existing() {
    # Create existing config file
    echo "existing=true" > "$TEST_CONFIG_FILE"
    
    assertTrue "Should handle existing config file" "create_default_config '$TEST_CONFIG_FILE'"
    assertTrue "Should preserve existing file" "grep -q 'existing=true' '$TEST_CONFIG_FILE'"
}

# Tests for configuration initialization
test_init_config() {
    # Mock required functions
    # shellcheck disable=SC2317  # Function called by test framework
    check_dependencies() { return 0; }
    
    # Set minimal required config
    QI_CONFIG[cache_dir]="/tmp/init_test"
    
    assertTrue "Should initialize config system" "init_config"
}

# Load and run shunit2
# shellcheck source=shunit2
# shellcheck disable=SC1091
. "$PROJECT_ROOT/shunit2"