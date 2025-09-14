# GitHub Actions Workflows Documentation

This document provides an overview of all GitHub Actions workflows implemented for the qi project.

## Overview

The qi project now includes a comprehensive set of GitHub Actions workflows to ensure code quality, security, and automated processes. All workflows are located in the `.github/workflows/` directory.

## Workflows Summary

### 1. CI Workflow (`ci.yml`)
**Trigger**: Push to main/develop, Pull Requests, Manual dispatch
**Purpose**: Comprehensive continuous integration testing

**Features**:
- Multi-version Bash compatibility testing (4.4, 5.0, 5.1, 5.2)
- Comprehensive test suite execution
- Coverage report generation
- Integration testing with real repositories
- OS compatibility testing (Ubuntu 22.04, latest)
- Security checks and documentation validation

**Jobs**:
- `test`: Runs test suite across multiple Bash versions
- `integration-test`: Tests qi with real repositories
- `compatibility-test`: Tests across different Ubuntu versions
- `security-check`: Basic security scanning
- `documentation-check`: Validates README and documentation

### 2. Release Workflow (`release.yml`)
**Trigger**: Git tags (v*), Manual dispatch
**Purpose**: Automated release creation and asset generation

**Features**:
- Version validation and format checking
- Automated version updates in scripts
- Release asset creation with checksums
- GitHub release creation with release notes
- Installation script URL updates
- Pre-release support

**Jobs**:
- `validate-release`: Validates version and runs pre-release tests
- `create-release-assets`: Creates distribution packages
- `create-github-release`: Creates GitHub release with assets
- `update-install-script`: Updates installation URLs
- `notify-release`: Sends release notifications

### 3. Installation Test Workflow (`install-test.yml`)
**Trigger**: Changes to install.sh/qi/lib, Schedule (daily), Manual dispatch
**Purpose**: Comprehensive installation testing

**Features**:
- Multi-method installation testing (curl, wget, manual)
- Different user privilege testing (root, sudo)
- Error scenario testing (missing deps, network issues, permissions)
- Installation idempotency testing
- End-to-end functionality testing

**Jobs**:
- `test-install-script`: Tests installation across different scenarios
- `test-install-scenarios`: Tests edge cases and error conditions
- `test-uninstall`: Tests uninstallation process
- `integration-test`: Full installation and usage testing

### 4. Security Workflow (`security.yml`)
**Trigger**: Push to main/develop, Pull Requests, Schedule (daily), Manual dispatch
**Purpose**: Comprehensive security scanning

**Features**:
- ShellCheck static analysis
- Secret detection and scanning
- Vulnerability pattern checking
- File permission auditing
- Input sanitization validation
- Dependency security checks

**Jobs**:
- `shellcheck`: ShellCheck analysis with SARIF output
- `secret-scan`: Git secrets and pattern detection
- `vulnerability-scan`: Common vulnerability patterns
- `dependency-check`: External dependency security review
- `code-quality-security`: Security-focused code quality checks
- `sarif-upload`: Upload results to GitHub Security tab

### 5. Lint Workflow (`lint.yml`)
**Trigger**: Push to main/develop, Pull Requests, Manual dispatch
**Purpose**: Code quality and style enforcement

**Features**:
- ShellCheck linting for all shell scripts
- Multi-version Bash syntax checking
- Shell script formatting with shfmt
- Best practices validation
- Documentation linting (Markdown, YAML)
- Comprehensive lint reporting

**Jobs**:
- `shellcheck`: ShellCheck linting
- `bash-syntax`: Syntax validation across Bash versions
- `style-check`: Code formatting validation
- `best-practices`: Shell scripting best practices
- `documentation-lint`: Markdown and documentation linting
- `yaml-lint`: YAML file validation
- `lint-summary`: Consolidated lint report

### 6. Stale Issues Workflow (`stale.yml`)
**Trigger**: Schedule (daily), Manual dispatch
**Purpose**: Automated stale issue and PR management

**Features**:
- Automatic stale marking for inactive issues (60 days)
- Automatic stale marking for inactive PRs (30 days)
- Customizable exemption labels
- Polite messaging with clear instructions
- Configurable close timing

### 7. Auto-Assign Workflow (`auto-assign.yml`)
**Trigger**: New issues, New pull requests
**Purpose**: Automated issue and PR management

**Features**:
- Automatic assignment to maintainers
- Smart labeling based on content and file changes
- First-time contributor welcome messages
- Context-aware label application

### 8. Cleanup Workflow (`cleanup.yml`)
**Trigger**: Schedule (weekly), Manual dispatch
**Purpose**: Repository maintenance and cleanup

**Features**:
- Old artifact cleanup (30+ days)
- Cache entry cleanup (7+ days)
- Workflow run cleanup (90+ days for success, 30+ days for failures)
- Configurable cleanup types
- Cleanup summary reporting

## Configuration Files

### Dependabot (`dependabot.yml`)
**Purpose**: Automated dependency updates

**Features**:
- GitHub Actions dependency monitoring
- Weekly update schedule
- Automatic PR creation for updates
- Configurable review assignments
- Support for future npm/Python dependencies

## Workflow Integration

### Triggers and Dependencies
- **CI workflow** runs on every push and PR to ensure code quality
- **Security workflow** runs daily and on code changes for continuous monitoring  
- **Lint workflow** runs on code changes to enforce standards
- **Release workflow** activates on version tags for automated releases
- **Installation tests** run on installation-related changes and daily
- **Cleanup workflow** runs weekly for maintenance
- **Stale workflow** runs daily for issue management

### Artifact Management
- Coverage reports retained for 30 days
- Release assets retained for 90 days
- Security reports retained for 90 days
- Lint summaries retained for 30 days
- Cleanup summaries retained for 30 days

### Permissions
All workflows use minimal required permissions following the principle of least privilege:
- `contents: read` for code access
- `security-events: write` for security scanning
- `issues: write` for issue management
- `pull-requests: write` for PR management
- `actions: write` for cleanup operations

## Usage Examples

### Running Tests Locally
```bash
# Run basic tests
./test.sh

# Run comprehensive test suite
./run_tests.sh

# Run with coverage
./run_tests.sh --verbose

# Run specific test category
./run_tests.sh --filter utils
```

### Creating a Release
```bash
# Tag a new version
git tag v1.0.1
git push origin v1.0.1

# Or use manual dispatch in GitHub Actions
```

### Security Scanning
```bash
# Run ShellCheck locally
shellcheck qi install.sh test.sh run_tests.sh lib/*.sh tests/*.sh tools/*.sh

# Check for secrets (requires git-secrets)
git secrets --scan
```

### Code Formatting
```bash
# Check formatting
shfmt -d -i 4 -ci qi install.sh test.sh run_tests.sh lib/*.sh tests/*.sh tools/*.sh

# Fix formatting
shfmt -w -i 4 -ci qi install.sh test.sh run_tests.sh lib/*.sh tests/*.sh tools/*.sh
```

## Monitoring and Maintenance

### GitHub Actions Tab
Monitor workflow runs in the GitHub Actions tab:
- Green checkmarks indicate successful runs
- Red X marks indicate failures requiring attention
- Yellow dots indicate in-progress runs

### Security Tab
Review security findings in the GitHub Security tab:
- Code scanning alerts from ShellCheck
- Secret scanning alerts
- Dependency vulnerability alerts

### Issues and Pull Requests
- New issues and PRs are automatically labeled and assigned
- Stale items are automatically managed
- First-time contributors receive welcome messages

## Customization

### Modifying Workflows
To customize workflows:
1. Edit the relevant `.yml` file in `.github/workflows/`
2. Test changes in a feature branch
3. Workflows will run on the PR to validate changes
4. Merge when tests pass

### Adding New Workflows
1. Create a new `.yml` file in `.github/workflows/`
2. Follow the existing patterns for consistency
3. Add documentation to this file
4. Test thoroughly before merging

### Environment Variables
Key environment variables used:
- `GITHUB_TOKEN`: Automatically provided by GitHub
- `QI_CACHE_DIR`: Test cache directory
- `ENABLE_COVERAGE`: Enable/disable coverage reporting
- `COVERAGE_THRESHOLD`: Coverage percentage threshold

## Troubleshooting

### Common Issues
1. **Workflow failures**: Check the Actions tab for detailed logs
2. **Permission errors**: Ensure proper permissions in workflow files
3. **Test failures**: Run tests locally to reproduce issues
4. **Security alerts**: Review and address flagged security issues

### Getting Help
- Review workflow logs in the GitHub Actions tab
- Check this documentation for configuration details
- Create an issue for workflow-related problems
- Review GitHub Actions documentation for advanced features

## Future Enhancements

Potential future additions:
- Performance benchmarking workflows
- Multi-architecture testing (ARM, x86)
- Container-based testing
- Integration with external testing services
- Automated documentation generation
- Release notes automation
- Slack/Discord notifications

---

*This documentation is automatically maintained. Last updated: $(date)*