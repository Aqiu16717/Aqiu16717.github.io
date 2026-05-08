# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal technical blog powered by [Hexo](https://hexo.io/) 8.0.0 + Cactus theme, hosted on GitHub Pages.

- **Website**: https://aqiu16717.github.io/
- **Language**: Chinese (zh-CN)
- **Theme**: Cactus (minimal, responsive, dark mode by default)

## Common Commands

```bash
# Development
npm install              # Install dependencies
npm run server           # Start dev server at http://localhost:4000

# Build & Deploy
npm run clean            # Clean generated files
npm run build            # Generate static site to public/
./deploy.sh              # Full deploy: clean, generate, commit, push to GitHub Pages
```

## Project Structure

```
├── _config.yml          # Hexo config + theme_config (nav, giscus, colorscheme)
├── source/
│   ├── _posts/          # Published blog posts (Markdown)
│   ├── _drafts/         # Draft posts
│   └── about/           # About page
├── themes/cactus/       # Cactus theme files
├── scaffolds/           # Post/draft templates
├── public/              # Generated static site (deployed to main branch)
└── .deploy_git/         # Hexo deployer git workspace
```

## Branch Structure

- `source` - Work here. Contains Hexo source files.
- `main` - Generated static site. Auto-deployed to GitHub Pages by hexo-deployer-git.

## Writing Posts

```bash
hexo new post "Title"              # Create new post in source/_posts/
hexo new draft "Title"             # Create draft in source/_drafts/
hexo publish draft "Title"         # Move draft to posts
```

### Front-matter Format

```yaml
---
title: Post Title
date: 2026-04-12 00:00:00
tags: [tag1, tag2]
categories: category
lang: zh-CN
---
```

## Theme Configuration

Theme settings are in `_config.yml` under `theme_config:`:

- **Color scheme**: `colorscheme: dark` (options: dark, light, classic, white)
- **Page width**: `page_width: 48`
- **Navigation**: Configured in `nav:` section
- **Giscus comments**: Configured with repo_id and category_id
- **RSS**: Enabled at `/atom.xml`

## Deployment Process

`./deploy.sh` performs:
1. `hexo clean` - Remove generated files
2. `hexo deploy` - Generate and push to main branch via git deployer
3. `git add . && git commit -m "feat: YYYY-MM-DD update posts"` - Commit source changes
4. `git push origin source` - Push source branch

## Key Features

- Giscus comments (GitHub Discussions)
- RSS feed at `/atom.xml`
- Responsive design with dark mode
- Code syntax highlighting via highlight.js
- Local search support
- i18n: Chinese (zh-CN) and English (en) support

## Commit Message Convention

Use English commit messages. Examples:
- `feat: add post about Raft algorithm`
- `chore: update theme configuration`
- `fix: correct typo in about page`
