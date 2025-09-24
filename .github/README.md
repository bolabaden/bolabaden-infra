# GitHub Actions & GitHub Pages Setup

This directory contains the configuration for automatic deployment of the compose2hcl project to GitHub Pages.

## 🚀 Automatic Deployment

### What Happens on Push

1. **Trigger**: Every push to `main` or `master` branch
2. **Build**: TypeScript compilation and web interface preparation
3. **Deploy**: Automatic deployment to GitHub Pages
4. **URL**: `https://{username}.github.io/{repository-name}`

### Workflow Files

- **`.github/workflows/deploy.yml`**: Main deployment workflow
- **`.github/scripts/setup-pages.sh`**: Dynamic configuration script
- **`.github/scripts/gh-pages-config.yml`**: Configuration template

## 🔧 Setup Requirements

### 1. Enable GitHub Pages

1. Go to your repository **Settings**
2. Navigate to **Pages** section
3. Set **Source** to **GitHub Actions**

### 2. Repository Permissions

The workflow requires these permissions:
- `contents: read` - Read repository content
- `pages: write` - Deploy to GitHub Pages
- `id-token: write` - GitHub token for authentication

### 3. Branch Protection (Optional)

Consider protecting your main branch:
- Require status checks to pass
- Require branches to be up to date
- Restrict pushes to matching branches

## 📁 Generated Files

The workflow automatically generates:
- **`src/compose2hcl/web/config.js`**: Dynamic repository configuration
- **`src/compose2hcl/dist/`**: Built web interface
- **Updated `package.json`**: Homepage field

## 🌐 Dynamic Configuration

The system automatically detects:
- Repository owner (username/organization)
- Repository name
- GitHub Pages URL

No hardcoding required - works for any GitHub repository!

## 🧪 Testing the Workflow

1. **Push to main branch**: Triggers automatic deployment
2. **Check Actions tab**: Monitor build and deployment progress
3. **Visit GitHub Pages**: Your site will be available at the generated URL

## 🔍 Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure GitHub Pages is enabled and set to GitHub Actions
2. **Build Failures**: Check TypeScript compilation in the Actions logs
3. **Deployment Issues**: Verify the workflow has proper permissions

### Manual Trigger

You can manually trigger the workflow:
1. Go to **Actions** tab
2. Select **Deploy to GitHub Pages**
3. Click **Run workflow**

## 📚 Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)
- [GitHub Pages with Actions](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site#publishing-with-a-custom-github-actions-workflow)
