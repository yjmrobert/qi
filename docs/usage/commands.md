# Commands Reference

This page provides a complete reference for all qi commands and options.

## Command Syntax

```bash
qi [OPTIONS] <command> [arguments]
qi [OPTIONS] <script-name> [script-arguments]
```

## Global Options

These options can be used with any command:

| Option | Short | Description |
|--------|-------|-------------|
| `--verbose` | `-v` | Enable verbose output |
| `--dry-run` | `-d` | Show what would be done without executing |
| `--force` | `-f` | Force operations (skip confirmations) |
| `--background` | `-b` | Run script in background |
| `--help` | `-h` | Show help message |
| `--version` |  | Show version information |

## Repository Management Commands

### add

Add a git repository to the cache.

**Syntax:**
```bash
qi add <repository-url> [name]
```

**Parameters:**
- `repository-url`: Git repository URL (HTTPS or SSH)
- `name`: Optional custom name for the repository

**Examples:**
```bash
qi add https://github.com/user/scripts.git
qi add https://github.com/user/tools.git mytools
qi add git@github.com:company/deploy.git deploy
```

**Output:**
- Success message with repository name and cache location
- Number of scripts found in the repository
- Warning if repository name conflicts exist

### remove

Remove a repository from the cache.

**Syntax:**
```bash
qi remove <name>
```

**Parameters:**
- `name`: Name of the repository to remove

**Examples:**
```bash
qi remove scripts
qi remove mytools
```

**Behavior:**
- Prompts for confirmation before removal (unless `--force` is used)
- Completely removes repository directory from cache
- Updates script index

### update

Update cached repositories to their latest versions.

**Syntax:**
```bash
qi update [repository-name]
```

**Parameters:**
- `repository-name`: Optional. Name of specific repository to update

**Examples:**
```bash
qi update                    # Update all repositories
qi update deploy            # Update specific repository
qi --force update mytools   # Force update (discard local changes)
```

**Output:**
- Update status for each repository
- Number of new commits pulled
- List of new scripts found
- Conflict resolution prompts if needed

## Information Commands

### list

List available scripts from cached repositories.

**Syntax:**
```bash
qi list [format]
```

**Format Options:**
- `full` (default): Complete script information
- `names`: Script names only
- `repos`: Group by repository

**Examples:**
```bash
qi list              # Full listing
qi list names        # Names only
qi list repos        # Grouped by repository
```

**Output:**
```
Available scripts:
==================

deploy               deploy-scripts    /server/deploy.bash
rollback            deploy-scripts    /server/rollback.bash
backup              backup-tools      /backup.bash
backup              deploy-scripts    /database/backup.bash

Total: 4 scripts (3 unique names)
Note: 1 script(s) have name conflicts and will require selection
```

### list-repos

List all cached repositories with their status.

**Syntax:**
```bash
qi list-repos
```

**Output:**
```
Cached repositories:
===================

Name:    deploy-scripts
URL:     https://github.com/company/deploy-scripts.git
Added:   2023-10-15
Status:  ✓ up-to-date

Name:    backup-tools
URL:     https://github.com/user/backup-tools.git
Added:   2023-10-14
Status:  ↓ behind

Total: 2 repositories
```

### status

Show detailed cache status and repository information.

**Syntax:**
```bash
qi status
```

**Output:**
- Cache statistics (directories, total size)
- Repository status with branches and commit information
- Script index status and age
- Recommendations for maintenance

### config

Show or manage configuration.

**Syntax:**
```bash
qi config [action]
```

**Actions:**
- `show` (default): Display current configuration
- `init`: Create default configuration file

**Examples:**
```bash
qi config           # Show configuration
qi config show      # Show configuration
qi config init      # Create default config
```

## Script Execution

### Execute Script

Run a script by name from cached repositories.

**Syntax:**
```bash
qi <script-name> [script-arguments]
```

**Parameters:**
- `script-name`: Name of the script to execute (without .bash extension)
- `script-arguments`: Arguments to pass to the script

**Examples:**
```bash
qi deploy
qi backup --env production
qi setup --config /path/to/config
qi --dry-run deploy          # Preview without executing
qi --background long-task    # Run in background
```

**Conflict Resolution:**
When multiple repositories have the same script name:
```
Multiple scripts found with name 'backup':
1. deploy-scripts (https://github.com/company/deploy-scripts.git)
2. backup-tools (https://github.com/user/backup-tools.git)
Select repository [1-2]: 1
```

## Utility Commands

### help

Show help information.

**Syntax:**
```bash
qi help
qi --help
qi -h
```

### version

Show version information.

**Syntax:**
```bash
qi version
qi --version
```

**Output:**
```
qi version 1.0.0
```

## Exit Codes

qi uses standard exit codes:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Repository not found |
| 4 | Script not found |
| 5 | Network/Git error |
| 6 | Permission error |
| 130 | Interrupted by user (Ctrl+C) |

## Examples by Use Case

### Initial Setup
```bash
# Install qi
curl -fsSL https://github.com/yjmrobert/qi/raw/main/install.sh | bash

# Add your first repository
qi add https://github.com/mycompany/scripts.git company

# List available scripts
qi list
```

### Daily Operations
```bash
# Update all repositories
qi update

# Run deployment script
qi deploy --env production

# Check status
qi status
```

### Maintenance
```bash
# Update specific repository
qi update company

# Remove unused repository
qi remove old-scripts

# Check cache status
qi status
```

### Troubleshooting
```bash
# Verbose output for debugging
qi --verbose deploy

# Dry run to see what would happen
qi --dry-run update

# Force update to resolve conflicts
qi --force update problematic-repo
```