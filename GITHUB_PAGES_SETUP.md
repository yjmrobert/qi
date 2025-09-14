# GitHub Pages Setup Instructions

This document provides step-by-step instructions to enable GitHub Pages for the qi documentation.

## Quick Setup Checklist

- [x] MkDocs configuration created (`mkdocs.yml`)
- [x] Documentation structure created (`docs/` folder)
- [x] GitHub Actions workflow created (`.github/workflows/docs.yml`)
- [x] Requirements file created (`requirements.txt`)
- [ ] **GitHub Pages enabled in repository settings** ← **YOU NEED TO DO THIS**
- [ ] **First deployment triggered**

## Step-by-Step Setup

### 1. Enable GitHub Pages

1. **Go to your repository on GitHub**
   - Navigate to: `https://github.com/yjmrobert/qi`

2. **Go to Settings**
   - Click the "Settings" tab in the repository

3. **Find Pages section**
   - Scroll down to "Pages" in the left sidebar
   - Click on "Pages"

4. **Configure Pages source**
   - Under "Source", select **"GitHub Actions"**
   - This tells GitHub to use the workflow we created instead of a branch

5. **Save the configuration**
   - The setting should save automatically

### 2. Trigger First Deployment

Option A: **Push a documentation change**
```bash
# Make any small change to trigger deployment
echo "# Documentation updated $(date)" >> docs/index.md
git add docs/index.md
git commit -m "docs: trigger initial Pages deployment"
git push origin main
```

Option B: **Push the new documentation files**
```bash
# If you haven't pushed the documentation files yet
git add .
git commit -m "docs: add MkDocs documentation and GitHub Pages setup"
git push origin main
```

### 3. Monitor Deployment

1. **Check Actions tab**
   - Go to the "Actions" tab in your repository
   - You should see a "Deploy Documentation" workflow running

2. **Wait for completion**
   - The workflow takes 2-3 minutes to complete
   - Green checkmark = successful deployment
   - Red X = deployment failed (check logs)

3. **Visit your documentation site**
   - Once deployed, visit: `https://yjmrobert.github.io/qi/`
   - It may take a few minutes for the URL to become active

## What Happens Automatically

### On Every Push to Main

When you push changes to the `main` branch that affect documentation:

1. **GitHub Actions triggers** the workflow
2. **Python environment** is set up
3. **Dependencies installed** from `requirements.txt`
4. **MkDocs builds** the documentation
5. **Site deployed** to GitHub Pages
6. **Available at** `https://yjmrobert.github.io/qi/`

### On Pull Requests

When someone opens a PR with documentation changes:

1. **Documentation builds** to check for errors
2. **Preview comment** is added to the PR
3. **No deployment** happens (only on main branch)

## Verification Steps

### 1. Check Repository Settings

Visit: `https://github.com/yjmrobert/qi/settings/pages`

You should see:
- Source: "GitHub Actions" ✅
- A green checkmark with your site URL

### 2. Check Actions

Visit: `https://github.com/yjmrobert/qi/actions`

You should see:
- "Deploy Documentation" workflows
- Green checkmarks for successful runs
- Recent runs when you push documentation changes

### 3. Check Live Site

Visit: `https://yjmrobert.github.io/qi/`

You should see:
- qi documentation homepage
- Material theme with blue color scheme
- Working navigation menu
- Search functionality
- Dark/light mode toggle

## Customization Options

### Update Site URL

If your repository name or username changes, update `mkdocs.yml`:

```yaml
site_url: https://yourusername.github.io/repositoryname/
repo_url: https://github.com/yourusername/repositoryname
```

### Custom Domain

To use a custom domain (e.g., `docs.qi-tool.com`):

1. **Add CNAME file** to `docs/` directory:
   ```bash
   echo "docs.qi-tool.com" > docs/CNAME
   ```

2. **Update mkdocs.yml**:
   ```yaml
   site_url: https://docs.qi-tool.com/
   ```

3. **Configure DNS** with your domain provider:
   - Add CNAME record pointing to `yjmrobert.github.io`

### Branch Protection

To prevent accidental documentation breaks:

1. **Go to Settings → Branches**
2. **Add rule for main branch**
3. **Require status checks**:
   - "build" (from documentation workflow)

## Troubleshooting

### Common Issues

**"404 - Page not found" when visiting site:**
- Check that GitHub Pages is enabled with "GitHub Actions" source
- Wait 5-10 minutes after first deployment
- Verify the URL: `https://yjmrobert.github.io/qi/`

**Workflow fails with "Permission denied":**
- Check repository Settings → Actions → General
- Ensure "Read and write permissions" is selected for GITHUB_TOKEN

**Build fails with "Config value 'nav' is invalid":**
- Check `mkdocs.yml` syntax (YAML is sensitive to indentation)
- Ensure all files referenced in navigation exist

**Site loads but looks broken:**
- Check browser console for errors
- Verify all CSS/JS files are loading
- Try hard refresh (Ctrl+F5)

### Debug Steps

1. **Check workflow logs:**
   ```
   Actions tab → Latest workflow run → View logs
   ```

2. **Test locally:**
   ```bash
   pip install -r requirements.txt
   mkdocs serve
   ```

3. **Validate configuration:**
   ```bash
   mkdocs build --strict
   ```

## Maintenance

### Regular Tasks

- **Update dependencies** in `requirements.txt` periodically
- **Review and update** documentation content
- **Check for broken links** using `mkdocs build --strict`
- **Monitor workflow** for any failures

### Updating MkDocs

```bash
# Update requirements.txt
pip install --upgrade mkdocs mkdocs-material
pip freeze | grep mkdocs > new-requirements.txt

# Test locally
mkdocs serve

# Commit updates
git add requirements.txt
git commit -m "docs: update MkDocs dependencies"
git push
```

## Success Indicators

✅ **Setup Complete When:**
- GitHub Pages shows "Your site is published at https://yjmrobert.github.io/qi/"
- Documentation site loads without errors
- Navigation works correctly
- Search functionality works
- Dark/light mode toggle works
- Mobile layout is responsive

✅ **Workflow Working When:**
- Green checkmarks in Actions tab
- Automatic deployments on documentation changes
- PR comments with preview links
- Build times under 3 minutes

## Next Steps

Once GitHub Pages is working:

1. **Share the documentation URL** with users
2. **Add link to README.md**:
   ```markdown
   ## Documentation
   
   Complete documentation is available at: https://yjmrobert.github.io/qi/
   ```

3. **Set up monitoring** for broken links
4. **Consider adding** more advanced features:
   - Search analytics
   - User feedback system
   - Version switching
   - API documentation generation

---

**Need Help?**
- Check the [DOCS_SETUP.md](DOCS_SETUP.md) guide for detailed information
- Review GitHub Pages documentation: https://docs.github.com/en/pages
- Open an issue if you encounter problems