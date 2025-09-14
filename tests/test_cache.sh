#!/bin/bash

# test_cache.sh - Unit tests for lib/cache.sh using shunit2
# Tests cache management functionality

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
. "$LIB_DIR/utils.sh"
. "$LIB_DIR/config.sh"
. "$LIB_DIR/cache.sh"

# Test fixtures and setup
setUp() {
    # Create temporary directory for tests
    TEST_TEMP_DIR=$(mktemp -d -t qi_cache_test.XXXXXX)
    export TEST_TEMP_DIR
    
    # Set up test cache directory
    TEST_CACHE_DIR="$TEST_TEMP_DIR/cache"
    export CACHE_DIR="$TEST_CACHE_DIR"
    
    # Mock log function to avoid output during tests
    log() {
        return 0
    }
    
    # Mock get_config function
    get_config() {
        case "$1" in
            "default_branch") echo "main" ;;
            *) echo "$2" ;;
        esac
    }
    
    # Mock get_timestamp function
    get_timestamp() {
        echo "2023-01-01T00:00:00Z"
    }
}

tearDown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Tests for cache initialization
test_init_cache() {
    assertTrue "Should initialize cache directory" "init_cache '$TEST_CACHE_DIR'"
    assertTrue "Cache directory should exist" "[[ -d '$TEST_CACHE_DIR' ]]"
    assertTrue "Meta directory should exist" "[[ -d '$TEST_CACHE_DIR/.qi-meta' ]]"
}

test_init_cache_existing() {
    # Create existing cache directory
    mkdir -p "$TEST_CACHE_DIR"
    
    assertTrue "Should handle existing cache directory" "init_cache '$TEST_CACHE_DIR'"
    assertTrue "Cache directory should still exist" "[[ -d '$TEST_CACHE_DIR' ]]"
}

test_init_cache_readonly() {
    # Create readonly parent directory
    local readonly_parent="$TEST_TEMP_DIR/readonly"
    mkdir -p "$readonly_parent"
    chmod 444 "$readonly_parent"
    
    local readonly_cache="$readonly_parent/cache"
    assertFalse "Should fail on readonly parent" "init_cache '$readonly_cache'"
    
    # Clean up
    chmod 755 "$readonly_parent"
}

# Tests for repository directory paths
test_get_repo_dir() {
    local result
    result=$(get_repo_dir "test-repo" "$TEST_CACHE_DIR")
    assertEquals "Should return correct repo directory path" "$TEST_CACHE_DIR/test-repo" "$result"
}

test_get_repo_metadata_file() {
    local result
    result=$(get_repo_metadata_file "test-repo" "$TEST_CACHE_DIR")
    assertEquals "Should return correct metadata file path" "$TEST_CACHE_DIR/test-repo/.qi-repo-meta" "$result"
}

# Tests for repository metadata
test_create_repo_metadata() {
    local repo_name="test-repo"
    local repo_url="https://github.com/user/test-repo.git"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create repo directory
    mkdir -p "$repo_dir"
    
    assertTrue "Should create repository metadata" "create_repo_metadata '$repo_name' '$repo_url' '$repo_dir' ''"
    
    local metadata_file="$repo_dir/.qi-repo-meta"
    assertTrue "Metadata file should exist" "[[ -f '$metadata_file' ]]"
    assertTrue "Should contain name" "grep -q 'name=$repo_name' '$metadata_file'"
    assertTrue "Should contain URL" "grep -q 'url=$repo_url' '$metadata_file'"
    assertTrue "Should contain directory" "grep -q 'directory=$repo_dir' '$metadata_file'"
}

test_read_repo_metadata() {
    local repo_name="test-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    local metadata_file="$repo_dir/.qi-repo-meta"
    
    # Create repo directory and metadata
    mkdir -p "$repo_dir"
    cat > "$metadata_file" << 'EOF'
name=test-repo
url=https://github.com/user/test-repo.git
directory=/path/to/repo
status=active
EOF
    
    local result
    result=$(read_repo_metadata "$repo_name" "name")
    assertEquals "Should read specific metadata key" "test-repo" "$result"
    
    result=$(read_repo_metadata "$repo_name" "url")
    assertEquals "Should read URL" "https://github.com/user/test-repo.git" "$result"
    
    # Test reading all metadata
    local all_metadata
    all_metadata=$(read_repo_metadata "$repo_name")
    assertTrue "Should read all metadata" "[[ -n '$all_metadata' ]]"
    assertTrue "All metadata should contain name" "echo '$all_metadata' | grep -q 'name=test-repo'"
}

test_read_repo_metadata_nonexistent() {
    assertFalse "Should fail for non-existent repository" "read_repo_metadata 'nonexistent' 'name'"
}

test_update_repo_metadata() {
    local repo_name="test-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    local metadata_file="$repo_dir/.qi-repo-meta"
    
    # Create repo directory and initial metadata
    mkdir -p "$repo_dir"
    cat > "$metadata_file" << 'EOF'
name=test-repo
url=https://github.com/user/test-repo.git
status=active
EOF
    
    assertTrue "Should update existing metadata key" "update_repo_metadata '$repo_name' 'status' 'updated'"
    
    local result
    result=$(read_repo_metadata "$repo_name" "status")
    assertEquals "Should have updated value" "updated" "$result"
    
    assertTrue "Should add new metadata key" "update_repo_metadata '$repo_name' 'new_key' 'new_value'"
    result=$(read_repo_metadata "$repo_name" "new_key")
    assertEquals "Should have new key value" "new_value" "$result"
}

# Tests for repository existence checking
test_repo_exists() {
    local repo_name="existing-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Repository doesn't exist yet
    assertFalse "Should return false for non-existent repo" "repo_exists '$repo_name' '$TEST_CACHE_DIR'"
    
    # Create repository directory and metadata
    mkdir -p "$repo_dir"
    touch "$repo_dir/.qi-repo-meta"
    
    assertTrue "Should return true for existing repo" "repo_exists '$repo_name' '$TEST_CACHE_DIR'"
}

# Tests for repository listing
test_list_cached_repos() {
    # Empty cache
    local result
    result=$(list_cached_repos "$TEST_CACHE_DIR")
    assertEquals "Should return empty for empty cache" "" "$result"
    
    # Create test repositories
    local repo1="$TEST_CACHE_DIR/repo1"
    local repo2="$TEST_CACHE_DIR/repo2"
    mkdir -p "$repo1" "$repo2"
    touch "$repo1/.qi-repo-meta" "$repo2/.qi-repo-meta"
    
    result=$(list_cached_repos "$TEST_CACHE_DIR" | sort)
    local expected="repo1
repo2"
    assertEquals "Should list all repositories" "$expected" "$result"
}

# Tests for repository name extraction
test_get_repo_name_from_url() {
    local result
    
    result=$(get_repo_name_from_url "https://github.com/user/my-repo.git")
    assertEquals "Should extract name from HTTPS URL" "my-repo" "$result"
    
    result=$(get_repo_name_from_url "git@github.com:user/another-repo.git")
    assertEquals "Should extract name from SSH URL" "another-repo" "$result"
    
    result=$(get_repo_name_from_url "https://github.com/user/repo-with-special-chars!.git")
    assertEquals "Should sanitize special characters" "repo-with-special-chars_" "$result"
}

# Tests for repository name conflict checking
test_check_repo_name_conflict() {
    local repo_name="conflict-test"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    assertFalse "Should return false when no conflict" "check_repo_name_conflict '$repo_name' '$TEST_CACHE_DIR'"
    
    # Create repository
    mkdir -p "$repo_dir"
    touch "$repo_dir/.qi-repo-meta"
    
    assertTrue "Should return true when conflict exists" "check_repo_name_conflict '$repo_name' '$TEST_CACHE_DIR'"
}

test_generate_unique_repo_name() {
    local base_name="test-repo"
    local repo_dir="$TEST_CACHE_DIR/$base_name"
    
    # No conflict initially
    local result
    result=$(generate_unique_repo_name "$base_name" "$TEST_CACHE_DIR")
    assertEquals "Should return original name when no conflict" "$base_name" "$result"
    
    # Create conflict
    mkdir -p "$repo_dir"
    touch "$repo_dir/.qi-repo-meta"
    
    result=$(generate_unique_repo_name "$base_name" "$TEST_CACHE_DIR")
    assertEquals "Should return unique name when conflict exists" "${base_name}_1" "$result"
    
    # Create another conflict
    mkdir -p "$TEST_CACHE_DIR/${base_name}_1"
    touch "$TEST_CACHE_DIR/${base_name}_1/.qi-repo-meta"
    
    result=$(generate_unique_repo_name "$base_name" "$TEST_CACHE_DIR")
    assertEquals "Should increment counter for multiple conflicts" "${base_name}_2" "$result"
}

# Tests for repository removal
test_remove_repo_from_cache() {
    local repo_name="remove-test"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create repository
    mkdir -p "$repo_dir"
    touch "$repo_dir/.qi-repo-meta"
    echo "test content" > "$repo_dir/test.txt"
    
    assertTrue "Repository should exist before removal" "[[ -d '$repo_dir' ]]"
    assertTrue "Should remove repository successfully" "remove_repo_from_cache '$repo_name' '$TEST_CACHE_DIR'"
    assertFalse "Repository should not exist after removal" "[[ -d '$repo_dir' ]]"
}

test_remove_repo_from_cache_nonexistent() {
    assertFalse "Should fail to remove non-existent repository" "remove_repo_from_cache 'nonexistent' '$TEST_CACHE_DIR'"
}

# Tests for cache locking
test_acquire_cache_lock() {
    # Initialize cache first
    init_cache "$TEST_CACHE_DIR"
    
    assertTrue "Should acquire cache lock" "acquire_cache_lock '$TEST_CACHE_DIR' 5"
    
    local lock_file="$TEST_CACHE_DIR/.qi-cache-lock"
    assertTrue "Lock file should exist" "[[ -f '$lock_file' ]]"
    
    local lock_pid
    lock_pid=$(cat "$lock_file")
    assertEquals "Lock file should contain current PID" "$$" "$lock_pid"
    
    # Release lock for cleanup
    release_cache_lock "$TEST_CACHE_DIR"
}

test_release_cache_lock() {
    # Initialize cache and acquire lock
    init_cache "$TEST_CACHE_DIR"
    acquire_cache_lock "$TEST_CACHE_DIR" 5
    
    local lock_file="$TEST_CACHE_DIR/.qi-cache-lock"
    assertTrue "Lock file should exist before release" "[[ -f '$lock_file' ]]"
    
    release_cache_lock "$TEST_CACHE_DIR"
    assertFalse "Lock file should not exist after release" "[[ -f '$lock_file' ]]"
}

test_acquire_cache_lock_timeout() {
    # Initialize cache and create stale lock
    init_cache "$TEST_CACHE_DIR"
    local lock_file="$TEST_CACHE_DIR/.qi-cache-lock"
    echo "99999" > "$lock_file"  # Non-existent PID
    
    # Should acquire lock after removing stale lock
    assertTrue "Should acquire lock after removing stale lock" "acquire_cache_lock '$TEST_CACHE_DIR' 5"
    
    # Clean up
    release_cache_lock "$TEST_CACHE_DIR"
}

# Tests for cache statistics
test_get_cache_stats() {
    # Initialize cache
    init_cache "$TEST_CACHE_DIR"
    
    # Create test repositories
    local repo1="$TEST_CACHE_DIR/stats-repo1"
    local repo2="$TEST_CACHE_DIR/stats-repo2"
    mkdir -p "$repo1" "$repo2"
    touch "$repo1/.qi-repo-meta" "$repo2/.qi-repo-meta"
    
    # Test that function runs without error
    assertTrue "Should get cache statistics" "get_cache_stats '$TEST_CACHE_DIR' >/dev/null"
}

# Load and run shunit2
. "$PROJECT_ROOT/shunit2"