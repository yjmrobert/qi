# Configuration

This page covers how to configure qi to suit your needs and environment.

## Configuration File

qi uses a configuration file located at `~/.qi/config` for persistent settings.

### Creating Configuration

Create a default configuration file:

```bash
qi config init
```

Or create it manually:

```bash
mkdir -p ~/.qi
cat > ~/.qi/config << EOF
# qi configuration file

# Cache directory (default: ~/.qi/cache)
cache_dir=$HOME/.qi/cache

# Default git branch to checkout (default: main)
default_branch=main

# Auto-update repositories when executing scripts (default: false)
auto_update=false

# Enable verbose output by default (default: false)
verbose=false

# Timeout for git operations in seconds (default: 30)
git_timeout=30

# Maximum number of repositories to cache (default: 100)
max_repositories=100
EOF
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `cache_dir` | `~/.qi/cache` | Directory where repositories are cached |
| `default_branch` | `main` | Default branch to checkout when cloning |
| `auto_update` | `false` | Automatically update repos before script execution |
| `verbose` | `false` | Enable verbose output by default |
| `git_timeout` | `30` | Timeout for git operations (seconds) |
| `max_repositories` | `100` | Maximum number of repositories to cache |

## Environment Variables

You can override configuration with environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `QI_CACHE_DIR` | Override cache directory | `/opt/qi-cache` |
| `QI_CONFIG_FILE` | Override config file location | `/etc/qi/config` |
| `QI_DEFAULT_BRANCH` | Override default branch | `develop` |
| `QI_VERBOSE` | Enable verbose output | `true` |
| `QI_AUTO_UPDATE` | Enable auto-update | `true` |

### Setting Environment Variables

**Temporary (current session):**
```bash
export QI_CACHE_DIR="/opt/qi-cache"
export QI_DEFAULT_BRANCH="develop"
qi add https://github.com/user/scripts.git
```

**Permanent (add to ~/.bashrc or ~/.profile):**
```bash
echo 'export QI_CACHE_DIR="/opt/qi-cache"' >> ~/.bashrc
echo 'export QI_DEFAULT_BRANCH="develop"' >> ~/.bashrc
source ~/.bashrc
```

## Cache Management

### Cache Directory Structure

The cache directory contains:

```
~/.qi/cache/
├── repository-name-1/          # Git repository clone
│   ├── .git/                   # Git metadata
│   ├── script1.bash            # Script files
│   └── subdir/
│       └── script2.bash
├── repository-name-2/
└── .qi-metadata/               # qi metadata
    ├── repositories.json       # Repository index
    ├── scripts.json           # Script index
    └── locks/                 # Lock files
```

### Cache Location

**Default location:**
```bash
~/.qi/cache/
```

**Custom location via config:**
```ini
cache_dir=/opt/qi-cache
```

**Custom location via environment:**
```bash
export QI_CACHE_DIR="/opt/qi-cache"
```

### Cache Maintenance

**Check cache size:**
```bash
du -sh ~/.qi/cache/
```

**Clean up cache:**
```bash
# Remove all cached repositories
rm -rf ~/.qi/cache/

# Remove specific repository
qi remove repository-name

# Or manually
rm -rf ~/.qi/cache/repository-name
```

## Git Configuration

### Authentication

qi uses your system's git configuration for authentication.

**HTTPS with credentials:**
```bash
# Store credentials (will prompt once)
git config --global credential.helper store

# Or use credential manager
git config --global credential.helper manager
```

**SSH with keys:**
```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"

# Add to SSH agent
ssh-add ~/.ssh/id_rsa

# Test connection
ssh -T git@github.com
```

### Git Options

qi respects your global git configuration:

```bash
# Set default branch name
git config --global init.defaultBranch main

# Set user information
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Configure proxy if needed
git config --global http.proxy http://proxy.company.com:8080
```

## Advanced Configuration

### Custom Script Discovery

By default, qi searches for `.bash` files in all directories. You can customize this behavior:

**Config file option (planned feature):**
```ini
# Search patterns for script files
script_patterns=*.bash,*.sh

# Directories to exclude from search
exclude_dirs=.git,node_modules,venv

# Maximum search depth
max_search_depth=10
```

### Repository-Specific Configuration

Create `.qi-config` in your repository root to override settings:

```bash
# .qi-config in your repository
default_script_dir=scripts
exclude_patterns=test_*,*_test.bash
```

### Network Configuration

**Timeout settings:**
```ini
# Git operation timeout (seconds)
git_timeout=30

# Network timeout for initial clone (seconds)
clone_timeout=300

# Retry attempts for network operations
network_retries=3
```

**Proxy configuration:**
```bash
# HTTP proxy
export http_proxy=http://proxy.company.com:8080
export https_proxy=http://proxy.company.com:8080

# Or in git config
git config --global http.proxy http://proxy.company.com:8080
git config --global https.proxy http://proxy.company.com:8080
```

## Configuration Examples

### Development Environment

```ini
# ~/.qi/config for development
cache_dir=/home/developer/qi-cache
default_branch=develop
auto_update=true
verbose=true
git_timeout=60
max_repositories=50
```

### Production Environment

```ini
# ~/.qi/config for production
cache_dir=/opt/qi-cache
default_branch=main
auto_update=false
verbose=false
git_timeout=30
max_repositories=20
```

### Team Shared Configuration

```bash
# /etc/qi/config (system-wide)
cache_dir=/var/cache/qi
default_branch=main
auto_update=true
verbose=false
git_timeout=45
max_repositories=100

# Set environment variable for all users
echo 'export QI_CONFIG_FILE="/etc/qi/config"' >> /etc/profile.d/qi.sh
```

## Troubleshooting Configuration

### Check Current Configuration

```bash
qi config show
```

### Verify Environment Variables

```bash
env | grep QI_
```

### Test Configuration

```bash
# Test with verbose output
qi --verbose status

# Test cache directory
ls -la "$QI_CACHE_DIR"

# Test git access
git ls-remote https://github.com/yjmrobert/qi.git
```

### Common Issues

**Permission denied on cache directory:**
```bash
# Fix permissions
chmod 755 ~/.qi
chmod 755 ~/.qi/cache

# Or use different location
export QI_CACHE_DIR="/tmp/qi-cache"
```

**Git authentication failures:**
```bash
# Test git credentials
git clone https://github.com/private/repo.git /tmp/test
rm -rf /tmp/test

# Test SSH keys
ssh -T git@github.com
```

**Configuration not loading:**
```bash
# Check config file exists and is readable
ls -la ~/.qi/config
cat ~/.qi/config

# Check environment variables
echo $QI_CONFIG_FILE
echo $QI_CACHE_DIR
```