#!/bin/bash

# test-integration.sh - Integration tests for qi
# Tests the complete qi workflow end-to-end

# Source the test utilities and all libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/tests/test-utils.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/cache.sh"
source "$SCRIPT_DIR/lib/git-ops.sh"
source "$SCRIPT_DIR/lib/script-ops.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/commands.sh"

# Test complete qi initialization
test_qi_initialization() {
    test_info "Testing complete qi initialization"
    
    setup_test_environment "qi-init"
    
    # Test full initialization sequence
    assert_command_success "init_config" "Configuration should initialize"
    assert_command_success "init_cache" "Cache should initialize"
    assert_command_success "init_commands" "Commands should initialize"
    
    # Verify all components are properly set up
    assert_dir_exists "$QI_CACHE_DIR" "Cache directory should exist"
    assert_file_exists "$QI_CACHE_DIR/.qi-metadata" "Cache metadata should exist"
    
    teardown_test_environment
}

# Test complete add repository workflow
test_add_repository_workflow() {
    test_info "Testing complete add repository workflow"
    
    setup_test_environment "add-workflow"
    init_config
    init_cache
    init_commands
    
    # Mock git clone for testing
    git() {
        case "$1" in
            clone)
                local target_dir="${!#}"
                mkdir -p "$target_dir/.git"
                
                # Create test scripts in the mock repository
                mkdir -p "$target_dir/scripts"
                cat > "$target_dir/scripts/deploy.bash" << 'EOF'
#!/bin/bash
echo "Deploying application"
EOF
                chmod +x "$target_dir/scripts/deploy.bash"
                
                cat > "$target_dir/backup.bash" << 'EOF'
#!/bin/bash
echo "Creating backup"
EOF
                chmod +x "$target_dir/backup.bash"
                
                return 0
                ;;
            *)
                command git "$@"
                ;;
        esac
    }
    export -f git
    
    # Test adding repository
    local repo_url="https://github.com/test/scripts.git"
    local repo_name="test-scripts"
    
    assert_command_success "add_repository '$repo_url' '$repo_name'" "Should add repository successfully"
    
    # Verify repository was added
    assert_command_success "repo_exists '$repo_name'" "Repository should exist in cache"
    
    # Verify metadata was created
    local url_from_metadata
    url_from_metadata=$(read_repo_metadata "$repo_name" "url")
    assert_equals "$repo_url" "$url_from_metadata" "Metadata should contain correct URL"
    
    # Verify scripts were discovered
    local script_count
    script_count=$(read_repo_metadata "$repo_name" "script_count")
    assert_equals "2" "$script_count" "Should discover 2 scripts"
    
    # Clean up mock
    unset -f git
    
    teardown_test_environment
}

# Test repository conflict detection
test_add_repository_conflict() {
    test_info "Testing add repository conflict detection"
    
    setup_test_environment "add-conflict"
    init_config
    init_cache
    init_commands
    
    # Create existing repository
    create_mock_repo "existing-repo"
    
    # Try to add repository with same name (should fail)
    assert_command_fails "add_repository 'https://github.com/test/other.git' 'existing-repo'" "Should fail when repository name already exists"
    
    teardown_test_environment
}

# Test complete remove repository workflow
test_remove_repository_workflow() {
    test_info "Testing complete remove repository workflow"
    
    setup_test_environment "remove-workflow"
    init_config
    init_cache
    init_commands
    
    # Create test repository
    create_mock_repo "remove-test"
    
    # Verify repository exists
    assert_command_success "repo_exists 'remove-test'" "Repository should exist before removal"
    
    # Mock user confirmation (force mode)
    export QI_FORCE="true"
    
    # Test removing repository
    assert_command_success "remove_repository 'remove-test'" "Should remove repository successfully"
    
    # Verify repository was removed
    assert_command_fails "repo_exists 'remove-test'" "Repository should not exist after removal"
    
    local repo_dir
    repo_dir=$(get_repo_dir "remove-test")
    assert_dir_not_exists "$repo_dir" "Repository directory should be removed"
    
    # Clean up
    unset QI_FORCE
    
    teardown_test_environment
}

# Test script execution workflow
test_script_execution_workflow() {
    test_info "Testing script execution workflow"
    
    setup_test_environment "execution-workflow"
    init_config
    init_cache
    init_commands
    
    # Create repository with test script
    create_mock_repo "exec-test"
    
    local repo_dir
    repo_dir=$(get_repo_dir "exec-test")
    
    # Create a test script that outputs specific text
    cat > "$repo_dir/hello.bash" << 'EOF'
#!/bin/bash
echo "Hello from qi script: $@"
EOF
    chmod +x "$repo_dir/hello.bash"
    
    # Update script count
    update_script_count "exec-test"
    
    # Test script execution
    local output
    output=$(execute_script "hello" "world" "test" 2>&1)
    
    assert_command_success "echo '$output' | grep -q 'Hello from qi script: world test'" "Script should execute with correct arguments"
    
    teardown_test_environment
}

# Test script conflict resolution workflow
test_script_conflict_workflow() {
    test_info "Testing script conflict resolution workflow"
    
    setup_test_environment "conflict-workflow"
    init_config
    init_cache
    init_commands
    
    # Create multiple repositories with same script name
    create_mock_repo "repo1"
    create_mock_repo "repo2"
    
    # Both repositories already have 'deploy' script from create_mock_repo
    # Test finding conflicting scripts
    local matching_scripts
    matching_scripts=$(find_scripts_by_name "deploy")
    
    local script_count
    script_count=$(echo "$matching_scripts" | wc -l)
    assert_equals "2" "$script_count" "Should find deploy script in both repositories"
    
    teardown_test_environment
}

# Test update repository workflow
test_update_repository_workflow() {
    test_info "Testing update repository workflow"
    
    setup_test_environment "update-workflow"
    init_config
    init_cache
    init_commands
    
    # Create mock repository
    create_mock_repo "update-test"
    
    # Mock git operations for update
    git() {
        case "$1 $2" in
            "diff --quiet"|"diff --cached")
                # Mock clean working directory
                return 0
                ;;
            "fetch origin"|"pull origin")
                # Mock successful update
                return 0
                ;;
            "rev-parse --abbrev-ref")
                echo "main"
                return 0
                ;;
            "remote get-url")
                echo "https://github.com/test/update-test.git"
                return 0
                ;;
            *)
                command git "$@"
                ;;
        esac
    }
    export -f git
    
    # Test updating repository
    assert_command_success "update_repository 'update-test'" "Should update repository successfully"
    
    # Verify metadata was updated
    local last_updated
    last_updated=$(read_repo_metadata "update-test" "last_updated")
    assert_not_equals "" "$last_updated" "Should have updated timestamp"
    
    # Clean up mock
    unset -f git
    
    teardown_test_environment
}

# Test update all repositories workflow
test_update_all_workflow() {
    test_info "Testing update all repositories workflow"
    
    setup_test_environment "update-all-workflow"
    init_config
    init_cache
    init_commands
    
    # Create multiple repositories
    create_mock_repo "repo1"
    create_mock_repo "repo2"
    
    # Mock git operations
    git() {
        case "$1 $2" in
            "diff --quiet"|"diff --cached")
                return 0
                ;;
            "fetch origin"|"pull origin")
                return 0
                ;;
            "rev-parse --abbrev-ref")
                echo "main"
                return 0
                ;;
            "remote get-url")
                echo "https://github.com/test/repo.git"
                return 0
                ;;
            *)
                command git "$@"
                ;;
        esac
    }
    export -f git
    
    # Test updating all repositories
    assert_command_success "update_all_repositories" "Should update all repositories successfully"
    
    # Clean up mock
    unset -f git
    
    teardown_test_environment
}

# Test complete qi workflow (add -> list -> execute -> remove)
test_complete_qi_workflow() {
    test_info "Testing complete qi workflow"
    
    setup_test_environment "complete-workflow"
    init_config
    init_cache
    init_commands
    
    # Mock git clone
    git() {
        case "$1" in
            clone)
                local target_dir="${!#}"
                mkdir -p "$target_dir/.git"
                
                cat > "$target_dir/workflow-test.bash" << 'EOF'
#!/bin/bash
echo "Workflow test script executed successfully"
EOF
                chmod +x "$target_dir/workflow-test.bash"
                return 0
                ;;
            "diff --quiet"|"diff --cached")
                return 0
                ;;
            "fetch origin"|"pull origin")
                return 0
                ;;
            "rev-parse --abbrev-ref")
                echo "main"
                return 0
                ;;
            "remote get-url")
                echo "https://github.com/test/workflow.git"
                return 0
                ;;
            *)
                command git "$@"
                ;;
        esac
    }
    export -f git
    
    local repo_url="https://github.com/test/workflow.git"
    local repo_name="workflow-test"
    
    # Step 1: Add repository
    assert_command_success "add_repository '$repo_url' '$repo_name'" "Step 1: Should add repository"
    
    # Step 2: Verify repository exists
    assert_command_success "repo_exists '$repo_name'" "Step 2: Repository should exist"
    
    # Step 3: List scripts (should find the workflow-test script)
    local scripts
    scripts=$(find_repo_scripts "$repo_name")
    assert_command_success "echo '$scripts' | grep -q 'workflow-test'" "Step 3: Should find workflow-test script"
    
    # Step 4: Execute script
    local output
    output=$(execute_script "workflow-test" 2>&1)
    assert_command_success "echo '$output' | grep -q 'Workflow test script executed successfully'" "Step 4: Should execute script successfully"
    
    # Step 5: Update repository
    assert_command_success "update_repository '$repo_name'" "Step 5: Should update repository"
    
    # Step 6: Remove repository (with force to skip confirmation)
    export QI_FORCE="true"
    assert_command_success "remove_repository '$repo_name'" "Step 6: Should remove repository"
    
    # Step 7: Verify repository was removed
    assert_command_fails "repo_exists '$repo_name'" "Step 7: Repository should be removed"
    
    # Clean up
    unset -f git
    unset QI_FORCE
    
    teardown_test_environment
}

# Test error handling in workflows
test_error_handling() {
    test_info "Testing error handling in workflows"
    
    setup_test_environment "error-handling"
    init_config
    init_cache
    init_commands
    
    # Test adding repository with invalid URL
    assert_command_fails "add_repository 'invalid-url' 'test'" "Should fail with invalid URL"
    
    # Test removing non-existent repository
    assert_command_fails "remove_repository 'nonexistent'" "Should fail for non-existent repository"
    
    # Test updating non-existent repository
    assert_command_fails "update_repository 'nonexistent'" "Should fail for non-existent repository"
    
    # Test executing non-existent script
    assert_command_fails "execute_script 'nonexistent'" "Should fail for non-existent script"
    
    teardown_test_environment
}

# Test dry-run mode across workflows
test_dry_run_workflows() {
    test_info "Testing dry-run mode across workflows"
    
    setup_test_environment "dry-run-workflows"
    init_config
    init_cache
    init_commands
    
    # Enable dry-run mode
    export QI_DRY_RUN="true"
    
    # Create test repository
    create_mock_repo "dry-run-test"
    
    # Test script execution in dry-run mode
    local output
    output=$(execute_script "deploy" 2>&1)
    assert_command_success "echo '$output' | grep -q 'DRY RUN'" "Should show dry-run message for script execution"
    
    # Clean up
    unset QI_DRY_RUN
    
    teardown_test_environment
}

# Run all integration tests
main() {
    test_info "Starting integration tests"
    
    test_qi_initialization
    test_add_repository_workflow
    test_add_repository_conflict
    test_remove_repository_workflow
    test_script_execution_workflow
    test_script_conflict_workflow
    test_update_repository_workflow
    test_update_all_workflow
    test_complete_qi_workflow
    test_error_handling
    test_dry_run_workflows
    
    test_success "Integration tests completed"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi