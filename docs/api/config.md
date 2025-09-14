# Configuration Options Reference

This document provides a complete reference for all configuration options available in qi.

## Configuration File Format

qi uses a simple key-value format for configuration files:

```ini
# qi configuration file
# Lines starting with # are comments

# Cache directory
cache_dir=/home/user/.qi/cache

# Default git branch
default_branch=main

# Enable verbose output
verbose=false
```

## Configuration Locations

qi looks for configuration in the following order (highest to lowest priority):

1. **Command-line arguments** (highest priority)
2. **Environment variables** (prefixed with `QI_`)
3. **User configuration file** (`~/.qi/config`)
4. **System configuration file** (`/etc/qi/config`)
5. **Built-in defaults** (lowest priority)

## Core Configuration Options

### cache_dir

**Description:** Directory where repositories are cached.

**Type:** String (directory path)

**Default:** `$HOME/.qi/cache`

**Environment Variable:** `QI_CACHE_DIR`

**Example:**
```ini
cache_dir=/opt/qi-cache
```

```bash
export QI_CACHE_DIR="/opt/qi-cache"
```

### default_branch

**Description:** Default git branch to checkout when cloning repositories.

**Type:** String (branch name)

**Default:** `main`

**Environment Variable:** `QI_DEFAULT_BRANCH`

**Example:**
```ini
default_branch=develop
```

```bash
export QI_DEFAULT_BRANCH="develop"
```

### verbose

**Description:** Enable verbose output by default.

**Type:** Boolean (`true`/`false`)

**Default:** `false`

**Environment Variable:** `QI_VERBOSE`

**Example:**
```ini
verbose=true
```

```bash
export QI_VERBOSE="true"
```

## Advanced Configuration Options

### auto_update

**Description:** Automatically update repositories before script execution.

**Type:** Boolean (`true`/`false`)

**Default:** `false`

**Environment Variable:** `QI_AUTO_UPDATE`

**Example:**
```ini
auto_update=true
```

**Behavior:**
- When `true`, qi will run `git pull` on the repository before executing scripts
- Adds latency to script execution but ensures latest scripts are used
- Useful for environments where repositories change frequently

### git_timeout

**Description:** Timeout for git operations in seconds.

**Type:** Integer (seconds)

**Default:** `30`

**Environment Variable:** `QI_GIT_TIMEOUT`

**Example:**
```ini
git_timeout=60
```

**Usage:**
- Applies to git clone, pull, and fetch operations
- Increase for slow network connections
- Decrease for faster failure detection

### max_repositories

**Description:** Maximum number of repositories to cache.

**Type:** Integer

**Default:** `100`

**Environment Variable:** `QI_MAX_REPOSITORIES`

**Example:**
```ini
max_repositories=50
```

**Behavior:**
- When limit is reached, oldest repositories are removed automatically
- Set to `0` for unlimited repositories
- Helps manage disk space usage

### script_patterns

**Description:** File patterns to search for scripts.

**Type:** String (comma-separated patterns)

**Default:** `*.bash`

**Environment Variable:** `QI_SCRIPT_PATTERNS`

**Example:**
```ini
script_patterns=*.bash,*.sh
```

**Usage:**
- Supports glob patterns
- Multiple patterns separated by commas
- Case-sensitive matching

### exclude_dirs

**Description:** Directory patterns to exclude from script search.

**Type:** String (comma-separated patterns)

**Default:** `.git,node_modules,.venv,__pycache__`

**Environment Variable:** `QI_EXCLUDE_DIRS`

**Example:**
```ini
exclude_dirs=.git,node_modules,venv,test,docs
```

**Usage:**
- Improves performance by skipping large directories
- Supports glob patterns
- Applied recursively to subdirectories

### max_search_depth

**Description:** Maximum directory depth for script discovery.

**Type:** Integer

**Default:** `10`

**Environment Variable:** `QI_MAX_SEARCH_DEPTH`

**Example:**
```ini
max_search_depth=5
```

**Usage:**
- Prevents infinite recursion in symlinked directories
- Improves performance in deep directory structures
- Set to `0` for unlimited depth

## Network Configuration Options

### http_proxy

**Description:** HTTP proxy server for git operations.

**Type:** String (URL)

**Default:** None

**Environment Variable:** `http_proxy` or `HTTP_PROXY`

**Example:**
```bash
export http_proxy="http://proxy.company.com:8080"
export HTTP_PROXY="http://proxy.company.com:8080"
```

### https_proxy

**Description:** HTTPS proxy server for git operations.

**Type:** String (URL)

**Default:** None

**Environment Variable:** `https_proxy` or `HTTPS_PROXY`

**Example:**
```bash
export https_proxy="http://proxy.company.com:8080"
export HTTPS_PROXY="http://proxy.company.com:8080"
```

### no_proxy

**Description:** Hosts to exclude from proxy.

**Type:** String (comma-separated hostnames)

**Default:** None

**Environment Variable:** `no_proxy` or `NO_PROXY`

**Example:**
```bash
export no_proxy="localhost,127.0.0.1,internal.company.com"
```

### clone_timeout

**Description:** Timeout for initial repository clone operations.

**Type:** Integer (seconds)

**Default:** `300`

**Environment Variable:** `QI_CLONE_TIMEOUT`

**Example:**
```ini
clone_timeout=600
```

### network_retries

**Description:** Number of retry attempts for network operations.

**Type:** Integer

**Default:** `3`

**Environment Variable:** `QI_NETWORK_RETRIES`

**Example:**
```ini
network_retries=5
```

## Output Configuration Options

### color

**Description:** Enable colored output.

**Type:** Boolean (`true`/`false`/`auto`)

**Default:** `auto`

**Environment Variable:** `QI_COLOR`

**Example:**
```ini
color=true
```

**Values:**
- `true` - Always use colors
- `false` - Never use colors
- `auto` - Use colors if terminal supports them

### log_level

**Description:** Minimum log level to display.

**Type:** String (`ERROR`/`WARN`/`INFO`/`DEBUG`)

**Default:** `INFO`

**Environment Variable:** `QI_LOG_LEVEL`

**Example:**
```ini
log_level=DEBUG
```

### date_format

**Description:** Date format for timestamps.

**Type:** String (strftime format)

**Default:** `%Y-%m-%d %H:%M:%S`

**Environment Variable:** `QI_DATE_FORMAT`

**Example:**
```ini
date_format=%Y-%m-%d
```

## Security Configuration Options

### trusted_hosts

**Description:** Git hosts that are trusted for automatic operations.

**Type:** String (comma-separated hostnames)

**Default:** `github.com,gitlab.com,bitbucket.org`

**Environment Variable:** `QI_TRUSTED_HOSTS`

**Example:**
```ini
trusted_hosts=github.com,gitlab.internal.com
```

### allow_shell_execution

**Description:** Allow execution of shell scripts.

**Type:** Boolean (`true`/`false`)

**Default:** `true`

**Environment Variable:** `QI_ALLOW_SHELL_EXECUTION`

**Example:**
```ini
allow_shell_execution=false
```

**Security Note:**
- When `false`, qi will only list scripts but not execute them
- Useful in restricted environments

### require_confirmation

**Description:** Require user confirmation for destructive operations.

**Type:** Boolean (`true`/`false`)

**Default:** `true`

**Environment Variable:** `QI_REQUIRE_CONFIRMATION`

**Example:**
```ini
require_confirmation=false
```

## Configuration Examples

### Development Environment

```ini
# ~/.qi/config - Development setup
cache_dir=/home/developer/qi-cache
default_branch=develop
verbose=true
auto_update=true
git_timeout=60
max_repositories=50
script_patterns=*.bash,*.sh,*.py
exclude_dirs=.git,node_modules,venv,test
color=true
log_level=DEBUG
```

### Production Environment

```ini
# /etc/qi/config - Production setup
cache_dir=/var/cache/qi
default_branch=main
verbose=false
auto_update=false
git_timeout=30
max_repositories=20
script_patterns=*.bash
exclude_dirs=.git,node_modules,venv,test,docs,examples
color=false
log_level=ERROR
require_confirmation=true
allow_shell_execution=true
trusted_hosts=github.internal.com,gitlab.internal.com
```

### Minimal Configuration

```ini
# ~/.qi/config - Minimal setup
cache_dir=~/.qi/cache
default_branch=main
verbose=false
```

### High-Security Environment

```ini
# ~/.qi/config - Security-focused setup
cache_dir=/secure/qi-cache
default_branch=main
verbose=false
auto_update=false
git_timeout=15
max_repositories=10
allow_shell_execution=false
require_confirmation=true
trusted_hosts=secure-git.company.com
color=false
log_level=WARN
```

## Environment Variable Reference

Complete list of environment variables that override configuration:

| Environment Variable | Configuration Key | Type | Description |
|---------------------|-------------------|------|-------------|
| `QI_CACHE_DIR` | `cache_dir` | String | Cache directory path |
| `QI_CONFIG_FILE` | N/A | String | Configuration file path |
| `QI_DEFAULT_BRANCH` | `default_branch` | String | Default git branch |
| `QI_VERBOSE` | `verbose` | Boolean | Enable verbose output |
| `QI_AUTO_UPDATE` | `auto_update` | Boolean | Auto-update repositories |
| `QI_GIT_TIMEOUT` | `git_timeout` | Integer | Git operation timeout |
| `QI_MAX_REPOSITORIES` | `max_repositories` | Integer | Maximum repositories |
| `QI_SCRIPT_PATTERNS` | `script_patterns` | String | Script file patterns |
| `QI_EXCLUDE_DIRS` | `exclude_dirs` | String | Excluded directories |
| `QI_MAX_SEARCH_DEPTH` | `max_search_depth` | Integer | Maximum search depth |
| `QI_CLONE_TIMEOUT` | `clone_timeout` | Integer | Clone operation timeout |
| `QI_NETWORK_RETRIES` | `network_retries` | Integer | Network retry attempts |
| `QI_COLOR` | `color` | String | Colored output setting |
| `QI_LOG_LEVEL` | `log_level` | String | Minimum log level |
| `QI_DATE_FORMAT` | `date_format` | String | Date format string |
| `QI_TRUSTED_HOSTS` | `trusted_hosts` | String | Trusted git hosts |
| `QI_ALLOW_SHELL_EXECUTION` | `allow_shell_execution` | Boolean | Allow script execution |
| `QI_REQUIRE_CONFIRMATION` | `require_confirmation` | Boolean | Require confirmations |

## Configuration Validation

qi validates configuration values on startup:

### Validation Rules

- **Paths** must be absolute or expandable (e.g., `~/.qi/cache`)
- **Timeouts** must be positive integers
- **Booleans** must be `true`, `false`, `yes`, `no`, `1`, or `0`
- **Branch names** must be valid git branch names
- **Patterns** must be valid shell glob patterns
- **URLs** must be valid HTTP/HTTPS URLs for proxies

### Validation Errors

```bash
# Check configuration validity
qi config show

# Common validation errors:
# ERROR: Invalid cache directory: /nonexistent/path
# ERROR: Invalid timeout value: -1
# ERROR: Invalid boolean value: maybe
# ERROR: Invalid branch name: feature/invalid name
```

## Configuration Migration

When upgrading qi versions, configuration may need migration:

### Automatic Migration

qi automatically migrates old configuration formats:

```bash
# qi will backup old config and create new format
# ~/.qi/config.backup.20231015
# ~/.qi/config (new format)
```

### Manual Migration

For complex configurations, manual migration may be needed:

```bash
# Backup current configuration
cp ~/.qi/config ~/.qi/config.backup

# Edit configuration file
nano ~/.qi/config

# Validate new configuration
qi config show
```

## Troubleshooting Configuration

### Common Issues

1. **Configuration not loading:**
   ```bash
   # Check file permissions
   ls -la ~/.qi/config
   
   # Check syntax
   qi config show
   ```

2. **Environment variables not working:**
   ```bash
   # Check variable is set
   echo $QI_CACHE_DIR
   
   # Check variable is exported
   env | grep QI_
   ```

3. **Invalid values:**
   ```bash
   # Validate configuration
   qi config show
   
   # Reset to defaults
   qi config init
   ```

### Debug Configuration

```bash
# Show all configuration sources
qi --verbose config show

# Test specific configuration
QI_VERBOSE=true qi status

# Show effective configuration
qi config show | grep -v "^#"
```