# Library Functions Reference

This document provides a complete reference for all library functions in qi.

## Cache Module (lib/cache.sh)

Functions for managing the repository cache.

### init_cache()

Initialize the cache directory structure.

**Description:** Creates the cache directory and required subdirectories if they don't exist.

**Parameters:** None

**Returns:**
- `0` - Success
- `1` - Failed to create cache directory

**Example:**
```bash
if init_cache; then
    echo "Cache initialized successfully"
else
    echo "Failed to initialize cache"
fi
```

### acquire_cache_lock()

Acquire an exclusive lock on the cache.

**Description:** Obtains a file-based lock to prevent concurrent cache modifications.

**Parameters:** None

**Returns:**
- `0` - Lock acquired successfully
- `1` - Failed to acquire lock (timeout or error)

**Example:**
```bash
if acquire_cache_lock; then
    # Perform cache operations
    release_cache_lock
else
    echo "Could not acquire cache lock"
fi
```

### release_cache_lock()

Release the cache lock.

**Description:** Releases the file-based lock acquired by `acquire_cache_lock()`.

**Parameters:** None

**Returns:**
- `0` - Always succeeds

**Example:**
```bash
acquire_cache_lock
# ... do work ...
release_cache_lock
```

### repo_exists(name)

Check if a repository exists in the cache.

**Description:** Verifies that a repository with the given name exists in the cache.

**Parameters:**
- `$1` - Repository name to check

**Returns:**
- `0` - Repository exists
- `1` - Repository does not exist

**Example:**
```bash
if repo_exists "my-scripts"; then
    echo "Repository exists"
else
    echo "Repository not found"
fi
```

### get_repo_dir(name)

Get the full path to a repository directory.

**Description:** Returns the absolute path to the specified repository in the cache.

**Parameters:**
- `$1` - Repository name

**Returns:**
- `0` - Success (path printed to stdout)
- `1` - Repository not found

**Example:**
```bash
repo_dir=$(get_repo_dir "my-scripts")
echo "Repository located at: $repo_dir"
```

### list_cached_repos()

List all cached repositories.

**Description:** Returns a list of all repository names currently in the cache.

**Parameters:** None

**Returns:**
- `0` - Success (repository names printed to stdout, one per line)

**Example:**
```bash
while IFS= read -r repo_name; do
    echo "Found repository: $repo_name"
done < <(list_cached_repos)
```

### get_cache_stats()

Display cache statistics.

**Description:** Shows information about cache size, number of repositories, etc.

**Parameters:** None

**Returns:**
- `0` - Always succeeds

**Example:**
```bash
get_cache_stats
```

### remove_repo_from_cache(name)

Remove a repository from the cache.

**Description:** Completely removes a repository directory and associated metadata.

**Parameters:**
- `$1` - Repository name to remove

**Returns:**
- `0` - Repository removed successfully
- `1` - Repository not found or removal failed

**Example:**
```bash
if remove_repo_from_cache "old-repo"; then
    echo "Repository removed"
else
    echo "Failed to remove repository"
fi
```

## Configuration Module (lib/config.sh)

Functions for handling configuration management.

### init_config()

Initialize the configuration system.

**Description:** Sets up configuration directory and loads configuration files.

**Parameters:** None

**Returns:**
- `0` - Configuration initialized successfully
- `1` - Configuration initialization failed

**Example:**
```bash
if init_config; then
    echo "Configuration ready"
else
    echo "Configuration error"
fi
```

### load_config()

Load configuration from files and environment.

**Description:** Reads configuration from files and environment variables in priority order.

**Parameters:** None

**Returns:**
- `0` - Configuration loaded successfully
- `1` - Configuration loading failed

**Example:**
```bash
load_config
echo "Cache directory: $CACHE_DIR"
```

### get_config_value(key, default)

Get a configuration value.

**Description:** Retrieves a configuration value with optional default.

**Parameters:**
- `$1` - Configuration key
- `$2` - Default value (optional)

**Returns:**
- `0` - Success (value printed to stdout)
- `1` - Key not found and no default provided

**Example:**
```bash
timeout=$(get_config_value "git_timeout" "30")
echo "Git timeout: $timeout seconds"
```

### set_config_value(key, value)

Set a configuration value.

**Description:** Sets a configuration value in the user configuration file.

**Parameters:**
- `$1` - Configuration key
- `$2` - Configuration value

**Returns:**
- `0` - Value set successfully
- `1` - Failed to set value

**Example:**
```bash
if set_config_value "verbose" "true"; then
    echo "Verbose mode enabled"
fi
```

### show_config()

Display current configuration.

**Description:** Shows all current configuration values and their sources.

**Parameters:** None

**Returns:**
- `0` - Always succeeds

**Example:**
```bash
show_config
```

### create_default_config()

Create a default configuration file.

**Description:** Creates a configuration file with default values.

**Parameters:** None

**Returns:**
- `0` - Configuration file created
- `1` - Failed to create configuration file

**Example:**
```bash
if create_default_config; then
    echo "Default configuration created"
fi
```

## Git Operations Module (lib/git-ops.sh)

Functions for git repository operations.

### validate_git_url(url)

Validate a git repository URL.

**Description:** Checks if the provided URL is a valid git repository URL.

**Parameters:**
- `$1` - Git repository URL to validate

**Returns:**
- `0` - URL is valid
- `1` - URL is invalid

**Example:**
```bash
if validate_git_url "https://github.com/user/repo.git"; then
    echo "Valid git URL"
else
    echo "Invalid git URL"
fi
```

### normalize_git_url(url)

Normalize a git repository URL.

**Description:** Converts git URL to a standard format.

**Parameters:**
- `$1` - Git repository URL to normalize

**Returns:**
- `0` - Success (normalized URL printed to stdout)
- `1` - Invalid URL

**Example:**
```bash
normalized=$(normalize_git_url "git@github.com:user/repo.git")
echo "Normalized URL: $normalized"
```

### clone_repository(url, name)

Clone a git repository to the cache.

**Description:** Clones the specified repository to the cache directory.

**Parameters:**
- `$1` - Git repository URL
- `$2` - Local repository name

**Returns:**
- `0` - Repository cloned successfully
- `1` - Clone operation failed

**Example:**
```bash
if clone_repository "https://github.com/user/repo.git" "my-repo"; then
    echo "Repository cloned successfully"
else
    echo "Clone failed"
fi
```

### update_repository(name, cache_dir, force)

Update a repository to the latest version.

**Description:** Performs git pull to update repository to latest commits.

**Parameters:**
- `$1` - Repository name
- `$2` - Cache directory path
- `$3` - Force update flag (true/false)

**Returns:**
- `0` - Repository updated successfully
- `1` - Update failed

**Example:**
```bash
if update_repository "my-repo" "$CACHE_DIR" "false"; then
    echo "Repository updated"
else
    echo "Update failed"
fi
```

### get_repository_status(name)

Get the git status of a repository.

**Description:** Returns the git status (clean, behind, ahead, modified, etc.).

**Parameters:**
- `$1` - Repository name

**Returns:**
- `0` - Success (status printed to stdout)
- `1` - Repository not found or git error

**Example:**
```bash
status=$(get_repository_status "my-repo")
echo "Repository status: $status"
```

### get_repository_branch(name)

Get the current branch of a repository.

**Description:** Returns the currently checked out branch name.

**Parameters:**
- `$1` - Repository name

**Returns:**
- `0` - Success (branch name printed to stdout)
- `1` - Repository not found or git error

**Example:**
```bash
branch=$(get_repository_branch "my-repo")
echo "Current branch: $branch"
```

### get_repo_name_from_url(url)

Extract repository name from URL.

**Description:** Extracts the repository name from a git URL.

**Parameters:**
- `$1` - Git repository URL

**Returns:**
- `0` - Success (repository name printed to stdout)
- `1` - Invalid URL

**Example:**
```bash
name=$(get_repo_name_from_url "https://github.com/user/my-repo.git")
echo "Repository name: $name"  # Output: my-repo
```

## Script Operations Module (lib/script-ops.sh)

Functions for script discovery and execution.

### discover_scripts()

Discover all scripts in cached repositories.

**Description:** Scans all cached repositories for `.bash` files and builds an index.

**Parameters:** None

**Returns:**
- `0` - Script discovery completed successfully
- `1` - Discovery failed

**Example:**
```bash
if discover_scripts; then
    echo "Script discovery completed"
else
    echo "Script discovery failed"
fi
```

### find_script(name)

Find script(s) by name.

**Description:** Searches for scripts matching the given name across all repositories.

**Parameters:**
- `$1` - Script name to find

**Returns:**
- `0` - Script(s) found (results printed to stdout)
- `1` - No scripts found

**Example:**
```bash
if find_script "deploy"; then
    echo "Found deploy script(s)"
else
    echo "No deploy script found"
fi
```

### execute_script(name, args...)

Execute a script by name.

**Description:** Finds and executes a script, handling conflicts if multiple scripts exist.

**Parameters:**
- `$1` - Script name to execute
- `$2...$n` - Arguments to pass to the script

**Returns:**
- `0` - Script executed successfully
- `1` - Script not found or execution failed
- Exit code of the executed script

**Example:**
```bash
if execute_script "deploy" "--env" "production"; then
    echo "Deployment completed successfully"
else
    echo "Deployment failed"
fi
```

### list_all_scripts(cache_dir, format)

List all available scripts.

**Description:** Lists all scripts found in cached repositories.

**Parameters:**
- `$1` - Cache directory path
- `$2` - Output format (full, name, repo)

**Returns:**
- `0` - Success (script list printed to stdout)

**Example:**
```bash
list_all_scripts "$CACHE_DIR" "full"
```

### get_script_count()

Get total number of scripts.

**Description:** Returns the total count of scripts in the index.

**Parameters:** None

**Returns:**
- `0` - Success (count printed to stdout)

**Example:**
```bash
count=$(get_script_count)
echo "Total scripts: $count"
```

### get_unique_script_count()

Get number of unique script names.

**Description:** Returns the count of unique script names (ignoring duplicates).

**Parameters:** None

**Returns:**
- `0` - Success (count printed to stdout)

**Example:**
```bash
unique_count=$(get_unique_script_count)
echo "Unique script names: $unique_count"
```

## Utilities Module (lib/utils.sh)

Common utility functions.

### log(level, message)

Log a message with the specified level.

**Description:** Outputs log messages based on verbosity settings.

**Parameters:**
- `$1` - Log level (ERROR, WARN, INFO, DEBUG)
- `$2` - Log message

**Returns:**
- `0` - Always succeeds

**Example:**
```bash
log "INFO" "Starting operation"
log "ERROR" "Operation failed"
```

### print_color(color, text)

Print colored text.

**Description:** Outputs text in the specified color if terminal supports it.

**Parameters:**
- `$1` - Color name or code
- `$2` - Text to print

**Returns:**
- `0` - Always succeeds

**Example:**
```bash
print_color "red" "Error message"
print_color "green" "Success message"
```

### validate_repo_name(name)

Validate a repository name.

**Description:** Checks if a repository name contains only allowed characters.

**Parameters:**
- `$1` - Repository name to validate

**Returns:**
- `0` - Name is valid
- `1` - Name is invalid

**Example:**
```bash
if validate_repo_name "my-repo_v1.0"; then
    echo "Valid repository name"
else
    echo "Invalid repository name"
fi
```

### confirm(message)

Prompt user for confirmation.

**Description:** Displays a confirmation prompt and waits for user input.

**Parameters:**
- `$1` - Confirmation message

**Returns:**
- `0` - User confirmed (y/yes)
- `1` - User declined (n/no) or invalid input

**Example:**
```bash
if confirm "Delete repository?"; then
    echo "User confirmed deletion"
else
    echo "User cancelled operation"
fi
```

### check_dependencies()

Check for required system dependencies.

**Description:** Verifies that all required tools (git, bash, etc.) are available.

**Parameters:** None

**Returns:**
- `0` - All dependencies satisfied
- `1` - One or more dependencies missing

**Example:**
```bash
if check_dependencies; then
    echo "All dependencies available"
else
    echo "Missing required dependencies"
fi
```

### time_diff(start, end)

Calculate time difference.

**Description:** Calculates and formats the difference between two timestamps.

**Parameters:**
- `$1` - Start timestamp (seconds since epoch)
- `$2` - End timestamp (seconds since epoch)

**Returns:**
- `0` - Success (formatted time difference printed to stdout)

**Example:**
```bash
start=$(date +%s)
sleep 2
end=$(date +%s)
diff=$(time_diff "$start" "$end")
echo "Operation took: $diff"
```

### generate_unique_repo_name(base_name)

Generate a unique repository name.

**Description:** Creates a unique repository name by appending a number if needed.

**Parameters:**
- `$1` - Base repository name

**Returns:**
- `0` - Success (unique name printed to stdout)

**Example:**
```bash
unique_name=$(generate_unique_repo_name "my-repo")
echo "Unique name: $unique_name"  # Might output: my-repo-2
```

## Error Codes

Standard error codes used throughout the library:

| Code | Constant | Description |
|------|----------|-------------|
| 0 | SUCCESS | Operation completed successfully |
| 1 | ERROR_GENERAL | General error |
| 2 | ERROR_INVALID_ARGS | Invalid arguments provided |
| 3 | ERROR_REPO_NOT_FOUND | Repository not found |
| 4 | ERROR_SCRIPT_NOT_FOUND | Script not found |
| 5 | ERROR_NETWORK | Network or git operation failed |
| 6 | ERROR_PERMISSION | Permission denied |
| 130 | ERROR_INTERRUPTED | Operation interrupted by user |

## Global Variables

Key global variables used by library functions:

| Variable | Description | Default |
|----------|-------------|---------|
| `CACHE_DIR` | Cache directory path | `~/.qi/cache` |
| `CONFIG_FILE` | Configuration file path | `~/.qi/config` |
| `VERBOSE` | Enable verbose output | `false` |
| `DRY_RUN` | Enable dry-run mode | `false` |
| `FORCE` | Force operations | `false` |