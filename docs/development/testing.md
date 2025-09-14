# Testing

This document covers the testing framework and practices used in the qi project.

## Test Framework

qi uses [shunit2](https://github.com/kward/shunit2) for unit testing bash scripts. The framework provides:

- Unit testing capabilities for shell scripts
- Test fixtures (setUp/tearDown)
- Assertions for validating results
- Test discovery and execution

## Test Structure

### Test Files

```
tests/
├── test_cache.sh           # Cache functionality tests
├── test_config.sh          # Configuration tests  
├── test_git_ops.sh         # Git operations tests
├── test_install.sh         # Installation tests
├── test_integration.sh     # Integration tests
├── test_script_ops.sh      # Script operations tests
└── test_utils.sh          # Utility function tests
```

### Test Naming Conventions

- Test files: `test_<module>.sh`
- Test functions: `test_<functionality>_<scenario>()`

Examples:
```bash
test_add_repository_success()
test_add_repository_invalid_url()
test_remove_repository_not_found()
test_validate_repo_name_valid()
test_validate_repo_name_invalid()
```

## Running Tests

### Basic Test Execution

```bash
# Run all tests
./test.sh

# Run specific test file
./test.sh cache
./test.sh git-ops

# Run with verbose output
./test.sh -v

# Run specific test function
./test.sh cache test_init_cache_success
```

### Test Output

```
Running tests for: cache
test_init_cache_success ... PASS
test_init_cache_permissions ... PASS
test_acquire_cache_lock_success ... PASS
test_acquire_cache_lock_conflict ... PASS

Ran 4 tests.
PASS
```

### Coverage Analysis

```bash
# Run tests with coverage (requires bash_coverage.sh)
./tools/bash_coverage.sh ./test.sh

# Generate coverage report
./tools/bash_coverage.sh --report ./test.sh
```

## Writing Tests

### Basic Test Structure

```bash
#!/bin/bash

# Source the module being tested
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/cache.sh"

# Test setup - runs before each test
setUp() {
    # Create temporary test environment
    TEST_DIR=$(mktemp -d)
    export QI_CACHE_DIR="$TEST_DIR/cache"
    export QI_CONFIG_FILE="$TEST_DIR/config"
}

# Test cleanup - runs after each test
tearDown() {
    # Clean up test environment
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Test function
test_init_cache_success() {
    # Test implementation
    assertTrue "init_cache should succeed" "init_cache"
    assertTrue "cache directory should exist" "[ -d '$QI_CACHE_DIR' ]"
}

# Load shunit2 framework
source "$SCRIPT_DIR/../shunit2"
```

### Assertion Functions

shunit2 provides various assertion functions:

```bash
# Equality assertions
assertEquals "expected" "actual"
assertNotEquals "not expected" "actual"

# Boolean assertions
assertTrue "condition should be true" "[ condition ]"
assertFalse "condition should be false" "[ condition ]"

# String assertions
assertContains "haystack" "needle"
assertNotContains "haystack" "needle"

# Null/empty assertions
assertNull "variable should be null" "$variable"
assertNotNull "variable should not be null" "$variable"

# File assertions (custom helpers)
assertFileExists "$file_path"
assertFileNotExists "$file_path"
assertDirectoryExists "$dir_path"
```

### Custom Assertions

```bash
# Custom assertion for file existence
assertFileExists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    assertTrue "$message" "[ -f '$file' ]"
}

# Custom assertion for command success
assertCommandSucceeds() {
    local command="$1"
    local message="${2:-Command should succeed: $command}"
    assertTrue "$message" "$command"
}

# Custom assertion for command failure
assertCommandFails() {
    local command="$1"
    local message="${2:-Command should fail: $command}"
    assertFalse "$message" "$command"
}
```

## Test Categories

### Unit Tests

Test individual functions in isolation:

```bash
test_validate_repo_name_valid() {
    assertTrue "valid name should pass" "validate_repo_name 'valid-repo'"
    assertTrue "name with dots should pass" "validate_repo_name 'repo.name'"
    assertTrue "name with underscores should pass" "validate_repo_name 'repo_name'"
}

test_validate_repo_name_invalid() {
    assertFalse "empty name should fail" "validate_repo_name ''"
    assertFalse "name with spaces should fail" "validate_repo_name 'repo name'"
    assertFalse "name with special chars should fail" "validate_repo_name 'repo@name'"
}
```

### Integration Tests

Test interaction between components:

```bash
test_add_and_remove_repository() {
    local repo_url="https://github.com/test/repo.git"
    local repo_name="test-repo"
    
    # Mock git clone
    git() {
        if [[ "$1" == "clone" ]]; then
            mkdir -p "$3"
            return 0
        fi
        command git "$@"
    }
    
    # Test adding repository
    assertTrue "should add repository" "cmd_add '$repo_url' '$repo_name'"
    assertTrue "repository directory should exist" "[ -d '$QI_CACHE_DIR/$repo_name' ]"
    
    # Test removing repository
    assertTrue "should remove repository" "cmd_remove '$repo_name'"
    assertFalse "repository directory should not exist" "[ -d '$QI_CACHE_DIR/$repo_name' ]"
}
```

### Functional Tests

Test complete user workflows:

```bash
test_complete_workflow() {
    # Setup test repository
    setup_test_repository
    
    # Add repository
    qi add "$TEST_REPO_URL" "test"
    assertEquals "0" "$?"
    
    # List scripts
    output=$(qi list)
    assertContains "$output" "test-script"
    
    # Execute script
    output=$(qi test-script)
    assertEquals "0" "$?"
    
    # Update repository
    qi update test
    assertEquals "0" "$?"
    
    # Remove repository
    qi remove test
    assertEquals "0" "$?"
}
```

## Mocking and Test Doubles

### Mocking External Commands

```bash
# Mock git command
git() {
    case "$1" in
        "clone")
            # Simulate successful clone
            mkdir -p "$3"
            echo "Cloning into '$3'..."
            return 0
            ;;
        "pull")
            echo "Already up to date."
            return 0
            ;;
        *)
            # Fall back to real git for other commands
            command git "$@"
            ;;
    esac
}

# Mock network access
curl() {
    case "$2" in
        "https://github.com/test/repo.git")
            echo "HTTP/1.1 200 OK"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
```

### Test Fixtures

```bash
# Create test repository structure
setup_test_repository() {
    local repo_dir="$QI_CACHE_DIR/test-repo"
    mkdir -p "$repo_dir/scripts"
    
    # Create test script
    cat > "$repo_dir/scripts/test-script.bash" << 'EOF'
#!/bin/bash
echo "Test script executed"
EOF
    chmod +x "$repo_dir/scripts/test-script.bash"
    
    # Create git repository
    cd "$repo_dir"
    git init
    git add .
    git commit -m "Initial commit"
}

# Create test configuration
setup_test_config() {
    cat > "$QI_CONFIG_FILE" << EOF
cache_dir=$QI_CACHE_DIR
default_branch=main
verbose=false
EOF
}
```

## Test Best Practices

### Test Independence

- Each test should be independent
- Use setUp/tearDown for test isolation
- Don't rely on test execution order

```bash
setUp() {
    # Create fresh environment for each test
    TEST_DIR=$(mktemp -d)
    export QI_CACHE_DIR="$TEST_DIR/cache"
}

tearDown() {
    # Clean up after each test
    rm -rf "$TEST_DIR"
}
```

### Test Data Management

```bash
# Use temporary directories for test data
TEST_DATA_DIR="$TEST_DIR/data"

# Create test data in setUp
setUp() {
    mkdir -p "$TEST_DATA_DIR"
    echo "test content" > "$TEST_DATA_DIR/test-file"
}
```

### Error Testing

```bash
test_error_conditions() {
    # Test missing parameters
    assertFalse "should fail with no parameters" "validate_repo_name"
    
    # Test invalid input
    assertFalse "should fail with invalid input" "validate_repo_name 'invalid name'"
    
    # Test missing files
    assertFalse "should fail with missing file" "process_file '/nonexistent/file'"
}
```

### Performance Testing

```bash
test_performance() {
    local start_time=$(date +%s%N)
    
    # Run operation
    large_operation
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # milliseconds
    
    # Assert reasonable performance (e.g., less than 1000ms)
    assertTrue "operation should complete within 1000ms" "[ $duration -lt 1000 ]"
}
```

## Continuous Integration

### GitHub Actions

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Run tests
      run: ./test.sh
    - name: Run integration tests
      run: ./test.sh integration
```

### Test Reports

```bash
# Generate test report
./test.sh --report > test-results.txt

# Generate coverage report
./tools/bash_coverage.sh --html ./test.sh
```

## Debugging Tests

### Verbose Output

```bash
# Run tests with verbose output
./test.sh -v

# Debug specific test
bash -x tests/test_cache.sh
```

### Test Debugging

```bash
test_debug_example() {
    # Add debug output
    echo "DEBUG: Testing with input: $input" >&2
    
    # Test the function
    result=$(function_to_test "$input")
    
    # Debug the result
    echo "DEBUG: Result: $result" >&2
    
    # Assert
    assertEquals "expected" "$result"
}
```

### Interactive Testing

```bash
# Run specific test interactively
bash -i tests/test_cache.sh

# Or source the test file and run functions manually
source tests/test_cache.sh
setUp
test_init_cache_success
tearDown
```