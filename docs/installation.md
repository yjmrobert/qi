# Installation

## Prerequisites

Before installing qi, ensure you have:

- Linux operating system
- Git installed and configured
- Bash shell
- Network access for cloning repositories

## Quick Installation (Recommended)

Install qi with a single command:

```bash
curl -fsSL https://github.com/yjmrobert/qi/raw/main/install.sh | bash
```

Or with sudo if you don't have root access:

```bash
curl -fsSL https://github.com/yjmrobert/qi/raw/main/install.sh | sudo bash
```

## Manual Installation

If you prefer to install manually:

```bash
# Clone the qi repository
git clone https://github.com/yjmrobert/qi.git
cd qi

# Make the script executable
chmod +x qi

# Install to system PATH
sudo cp qi /usr/local/bin/
sudo mkdir -p /usr/local/bin/qi-lib
sudo cp -r lib/* /usr/local/bin/qi-lib/

# Update qi to use installed lib directory
sudo sed -i 's|LIB_DIR="\$SCRIPT_DIR/lib"|LIB_DIR="/usr/local/bin/qi-lib"|' /usr/local/bin/qi
```

## Verification

After installation, verify qi is working:

```bash
qi --version
qi help
```

You should see the version information and help text.

## Uninstallation

To remove qi from your system:

```bash
sudo rm /usr/local/bin/qi
sudo rm -rf /usr/local/bin/qi-lib
rm -rf ~/.qi  # Remove cache and configuration
```

## Troubleshooting Installation

### Permission Denied

If you get permission errors:

```bash
# Check if /usr/local/bin is in your PATH
echo $PATH

# Make sure qi is executable
ls -la /usr/local/bin/qi

# Fix permissions if needed
sudo chmod +x /usr/local/bin/qi
```

### Command Not Found

If qi command is not found after installation:

```bash
# Check if /usr/local/bin is in PATH
echo $PATH | grep -o '/usr/local/bin'

# Add to PATH if missing (add to ~/.bashrc or ~/.profile)
export PATH="/usr/local/bin:$PATH"

# Reload your shell
source ~/.bashrc
```

### Git Not Found

If git is not installed:

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install git

# CentOS/RHEL/Fedora
sudo yum install git
# or
sudo dnf install git

# Verify git installation
git --version
```