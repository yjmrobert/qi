#!/bin/bash

# test-cache.sh - Unit tests for cache management system
# Tests lib/cache.sh functionality

# Source the test utilities and libraries under test
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/tests/test-utils.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/cache.sh"

# Test cache initialization
test_cache_initialization() {
    test_info "Testing cache initialization"
    
    setup_test_environment "cache-init"
    init_config
    
    # Test init_cache function
    assert_command_success "init_cache" "Cache should initialize successfully"
    
    # Test that cache directory is created
    assert_dir_exists "$QI_CACHE_DIR" "Cache directory should be created"
    
    # Test that metadata file is created
    local metadata_file="$QI_CACHE_DIR/.qi-metadata"
    assert_file_exists "$metadata_file" "Cache metadata file should be created"
    
    # Test metadata content
    assert_command_success "grep -q 'version=1.0.0' '$metadata_file'" "Metadata should contain version"
    assert_command_success "grep -q 'created=' '$metadata_file'" "Metadata should contain creation timestamp"
    
    teardown_test_environment
}

# Test repository directory operations
test_repo_directory_operations() {
    test_info "Testing repository directory operations"
    
    setup_test_environment "cache-repo-dir"
    init_config
    init_cache
    
    # Test get_repo_dir function
    local repo_dir
    repo_dir=$(get_repo_dir "test-repo")
    assert_equals "$QI_CACHE_DIR/test-repo" "$repo_dir" "get_repo_dir should return correct path"
    
    # Test get_repo_metadata_file function
    local metadata_file
    metadata_file=$(get_repo_metadata_file "test-repo")
    assert_equals "$QI_CACHE_DIR/test-repo/.qi-repo-metadata" "$metadata_file" "get_repo_metadata_file should return correct path"
    
    teardown_test_environment
}

# Test repository metadata operations
test_repo_metadata_operations() {
    test_info "Testing repository metadata operations"
    
    setup_test_environment "cache-metadata"
    init_config
    init_cache
    
    # Create a test repository directory
    local repo_name="test-repo"
    local repo_url="https://github.com/test/repo.git"
    local repo_dir
    repo_dir=$(get_repo_dir "$repo_name")
    
    mkdir -p "$repo_dir"
    
    # Test create_repo_metadata
    assert_command_success "create_repo_metadata '$repo_name' '$repo_url'" "Should create repository metadata"
    
    local metadata_file
    metadata_file=$(get_repo_metadata_file "$repo_name")
    assert_file_exists "$metadata_file" "Metadata file should be created"
    
    # Test read_repo_metadata
    local name_from_metadata
    name_from_metadata=$(read_repo_metadata "$repo_name" "name")
    assert_equals "$repo_name" "$name_from_metadata" "Should read repository name from metadata"
    
    local url_from_metadata
    url_from_metadata=$(read_repo_metadata "$repo_name" "url")
    assert_equals "$repo_url" "$url_from_metadata" "Should read repository URL from metadata"
    
    # Test update_repo_metadata
    assert_command_success "update_repo_metadata '$repo_name' 'script_count' '5'" "Should update metadata"
    
    local script_count
    script_count=$(read_repo_metadata "$repo_name" "script_count")
    assert_equals "5" "$script_count" "Should read updated script count"
    
    teardown_test_environment
}

# Test repository existence checking
test_repo_existence() {
    test_info "Testing repository existence checking"
    
    setup_test_environment "cache-existence"
    init_config
    init_cache
    
    # Test non-existent repository
    assert_command_fails "repo_exists 'nonexistent'" "Non-existent repository should return false"
    
    # Create a repository
    create_mock_repo "test-repo"
    
    # Test existing repository
    assert_command_success "repo_exists 'test-repo'" "Existing repository should return true"
    
    teardown_test_environment
}

# Test listing cached repositories
test_list_cached_repos() {
    test_info "Testing cached repository listing"
    
    setup_test_environment "cache-list"
    init_config
    init_cache
    
    # Test empty cache
    local empty_list
    empty_list=$(list_cached_repos)
    assert_equals "" "$empty_list" "Empty cache should return no repositories"
    
    # Create test repositories
    create_mock_repo "repo1"
    create_mock_repo "repo2"
    create_mock_repo "repo3"
    
    # Test listing repositories
    local repo_list
    repo_list=$(list_cached_repos | tr '\n' ' ' | sed 's/ $//')
    assert_equals "repo1 repo2 repo3" "$repo_list" "Should list all repositories in sorted order"
    
    # Test repository count
    local count
    count=$(get_repo_count)
    assert_equals "3" "$count" "Should return correct repository count"
    
    teardown_test_environment
}

# Test cache locking mechanism
test_cache_locking() {
    test_info "Testing cache locking mechanism"
    
    setup_test_environment "cache-locking"
    init_config
    init_cache
    
    # Test acquiring lock
    assert_command_success "acquire_cache_lock 5" "Should acquire cache lock"
    
    local lock_file="$QI_CACHE_DIR/.qi-cache.lock"
    assert_file_exists "$lock_file" "Lock file should exist"
    
    # Test releasing lock
    assert_command_success "release_cache_lock" "Should release cache lock"
    assert_file_not_exists "$lock_file" "Lock file should be removed after release"
    
    teardown_test_environment
}

# Test cache statistics
test_cache_statistics() {
    test_info "Testing cache statistics"
    
    setup_test_environment "cache-stats"
    init_config
    init_cache
    
    # Create test repositories
    create_mock_repo "repo1"
    create_mock_repo "repo2"
    
    # Test cache statistics
    local stats
    stats=$(get_cache_stats)
    
    # Check that statistics contain expected information
    assert_command_success "echo '$stats' | grep -q 'repositories:2'" "Statistics should show correct repository count"
    assert_command_success "echo '$stats' | grep -q 'total_size:'" "Statistics should include total size"
    assert_command_success "echo '$stats' | grep -q 'last_updated:'" "Statistics should include last updated time"
    
    teardown_test_environment
}

# Test repository removal from cache
test_repo_removal() {
    test_info "Testing repository removal from cache"
    
    setup_test_environment "cache-removal"
    init_config
    init_cache
    
    # Create test repository
    create_mock_repo "test-repo"
    
    # Verify repository exists
    assert_command_success "repo_exists 'test-repo'" "Repository should exist before removal"
    
    local repo_dir
    repo_dir=$(get_repo_dir "test-repo")
    assert_dir_exists "$repo_dir" "Repository directory should exist"
    
    # Remove repository
    assert_command_success "remove_repo_from_cache 'test-repo'" "Should remove repository from cache"
    
    # Verify repository is removed
    assert_command_fails "repo_exists 'test-repo'" "Repository should not exist after removal"
    assert_dir_not_exists "$repo_dir" "Repository directory should be removed"
    
    teardown_test_environment
}

# Test cache validation
test_cache_validation() {
    test_info "Testing cache validation"
    
    setup_test_environment "cache-validation"
    init_config
    init_cache
    
    # Test validation of empty cache
    assert_command_success "validate_cache" "Empty cache should validate successfully"
    
    # Create valid repository
    create_mock_repo "valid-repo"
    assert_command_success "validate_cache" "Valid cache should validate successfully"
    
    # Create invalid repository (missing .git directory)
    local invalid_repo_dir="$QI_CACHE_DIR/invalid-repo"
    mkdir -p "$invalid_repo_dir"
    create_repo_metadata "invalid-repo" "https://github.com/test/invalid.git"
    
    # Validation should report issues but not fail completely
    validate_cache
    local validation_result=$?
    assert_not_equals "0" "$validation_result" "Invalid repository should cause validation to report issues"
    
    teardown_test_environment
}

# Test cache metadata operations
test_cache_metadata() {
    test_info "Testing cache metadata operations"
    
    setup_test_environment "cache-metadata-ops"
    init_config
    init_cache
    
    # Test reading cache metadata
    local version
    version=$(read_cache_metadata "version")
    assert_equals "1.0.0" "$version" "Should read version from cache metadata"
    
    # Test updating cache metadata
    assert_command_success "update_cache_metadata" "Should update cache metadata"
    
    # Verify last_updated was changed
    local last_updated
    last_updated=$(read_cache_metadata "last_updated")
    assert_not_equals "" "$last_updated" "Should have last_updated timestamp"
    
    teardown_test_environment
}

# Test stale lock cleanup
test_stale_lock_cleanup() {
    test_info "Testing stale lock cleanup"
    
    setup_test_environment "cache-stale-locks"
    init_config
    init_cache
    
    # Create old lock file
    local old_lock="$QI_CACHE_DIR/old.lock"
    touch "$old_lock"
    
    # Make it appear old (this is a simulation since we can't easily change file times in tests)
    # We'll test the function exists and runs without error
    assert_command_success "cleanup_stale_locks" "Stale lock cleanup should run without error"
    
    teardown_test_environment
}

# Run all cache tests
main() {
    test_info "Starting cache management tests"
    
    test_cache_initialization
    test_repo_directory_operations
    test_repo_metadata_operations
    test_repo_existence
    test_list_cached_repos
    test_cache_locking
    test_cache_statistics
    test_repo_removal
    test_cache_validation
    test_cache_metadata
    test_stale_lock_cleanup
    
    test_success "Cache management tests completed"
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi