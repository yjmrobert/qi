# Architecture

This document describes the architecture and design principles of the qi project.

## Overview

qi is designed as a modular bash application with a clear separation of concerns. The architecture follows Unix philosophy principles: do one thing well, be composable, and use text streams.

## High-Level Architecture

```
┌─────────────────┐
│   qi (main)     │  ← Main executable and CLI interface
└─────────────────┘
         │
         ▼
┌─────────────────┐
│   Library       │  ← Modular library functions
│   Functions     │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│   File System   │  ← Cache, config, and metadata storage
│   & Git         │
└─────────────────┘
```

## Component Architecture

### Core Components

1. **Main Executable (`qi`)**
   - Command-line interface
   - Argument parsing
   - Command dispatching
   - Error handling

2. **Library Modules (`lib/`)**
   - `cache.sh` - Cache management
   - `config.sh` - Configuration handling
   - `git-ops.sh` - Git operations
   - `script-ops.sh` - Script discovery and execution
   - `utils.sh` - Utility functions

3. **Storage Layer**
   - File system cache
   - Configuration files
   - Metadata storage

## Module Details

### Main Executable (qi)

**Responsibilities:**
- Parse command-line arguments
- Initialize environment
- Load library modules
- Dispatch commands to appropriate handlers
- Handle global error conditions

**Key Functions:**
- `main()` - Entry point and command dispatcher
- `parse_args()` - Command-line argument parsing
- `init_qi()` - Environment initialization
- `show_usage()` - Help system

**Design Patterns:**
- Command pattern for subcommand handling
- Template method for common operations

### Cache Module (lib/cache.sh)

**Responsibilities:**
- Manage repository cache directory structure
- Handle cache locking for concurrent access
- Provide cache metadata operations
- Implement cache cleanup and maintenance

**Key Functions:**
```bash
init_cache()                    # Initialize cache directory
acquire_cache_lock()            # Acquire exclusive cache lock
release_cache_lock()            # Release cache lock
get_cache_stats()              # Get cache statistics
cleanup_cache()                # Clean up unused cache entries
```

**Data Structures:**
```
~/.qi/cache/
├── repository-name-1/          # Git repository clone
├── repository-name-2/
└── .qi-metadata/               # Metadata directory
    ├── repositories.json       # Repository index
    ├── scripts.json           # Script index
    └── locks/                 # Lock files
        └── cache.lock
```

### Configuration Module (lib/config.sh)

**Responsibilities:**
- Load and parse configuration files
- Handle environment variable overrides
- Provide configuration validation
- Manage default values

**Key Functions:**
```bash
init_config()                  # Initialize configuration system
load_config()                  # Load configuration from file
get_config_value()             # Get configuration value
set_config_value()             # Set configuration value
validate_config()              # Validate configuration
```

**Configuration Hierarchy:**
1. Command-line arguments (highest priority)
2. Environment variables
3. User configuration file (`~/.qi/config`)
4. System configuration file (`/etc/qi/config`)
5. Built-in defaults (lowest priority)

### Git Operations Module (lib/git-ops.sh)

**Responsibilities:**
- Handle git repository operations
- Manage authentication and network issues
- Provide git status and metadata queries
- Handle repository updates and synchronization

**Key Functions:**
```bash
clone_repository()             # Clone git repository
update_repository()            # Update repository to latest
validate_git_url()             # Validate git URL format
get_repository_status()        # Get git status information
get_repository_branch()        # Get current branch
normalize_git_url()            # Normalize URL format
```

**Git Integration:**
- Uses system git configuration
- Respects git credentials and SSH keys
- Handles both HTTPS and SSH URLs
- Implements retry logic for network issues

### Script Operations Module (lib/script-ops.sh)

**Responsibilities:**
- Discover scripts in cached repositories
- Build and maintain script index
- Handle script execution
- Manage script name conflicts

**Key Functions:**
```bash
discover_scripts()             # Scan repositories for scripts
build_script_index()           # Build searchable script index
find_script()                  # Find script by name
execute_script()               # Execute script with arguments
resolve_script_conflict()      # Handle duplicate script names
```

**Script Discovery:**
- Searches for `*.bash` files recursively
- Builds index for fast lookups
- Handles script name conflicts
- Caches results for performance

### Utilities Module (lib/utils.sh)

**Responsibilities:**
- Common utility functions
- String manipulation and validation
- File system operations
- Logging and output formatting

**Key Functions:**
```bash
log()                          # Logging with levels
print_color()                  # Colored output
validate_repo_name()           # Repository name validation
confirm()                      # User confirmation prompts
time_diff()                    # Time difference calculations
```

## Data Flow

### Adding a Repository

```
User Input → Validation → Git Clone → Cache Storage → Index Update
     │            │            │            │             │
     ▼            ▼            ▼            ▼             ▼
qi add URL → validate_git_url → git clone → store metadata → update index
```

### Executing a Script

```
User Input → Script Discovery → Conflict Resolution → Execution
     │              │                 │                │
     ▼              ▼                 ▼                ▼
qi script-name → find_script → resolve_conflicts → execute_script
```

### Updating Repositories

```
User Input → Repository List → Git Operations → Index Update
     │              │               │              │
     ▼              ▼               ▼              ▼
qi update → list_cached_repos → git pull → rebuild_index
```

## Design Principles

### Modularity

- Each module has a single responsibility
- Clear interfaces between modules
- Minimal dependencies between modules
- Easy to test individual components

### Error Handling

- Fail fast with clear error messages
- Graceful degradation where possible
- Consistent error codes and messages
- Proper cleanup on errors

### Performance

- Lazy loading of expensive operations
- Caching of frequently accessed data
- Efficient file system operations
- Minimal external command calls

### Reliability

- Atomic operations where possible
- Lock files for concurrent access
- Data validation and sanitization
- Recovery from corrupt state

## Concurrency Model

### File Locking

qi uses file-based locking to handle concurrent access:

```bash
# Acquire exclusive lock
acquire_cache_lock() {
    local lock_file="$CACHE_DIR/.qi-metadata/locks/cache.lock"
    local timeout=30
    
    # Implementation uses flock for atomic locking
    exec 200>"$lock_file"
    if ! flock -x -w "$timeout" 200; then
        return 1
    fi
    return 0
}
```

### Atomic Operations

- Repository cloning to temporary directory, then move
- Configuration updates using temporary files
- Index rebuilding with atomic replacement

## Security Considerations

### Input Validation

- All user inputs are validated
- Repository URLs are sanitized
- File paths are validated to prevent directory traversal
- Script names are validated against allowed patterns

### File Permissions

- Cache directory has restricted permissions (700)
- Configuration files have restricted permissions (600)
- Scripts maintain their original permissions

### Git Security

- Uses system git configuration
- No credential storage in qi
- Respects git security settings
- URL validation prevents malicious URLs

## Extension Points

### Plugin Architecture (Future)

Planned extension points for future development:

```bash
# Plugin hooks
before_repository_add()
after_repository_add()
before_script_execute()
after_script_execute()
```

### Custom Script Discovery

- Configurable file patterns
- Custom directory exclusions
- Repository-specific configuration

### Output Formatters

- JSON output format
- XML output format
- Custom formatting plugins

## Testing Architecture

### Test Organization

```
tests/
├── unit/                      # Unit tests for individual functions
├── integration/               # Integration tests for workflows
├── fixtures/                  # Test data and fixtures
└── mocks/                    # Mock implementations
```

### Test Isolation

- Each test runs in isolated environment
- Temporary directories for test data
- Mock external dependencies
- No shared state between tests

## Deployment Architecture

### Installation Methods

1. **Curl Installation**
   - Single command installation
   - Automatic dependency detection
   - System-wide installation

2. **Manual Installation**
   - Git clone and copy
   - Custom installation paths
   - Development installations

### File Layout

```
/usr/local/bin/qi              # Main executable
/usr/local/bin/qi-lib/         # Library modules
~/.qi/                         # User data directory
├── cache/                     # Repository cache
├── config                     # User configuration
└── logs/                      # Log files (future)
```

## Performance Characteristics

### Time Complexity

- Repository addition: O(1) for metadata, O(n) for git clone
- Script discovery: O(n) where n is total number of files
- Script execution: O(1) lookup, O(m) for execution
- Repository update: O(k) where k is number of repositories

### Space Complexity

- Cache size grows linearly with number of repositories
- Script index size grows linearly with number of scripts
- Metadata overhead is minimal

### Optimization Strategies

- Lazy script discovery (only when needed)
- Incremental index updates
- Efficient file system traversal
- Minimal memory usage

## Future Architecture Considerations

### Scalability

- Support for large numbers of repositories
- Distributed cache architecture
- Repository prioritization
- Background update processes

### Extensibility

- Plugin system for custom functionality
- API for external tool integration
- Configuration schema versioning
- Backward compatibility guarantees