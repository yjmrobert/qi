# Basic Usage

This page covers the fundamental operations of qi and how to use them effectively.

## Repository Management

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

# Add repository using SSH
qi add git@github.com:user/scripts.git
```

### Removing Repositories

Remove a repository from the qi cache:

```bash
qi remove <name>
```

**Parameters:**

- `<name>`: The name of the repository to remove (either custom name or default repository name)

**Examples:**

```bash
# Remove repository by name
qi remove scripts

# Remove repository by custom name
qi remove devtools
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

## Script Execution

### Running Scripts

Execute a bash script by name from any cached repository:

```bash
qi <script-name> [script-arguments]
```

**Parameters:**

- `<script-name>`: The name of the `.bash` file to execute (without the `.bash` extension)
- `[script-arguments]`: Optional arguments to pass to the script

**Behavior:**

- Searches all cached repositories for files matching `<script-name>.bash`
- If one match is found, executes the script immediately
- If multiple matches are found, prompts you to select which repository's script to run
- If no matches are found, displays an error message

**Examples:**

```bash
# Execute a script named 'deploy.bash'
qi deploy

# Execute a script with arguments
qi backup --env production --force

# Execute a script named 'setup.bash'
qi setup
```

### Handling Script Conflicts

When multiple repositories contain scripts with the same name, qi will prompt you to choose:

```bash
qi backup
# Output:
# Multiple scripts found with name 'backup':
# 1. deploy (https://github.com/company/deployment-scripts.git)
# 2. tools (https://github.com/user/personal-tools.git)
# Select repository [1-2]: 1
# Executing backup.bash from deploy repository...
```

## Information Commands

### Listing Scripts

List all available scripts from cached repositories:

```bash
qi list [format]
```

**Format options:**

- `full` (default): Shows script name, repository, and path
- `names`: Shows only script names
- `repos`: Groups scripts by repository

**Examples:**

```bash
# List all scripts with full information
qi list

# List only script names
qi list names

# Group scripts by repository
qi list repos
```

### Listing Repositories

List all cached repositories:

```bash
qi list-repos
```

This shows:

- Repository name
- Repository URL
- Date added
- Current status (up-to-date, behind, ahead, modified)

### Checking Status

Show cache status and repository information:

```bash
qi status
```

This displays:

- Cache statistics (total repositories, total scripts)
- Repository status for each cached repository
- Script index status and last update time

## Advanced Usage

### Passing Arguments to Scripts

You can pass arguments to your scripts:

```bash
qi deploy --env production --force
qi backup --destination /backup/location
qi setup --config /path/to/config.yml
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

### Verbose Output

Enable verbose output for debugging:

```bash
qi --verbose deploy
qi -v update
```

## Script Organization Best Practices

### Repository Structure

Organize your scripts in a logical directory structure:

```
my-scripts/
├── deployment/
│   ├── deploy.bash
│   ├── rollback.bash
│   └── health-check.bash
├── backup/
│   ├── database-backup.bash
│   └── file-backup.bash
└── maintenance/
    ├── cleanup.bash
    └── update-system.bash
```

### Script Naming

- Use descriptive names for your scripts
- Use hyphens or underscores for multi-word names
- Keep names short but meaningful
- Avoid special characters that might cause issues in the shell

### Script Documentation

Include help information in your scripts:

```bash
#!/bin/bash
# deploy.bash - Deploy application to specified environment
# Usage: deploy.bash [--env ENV] [--force]

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [--env ENV] [--force]"
    echo "Deploy application to specified environment"
    echo ""
    echo "Options:"
    echo "  --env ENV    Target environment (default: staging)"
    echo "  --force      Force deployment without confirmation"
    exit 0
fi
```