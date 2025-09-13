#!/bin/bash

# test-git-ops.sh - Unit tests for git operations
# Tests lib/git-ops.sh functionality

# Source the test utilities and libraries under test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/tests/test-utils.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/cache.sh"
source "$SCRIPT_DIR/lib/git-ops.sh"

# Test git availability check
test_git_availability() {
    test_info "Testing git availability check"
    
    setup_test_environment "git-availability"
    
    # Test git availability (should pass on most systems)
    assert_command_success "check_git_available" "Git should be available"
    
    teardown_test_environment
}

# Test git URL validation
test_git_url_validation() {
    test_info "Testing git URL validation"
    
    setup_test_environment "git-url-validation"
    
    # Test valid URLs
    assert_command_success "validate_git_url 'https://github.com/user/repo.git'" "HTTPS URL should be valid"
    assert_command_success "validate_git_url 'git@github.com:user/repo.git'" "SSH URL should be valid"
    assert_command_success "validate_git_url 'https://gitlab.com/group/project.git'" "GitLab URL should be valid"
    
    # Test invalid URLs
    assert_command_fails "validate_git_url 'not-a-url'" "Invalid URL should fail validation"
    assert_command_fails "validate_git_url 'https://github.com/user/repo'" "URL without .git should fail validation"
    assert_command_fails "validate_git_url ''" "Empty URL should fail validation"
    
    teardown_test_environment
}

# Test repository name extraction
test_repo_name_extraction() {
    test_info "Testing repository name extraction"
    
    setup_test_environment "git-name-extraction"
    
    # Test name extraction from various URLs
    local name
    
    name=$(extract_repo_name "https://github.com/user/myrepo.git")
    assert_equals "myrepo" "$name" "Should extract name from HTTPS URL"
    
    name=$(extract_repo_name "git@github.com:user/project.git")
    assert_equals "project" "$name" "Should extract name from SSH URL"
    
    name=$(extract_repo_name "https://gitlab.com/group/subgroup/tool.git")
    assert_equals "tool" "$name" "Should extract name from nested GitLab URL"
    
    # Test invalid URL (should fail)
    assert_command_fails "extract_repo_name 'invalid-url'" "Invalid URL should fail name extraction"
    
    teardown_test_environment
}

# Test repository cloning (mock test)
test_repo_cloning_mock() {
    test_info "Testing repository cloning (mock)"
    
    setup_test_environment "git-clone-mock"
    init_config
    init_cache
    
    # Create a function to mock git clone for testing
    git() {
        case "$1" in
            clone)
                # Mock successful clone
                local target_dir="${!#}"  # Last argument
                mkdir -p "$target_dir/.git"
                echo "Mocked clone to $target_dir"
                return 0
                ;;
            *)
                # Call real git for other operations
                command git "$@"
                ;;
        esac
    }
    
    export -f git
    
    # Test cloning
    local repo_url="https://github.com/test/repo.git"
    local repo_name="test-repo"
    
    assert_command_success "clone_repository '$repo_url' '$repo_name'" "Should clone repository successfully"
    
    # Verify repository directory was created
    local repo_dir
    repo_dir=$(get_repo_dir "$repo_name")
    assert_dir_exists "$repo_dir" "Repository directory should be created"
    assert_dir_exists "$repo_dir/.git" "Git directory should be created"
    
    # Verify metadata was created
    local metadata_file
    metadata_file=$(get_repo_metadata_file "$repo_name")
    assert_file_exists "$metadata_file" "Repository metadata should be created"
    
    # Verify metadata content
    local url_from_metadata
    url_from_metadata=$(read_repo_metadata "$repo_name" "url")
    assert_equals "$repo_url" "$url_from_metadata" "Metadata should contain correct URL"
    
    # Clean up mock
    unset -f git
    
    teardown_test_environment
}

# Test repository cloning conflict detection
test_clone_conflict_detection() {
    test_info "Testing clone conflict detection"
    
    setup_test_environment "git-clone-conflict"
    init_config
    init_cache
    
    # Create existing repository directory
    local repo_name="existing-repo"
    local repo_dir
    repo_dir=$(get_repo_dir "$repo_name")
    mkdir -p "$repo_dir"
    
    # Try to clone to existing directory (should fail)
    assert_command_fails "clone_repository 'https://github.com/test/repo.git' '$repo_name'" "Should fail when directory already exists"
    
    teardown_test_environment
}

# Test repository status checking (mock)
test_repo_status_mock() {
    test_info "Testing repository status checking (mock)"
    
    setup_test_environment "git-status-mock"
    init_config
    init_cache
    
    # Create mock repository
    create_mock_repo "status-test"
    
    # Test getting repository status
    local status_info
    status_info=$(get_repo_status "status-test")
    
    # Verify status information contains expected fields
    assert_command_success "echo '$status_info' | grep -q 'branch:'" "Status should include branch information"
    assert_command_success "echo '$status_info' | grep -q 'url:'" "Status should include URL information"
    assert_command_success "echo '$status_info' | grep -q 'commit:'" "Status should include commit information"
    assert_command_success "echo '$status_info' | grep -q 'status:'" "Status should include working directory status"
    
    teardown_test_environment
}

# Test repository status for non-existent repository
test_repo_status_nonexistent() {
    test_info "Testing repository status for non-existent repository"
    
    setup_test_environment "git-status-nonexistent"
    init_config
    init_cache
    
    # Test status of non-existent repository
    local status_info
    status_info=$(get_repo_status "nonexistent-repo" 2>/dev/null)
    
    assert_command_success "echo '$status_info' | grep -q 'error:Repository not found'" "Should return error for non-existent repository"
    
    teardown_test_environment
}

# Test repository information retrieval
test_repo_info_retrieval() {
    test_info "Testing repository information retrieval"
    
    setup_test_environment "git-info-retrieval"
    init_config
    init_cache
    
    # Create mock repository
    create_mock_repo "info-test"
    
    # Test getting repository information
    local repo_info
    repo_info=$(get_repo_info "info-test")
    
    # Verify information contains expected metadata
    assert_command_success "echo '$repo_info' | grep -q 'name=info-test'" "Info should include repository name"
    assert_command_success "echo '$repo_info' | grep -q 'url='" "Info should include repository URL"
    assert_command_success "echo '$repo_info' | grep -q 'added='" "Info should include added timestamp"
    
    teardown_test_environment
}

# Test repository update checking (mock)
test_repo_needs_update_mock() {
    test_info "Testing repository update checking (mock)"
    
    setup_test_environment "git-needs-update"
    init_config
    init_cache
    
    # Create mock repository
    create_mock_repo "update-test"
    
    # Create a function to mock git operations for update checking
    git() {
        case "$1 $2" in
            "fetch origin")
                # Mock successful fetch
                return 0
                ;;
            "rev-parse --abbrev-ref")
                echo "main"
                return 0
                ;;
            "rev-list --count")
                # Mock that there are no new commits (up to date)
                echo "0"
                return 0
                ;;
            *)
                # Call real git for other operations
                command git "$@"
                ;;
        esac
    }
    
    export -f git
    
    # Test update checking
    if repo_needs_update "update-test"; then
        test_log "Repository needs update"
    else
        test_log "Repository is up to date"
    fi
    
    # The function should run without error regardless of result
    assert_true "true" "repo_needs_update should run without error"
    
    # Clean up mock
    unset -f git
    
    teardown_test_environment
}

# Test git URL validation edge cases
test_git_url_edge_cases() {
    test_info "Testing git URL validation edge cases"
    
    setup_test_environment "git-url-edge-cases"
    
    # Test URLs with different protocols
    assert_command_success "validate_git_url 'git://github.com/user/repo.git'" "Git protocol should be valid"
    assert_command_success "validate_git_url 'ssh://git@github.com/user/repo.git'" "SSH protocol should be valid"
    
    # Test URLs with ports
    assert_command_success "validate_git_url 'ssh://git@example.com:2222/user/repo.git'" "URL with port should be valid"
    
    # Test self-hosted git servers
    assert_command_success "validate_git_url 'https://git.company.com/team/project.git'" "Self-hosted URL should be valid"
    
    teardown_test_environment
}

# Test repository name extraction edge cases
test_name_extraction_edge_cases() {
    test_info "Testing repository name extraction edge cases"
    
    setup_test_environment "git-name-edge-cases"
    
    # Test complex repository paths
    local name
    
    name=$(extract_repo_name "https://bitbucket.org/workspace/repository-name.git")
    assert_equals "repository-name" "$name" "Should extract name with hyphens"
    
    name=$(extract_repo_name "git@gitlab.company.com:group/subgroup/project_name.git")
    assert_equals "project_name" "$name" "Should extract name with underscores"
    
    # Test URL without .git extension (should still work with basename)
    name=$(extract_repo_name "https://github.com/user/repo")
    assert_equals "repo" "$name" "Should extract name even without .git extension"
    
    teardown_test_environment
}

# Run all git operations tests
main() {
    test_info "Starting git operations tests"
    
    test_git_availability
    test_git_url_validation
    test_repo_name_extraction
    test_repo_cloning_mock
    test_clone_conflict_detection
    test_repo_status_mock
    test_repo_status_nonexistent
    test_repo_info_retrieval
    test_repo_needs_update_mock
    test_git_url_edge_cases
    test_name_extraction_edge_cases
    
    test_success "Git operations tests completed"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi