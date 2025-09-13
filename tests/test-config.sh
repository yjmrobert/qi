#!/bin/bash

# test-config.sh - Unit tests for configuration system
# Tests lib/config.sh functionality

# Source the test utilities and library under test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/tests/test-utils.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Test configuration initialization
test_config_initialization() {
    test_info "Testing configuration initialization"
    
    setup_test_environment "config-init"
    
    # Test init_config function
    assert_command_success "init_config" "Configuration should initialize successfully"
    
    # Test that cache directory is created
    assert_dir_exists "$QI_CACHE_DIR" "Cache directory should be created"
    
    # Test default values
    assert_equals "$TEST_CACHE_DIR" "$(get_config cache_dir)" "Cache directory should match test environment"
    assert_equals "main" "$(get_config default_branch)" "Default branch should be 'main'"
    assert_equals "false" "$(get_config auto_update)" "Auto update should be false by default"
    
    teardown_test_environment
}

# Test environment variable configuration
test_environment_variables() {
    test_info "Testing environment variable configuration"
    
    setup_test_environment "config-env"
    
    # Set environment variables
    export QI_DEFAULT_BRANCH="develop"
    export QI_AUTO_UPDATE="true"
    
    # Initialize configuration
    init_config
    
    # Test that environment variables override defaults
    assert_equals "develop" "$(get_config default_branch)" "Environment variable should override default branch"
    
    # Clean up
    unset QI_DEFAULT_BRANCH QI_AUTO_UPDATE
    teardown_test_environment
}

# Test configuration file parsing
test_config_file_parsing() {
    test_info "Testing configuration file parsing"
    
    setup_test_environment "config-file"
    
    # Create test configuration file
    cat > "$QI_CONFIG_FILE" << EOF
# Test configuration
cache_dir=/tmp/test-cache
default_branch=develop
auto_update=true
verbose=false
EOF
    
    # Initialize configuration
    init_config
    
    # Test that config file values are loaded
    assert_equals "/tmp/test-cache" "$(get_config cache_dir)" "Config file should set cache directory"
    assert_equals "develop" "$(get_config default_branch)" "Config file should set default branch"
    assert_equals "true" "$(get_config auto_update)" "Config file should set auto update"
    
    teardown_test_environment
}

# Test configuration validation
test_config_validation() {
    test_info "Testing configuration validation"
    
    setup_test_environment "config-validation"
    
    # Test valid configuration
    QI_CACHE_DIR="$TEST_CACHE_DIR"
    QI_DEFAULT_BRANCH="main"
    QI_AUTO_UPDATE="true"
    QI_VERBOSE="false"
    
    assert_command_success "validate_config" "Valid configuration should pass validation"
    
    # Test invalid auto_update value
    QI_AUTO_UPDATE="invalid"
    assert_command_fails "validate_config" "Invalid auto_update value should fail validation"
    
    # Test empty default branch
    QI_AUTO_UPDATE="true"
    QI_DEFAULT_BRANCH=""
    assert_command_fails "validate_config" "Empty default branch should fail validation"
    
    teardown_test_environment
}

# Test configuration priority (env vars override config file)
test_config_priority() {
    test_info "Testing configuration priority"
    
    setup_test_environment "config-priority"
    
    # Create config file
    cat > "$QI_CONFIG_FILE" << EOF
default_branch=main
auto_update=false
EOF
    
    # Set environment variable
    export QI_DEFAULT_BRANCH="develop"
    
    # Initialize configuration
    init_config
    
    # Environment variable should override config file
    assert_equals "develop" "$(get_config default_branch)" "Environment variable should override config file"
    assert_equals "false" "$(get_config auto_update)" "Config file value should be used when no env var"
    
    # Clean up
    unset QI_DEFAULT_BRANCH
    teardown_test_environment
}

# Test tilde expansion in paths
test_tilde_expansion() {
    test_info "Testing tilde expansion in paths"
    
    setup_test_environment "config-tilde"
    
    # Set cache directory with tilde
    QI_CACHE_DIR="~/test-cache"
    
    # Validate configuration (should expand tilde)
    validate_config
    
    # Check that tilde was expanded
    assert_not_equals "~/test-cache" "$QI_CACHE_DIR" "Tilde should be expanded"
    assert_equals "$HOME/test-cache" "$QI_CACHE_DIR" "Tilde should expand to home directory"
    
    teardown_test_environment
}

# Test get_config and set_config functions
test_config_getters_setters() {
    test_info "Testing configuration getters and setters"
    
    setup_test_environment "config-getset"
    
    init_config
    
    # Test getting existing values
    local cache_dir
    cache_dir=$(get_config cache_dir)
    assert_equals "$TEST_CACHE_DIR" "$cache_dir" "get_config should return correct cache directory"
    
    # Test setting values
    set_config default_branch "feature"
    assert_equals "feature" "$(get_config default_branch)" "set_config should update default branch"
    
    # Test invalid key
    assert_command_fails "get_config invalid_key" "get_config should fail for invalid key"
    assert_command_fails "set_config invalid_key value" "set_config should fail for invalid key"
    
    teardown_test_environment
}

# Test configuration file creation
test_config_file_creation() {
    test_info "Testing configuration file creation"
    
    setup_test_environment "config-create"
    
    # Ensure config file doesn't exist
    rm -f "$QI_CONFIG_FILE"
    assert_file_not_exists "$QI_CONFIG_FILE" "Config file should not exist initially"
    
    # Create default config
    create_default_config
    
    # Check that file was created
    assert_file_exists "$QI_CONFIG_FILE" "Config file should be created"
    
    # Check that file contains expected content
    assert_command_success "grep -q 'cache_dir=' '$QI_CONFIG_FILE'" "Config file should contain cache_dir setting"
    assert_command_success "grep -q 'default_branch=' '$QI_CONFIG_FILE'" "Config file should contain default_branch setting"
    
    teardown_test_environment
}

# Test malformed configuration file handling
test_malformed_config_file() {
    test_info "Testing malformed configuration file handling"
    
    setup_test_environment "config-malformed"
    
    # Create malformed config file
    cat > "$QI_CONFIG_FILE" << EOF
# Valid comment
cache_dir=/tmp/test
invalid line without equals
default_branch=main
=value_without_key
another_invalid_line
EOF
    
    # Configuration should still work despite malformed lines
    assert_command_success "init_config" "Configuration should handle malformed lines gracefully"
    
    # Valid settings should still be loaded
    assert_equals "/tmp/test" "$(get_config cache_dir)" "Valid settings should be loaded despite malformed lines"
    assert_equals "main" "$(get_config default_branch)" "Valid settings should be loaded despite malformed lines"
    
    teardown_test_environment
}

# Run all configuration tests
main() {
    test_info "Starting configuration tests"
    
    test_config_initialization
    test_environment_variables
    test_config_file_parsing
    test_config_validation
    test_config_priority
    test_tilde_expansion
    test_config_getters_setters
    test_config_file_creation
    test_malformed_config_file
    
    test_success "Configuration tests completed"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi