# AGENTS.md - Aqiu's Blog

## Project Overview

Personal technical blog powered by [Hexo 8.0.0](https://hexo.io/) + Cactus theme, hosted on GitHub Pages.

- **Website**: https://aqiu16717.github.io/
- **Author**: aq1u (aqiu16717@gmail.com)
- **Language**: Chinese (zh-CN)
- **Repo**: https://github.com/Aqiu16717/Aqiu16717.github.io

## Quick Start

```bash
# Install dependencies
npm install

# Dev server
npm run server      # http://localhost:4000

# Build & Deploy
npm run build       # hexo generate
./deploy.sh         # full deploy with git commit
```

## Project Structure

```
├── _config.yml          # Hexo config
├── source/
│   ├── _posts/          # Blog posts (Markdown)
│   ├── _drafts/         # Drafts
│   └── about/           # About page
├── themes/cactus/       # Theme files
├── scaffolds/           # Post templates
└── public/              # Generated site
```

## Writing Posts

```bash
hexo new post "Title"    # Create post
hexo new draft "Title"   # Create draft
hexo publish draft "X"   # Publish draft
```

Front-matter:
```yaml
---
title: Post Title
date: 2026-04-12 00:00:00
tags: [tag1, tag2]
categories: category
---
```

## Deployment

This repo has two branches:
- `source` - Hexo source files (work here)
- `main` - Generated static files (auto-deployed to GitHub Pages)

Use `./deploy.sh` to deploy (cleans, generates, commits, pushes).

## Key Features

- Giscus comments (GitHub Discussions)
- RSS feed at `/atom.xml`
- Responsive design
- Code copy buttons
- Local search

---

*Last updated: 2026-04-12*
