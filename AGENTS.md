# Project Overview

This is a personal blog website built with [Hexo](https://hexo.io/), a fast, simple and powerful blog framework powered by Node.js. The site is deployed to GitHub Pages at `Aqiu16717.github.io`.

The blog contains technical articles primarily written in Chinese, covering topics such as:
- InnoDB B-tree locking strategies
- Go programming language pointers and best practices
- MySQL internals (metadata locking, DDL logs, table definition cache)
- LevelDB and etcd/Raft distributed systems

## Technology Stack

| Component | Technology |
|-----------|------------|
| Static Site Generator | Hexo 8.0.0 |
| Runtime | Node.js |
| Template Engine | EJS (Embedded JavaScript) |
| Styling | Stylus |
| Markup | Markdown |
| Theme | Landscape (Hexo default theme) |
| Deployment | Git (hexo-deployer-git) |

## Project Structure

```
.
├── _config.yml              # Main Hexo configuration
├── _config.landscape.yml    # Theme-specific configuration (empty)
├── package.json             # Node.js dependencies and npm scripts
├── scaffolds/               # Templates for new posts/pages/drafts
│   ├── draft.md             # Template for drafts
│   ├── page.md              # Template for pages
│   └── post.md              # Template for posts
├── source/                  # Content source files
│   ├── _drafts/             # Draft posts (not published)
│   ├── _posts/              # Published blog posts
│   └── images/              # Static images
├── themes/                  # Theme files
│   └── landscape/           # Landscape theme (default)
│       ├── _config.yml      # Theme configuration
│       ├── layout/          # EJS templates
│       ├── source/          # Theme assets (CSS, JS)
│       └── scripts/         # Hexo tag plugins
├── public/                  # Generated static site (gitignored)
└── .deploy_git/             # Git repository for deployment
```

## Key Configuration Files

### `_config.yml` (Main Configuration)

- **Site metadata**: Title, author, language (en), timezone
- **URL**: Currently set to `http://example.com` (needs update for production)
- **Permalink format**: `:year/:month/:day/:title/`
- **Theme**: `landscape`
- **Deployment**: Git repository `git@github.com:Aqiu16717/Aqiu16717.github.io.git`, branch `main`
- **Pagination**: 10 posts per page
- **Syntax highlighting**: highlight.js with line numbers enabled

### `package.json`

Key dependencies:
- `hexo`: ^8.0.0 (core framework)
- `hexo-deployer-git`: ^4.0.0 (Git deployment)
- `hexo-renderer-ejs`: ^2.0.0 (EJS template rendering)
- `hexo-renderer-marked`: ^7.0.0 (Markdown rendering)
- `hexo-renderer-stylus`: ^3.0.1 (Stylus CSS rendering)
- `hexo-server`: ^3.0.0 (Development server)
- `hexo-theme-landscape`: ^1.0.0 (Default theme)

## Build and Development Commands

```bash
# Install dependencies
npm install

# Start development server (with live reload)
npm run server
# or
hexo server

# Generate static files
npm run build
# or
hexo generate

# Clean generated files and cache
npm run clean
# or
hexo clean

# Deploy to GitHub Pages
npm run deploy
# or
hexo deploy

# Create a new post
hexo new post "Post Title"

# Create a new draft
hexo new draft "Draft Title"

# Create a new page
hexo new page "Page Title"
```

## Content Organization

### Posts
- Published posts go in `source/_posts/`
- Each post is a Markdown file with YAML front matter
- Posts are automatically published based on date

### Drafts
- Drafts go in `source/_drafts/`
- Drafts are not published until moved to `_posts/`
- Use `hexo publish draft-name` to publish a draft

### Front Matter Format

```yaml
---
title: Post Title
date: 2025-11-12 22:35:51
tags: tag1, tag2, tag3
---
```

## Theme Structure (Landscape)

The Landscape theme is the default Hexo theme with the following structure:

```
themes/landscape/
├── _config.yml          # Theme configuration
├── layout/              # EJS templates
│   ├── layout.ejs       # Base layout
│   ├── index.ejs        # Homepage
│   ├── post.ejs         # Post page
│   ├── page.ejs         # Static page
│   ├── archive.ejs      # Archive page
│   ├── _partial/        # Reusable partials
│   └── _widget/         # Sidebar widgets
├── source/              # Static assets
│   ├── css/             # Stylus stylesheets
│   ├── js/              # JavaScript files
│   └── fancybox/        # Fancybox image viewer
└── scripts/             # Hexo tag plugins
    └── fancybox.js      # Fancybox tag plugin
```

### Theme Features
- Responsive sidebar (position: right)
- Built-in widgets: category, tag, tagcloud, archive, recent_posts
- Fancybox image lightbox integration
- Google Analytics and Gauges Analytics support
- Valine comment system support (currently disabled)
- Social link icons via Fork Awesome

## Deployment

The site is configured to deploy to GitHub Pages using the `hexo-deployer-git` plugin.

### Deployment Configuration
```yaml
deploy:
  type: git
  repo: git@github.com:Aqiu16717/Aqiu16717.github.io.git
  branch: main
```

### Deployment Process
1. Run `hexo deploy` or `npm run deploy`
2. Hexo generates the static site to `public/`
3. The `hexo-deployer-git` plugin pushes the `public/` directory to the specified Git repository
4. The site is served from the `main` branch on GitHub Pages

## Development Guidelines

### Adding New Content
1. Use `hexo new post "Title"` to create posts
2. Use `hexo new draft "Title"` for work-in-progress content
3. Store images in `source/images/` and reference them with relative paths
4. Use tags to categorize content

### Modifying Theme
- Do NOT directly modify `themes/landscape/_config.yml`
- Instead, copy configurations to `_config.landscape.yml` in the project root
- This prevents changes from being lost during theme updates

### Code Style
- Blog posts are written in Chinese
- Technical terms (InnoDB, B-tree, Go, MySQL, etc.) use English
- Code blocks use standard Markdown syntax with language identifiers

## Testing

This project does not have an automated test suite. Testing is done manually by:
1. Running `hexo server` to preview changes locally
2. Verifying the generated site at `http://localhost:4000`
3. Checking that all links, images, and formatting render correctly

## Security Considerations

- The `.gitignore` file excludes `node_modules/`, `public/`, and `db.json`
- Never commit sensitive information (API keys, passwords) to the repository
- The `_config.yml` contains deployment credentials via Git SSH URL

## Git Branching Strategy

This repository uses a **dual-branch workflow** for Hexo + GitHub Pages deployment:

### Branch Overview

| Branch | Purpose | Content | Push Method |
|--------|---------|---------|-------------|
| `main` | Website files | Generated static HTML/CSS/JS | `hexo deploy` (automatic) |
| `source` | Source files | `_config.yml`, posts, themes, drafts | Manual `git push` |

### Why Two Branches?

1. **GitHub Pages Limitation**: GitHub Pages can only serve from one branch (`main` by default)
2. **Hexo Workflow**: Hexo generates static files from source files, and these need separate version control
3. **Clean Separation**: Source files (editable) and generated files (machine-generated) should not mix

### Workflow

```bash
# 1. Work on source branch
git checkout source

# 2. Edit configs, write posts, modify themes...
vim source/_posts/my-post.md

# 3. Commit source changes
git add -A
git commit -m "docs: add new post"
git push origin source

# 4. Deploy to main branch (generates and pushes website files)
hexo deploy
```

### Branch Details

**`main` branch**:
- Contains the generated static site from `hexo generate`
- Used by GitHub Pages to serve the website
- Should never be manually edited (always overwritten by `hexo deploy`)

**`source` branch**:
- Contains all source files needed to regenerate the site
- Includes: `_config.yml`, `source/`, `themes/`, `scaffolds/`, `package.json`
- Excludes: `node_modules/`, `public/`, `.deploy_git/` (in `.gitignore`)

### Initial Setup

If cloning on a new machine:
```bash
git clone git@github.com:Aqiu16717/Aqiu16717.github.io.git
cd Aqiu16717.github.io
git checkout source
npm install
```

## Dependency Management

Dependabot is configured (`.github/dependabot.yml`) to check for npm package updates daily with a limit of 20 open pull requests.

## Useful Resources

- [Hexo Documentation](https://hexo.io/docs/)
- [Hexo Configuration](https://hexo.io/docs/configuration.html)
- [Hexo Deployment](https://hexo.io/docs/one-command-deployment.html)
- [Landscape Theme](https://github.com/hexojs/hexo-theme-landscape)
