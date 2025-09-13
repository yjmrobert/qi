#!/bin/bash

# test-script-ops.sh - Unit tests for script operations
# Tests lib/script-ops.sh functionality

# Source the test utilities and libraries under test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/tests/test-utils.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/cache.sh"
source "$SCRIPT_DIR/lib/script-ops.sh"

# Test script discovery in repository
test_script_discovery() {
    test_info "Testing script discovery in repository"
    
    setup_test_environment "script-discovery"
    init_config
    init_cache
    
    # Create mock repository with scripts
    create_mock_repo "script-test"
    
    # Test finding scripts in repository
    local scripts
    scripts=$(find_repo_scripts "script-test")
    
    # Verify scripts were found
    assert_command_success "echo '$scripts' | grep -q 'deploy:scripts/deploy.bash:script-test'" "Should find deploy script"
    assert_command_success "echo '$scripts' | grep -q 'backup:tools/backup.bash:script-test'" "Should find backup script"
    assert_command_success "echo '$scripts' | grep -q 'test-script:test-script.bash:script-test'" "Should find test-script"
    
    teardown_test_environment
}

# Test script discovery across all repositories
test_all_script_discovery() {
    test_info "Testing script discovery across all repositories"
    
    setup_test_environment "all-script-discovery"
    init_config
    init_cache
    
    # Create multiple mock repositories
    create_mock_repo "repo1"
    create_mock_repo "repo2"
    
    # Test finding all scripts
    local all_scripts
    all_scripts=$(find_all_scripts)
    
    # Should find scripts from both repositories
    assert_command_success "echo '$all_scripts' | grep -q 'repo1'" "Should find scripts from repo1"
    assert_command_success "echo '$all_scripts' | grep -q 'repo2'" "Should find scripts from repo2"
    
    # Count total scripts (should be 6: 3 from each repo)
    local script_count
    script_count=$(echo "$all_scripts" | wc -l)
    assert_equals "6" "$script_count" "Should find 6 total scripts"
    
    teardown_test_environment
}

# Test finding scripts by name
test_find_scripts_by_name() {
    test_info "Testing finding scripts by name"
    
    setup_test_environment "find-by-name"
    init_config
    init_cache
    
    # Create repositories with duplicate script names
    create_mock_repo "repo1"
    create_mock_repo "repo2"
    
    # Test finding specific script name
    local deploy_scripts
    deploy_scripts=$(find_scripts_by_name "deploy")
    
    # Should find deploy script from both repositories
    local deploy_count
    deploy_count=$(echo "$deploy_scripts" | wc -l)
    assert_equals "2" "$deploy_count" "Should find deploy script in both repositories"
    
    # Test finding unique script name
    local backup_scripts
    backup_scripts=$(find_scripts_by_name "backup")
    
    local backup_count
    backup_count=$(echo "$backup_scripts" | wc -l)
    assert_equals "2" "$backup_count" "Should find backup script in both repositories"
    
    # Test finding non-existent script
    local nonexistent_scripts
    nonexistent_scripts=$(find_scripts_by_name "nonexistent")
    assert_equals "" "$nonexistent_scripts" "Should not find non-existent script"
    
    teardown_test_environment
}

# Test script count functionality
test_script_count() {
    test_info "Testing script count functionality"
    
    setup_test_environment "script-count"
    init_config
    init_cache
    
    # Create mock repository
    create_mock_repo "count-test"
    
    # Test getting script count
    local count
    count=$(get_repo_script_count "count-test")
    assert_equals "3" "$count" "Should count 3 scripts in repository"
    
    # Test updating script count in metadata
    assert_command_success "update_script_count 'count-test'" "Should update script count in metadata"
    
    # Verify metadata was updated
    local metadata_count
    metadata_count=$(read_repo_metadata "count-test" "script_count")
    assert_equals "3" "$metadata_count" "Metadata should contain correct script count"
    
    teardown_test_environment
}

# Test script file validation
test_script_validation() {
    test_info "Testing script file validation"
    
    setup_test_environment "script-validation"
    init_config
    init_cache
    
    # Create test script file
    local test_script="$TEST_DIR/test.bash"
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "Test script"
EOF
    
    # Test validation of readable script
    chmod +r "$test_script"
    assert_command_success "validate_script_file '$test_script'" "Should validate readable script"
    
    # Script should be made executable
    assert_true "$(if [[ -x '$test_script' ]]; then echo 'true'; else echo 'false'; fi)" "Script should be made executable"
    
    # Test validation of non-existent script
    assert_command_fails "validate_script_file '/nonexistent/script.bash'" "Should fail for non-existent script"
    
    teardown_test_environment
}

# Test script execution
test_script_execution() {
    test_info "Testing script execution"
    
    setup_test_environment "script-execution"
    init_config
    init_cache
    
    # Create test script
    local test_script="$TEST_DIR/executable.bash"
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "Script executed with args: $@"
exit 0
EOF
    chmod +x "$test_script"
    
    # Test script execution (capture output)
    local output
    output=$(execute_script_file "$test_script" "arg1" "arg2" 2>&1)
    
    assert_command_success "echo '$output' | grep -q 'Script executed with args: arg1 arg2'" "Script should execute with correct arguments"
    
    teardown_test_environment
}

# Test dry-run mode for script execution
test_dry_run_execution() {
    test_info "Testing dry-run mode for script execution"
    
    setup_test_environment "dry-run-execution"
    init_config
    init_cache
    
    # Set dry-run mode
    export QI_DRY_RUN="true"
    
    # Create test script
    local test_script="$TEST_DIR/dryrun.bash"
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "This should not execute in dry-run mode"
EOF
    chmod +x "$test_script"
    
    # Test dry-run execution
    local output
    output=$(execute_script_file "$test_script" 2>&1)
    
    assert_command_success "echo '$output' | grep -q 'DRY RUN'" "Should show dry-run message"
    assert_command_fails "echo '$output' | grep -q 'This should not execute'" "Should not actually execute script"
    
    # Clean up
    unset QI_DRY_RUN
    
    teardown_test_environment
}

# Test script execution by name (single match)
test_execute_by_name_single() {
    test_info "Testing script execution by name (single match)"
    
    setup_test_environment "execute-single"
    init_config
    init_cache
    
    # Create repository with unique script
    create_mock_repo "single-repo"
    
    # Add a unique script
    local repo_dir
    repo_dir=$(get_repo_dir "single-repo")
    cat > "$repo_dir/unique.bash" << 'EOF'
#!/bin/bash
echo "Unique script executed"
EOF
    chmod +x "$repo_dir/unique.bash"
    
    # Test execution by name (should execute directly)
    local output
    output=$(execute_script_by_name "unique" 2>&1)
    
    assert_command_success "echo '$output' | grep -q 'Found script.*unique.*in repository.*single-repo'" "Should find and identify unique script"
    
    teardown_test_environment
}

# Test script listing functionality
test_script_listing() {
    test_info "Testing script listing functionality"
    
    setup_test_environment "script-listing"
    init_config
    init_cache
    
    # Create repositories with scripts
    create_mock_repo "list-repo1"
    create_mock_repo "list-repo2"
    
    # Test listing all scripts
    local output
    output=$(list_all_scripts 2>&1)
    
    assert_command_success "echo '$output' | grep -q 'Available Scripts:'" "Should show script listing header"
    assert_command_success "echo '$output' | grep -q 'deploy'" "Should list deploy script"
    assert_command_success "echo '$output' | grep -q 'backup'" "Should list backup script"
    assert_command_success "echo '$output' | grep -q 'Total:'" "Should show total count"
    
    teardown_test_environment
}

# Test listing scripts for specific repository
test_repo_script_listing() {
    test_info "Testing repository-specific script listing"
    
    setup_test_environment "repo-script-listing"
    init_config
    init_cache
    
    # Create mock repository
    create_mock_repo "list-test"
    
    # Test listing scripts for specific repository
    local output
    output=$(list_repo_scripts "list-test" 2>&1)
    
    assert_command_success "echo '$output' | grep -q 'Scripts in repository.*list-test'" "Should show repository-specific header"
    assert_command_success "echo '$output' | grep -q 'deploy'" "Should list deploy script"
    assert_command_success "echo '$output' | grep -q 'Total: 3 script'" "Should show correct count"
    
    # Test listing for non-existent repository
    assert_command_fails "list_repo_scripts 'nonexistent'" "Should fail for non-existent repository"
    
    teardown_test_environment
}

# Test script name validation
test_script_name_validation() {
    test_info "Testing script name validation"
    
    setup_test_environment "script-name-validation"
    init_config
    init_cache
    
    # Test valid script names
    assert_command_success "validate_name 'valid-script'" "Should accept valid script name with hyphens"
    assert_command_success "validate_name 'valid_script'" "Should accept valid script name with underscores"
    assert_command_success "validate_name 'validScript123'" "Should accept valid script name with numbers"
    
    # Test invalid script names
    assert_command_fails "validate_name 'invalid script'" "Should reject script name with spaces"
    assert_command_fails "validate_name 'invalid@script'" "Should reject script name with special characters"
    assert_command_fails "validate_name ''" "Should reject empty script name"
    
    teardown_test_environment
}

# Test empty repository script discovery
test_empty_repo_scripts() {
    test_info "Testing script discovery in empty repository"
    
    setup_test_environment "empty-repo-scripts"
    init_config
    init_cache
    
    # Create empty repository
    local repo_name="empty-repo"
    local repo_dir
    repo_dir=$(get_repo_dir "$repo_name")
    mkdir -p "$repo_dir/.git"
    create_repo_metadata "$repo_name" "https://github.com/test/empty.git"
    
    # Test finding scripts in empty repository
    local scripts
    scripts=$(find_repo_scripts "$repo_name")
    assert_equals "" "$scripts" "Should find no scripts in empty repository"
    
    # Test script count
    local count
    count=$(get_repo_script_count "$repo_name")
    assert_equals "0" "$count" "Should count 0 scripts in empty repository"
    
    teardown_test_environment
}

# Run all script operations tests
main() {
    test_info "Starting script operations tests"
    
    test_script_discovery
    test_all_script_discovery
    test_find_scripts_by_name
    test_script_count
    test_script_validation
    test_script_execution
    test_dry_run_execution
    test_execute_by_name_single
    test_script_listing
    test_repo_script_listing
    test_script_name_validation
    test_empty_repo_scripts
    
    test_success "Script operations tests completed"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi