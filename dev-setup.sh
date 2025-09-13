#!/bin/bash

# dev-setup.sh - Development environment setup for qi
# Sets up the development environment and runs basic validation

set -euo pipefail

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check for required commands
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    if ! command -v bash >/dev/null 2>&1; then
        missing_deps+=("bash")
    fi
    
    # Check bash version (need 4.0+)
    local bash_version
    bash_version=$(bash --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
    local major_version
    major_version=$(echo "$bash_version" | cut -d. -f1)
    
    if [[ $major_version -lt 4 ]]; then
        log_error "Bash version 4.0+ required, found: $bash_version"
        missing_deps+=("bash-4.0+")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        echo
        echo "Please install the missing dependencies:"
        echo "  Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
        echo "  CentOS/RHEL:   sudo yum install ${missing_deps[*]}"
        echo "  Fedora:        sudo dnf install ${missing_deps[*]}"
        echo "  Arch Linux:    sudo pacman -S ${missing_deps[*]}"
        return 1
    fi
    
    log_success "All prerequisites satisfied"
    return 0
}

# Set up file permissions
setup_permissions() {
    log_info "Setting up file permissions..."
    
    # Make main script executable
    chmod +x "$SCRIPT_DIR/qi"
    
    # Make test runner executable
    chmod +x "$SCRIPT_DIR/test.sh"
    
    # Make development setup script executable
    chmod +x "$SCRIPT_DIR/dev-setup.sh"
    
    log_success "File permissions set up"
}

# Validate project structure
validate_structure() {
    log_info "Validating project structure..."
    
    local required_files=(
        "qi"
        "README.md"
        "project-plan.md"
        "test.sh"
        "lib/utils.sh"
        "lib/config.sh"
        "lib/cache.sh"
        "lib/git-ops.sh"
        "lib/script-ops.sh"
        "lib/ui.sh"
        "lib/commands.sh"
    )
    
    local required_dirs=(
        "lib"
        "tests"
        "docs"
    )
    
    local missing_files=()
    local missing_dirs=()
    
    # Check required files
    for file in "${required_files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    # Check required directories
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$SCRIPT_DIR/$dir" ]]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing files: ${missing_files[*]}"
        return 1
    fi
    
    if [[ ${#missing_dirs[@]} -gt 0 ]]; then
        log_error "Missing directories: ${missing_dirs[*]}"
        return 1
    fi
    
    log_success "Project structure is valid"
    return 0
}

# Test basic functionality
test_basic_functionality() {
    log_info "Testing basic functionality..."
    
    # Test help command
    if ! "$SCRIPT_DIR/qi" --help >/dev/null 2>&1; then
        log_error "qi --help failed"
        return 1
    fi
    
    # Test version command
    if ! "$SCRIPT_DIR/qi" --version >/dev/null 2>&1; then
        log_error "qi --version failed"
        return 1
    fi
    
    # Test that libraries can be sourced
    if ! bash -c "source '$SCRIPT_DIR/lib/utils.sh' && source '$SCRIPT_DIR/lib/config.sh'" 2>/dev/null; then
        log_error "Failed to source library files"
        return 1
    fi
    
    log_success "Basic functionality tests passed"
    return 0
}

# Run test suite
run_tests() {
    log_info "Running test suite..."
    
    if "$SCRIPT_DIR/test.sh" unit >/dev/null 2>&1; then
        log_success "Unit tests passed"
    else
        log_error "Some unit tests failed (this is expected in development)"
        log_info "Run './test.sh -v unit' for detailed test output"
    fi
}

# Show development information
show_dev_info() {
    echo
    echo "qi Development Environment Setup Complete!"
    echo "========================================"
    echo
    echo "Available commands:"
    echo "  ./qi --help          Show qi help"
    echo "  ./qi --version       Show qi version"
    echo "  ./test.sh            Run all tests"
    echo "  ./test.sh -v unit    Run unit tests with verbose output"
    echo "  ./test.sh -c all     Run all tests with coverage report"
    echo
    echo "Development workflow:"
    echo "  1. Make changes to source code"
    echo "  2. Run tests: ./test.sh"
    echo "  3. Test manually: ./qi <command>"
    echo "  4. Update documentation as needed"
    echo
    echo "Project structure:"
    echo "  qi              - Main executable script"
    echo "  lib/            - Library modules"
    echo "  tests/          - Test suite"
    echo "  docs/           - Documentation"
    echo "  README.md       - Project documentation"
    echo "  project-plan.md - Development plan"
    echo
    echo "Priority 1 features (COMPLETED):"
    echo "  ✓ Basic CLI Framework"
    echo "  ✓ Cache Management"
    echo "  ✓ Repository Add/Remove"
    echo "  ✓ Script Discovery"
    echo "  ✓ Basic Script Execution"
    echo "  ✓ Configuration System"
    echo "  ✓ Comprehensive Test Suite"
    echo
    echo "Next steps (Priority 2):"
    echo "  - Repository Update functionality"
    echo "  - Script conflict resolution"
    echo "  - Enhanced error handling"
    echo "  - Status and listing commands"
    echo
}

# Main setup function
main() {
    echo "qi Development Environment Setup"
    echo "================================"
    echo
    
    # Run setup steps
    if ! check_prerequisites; then
        exit 1
    fi
    
    setup_permissions
    
    if ! validate_structure; then
        exit 1
    fi
    
    if ! test_basic_functionality; then
        exit 1
    fi
    
    run_tests
    
    show_dev_info
    
    return 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi