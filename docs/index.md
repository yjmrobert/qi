# qi - Git Repository Script Manager

`qi` is a Linux command line tool that manages a cache of remote git repositories and allows you to quickly execute bash scripts from them by name.

## Overview

`qi` simplifies the process of managing and executing bash scripts from multiple git repositories. Instead of manually cloning repositories and searching for scripts, `qi` maintains a local cache of repositories and provides fast script execution by name.

### Key Features

- **Repository Management**: Add remote git repositories to a local cache
- **Script Discovery**: Automatically finds `.bash` files across all cached repositories
- **Quick Execution**: Run scripts by name with a simple command
- **Conflict Resolution**: Handles duplicate script names by prompting for repository selection
- **Clean Removal**: Remove repositories from the cache when no longer needed

## Quick Start

### Installation

Install qi with a single command:

```bash
curl -fsSL https://github.com/yjmrobert/qi/raw/main/install.sh | bash
```

### Basic Usage

```bash
# Add a repository
qi add https://github.com/user/scripts.git

# Execute a script
qi deploy

# Update repositories
qi update

# List available scripts
qi list
```

## Getting Help

- **Issues**: Report bugs and feature requests on [GitHub](https://github.com/yjmrobert/qi/issues)
- **Documentation**: Browse the complete documentation in this site
- **Community**: Join our discussion forum or chat channel

---

**Version**: 1.0.0  
**Maintainer**: qi Project Team