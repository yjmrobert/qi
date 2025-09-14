# Quick Start Guide

This guide will get you up and running with qi in just a few minutes.

## Step 1: Install qi

Install qi with the quick installation command:

```bash
curl -fsSL https://github.com/yjmrobert/qi/raw/main/install.sh | bash
```

## Step 2: Add Your First Repository

Add a git repository containing bash scripts:

```bash
# Add repository with default name
qi add https://github.com/user/scripts.git

# Or add with a custom name
qi add https://github.com/user/devtools.git devtools
```

## Step 3: List Available Scripts

See what scripts are available:

```bash
qi list
```

This will show all `.bash` files found in your cached repositories.

## Step 4: Execute a Script

Run a script by name:

```bash
qi deploy
```

If multiple repositories have a script with the same name, qi will ask you to choose which one to run.

## Step 5: Keep Repositories Updated

Update your cached repositories to get the latest scripts:

```bash
# Update all repositories
qi update

# Update specific repository
qi update devtools
```

## Complete Workflow Example

Here's a complete example workflow:

```bash
# 1. Add some repositories
qi add https://github.com/company/deployment-scripts.git deploy
qi add https://github.com/user/personal-tools.git tools
qi add https://github.com/team/utilities.git

# 2. List all available scripts
qi list

# 3. Execute a script
qi setup

# 4. Handle script conflicts (if backup.bash exists in multiple repos)
qi backup
# Output:
# Multiple scripts found with name 'backup':
# 1. deploy (https://github.com/company/deployment-scripts.git)
# 2. tools (https://github.com/user/personal-tools.git)
# Select repository [1-2]: 1

# 5. Update repositories
qi update

# 6. Remove a repository when no longer needed
qi remove tools
```

## Script Organization

Your repositories should contain `.bash` files in any directory structure. For example:

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

All scripts (`deploy`, `rollback`, `backup`, `restore`, `health-check`) will be discoverable by qi.

## Next Steps

- Read the [Basic Usage](usage/basic.md) guide for more detailed information
- Learn about [Configuration](usage/configuration.md) options
- Explore all available [Commands](usage/commands.md)
- Check out [Troubleshooting](usage/troubleshooting.md) if you encounter issues