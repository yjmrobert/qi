# qi - Git Repository Script Manager

`qi` is a Linux command line tool that manages a cache of remote git repositories and allows you to quickly execute bash scripts from them by name.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Usage](#usage)
  - [Adding Repositories](#adding-repositories)
  - [Executing Scripts](#executing-scripts)
  - [Updating Repositories](#updating-repositories)
  - [Removing Repositories](#removing-repositories)
- [Examples](#examples)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Overview

`qi` simplifies the process of managing and executing bash scripts from multiple git repositories. Instead of manually cloning repositories and searching for scripts, `qi` maintains a local cache of repositories and provides fast script execution by name.

### Key Features

- **Repository Management**: Add remote git repositories to a local cache
- **Script Discovery**: Automatically finds `.bash` files across all cached repositories
- **Quick Execution**: Run scripts by name with a simple command
- **Conflict Resolution**: Handles duplicate script names by prompting for repository selection
- **Clean Removal**: Remove repositories from the cache when no longer needed

## Installation

### Prerequisites

- Linux operating system
- Git installed and configured
- Bash shell
- Network access for cloning repositories

### Install qi

#### Quick Installation (Recommended)

Install qi with a single command:

```bash
curl -fsSL https://github.com/yjmrobert/qi/raw/main/install.sh | bash
```

Or with sudo if you don't have root access:

```bash
curl -fsSL https://github.com/yjmrobert/qi/raw/main/install.sh | sudo bash
```

#### Manual Installation

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

## Usage

### Adding Repositories

Add a remote git repository to the qi cache:

```bash
qi add <repository-url> [name]
```

**Parameters:**
- `<repository-url>`: The URL of the git repository (HTTPS or SSH)
- `[name]`: Optional custom name for the repository. If not provided, uses the repository name

**Examples:**
```bash
# Add repository with default name
qi add https://github.com/user/scripts.git

# Add repository with custom name
qi add https://github.com/user/devtools.git devtools
```

### Executing Scripts

Execute a bash script by name from any cached repository:

```bash
qi <script-name>
```

**Parameters:**
- `<script-name>`: The name of the `.bash` file to execute (without the `.bash` extension)

**Behavior:**
- Searches all cached repositories for files matching `<script-name>.bash`
- If one match is found, executes the script immediately
- If multiple matches are found, prompts you to select which repository's script to run
- If no matches are found, displays an error message

**Examples:**
```bash
# Execute a script named 'deploy.bash'
qi deploy

# Execute a script named 'backup.bash'
qi backup
```

### Updating Repositories

Update cached repositories to their latest versions:

```bash
qi update [repository-name]
```

**Parameters:**
- `[repository-name]`: Optional. The name of a specific repository to update. If not provided, updates all cached repositories.

**Behavior:**
- If a repository name is specified, only that repository is updated
- If no repository name is provided, all cached repositories are updated
- Performs a `git pull` operation on the default branch of each repository
- Shows update status for each repository (updated, already up-to-date, or error)
- Maintains the current branch and any local modifications are preserved where possible

**Examples:**
```bash
# Update all cached repositories
qi update

# Update only the 'deploy' repository
qi update deploy

# Update a specific repository by its full name
qi update deployment-scripts
```

### Removing Repositories

Remove a repository from the qi cache:

```bash
qi remove <name>
```

**Parameters:**
- `<name>`: The name of the repository to remove (either the custom name or default repository name)

**Examples:**
```bash
# Remove repository by name
qi remove scripts

# Remove repository by custom name
qi remove devtools
```

## Examples

### Complete Workflow Example

```bash
# 1. Add some repositories to the cache
qi add https://github.com/company/deployment-scripts.git deploy
qi add https://github.com/user/personal-tools.git tools
qi add https://github.com/team/utilities.git

# 2. Execute a script (assuming 'setup.bash' exists in one repository)
qi setup

# 3. Update all repositories to latest versions
qi update

# 4. Update only a specific repository
qi update deploy

# 5. Execute a script with conflicts (assuming 'backup.bash' exists in multiple repositories)
qi backup
# Output:
# Multiple scripts found with name 'backup':
# 1. deploy (https://github.com/company/deployment-scripts.git)
# 2. tools (https://github.com/user/personal-tools.git)
# Select repository [1-2]: 1
# Executing backup.bash from deploy repository...

# 6. Remove a repository when no longer needed
qi remove tools
```

### Script Organization Example

Your repositories should contain `.bash` files in any directory structure:

```
deployment-scripts/
├── server/
│   ├── deploy.bash
│   └── rollback.bash
├── database/
│   ├── backup.bash
│   └── restore.bash
└── monitoring/
    └── health-check.bash
```

All scripts (`deploy`, `rollback`, `backup`, `restore`, `health-check`) will be discoverable by `qi`.

### Update Command Examples

**Update all repositories:**
```bash
qi update
# Output:
# Updating deploy (https://github.com/company/deployment-scripts.git)... ✓ Updated
# Updating tools (https://github.com/user/personal-tools.git)... ✓ Already up-to-date  
# Updating utilities (https://github.com/team/utilities.git)... ✓ Updated (3 new commits)
```

**Update specific repository:**
```bash
qi update deploy
# Output:
# Updating deploy (https://github.com/company/deployment-scripts.git)... ✓ Updated (1 new commit)
# New scripts available: 
#   - rollback-v2.bash
#   - monitoring.bash
```

**Update with conflict resolution:**
```bash
qi update tools
# Output:
# Updating tools (https://github.com/user/personal-tools.git)... ⚠ Conflicts detected
# Local changes found in: custom-config.bash
# Options:
# 1. Stash local changes and update
# 2. Skip update and keep local changes  
# 3. Show diff
# Select option [1-3]: 1
# ✓ Updated with local changes stashed
```

## Configuration

### Cache Location

By default, `qi` stores cached repositories in:
```
~/.qi/cache/
```

### Environment Variables

You can customize `qi` behavior with these environment variables:

- `QI_CACHE_DIR`: Override the default cache directory
- `QI_DEFAULT_BRANCH`: Specify default branch to checkout (default: main/master)

**Example:**
```bash
export QI_CACHE_DIR="/opt/qi-cache"
export QI_DEFAULT_BRANCH="develop"
```

### Configuration File

Create `~/.qi/config` for persistent settings:

```ini
cache_dir=/opt/qi-cache
default_branch=main
auto_update=true
verbose=false
```

## Troubleshooting

### Common Issues

**Repository clone fails:**
```bash
# Check git credentials and network access
git clone <repository-url>

# Verify SSH keys (for SSH URLs)
ssh -T git@github.com
```

**Script not found:**
```bash
# List all available scripts
qi list

# Check repository contents
ls -la ~/.qi/cache/<repository-name>/

# Update repositories to get latest scripts
qi update
```

**Repository update fails:**
```bash
# Check network connectivity
ping github.com

# Check git status in cache
cd ~/.qi/cache/<repository-name>
git status
git pull

# Force update (discards local changes)
qi update --force <repository-name>
```

**Permission denied when executing script:**
```bash
# Scripts should be executable
chmod +x ~/.qi/cache/<repository-name>/path/to/script.bash
```

### Debugging

Enable verbose output:
```bash
qi -v <command>
```

Check cache status:
```bash
qi status
```

Update all cached repositories:
```bash
qi update
```

### Cache Management

**Clear entire cache:**
```bash
rm -rf ~/.qi/cache/
```

**Update specific repository:**
```bash
qi update <repository-name>
```

**Check update status:**
```bash
qi update --dry-run
```

**List cached repositories:**
```bash
qi list-repos
```

## Advanced Usage

### Script Arguments

Pass arguments to scripts:
```bash
qi deploy --env production --force
```

### Dry Run Mode

Preview what script would be executed without running it:
```bash
qi --dry-run deploy
```

### Background Execution

Run scripts in the background:
```bash
qi --background long-running-task
```

## Contributing

### Development Setup

```bash
git clone <qi-repository-url>
cd qi
./dev-setup.sh
```

### Testing

```bash
# Run test suite
./test.sh

# Test specific functionality
./test.sh add-remove
```

### Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

[Specify your license here]

## Support

- **Issues**: Report bugs and feature requests on GitHub
- **Documentation**: Additional documentation available in the `docs/` directory
- **Community**: Join our discussion forum or chat channel

---

**Version**: 1.0.0  
**Last Updated**: $(date +"%Y-%m-%d")  
**Maintainer**: [Your Name/Organization]