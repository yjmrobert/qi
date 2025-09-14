#!/bin/bash

# test_script_ops.sh - Unit tests for lib/script-ops.sh using shunit2
# Tests script discovery and execution functionality

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
. "$LIB_DIR/script-ops.sh"

# Test fixtures and setup
setUp() {
    # Create temporary directory for tests
    TEST_TEMP_DIR=$(mktemp -d -t qi_script_test.XXXXXX)
    export TEST_TEMP_DIR
    
    # Set up test cache directory
    TEST_CACHE_DIR="$TEST_TEMP_DIR/cache"
    export CACHE_DIR="$TEST_CACHE_DIR"
    
    # Mock variables
    export DRY_RUN=false
    export BACKGROUND=false
    
    # Mock log function to avoid output during tests
    log() {
        return 0
    }
    
    # Mock print functions
    print_success() { echo "SUCCESS: $*"; }
    print_error() { echo "ERROR: $*" >&2; }
    
    # Mock cache functions
    list_cached_repos() {
        if [[ -d "$TEST_CACHE_DIR" ]]; then
            find "$TEST_CACHE_DIR" -maxdepth 1 -type d -name "*" ! -name ".*" -exec basename {} \; 2>/dev/null | sort
        fi
    }
    
    get_repo_dir() { echo "$CACHE_DIR/$1"; }
    
    # Mock time functions
    time_diff() { echo "1s"; }
}

tearDown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Helper function to create a test repository with scripts
create_test_repo_with_scripts() {
    local repo_name="$1"
    shift
    local scripts=("$@")
    
    local repo_dir="$TEST_CACHE_DIR/$repo_name"
    local qi_dir="$repo_dir/qi"
    
    mkdir -p "$qi_dir"
    
    for script in "${scripts[@]}"; do
        cat > "$qi_dir/$script.bash" << 'EOF'
#!/bin/bash
echo "Test script executed: $script"
echo "Arguments: $*"
EOF
        chmod +x "$qi_dir/$script.bash"
    done
}

# Tests for script index file path
test_get_script_index_file() {
    local result
    result=$(get_script_index_file "$TEST_CACHE_DIR")
    assertEquals "Should return correct index file path" "$TEST_CACHE_DIR/.qi-meta/.qi-script-index" "$result"
}

# Tests for script discovery
test_discover_scripts_empty_cache() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    
    assertTrue "Should handle empty cache" "discover_scripts '$TEST_CACHE_DIR'"
    
    local index_file="$TEST_CACHE_DIR/.qi-meta/.qi-script-index"
    assertTrue "Index file should exist" "[[ -f '$index_file' ]]"
    
    local line_count
    line_count=$(wc -l < "$index_file")
    assertEquals "Index should be empty for empty cache" "0" "$line_count"
}

test_discover_scripts_with_repositories() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    
    # Create test repositories with scripts
    create_test_repo_with_scripts "repo1" "deploy" "backup"
    create_test_repo_with_scripts "repo2" "test" "build"
    
    assertTrue "Should discover scripts" "discover_scripts '$TEST_CACHE_DIR'"
    
    local index_file="$TEST_CACHE_DIR/.qi-meta/.qi-script-index"
    assertTrue "Index file should exist" "[[ -f '$index_file' ]]"
    
    local line_count
    line_count=$(wc -l < "$index_file")
    assertEquals "Should index 4 scripts" "4" "$line_count"
    
    # Check specific entries
    assertTrue "Should contain deploy script" "grep -q '^deploy|repo1|' '$index_file'"
    assertTrue "Should contain backup script" "grep -q '^backup|repo1|' '$index_file'"
    assertTrue "Should contain test script" "grep -q '^test|repo2|' '$index_file'"
    assertTrue "Should contain build script" "grep -q '^build|repo2|' '$index_file'"
}

test_discover_scripts_no_qi_directory() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    
    # Create repository without qi directory
    local repo_dir="$TEST_CACHE_DIR/no-qi-repo"
    mkdir -p "$repo_dir"
    
    assertTrue "Should handle repository without qi directory" "discover_scripts '$TEST_CACHE_DIR'"
    
    local index_file="$TEST_CACHE_DIR/.qi-meta/.qi-script-index"
    local line_count
    line_count=$(wc -l < "$index_file")
    assertEquals "Should not index any scripts" "0" "$line_count"
}

test_discover_scripts_force_rebuild() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    local index_file="$TEST_CACHE_DIR/.qi-meta/.qi-script-index"
    
    # Create old index file
    echo "old|content|here" > "$index_file"
    
    # Create new repository
    create_test_repo_with_scripts "new-repo" "new-script"
    
    assertTrue "Should force rebuild index" "discover_scripts '$TEST_CACHE_DIR' true"
    
    assertFalse "Should not contain old content" "grep -q 'old|content|here' '$index_file'"
    assertTrue "Should contain new script" "grep -q '^new-script|new-repo|' '$index_file'"
}

# Tests for script searching
test_find_scripts_by_name() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "deploy" "backup"
    create_test_repo_with_scripts "repo2" "deploy" "test"
    
    # Build index
    discover_scripts "$TEST_CACHE_DIR"
    
    local result
    result=$(find_scripts_by_name "deploy" "$TEST_CACHE_DIR")
    
    assertTrue "Should find deploy scripts" "[[ -n '$result' ]]"
    
    local count
    count=$(echo "$result" | wc -l)
    assertEquals "Should find 2 deploy scripts" "2" "$count"
    
    assertTrue "Should contain repo1 deploy" "echo '$result' | grep -q 'deploy|repo1|'"
    assertTrue "Should contain repo2 deploy" "echo '$result' | grep -q 'deploy|repo2|'"
}

test_find_scripts_by_name_not_found() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "deploy"
    
    discover_scripts "$TEST_CACHE_DIR"
    
    local result
    result=$(find_scripts_by_name "nonexistent" "$TEST_CACHE_DIR")
    
    assertEquals "Should return empty for non-existent script" "" "$result"
}

# Tests for script listing
test_list_all_scripts_name_format() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "deploy" "backup"
    create_test_repo_with_scripts "repo2" "test" "deploy"
    
    discover_scripts "$TEST_CACHE_DIR"
    
    local result
    result=$(list_all_scripts "$TEST_CACHE_DIR" "name")
    
    # Should list unique script names
    assertTrue "Should contain deploy" "echo '$result' | grep -q '^deploy$'"
    assertTrue "Should contain backup" "echo '$result' | grep -q '^backup$'"
    assertTrue "Should contain test" "echo '$result' | grep -q '^test$'"
    
    local unique_count
    unique_count=$(echo "$result" | wc -l)
    assertEquals "Should list 3 unique script names" "3" "$unique_count"
}

test_list_all_scripts_full_format() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "deploy"
    
    discover_scripts "$TEST_CACHE_DIR"
    
    local result
    result=$(list_all_scripts "$TEST_CACHE_DIR" "full")
    
    assertTrue "Should contain full information" "echo '$result' | grep -q 'deploy (repo1:'"
}

test_list_all_scripts_repo_format() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "deploy" "backup"
    
    discover_scripts "$TEST_CACHE_DIR"
    
    local result
    result=$(list_all_scripts "$TEST_CACHE_DIR" "repo")
    
    assertTrue "Should group by repository" "echo '$result' | grep -q '^repo1:$'"
    assertTrue "Should list scripts under repo" "echo '$result' | grep -q '  deploy '"
    assertTrue "Should list scripts under repo" "echo '$result' | grep -q '  backup '"
}

# Tests for script counting
test_get_script_count() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "deploy" "backup"
    
    discover_scripts "$TEST_CACHE_DIR"
    
    local count
    count=$(get_script_count "$TEST_CACHE_DIR")
    assertEquals "Should count 2 scripts" "2" "$count"
}

test_get_unique_script_count() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "deploy" "backup"
    create_test_repo_with_scripts "repo2" "deploy" "test"
    
    discover_scripts "$TEST_CACHE_DIR"
    
    local count
    count=$(get_unique_script_count "$TEST_CACHE_DIR")
    assertEquals "Should count 3 unique scripts" "3" "$count"
}

# Tests for script existence checking
test_script_exists() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "deploy"
    
    discover_scripts "$TEST_CACHE_DIR"
    
    assertTrue "Should find existing script" "script_exists 'deploy' '$TEST_CACHE_DIR'"
    assertFalse "Should not find non-existent script" "script_exists 'nonexistent' '$TEST_CACHE_DIR'"
}

# Tests for script conflicts
test_get_script_conflicts() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "deploy"
    create_test_repo_with_scripts "repo2" "deploy"
    
    discover_scripts "$TEST_CACHE_DIR"
    
    local conflicts
    conflicts=$(get_script_conflicts "deploy" "$TEST_CACHE_DIR")
    assertTrue "Should detect conflicts" "[[ -n '$conflicts' ]]"
    
    local count
    count=$(echo "$conflicts" | wc -l)
    assertEquals "Should have 2 conflicting scripts" "2" "$count"
}

test_get_script_conflicts_none() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "unique-script"
    
    discover_scripts "$TEST_CACHE_DIR"
    
    assertFalse "Should not detect conflicts for unique script" "get_script_conflicts 'unique-script' '$TEST_CACHE_DIR' >/dev/null"
}

# Tests for script validation
test_validate_script_file() {
    local test_script="$TEST_TEMP_DIR/test.bash"
    
    # Create valid bash script
    cat > "$test_script" << 'EOF'
#!/bin/bash
echo "test"
EOF
    
    assertTrue "Should validate .bash file" "validate_script_file '$test_script'"
    
    # Test non-existent file
    assertFalse "Should reject non-existent file" "validate_script_file '/nonexistent/file'"
    
    # Test file with bash shebang but no .bash extension
    local shebang_script="$TEST_TEMP_DIR/shebang_test"
    cat > "$shebang_script" << 'EOF'
#!/bin/bash
echo "test"
EOF
    
    assertTrue "Should validate file with bash shebang" "validate_script_file '$shebang_script'"
}

# Tests for script metadata
test_get_script_metadata() {
    local test_script="$TEST_TEMP_DIR/metadata_test.bash"
    
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Description: Test script for metadata extraction
# This script demonstrates usage information
echo "test"
EOF
    
    local metadata
    metadata=$(get_script_metadata "$test_script")
    
    assertTrue "Should extract metadata" "[[ -n '$metadata' ]]"
    assertTrue "Should include size info" "echo '$metadata' | grep -q 'Size:'"
    assertTrue "Should include permissions" "echo '$metadata' | grep -q 'Permissions:'"
    assertTrue "Should include modified date" "echo '$metadata' | grep -q 'Modified:'"
    assertTrue "Should extract description" "echo '$metadata' | grep -q 'Description: Test script'"
    assertTrue "Should detect usage info" "echo '$metadata' | grep -q 'Has usage info: yes'"
}

# Tests for script index rebuilding
test_rebuild_script_index() {
    mkdir -p "$TEST_CACHE_DIR/.qi-meta"
    create_test_repo_with_scripts "repo1" "script1"
    
    assertTrue "Should rebuild script index" "rebuild_script_index '$TEST_CACHE_DIR'"
    
    local index_file="$TEST_CACHE_DIR/.qi-meta/.qi-script-index"
    assertTrue "Index file should exist after rebuild" "[[ -f '$index_file' ]]"
    assertTrue "Should contain script1" "grep -q '^script1|repo1|' '$index_file'"
}

# Load and run shunit2
. "$PROJECT_ROOT/shunit2"