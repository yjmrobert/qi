# Contributing to qi

We welcome contributions to qi! This guide will help you get started with contributing to the project.

## Getting Started

### Prerequisites

- Linux operating system
- Git installed and configured
- Bash shell (version 4.0 or higher)
- Basic understanding of shell scripting

### Development Setup

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/yourusername/qi.git
   cd qi
   ```

2. **Set up development environment:**
   ```bash
   # Make qi executable
   chmod +x qi
   
   # Create development alias (optional)
   alias qi-dev="$(pwd)/qi"
   ```

3. **Run tests to ensure everything works:**
   ```bash
   ./test.sh
   ```

## Development Workflow

### Making Changes

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

2. **Make your changes:**
   - Follow the existing code style
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes:**
   ```bash
   # Run all tests
   ./test.sh
   
   # Run specific test suites
   ./test.sh cache
   ./test.sh git-ops
   ```

4. **Commit your changes:**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   # or
   git commit -m "fix: resolve issue description"
   ```

### Commit Message Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(cache): add repository metadata storage
fix(git-ops): handle empty repository URLs
docs: update installation instructions
test: add tests for script discovery
```

## Code Style Guidelines

### Shell Script Style

1. **Use bash strict mode:**
   ```bash
   set -euo pipefail
   ```

2. **Function naming:**
   ```bash
   # Use snake_case for function names
   function validate_repo_name() {
       # Function body
   }
   ```

3. **Variable naming:**
   ```bash
   # Use UPPER_CASE for constants
   readonly DEFAULT_CACHE_DIR="$HOME/.qi/cache"
   
   # Use snake_case for local variables
   local repo_name="example"
   
   # Use snake_case for global variables
   cache_dir="/path/to/cache"
   ```

4. **Error handling:**
   ```bash
   # Always check command results
   if ! git clone "$url" "$dest"; then
       log "ERROR" "Failed to clone repository"
       return 1
   fi
   ```

5. **Logging:**
   ```bash
   # Use the log function for output
   log "INFO" "Processing repository: $repo_name"
   log "ERROR" "Repository not found: $repo_name"
   log "DEBUG" "Cache directory: $cache_dir"
   ```

### Code Organization

1. **File structure:**
   ```
   qi                    # Main executable
   lib/                  # Library functions
   ├── cache.sh         # Cache management
   ├── config.sh        # Configuration handling
   ├── git-ops.sh       # Git operations
   ├── script-ops.sh    # Script operations
   └── utils.sh         # Utility functions
   ```

2. **Function organization:**
   - Public functions at the top
   - Private (helper) functions at the bottom
   - Use `_` prefix for private functions

3. **Documentation:**
   ```bash
   # Function documentation format
   # Description: What the function does
   # Parameters:
   #   $1 - Description of first parameter
   #   $2 - Description of second parameter
   # Returns:
   #   0 - Success
   #   1 - Error condition
   function example_function() {
       local param1="$1"
       local param2="$2"
       
       # Function implementation
   }
   ```

## Testing

### Test Structure

```
tests/
├── test_cache.sh           # Cache functionality tests
├── test_config.sh          # Configuration tests
├── test_git_ops.sh         # Git operations tests
├── test_install.sh         # Installation tests
├── test_integration.sh     # Integration tests
├── test_script_ops.sh      # Script operations tests
└── test_utils.sh          # Utility function tests
```

### Writing Tests

1. **Use shunit2 framework:**
   ```bash
   #!/bin/bash
   
   # Test setup
   setUp() {
       # Create test environment
   }
   
   # Test teardown
   tearDown() {
       # Clean up test environment
   }
   
   # Test function
   test_function_name() {
       # Test implementation
       assertEquals "expected" "$(actual_function)"
   }
   
   # Load shunit2
   source shunit2
   ```

2. **Test naming conventions:**
   ```bash
   test_add_repository_success()
   test_add_repository_invalid_url()
   test_remove_repository_not_found()
   ```

3. **Mock external dependencies:**
   ```bash
   # Mock git command for testing
   git() {
       case "$1" in
           "clone")
               mkdir -p "$3"
               return 0
               ;;
           *)
               command git "$@"
               ;;
       esac
   }
   ```

### Running Tests

```bash
# Run all tests
./test.sh

# Run specific test file
./test.sh cache

# Run with verbose output
./test.sh -v

# Run with coverage (if bash_coverage.sh is available)
./tools/bash_coverage.sh ./test.sh
```

## Documentation

### Documentation Structure

- `README.md` - Main project documentation
- `docs/` - Detailed documentation (MkDocs format)
- Inline code comments for complex functions
- Function documentation headers

### Documentation Standards

1. **Keep README.md concise** - Link to detailed docs
2. **Update docs with code changes** - Don't let docs get stale
3. **Include examples** - Show how to use new features
4. **Document breaking changes** - Help users migrate

### Building Documentation

```bash
# Install MkDocs (if not already installed)
pip install mkdocs mkdocs-material

# Serve documentation locally
mkdocs serve

# Build documentation
mkdocs build
```

## Submitting Changes

### Pull Request Process

1. **Ensure all tests pass:**
   ```bash
   ./test.sh
   ```

2. **Update documentation** if needed

3. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

4. **Create pull request** on GitHub with:
   - Clear description of changes
   - Reference to related issues
   - Screenshots if UI changes
   - Test results

### Pull Request Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Other (please describe)

## Testing
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings or errors
```

## Code Review Process

### For Contributors

- Be open to feedback and suggestions
- Respond to review comments promptly
- Make requested changes in additional commits
- Squash commits before final merge if requested

### For Reviewers

- Be constructive and helpful
- Focus on code quality, not personal preferences
- Test the changes locally if possible
- Approve when satisfied with the changes

## Release Process

### Version Numbering

We use [Semantic Versioning](https://semver.org/):
- MAJOR.MINOR.PATCH (e.g., 1.2.3)
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)

### Release Checklist

1. Update version in `qi` script
2. Update CHANGELOG.md
3. Update documentation
4. Create git tag
5. Update installation script if needed
6. Create GitHub release

## Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- Help others learn and grow
- Focus on constructive feedback
- No harassment or discrimination

### Communication

- Use GitHub issues for bug reports and feature requests
- Use GitHub discussions for questions and general discussion
- Be clear and specific in issue descriptions
- Search existing issues before creating new ones

## Getting Help

- **Documentation**: Check the docs first
- **Issues**: Search existing issues
- **Discussions**: Use GitHub discussions for questions
- **Email**: Contact maintainers for sensitive issues

Thank you for contributing to qi!