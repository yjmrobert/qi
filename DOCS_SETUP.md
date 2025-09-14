# Documentation Setup Guide

This guide explains how to set up and deploy the qi documentation using MkDocs and GitHub Pages.

## Overview

The qi project uses [MkDocs](https://www.mkdocs.org/) with the [Material theme](https://squidfunk.github.io/mkdocs-material/) to generate beautiful, searchable documentation. The documentation is automatically deployed to GitHub Pages using GitHub Actions.

## Documentation Structure

```
qi/
├── docs/                          # Documentation source files
│   ├── index.md                  # Homepage
│   ├── installation.md           # Installation guide
│   ├── quickstart.md            # Quick start guide
│   ├── usage/                   # User guide
│   │   ├── basic.md            # Basic usage
│   │   ├── commands.md         # Commands reference
│   │   ├── configuration.md    # Configuration guide
│   │   └── troubleshooting.md  # Troubleshooting guide
│   ├── development/             # Development documentation
│   │   ├── contributing.md     # Contributing guide
│   │   ├── testing.md          # Testing documentation
│   │   └── architecture.md     # Architecture overview
│   └── api/                     # API reference
│       ├── library.md          # Library functions
│       └── config.md           # Configuration options
├── mkdocs.yml                    # MkDocs configuration
├── requirements.txt              # Python dependencies
└── .github/workflows/docs.yml    # GitHub Actions workflow
```

## Local Development

### Prerequisites

- Python 3.7 or higher
- pip (Python package installer)

### Setup

1. **Create a virtual environment (recommended):**
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Serve documentation locally:**
   ```bash
   mkdocs serve
   ```

4. **Open your browser to:** http://127.0.0.1:8000

### Making Changes

1. **Edit documentation files** in the `docs/` directory
2. **The local server auto-reloads** when files change
3. **Preview changes** in your browser
4. **Commit and push** when satisfied with changes

### Building Static Site

To build the static site without serving:

```bash
mkdocs build
```

This creates a `site/` directory with the generated HTML files.

## GitHub Pages Deployment

### Automatic Deployment

The documentation is automatically deployed to GitHub Pages when:

- Changes are pushed to the `main` branch
- Changes affect documentation files (`docs/`, `mkdocs.yml`, `requirements.txt`)

### Manual Setup (One-time)

1. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Set Source to "GitHub Actions"

2. **The workflow will:**
   - Build the documentation
   - Deploy to GitHub Pages
   - Make it available at: `https://yourusername.github.io/qi/`

### Workflow Features

- **Automatic builds** on documentation changes
- **Pull request previews** with comment links
- **Caching** for faster builds
- **Strict mode** to catch broken links
- **Git revision dates** for each page

## Configuration

### MkDocs Configuration (mkdocs.yml)

Key configuration options:

```yaml
site_name: qi - Git Repository Script Manager
site_url: https://yourusername.github.io/qi/

theme:
  name: material
  palette:
    # Light/dark mode toggle
    - scheme: default
      primary: blue
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - scheme: slate
      primary: blue
      toggle:
        icon: material/brightness-4
        name: Switch to light mode

plugins:
  - search
  - git-revision-date-localized

nav:
  - Home: index.md
  - Getting Started:
    - Installation: installation.md
    - Quick Start: quickstart.md
  # ... more navigation
```

### Theme Features

- **Material Design** appearance
- **Dark/light mode** toggle
- **Search functionality**
- **Mobile responsive**
- **Code syntax highlighting**
- **Navigation tabs**
- **Git revision dates**

## Customization

### Adding New Pages

1. **Create markdown file** in `docs/` directory
2. **Add to navigation** in `mkdocs.yml`:
   ```yaml
   nav:
     - New Page: new-page.md
   ```

### Organizing Content

- Use **subdirectories** for logical grouping
- Update **navigation structure** in `mkdocs.yml`
- Use **clear, descriptive filenames**

### Styling

- **Override CSS** by creating `docs/stylesheets/extra.css`
- **Add to mkdocs.yml**:
  ```yaml
  extra_css:
    - stylesheets/extra.css
  ```

### Adding Plugins

1. **Add to requirements.txt:**
   ```
   mkdocs-plugin-name>=1.0.0
   ```

2. **Add to mkdocs.yml:**
   ```yaml
   plugins:
     - plugin-name
   ```

## Troubleshooting

### Common Issues

**Build fails with "Config value 'nav' is invalid":**
- Check YAML syntax in `mkdocs.yml`
- Ensure all referenced files exist
- Use proper indentation (spaces, not tabs)

**Missing pages or broken links:**
- Run `mkdocs build --strict` to catch errors
- Check file paths in navigation
- Ensure markdown files exist

**Styling issues:**
- Clear browser cache
- Check CSS syntax if using custom styles
- Verify theme configuration

**GitHub Actions fails:**
- Check workflow logs in GitHub Actions tab
- Verify requirements.txt is up to date
- Ensure all referenced files exist

### Local Testing

```bash
# Test build process
mkdocs build --strict

# Check for broken links
mkdocs build --strict --verbose

# Serve with specific configuration
mkdocs serve --config-file mkdocs.yml

# Build for specific site URL
mkdocs build --site-dir custom-site
```

### Debugging

**Enable verbose output:**
```bash
mkdocs serve --verbose
mkdocs build --verbose
```

**Check configuration:**
```bash
mkdocs config
```

**Validate navigation:**
```bash
python3 -c "import yaml; print(yaml.safe_load(open('mkdocs.yml'))['nav'])"
```

## Best Practices

### Content Writing

- **Use clear headings** for navigation
- **Include code examples** with syntax highlighting
- **Add cross-references** between related pages
- **Keep paragraphs short** and scannable
- **Use bullet points** and tables for structured information

### File Organization

- **Group related content** in subdirectories
- **Use consistent naming** conventions
- **Keep URLs stable** to avoid broken links
- **Include index files** for directory listings

### Maintenance

- **Regular updates** to keep content current
- **Test all examples** and code snippets
- **Review and update** navigation structure
- **Monitor build logs** for warnings

## Advanced Features

### Code Blocks with Line Numbers

```python linenums="1"
#!/usr/bin/env python3
def hello_world():
    print("Hello, World!")

if __name__ == "__main__":
    hello_world()
```

### Admonitions

!!! note "Information"
    This is an informational note.

!!! warning "Warning"
    This is a warning message.

!!! tip "Pro Tip"
    This is a helpful tip.

### Tabs

=== "Bash"
    ```bash
    qi add https://github.com/user/repo.git
    ```

=== "Result"
    ```
    Repository added successfully: repo
    ```

### Keyboard Keys

Press ++ctrl+c++ to cancel the operation.

## Support

For documentation-related issues:

1. **Check this guide** for common solutions
2. **Review MkDocs documentation:** https://www.mkdocs.org/
3. **Check Material theme docs:** https://squidfunk.github.io/mkdocs-material/
4. **Open an issue** on the qi GitHub repository

---

**Last Updated:** $(date +"%Y-%m-%d")
**MkDocs Version:** 1.5.0+
**Material Theme Version:** 9.4.0+