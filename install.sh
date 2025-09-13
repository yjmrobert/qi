#!/bin/bash

# install.sh - Installation script for qi
# Installs qi to /usr/local/bin and sets up necessary permissions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
QI_SCRIPT="$SCRIPT_DIR/qi"
LIB_DIR="$SCRIPT_DIR/lib"

echo "qi - Git Repository Script Manager Installation"
echo "=============================================="

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
    echo "Running as root..."
elif command -v sudo >/dev/null 2>&1; then
    echo "Using sudo for installation..."
    SUDO="sudo"
else
    echo "ERROR: Root access required for installation"
    echo "Please run as root or install sudo"
    exit 1
fi

# Check if qi script exists
if [[ ! -f "$QI_SCRIPT" ]]; then
    echo "ERROR: qi script not found at $QI_SCRIPT"
    exit 1
fi

# Check if lib directory exists
if [[ ! -d "$LIB_DIR" ]]; then
    echo "ERROR: lib directory not found at $LIB_DIR"
    exit 1
fi

# Create installation directory if it doesn't exist
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Creating installation directory: $INSTALL_DIR"
    ${SUDO:-} mkdir -p "$INSTALL_DIR"
fi

# Copy qi script
echo "Installing qi script to $INSTALL_DIR/qi"
${SUDO:-} cp "$QI_SCRIPT" "$INSTALL_DIR/qi"
${SUDO:-} chmod +x "$INSTALL_DIR/qi"

# Create lib directory in installation location
LIB_INSTALL_DIR="$INSTALL_DIR/../share/qi/lib"
echo "Installing libraries to $LIB_INSTALL_DIR"
${SUDO:-} mkdir -p "$LIB_INSTALL_DIR"
${SUDO:-} cp -r "$LIB_DIR"/* "$LIB_INSTALL_DIR/"

# Update qi script to use installed lib directory
echo "Updating library path in installed script"
${SUDO:-} sed -i "s|LIB_DIR=\"\$SCRIPT_DIR/lib\"|LIB_DIR=\"$LIB_INSTALL_DIR\"|" "$INSTALL_DIR/qi"

# Verify installation
if command -v qi >/dev/null 2>&1; then
    echo ""
    echo "✓ Installation successful!"
    echo ""
    echo "qi is now available in your PATH"
    echo "Try: qi --help"
    echo ""
    echo "To get started:"
    echo "  1. Add a repository: qi add https://github.com/user/scripts.git"
    echo "  2. List scripts: qi list"
    echo "  3. Execute a script: qi <script-name>"
else
    echo ""
    echo "✓ Installation completed, but qi is not in PATH"
    echo ""
    echo "You may need to:"
    echo "  1. Restart your shell"
    echo "  2. Add $INSTALL_DIR to your PATH"
    echo "  3. Run: export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo ""
echo "For more information, see the README.md file"