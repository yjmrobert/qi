#!/bin/bash

# qi installation script
# Usage: curl -fsSL https://github.com/yjmrobert/qi/install.sh | bash

set -euo pipefail

# Configuration
REPO_URL="https://github.com/yjmrobert/qi"
INSTALL_DIR="/usr/local/bin"
TEMP_DIR="/tmp/qi-install-$$"
QI_BINARY="qi"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    local color="$1"
    shift
    echo -e "${color}$*${NC}"
}

# Print status messages
info() {
    print_color "$BLUE" "ℹ $*"
}

success() {
    print_color "$GREEN" "✓ $*"
}

warn() {
    print_color "$YELLOW" "⚠ $*"
}

error() {
    print_color "$RED" "✗ $*" >&2
}

# Check if running as root or with sudo
check_permissions() {
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        error "This script requires root privileges to install to $INSTALL_DIR"
        error "Please run with sudo or as root:"
        error "  curl -fsSL https://github.com/yjmrobert/qi/install.sh | sudo bash"
        exit 1
    fi
}

# Check system requirements
check_requirements() {
    info "Checking system requirements..."
    
    # Check if running on Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        error "qi is only supported on Linux systems"
        exit 1
    fi
    
    # Check for required commands
    local missing_deps=()
    
    for cmd in git bash curl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        error "Please install the missing dependencies and try again"
        exit 1
    fi
    
    success "System requirements met"
}

# Create temporary directory
create_temp_dir() {
    info "Creating temporary directory..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    mkdir -p "$TEMP_DIR"
    success "Temporary directory created: $TEMP_DIR"
}

# Download and extract qi
download_qi() {
    info "Downloading qi from $REPO_URL..."
    
    cd "$TEMP_DIR"
    
    # Try to clone the repository
    if ! git clone "$REPO_URL.git" qi 2>/dev/null; then
        error "Failed to clone repository from $REPO_URL.git"
        error "Please check your internet connection and try again"
        exit 1
    fi
    
    success "qi downloaded successfully"
}

# Verify qi installation files
verify_files() {
    info "Verifying installation files..."
    
    local qi_dir="$TEMP_DIR/qi"
    
    # Check if main qi script exists
    if [[ ! -f "$qi_dir/qi" ]]; then
        error "qi script not found in downloaded files"
        exit 1
    fi
    
    # Check if lib directory exists
    if [[ ! -d "$qi_dir/lib" ]]; then
        error "lib directory not found in downloaded files"
        exit 1
    fi
    
    # Check for required library files
    local required_libs=("cache.sh" "config.sh" "git-ops.sh" "script-ops.sh" "utils.sh")
    local missing_libs=()
    
    for lib in "${required_libs[@]}"; do
        if [[ ! -f "$qi_dir/lib/$lib" ]]; then
            missing_libs+=("$lib")
        fi
    done
    
    if [[ ${#missing_libs[@]} -gt 0 ]]; then
        error "Missing required library files: ${missing_libs[*]}"
        exit 1
    fi
    
    success "All required files verified"
}

# Install qi
install_qi() {
    info "Installing qi to $INSTALL_DIR..."
    
    local qi_dir="$TEMP_DIR/qi"
    local lib_install_dir="$INSTALL_DIR/qi-lib"
    
    # Create lib directory if it doesn't exist
    if [[ $EUID -eq 0 ]]; then
        mkdir -p "$lib_install_dir"
    else
        sudo mkdir -p "$lib_install_dir"
    fi
    
    # Copy library files
    if [[ $EUID -eq 0 ]]; then
        cp -r "$qi_dir/lib/"* "$lib_install_dir/"
    else
        sudo cp -r "$qi_dir/lib/"* "$lib_install_dir/"
    fi
    
    # Update qi script to use the installed lib directory
    local temp_qi_script="$TEMP_DIR/qi-modified"
    sed "s|LIB_DIR=\"\$SCRIPT_DIR/lib\"|LIB_DIR=\"$lib_install_dir\"|" "$qi_dir/qi" > "$temp_qi_script"
    
    # Make qi script executable
    chmod +x "$temp_qi_script"
    
    # Install qi script
    if [[ $EUID -eq 0 ]]; then
        cp "$temp_qi_script" "$INSTALL_DIR/$QI_BINARY"
        chmod +x "$INSTALL_DIR/$QI_BINARY"
    else
        sudo cp "$temp_qi_script" "$INSTALL_DIR/$QI_BINARY"
        sudo chmod +x "$INSTALL_DIR/$QI_BINARY"
    fi
    
    success "qi installed to $INSTALL_DIR/$QI_BINARY"
}

# Verify installation
verify_installation() {
    info "Verifying installation..."
    
    # Check if qi is in PATH
    if ! command -v qi >/dev/null 2>&1; then
        warn "qi is not in your PATH"
        warn "Make sure $INSTALL_DIR is in your PATH environment variable"
        warn "You can add this line to your ~/.bashrc or ~/.profile:"
        warn "  export PATH=\"$INSTALL_DIR:\$PATH\""
    fi
    
    # Test qi command
    if "$INSTALL_DIR/$QI_BINARY" --version >/dev/null 2>&1; then
        success "qi installation verified"
    else
        error "qi installation verification failed"
        exit 1
    fi
}

# Cleanup temporary files
cleanup() {
    info "Cleaning up temporary files..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
        success "Temporary files cleaned up"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
qi - Git Repository Script Manager

qi has been successfully installed!

Quick Start:
  1. Add a repository:
     qi add https://github.com/user/scripts.git

  2. List available scripts:
     qi list

  3. Execute a script:
     qi script-name

  4. Get help:
     qi --help

For more information, visit: $REPO_URL

EOF
}

# Main installation function
main() {
    print_color "$BLUE" "qi Installation Script"
    print_color "$BLUE" "====================="
    echo ""
    
    # Set up error handling
    trap cleanup EXIT
    
    # Run installation steps
    check_permissions
    check_requirements
    create_temp_dir
    download_qi
    verify_files
    install_qi
    verify_installation
    
    echo ""
    success "qi has been successfully installed!"
    echo ""
    
    show_usage
}

# Handle errors
handle_error() {
    local exit_code=$?
    error "Installation failed with exit code $exit_code"
    cleanup
    exit $exit_code
}

trap handle_error ERR

# Run main installation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi