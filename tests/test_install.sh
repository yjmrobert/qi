#!/bin/bash

# test_install.sh - Unit tests for install.sh using shunit2
# Tests the installation script functionality

# Set up test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
INSTALL_SCRIPT="$PROJECT_ROOT/install.sh"

# Test fixtures and setup
setUp() {
    # Create temporary directory for tests
    TEST_TEMP_DIR=$(mktemp -d -t qi_install_test.XXXXXX)
    export TEST_TEMP_DIR

    # Set up test directories
    TEST_INSTALL_DIR="$TEST_TEMP_DIR/install"
    TEST_USER_HOME="$TEST_TEMP_DIR/home"
    export TEST_INSTALL_DIR TEST_USER_HOME
}

tearDown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Tests for install script existence and structure
test_install_script_exists() {
    assertTrue "install.sh should exist" "[[ -f '$INSTALL_SCRIPT' ]]"
}

test_install_script_executable() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "install.sh should be executable" "[[ -x '$INSTALL_SCRIPT' ]]"
}

test_install_script_syntax() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "install.sh should have valid bash syntax" "bash -n '$INSTALL_SCRIPT'"
}

test_install_script_shebang() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    local first_line
    first_line=$(head -n1 "$INSTALL_SCRIPT")
    assertEquals "Should have correct shebang" "#!/bin/bash" "$first_line"
}

# Tests for install script structure and content
test_install_script_error_handling() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should have error handling setup" "grep -q 'set -euo pipefail' '$INSTALL_SCRIPT'"
}

test_install_script_required_variables() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    local required_vars=("REPO_URL" "INSTALL_DIR" "TEMP_DIR" "QI_BINARY")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$INSTALL_SCRIPT"; then
            missing_vars+=("$var")
        fi
    done

    assertEquals "Should have all required variables" "0" "${#missing_vars[@]}"
}

test_install_script_required_functions() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    local required_functions=(
        "print_color" "info" "success" "warn" "error"
        "check_permissions" "check_requirements" "create_temp_dir"
        "download_qi" "verify_files" "install_qi" "verify_installation"
        "cleanup" "show_usage" "main"
    )
    local missing_functions=()

    for func in "${required_functions[@]}"; do
        if ! grep -q "^$func()" "$INSTALL_SCRIPT"; then
            missing_functions+=("$func")
        fi
    done

    assertEquals "Should have all required functions" "0" "${#missing_functions[@]}"
}

# Tests for install script error handling features
test_install_script_trap_setup() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should have error trap" "grep -q 'trap.*handle_error' '$INSTALL_SCRIPT'"
    assertTrue "Should have cleanup trap" "grep -q 'trap.*cleanup.*EXIT' '$INSTALL_SCRIPT'"
}

test_install_script_permission_checks() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should check for root permissions" "grep -q 'EUID.*0' '$INSTALL_SCRIPT'"
    assertTrue "Should mention sudo" "grep -q 'sudo' '$INSTALL_SCRIPT'"
}

# Tests for install script requirements checking
test_install_script_command_checks() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    local command_check_count
    command_check_count=$(grep -c "command -v" "$INSTALL_SCRIPT")
    assertTrue "Should check for required commands" "[[ $command_check_count -ge 2 ]]"
}

test_install_script_os_check() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should check for Linux OS" "grep -q 'uname.*Linux' '$INSTALL_SCRIPT'"
}

# Tests for install script repository handling
test_install_script_repository_url() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should have repository URL" "grep -q 'REPO_URL.*github.com.*qi' '$INSTALL_SCRIPT'"
}

test_install_script_git_clone() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should use git clone" "grep -q 'git clone.*REPO_URL' '$INSTALL_SCRIPT'"
}

test_install_script_file_verification() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should verify required files" "grep -q 'qi.*lib.*cache.sh\|config.sh\|git-ops.sh' '$INSTALL_SCRIPT'"
}

# Tests for install script installation process
test_install_script_directory_creation() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should create installation directories" "grep -q 'mkdir.*INSTALL_DIR\|lib_install_dir' '$INSTALL_SCRIPT'"
}

test_install_script_file_copying() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should copy qi binary" "grep -q 'cp.*qi.*INSTALL_DIR' '$INSTALL_SCRIPT'"
    assertTrue "Should copy lib files" "grep -q 'cp.*lib' '$INSTALL_SCRIPT'"
}

test_install_script_permissions() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should set executable permissions" "grep -q 'chmod.*+x' '$INSTALL_SCRIPT'"
}

test_install_script_library_path() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should modify library path" "grep -q 'sed.*LIB_DIR' '$INSTALL_SCRIPT'"
}

# Tests for install script verification
test_install_script_installation_verification() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should verify installation" "grep -q 'command -v qi\|qi.*--version' '$INSTALL_SCRIPT'"
}

test_install_script_path_warning() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should warn about PATH" "grep -q 'export PATH' '$INSTALL_SCRIPT'"
}

# Tests for install script usage information
test_install_script_usage_function() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should have usage function" "grep -q 'show_usage()' '$INSTALL_SCRIPT'"
}

test_install_script_quick_start() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should provide quick start info" "grep -q 'Quick Start\|qi add\|qi list' '$INSTALL_SCRIPT'"
}

test_install_script_repository_url_in_usage() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should include repository URL in usage" "grep -q 'visit.*REPO_URL\|github.com' '$INSTALL_SCRIPT'"
}

# Tests for install script curl command
test_install_script_curl_installation() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should contain curl installation command" "grep -q 'curl.*fsSL.*install\.sh.*bash' '$INSTALL_SCRIPT'"
}

# Test for install script main function
test_install_script_main_function() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should have main function" "grep -q '^main()' '$INSTALL_SCRIPT'"
    assertTrue "Should call main with arguments" "grep -q 'main.*\"\$@\"' '$INSTALL_SCRIPT'"
}

# Test for install script cleanup function
test_install_script_cleanup_function() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should have cleanup function" "grep -q '^cleanup()' '$INSTALL_SCRIPT'"
}

# Test for install script color output
test_install_script_color_functions() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should have print_color function" "grep -q 'print_color()' '$INSTALL_SCRIPT'"
    assertTrue "Should have color definitions" "grep -q -E '(RED|GREEN|YELLOW|BLUE|NC)=' '$INSTALL_SCRIPT'"
}

# Test for install script temporary directory handling
test_install_script_temp_dir() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should handle temporary directory" "grep -q 'TEMP_DIR' '$INSTALL_SCRIPT'"
    assertTrue "Should create temp dir function" "grep -q 'create_temp_dir()' '$INSTALL_SCRIPT'"
}

# Test for install script network operations
test_install_script_network_check() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    # Should have some form of network operation (git clone)
    assertTrue "Should perform network operations" "grep -q 'git.*clone\|curl\|wget' '$INSTALL_SCRIPT'"
}

# Test for install script logging
test_install_script_logging() {
    if [[ ! -f "$INSTALL_SCRIPT" ]]; then
        startSkipping
    fi

    assertTrue "Should have info logging" "grep -q 'info.*()' '$INSTALL_SCRIPT'"
    assertTrue "Should have success logging" "grep -q 'success.*()' '$INSTALL_SCRIPT'"
    assertTrue "Should have error logging" "grep -q 'error.*()' '$INSTALL_SCRIPT'"
}

# Load and run shunit2
# shellcheck source=../shunit2
# shellcheck disable=SC1091
. "$PROJECT_ROOT/shunit2"
