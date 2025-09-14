#!/bin/bash

# test_git_ops.sh - Unit tests for lib/git-ops.sh using shunit2
# Tests git operations functionality

# Set up test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
LIB_DIR="$PROJECT_ROOT/lib"

# Source required libraries
. "$LIB_DIR/utils.sh"
. "$LIB_DIR/config.sh"
. "$LIB_DIR/cache.sh"
. "$LIB_DIR/git-ops.sh"

# Test fixtures and setup
setUp() {
    # Create temporary directory for tests
    TEST_TEMP_DIR=$(mktemp -d -t qi_git_test.XXXXXX)
    export TEST_TEMP_DIR
    
    # Set up test cache directory
    TEST_CACHE_DIR="$TEST_TEMP_DIR/cache"
    export CACHE_DIR="$TEST_CACHE_DIR"
    
    # Mock variables
    export DRY_RUN=false
    
    # Mock log function to avoid output during tests
    log() {
        return 0
    }
    
    # Mock print functions
    print_success() { echo "SUCCESS: $*"; }
    print_error() { echo "ERROR: $*" >&2; }
    
    # Mock config functions
    get_config() {
        case "$1" in
            "default_branch") echo "main" ;;
            *) echo "$2" ;;
        esac
    }
    
    # Mock cache functions
    create_repo_metadata() { return 0; }
    get_repo_dir() { echo "$CACHE_DIR/$1"; }
    get_timestamp() { echo "2023-01-01T00:00:00Z"; }
    update_repo_metadata() { return 0; }
    
    # Mock network check
    check_network() { return 0; }
}

tearDown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Helper function to create a mock git repository
create_mock_git_repo() {
    local repo_dir="$1"
    mkdir -p "$repo_dir/.git"
    echo "ref: refs/heads/main" > "$repo_dir/.git/HEAD"
    mkdir -p "$repo_dir/.git/refs/heads"
    echo "abc123" > "$repo_dir/.git/refs/heads/main"
}

# Tests for repository status checking
test_get_repository_status_not_found() {
    local result
    result=$(get_repository_status "nonexistent" "$TEST_CACHE_DIR")
    assertEquals "Should return not_found for non-existent repo" "not_found" "$result"
}

test_get_repository_status_invalid() {
    local repo_dir="$TEST_CACHE_DIR/invalid-repo"
    mkdir -p "$repo_dir"
    
    local result
    result=$(get_repository_status "invalid-repo" "$TEST_CACHE_DIR")
    assertEquals "Should return invalid for directory without .git" "invalid" "$result"
}

test_get_repository_status_clean() {
    local repo_name="clean-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create mock git repository
    create_mock_git_repo "$repo_dir"
    
    # Mock git commands for clean status
    git() {
        case "$1" in
            "status")
                echo ""  # Empty output indicates clean
                ;;
            "rev-list")
                echo "0	0"  # No commits ahead/behind
                ;;
            "rev-parse")
                if [[ "$2" == "--abbrev-ref" ]]; then
                    return 1  # No upstream
                else
                    echo "abc123"
                fi
                ;;
            *)
                return 0
                ;;
        esac
    }
    
    local result
    result=$(get_repository_status "$repo_name" "$TEST_CACHE_DIR")
    assertEquals "Should return clean for clean repository" "clean" "$result"
    
    unset -f git
}

test_get_repository_status_modified() {
    local repo_name="modified-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create mock git repository
    create_mock_git_repo "$repo_dir"
    
    # Mock git commands for modified status
    git() {
        case "$1" in
            "status")
                echo "M modified_file.txt"  # Modified file
                ;;
            *)
                return 0
                ;;
        esac
    }
    
    local result
    result=$(get_repository_status "$repo_name" "$TEST_CACHE_DIR")
    assertEquals "Should return modified for repository with changes" "modified" "$result"
    
    unset -f git
}

# Tests for repository URL retrieval
test_get_repository_url() {
    local repo_name="url-test-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    local test_url="https://github.com/user/repo.git"
    
    # Create mock git repository
    create_mock_git_repo "$repo_dir"
    
    # Mock git remote command
    git() {
        case "$1 $2" in
            "remote get-url")
                echo "$test_url"
                ;;
            *)
                return 0
                ;;
        esac
    }
    
    local result
    result=$(get_repository_url "$repo_name" "$TEST_CACHE_DIR")
    assertEquals "Should return repository URL" "$test_url" "$result"
    
    unset -f git
}

test_get_repository_url_invalid() {
    local result
    result=$(get_repository_url "nonexistent" "$TEST_CACHE_DIR")
    assertFalse "Should fail for invalid repository" "[[ $? -eq 0 ]]"
}

# Tests for repository branch retrieval
test_get_repository_branch() {
    local repo_name="branch-test-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create mock git repository
    create_mock_git_repo "$repo_dir"
    
    # Mock git branch command
    git() {
        case "$1 $2" in
            "branch --show-current")
                echo "feature-branch"
                ;;
            *)
                return 0
                ;;
        esac
    }
    
    local result
    result=$(get_repository_branch "$repo_name" "$TEST_CACHE_DIR")
    assertEquals "Should return current branch" "feature-branch" "$result"
    
    unset -f git
}

# Tests for repository last commit info
test_get_repository_last_commit() {
    local repo_name="commit-test-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create mock git repository
    create_mock_git_repo "$repo_dir"
    
    # Mock git log command
    git() {
        case "$1" in
            "log")
                echo "abc123 Initial commit John Doe Mon Jan 1 00:00:00 2023"
                ;;
            *)
                return 0
                ;;
        esac
    }
    
    local result
    result=$(get_repository_last_commit "$repo_name" "$TEST_CACHE_DIR")
    assertEquals "Should return commit info" "abc123 Initial commit John Doe Mon Jan 1 00:00:00 2023" "$result"
    
    unset -f git
}

# Tests for repository verification
test_verify_repository() {
    local repo_name="verify-test-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create mock git repository
    create_mock_git_repo "$repo_dir"
    
    # Mock git commands
    git() {
        case "$1" in
            "fsck")
                return 0  # Repository is valid
                ;;
            "remote")
                if [[ "$2" == "get-url" ]]; then
                    echo "https://github.com/user/repo.git"
                fi
                ;;
            *)
                return 0
                ;;
        esac
    }
    
    assertTrue "Should verify valid repository" "verify_repository '$repo_name' '$TEST_CACHE_DIR'"
    
    unset -f git
}

test_verify_repository_invalid() {
    assertFalse "Should fail for non-existent repository" "verify_repository 'nonexistent' '$TEST_CACHE_DIR'"
}

test_verify_repository_not_git() {
    local repo_name="not-git-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create directory without .git
    mkdir -p "$repo_dir"
    
    assertFalse "Should fail for directory without .git" "verify_repository '$repo_name' '$TEST_CACHE_DIR'"
}

test_verify_repository_corrupt() {
    local repo_name="corrupt-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create mock git repository
    create_mock_git_repo "$repo_dir"
    
    # Mock git fsck to fail
    git() {
        case "$1" in
            "fsck")
                return 1  # Repository is corrupt
                ;;
            *)
                return 0
                ;;
        esac
    }
    
    assertFalse "Should fail for corrupt repository" "verify_repository '$repo_name' '$TEST_CACHE_DIR'"
    
    unset -f git
}

# Tests for up-to-date checking
test_is_repository_up_to_date() {
    local repo_name="uptodate-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create mock git repository
    create_mock_git_repo "$repo_dir"
    
    # Mock git commands for clean status
    git() {
        case "$1" in
            "status")
                echo ""  # Clean status
                ;;
            "rev-list")
                echo "0	0"  # No commits ahead/behind
                ;;
            "rev-parse")
                return 1  # No upstream
                ;;
            *)
                return 0
                ;;
        esac
    }
    
    assertTrue "Should return true for up-to-date repository" "is_repository_up_to_date '$repo_name' '$TEST_CACHE_DIR'"
    
    unset -f git
}

test_is_repository_up_to_date_behind() {
    local repo_name="behind-repo"
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    
    # Create mock git repository
    create_mock_git_repo "$repo_dir"
    
    # Mock git commands for behind status
    git() {
        case "$1" in
            "status")
                echo ""  # Clean status
                ;;
            "rev-list")
                echo "1	0"  # Behind by 1 commit
                ;;
            "rev-parse")
                return 1  # No upstream
                ;;
            *)
                return 0
                ;;
        esac
    }
    
    assertFalse "Should return false for repository behind" "is_repository_up_to_date '$repo_name' '$TEST_CACHE_DIR'"
    
    unset -f git
}

# Tests for dry run mode
test_clone_repository_dry_run() {
    export DRY_RUN=true
    local repo_url="https://github.com/user/test-repo.git"
    local repo_name="dry-run-test"
    
    # Mock validate_git_url and normalize_git_url
    validate_git_url() { return 0; }
    normalize_git_url() { echo "$1"; }
    
    assertTrue "Should succeed in dry run mode" "clone_repository '$repo_url' '$repo_name' '$TEST_CACHE_DIR'"
    
    export DRY_RUN=false
    unset -f validate_git_url normalize_git_url
}

# Load and run shunit2
. "$PROJECT_ROOT/shunit2"