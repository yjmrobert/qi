# Troubleshooting

This page covers common issues you might encounter with qi and how to resolve them.

## Installation Issues

### Command Not Found

**Problem:** `qi: command not found` after installation.

**Solutions:**

1. **Check if qi is in PATH:**
   ```bash
   which qi
   echo $PATH | grep -o '/usr/local/bin'
   ```

2. **Add /usr/local/bin to PATH:**
   ```bash
   echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

3. **Verify installation:**
   ```bash
   ls -la /usr/local/bin/qi
   ls -la /usr/local/bin/qi-lib/
   ```

### Permission Denied

**Problem:** Permission denied when running qi or during installation.

**Solutions:**

1. **Make qi executable:**
   ```bash
   sudo chmod +x /usr/local/bin/qi
   ```

2. **Fix library permissions:**
   ```bash
   sudo chmod -R 755 /usr/local/bin/qi-lib/
   ```

3. **Use sudo for installation:**
   ```bash
   curl -fsSL https://github.com/yjmrobert/qi/raw/main/install.sh | sudo bash
   ```

## Repository Management Issues

### Repository Clone Fails

**Problem:** Cannot clone repository.

**Diagnosis:**
```bash
# Test git access directly
git clone <repository-url> /tmp/test-clone
```

**Solutions:**

1. **Check network connectivity:**
   ```bash
   ping github.com
   curl -I https://github.com
   ```

2. **Verify git credentials (HTTPS):**
   ```bash
   git config --global --list | grep credential
   git config --global credential.helper store
   ```

3. **Test SSH access (SSH URLs):**
   ```bash
   ssh -T git@github.com
   ssh-add -l  # List SSH keys
   ```

4. **Check repository URL:**
   ```bash
   # Ensure URL is correct and accessible
   curl -I https://github.com/user/repo.git
   ```

### Repository Update Fails

**Problem:** `qi update` fails for specific repositories.

**Diagnosis:**
```bash
# Check repository status manually
cd ~/.qi/cache/repository-name
git status
git remote -v
git pull
```

**Solutions:**

1. **Reset repository to clean state:**
   ```bash
   cd ~/.qi/cache/repository-name
   git reset --hard HEAD
   git clean -fd
   git pull
   ```

2. **Force update with qi:**
   ```bash
   qi --force update repository-name
   ```

3. **Remove and re-add repository:**
   ```bash
   qi remove repository-name
   qi add <repository-url> repository-name
   ```

### Authentication Issues

**Problem:** Git authentication failures.

**Solutions:**

1. **For HTTPS repositories:**
   ```bash
   # Update stored credentials
   git config --global credential.helper store
   git pull  # Will prompt for credentials
   
   # Or use personal access tokens (GitHub)
   # Username: your-username
   # Password: your-personal-access-token
   ```

2. **For SSH repositories:**
   ```bash
   # Generate new SSH key
   ssh-keygen -t rsa -b 4096 -C "your.email@example.com"
   
   # Add to SSH agent
   ssh-add ~/.ssh/id_rsa
   
   # Add public key to GitHub/GitLab
   cat ~/.ssh/id_rsa.pub
   
   # Test connection
   ssh -T git@github.com
   ```

## Script Execution Issues

### Script Not Found

**Problem:** qi cannot find a script that exists in the repository.

**Diagnosis:**
```bash
# Check if script exists
qi list | grep script-name

# Check repository contents
ls -la ~/.qi/cache/repository-name/
find ~/.qi/cache/repository-name/ -name "*.bash"
```

**Solutions:**

1. **Refresh script index:**
   ```bash
   qi list  # This rebuilds the script index
   ```

2. **Update repository:**
   ```bash
   qi update repository-name
   ```

3. **Check script file extension:**
   ```bash
   # qi looks for .bash files
   find ~/.qi/cache/repository-name/ -name "*script-name*"
   ```

### Script Execution Fails

**Problem:** Script exists but fails to execute.

**Diagnosis:**
```bash
# Run script directly to see error
cd ~/.qi/cache/repository-name
bash path/to/script.bash

# Check script permissions
ls -la path/to/script.bash
```

**Solutions:**

1. **Make script executable:**
   ```bash
   chmod +x ~/.qi/cache/repository-name/path/to/script.bash
   ```

2. **Check script syntax:**
   ```bash
   bash -n ~/.qi/cache/repository-name/path/to/script.bash
   ```

3. **Run with verbose output:**
   ```bash
   qi --verbose script-name
   ```

### Multiple Scripts Conflict

**Problem:** Multiple repositories have scripts with the same name.

**Expected Behavior:** qi should prompt you to choose which script to run.

**If prompt doesn't appear:**
```bash
# Check all matching scripts
qi list | grep script-name

# Force script discovery refresh
rm ~/.qi/cache/.qi-metadata/scripts.json
qi list
```

## Cache Issues

### Cache Corruption

**Problem:** qi behaves unexpectedly, cache seems corrupted.

**Solutions:**

1. **Clear cache completely:**
   ```bash
   rm -rf ~/.qi/cache/
   qi list  # This will recreate the cache structure
   ```

2. **Rebuild script index:**
   ```bash
   rm ~/.qi/cache/.qi-metadata/scripts.json
   qi list
   ```

3. **Re-add all repositories:**
   ```bash
   # List current repositories first
   qi list-repos
   
   # Remove and re-add each one
   qi remove repo-name
   qi add <repo-url> repo-name
   ```

### Disk Space Issues

**Problem:** Cache directory taking up too much space.

**Diagnosis:**
```bash
du -sh ~/.qi/cache/
du -sh ~/.qi/cache/*/
```

**Solutions:**

1. **Remove unused repositories:**
   ```bash
   qi remove unused-repo-name
   ```

2. **Clean git repositories:**
   ```bash
   # For each repository
   cd ~/.qi/cache/repository-name
   git gc --aggressive
   git prune
   ```

3. **Move cache to different location:**
   ```bash
   export QI_CACHE_DIR="/larger/disk/qi-cache"
   mv ~/.qi/cache/* "$QI_CACHE_DIR/"
   ```

## Performance Issues

### Slow Script Discovery

**Problem:** `qi list` or script execution is slow.

**Solutions:**

1. **Limit repository size:**
   ```bash
   # Check repository sizes
   du -sh ~/.qi/cache/*/
   
   # Remove large unnecessary repositories
   qi remove large-repo
   ```

2. **Optimize git repositories:**
   ```bash
   # Clean up each repository
   cd ~/.qi/cache/repository-name
   git gc --aggressive
   ```

### Network Timeouts

**Problem:** Git operations timeout.

**Solutions:**

1. **Increase timeout in configuration:**
   ```bash
   echo "git_timeout=60" >> ~/.qi/config
   ```

2. **Check network connection:**
   ```bash
   ping -c 4 github.com
   traceroute github.com
   ```

3. **Use different network or proxy:**
   ```bash
   export http_proxy=http://proxy.company.com:8080
   export https_proxy=http://proxy.company.com:8080
   ```

## Debugging

### Enable Verbose Output

Get detailed information about what qi is doing:

```bash
qi --verbose <command>
qi -v update
qi -v script-name
```

### Check System Status

```bash
# Check qi status
qi status

# Check configuration
qi config show

# Check git configuration
git config --list

# Check environment
env | grep QI_
```

### Log Files

qi doesn't create log files by default, but you can capture output:

```bash
# Capture verbose output
qi --verbose update 2>&1 | tee qi-debug.log

# Capture all output
qi status > qi-status.log 2>&1
```

### Manual Debugging

```bash
# Check cache structure
ls -la ~/.qi/cache/
ls -la ~/.qi/cache/.qi-metadata/

# Check specific repository
cd ~/.qi/cache/repository-name
git status
git log --oneline -n 5

# Test git operations
git fetch
git pull
```

## Getting Help

If you're still experiencing issues:

1. **Check the GitHub issues:** [qi Issues](https://github.com/yjmrobert/qi/issues)
2. **Create a new issue with:**
   - qi version (`qi --version`)
   - Operating system and version
   - Complete error message
   - Steps to reproduce
   - Output of `qi --verbose status`

3. **Emergency recovery:**
   ```bash
   # Complete reset
   rm -rf ~/.qi/
   # Reinstall qi
   curl -fsSL https://github.com/yjmrobert/qi/raw/main/install.sh | bash
   # Re-add your repositories
   ```