<!-- AGENTS.md - Aqiu's Blog -->

## Project Overview

This is **aq1u's personal technical blog** - a static site generated using [Hexo](https://hexo.io/) (version 8.0.0) and hosted on GitHub Pages. The blog is written primarily in Chinese (zh-CN) with some English content, focusing on programming, databases, and distributed systems.

- **Website**: https://aqiu16717.github.io/
- **Repository**: https://github.com/Aqiu16717/Aqiu16717.github.io
- **Author**: aq1u
- **Email**: aqiu16717@gmail.com
- **Generator**: Hexo 8.0.0
- **Theme**: Cactus (a clean, responsive, minimal theme)
- **Primary Language**: Chinese (zh-CN)

## Technology Stack

### Core Technologies
| Technology | Version | Purpose |
|------------|---------|---------|
| Hexo | 8.0.0 | Static site generator |
| Node.js | 18+ | Runtime for Hexo |
| EJS | 2.0.0 | Template engine |
| Marked | 7.0.0 | Markdown renderer |
| Stylus | 3.0.1 | CSS preprocessor |

### Hexo Plugins
| Plugin | Purpose |
|--------|---------|
| hexo-deployer-git | Git-based deployment |
| hexo-generator-archive | Archive page generator |
| hexo-generator-category | Category page generator |
| hexo-generator-feed | RSS/Atom feed generator |
| hexo-generator-index | Index page generator |
| hexo-generator-tag | Tag page generator |
| hexo-renderer-ejs | EJS template renderer |
| hexo-renderer-marked | Markdown renderer |
| hexo-renderer-stylus | Stylus CSS renderer |
| hexo-server | Development server |

### Frontend Libraries (Theme)
| Library | Version | Purpose |
|---------|---------|---------|
| jQuery | 3.6.x | DOM manipulation |
| Font Awesome | 6.x | Icon library |
| Clipboard.js | 2.x | Code copy functionality |
| Justified Gallery | 3.8.x | Image gallery layout |

### Comments & Analytics
- **Giscus** - GitHub Discussions-based comment system
  - Repository: `Aqiu16717/Aqiu16717.github.io`
  - Category: Announcements
- RSS Feed: Atom format at `/atom.xml`

## Project Structure

```
Aqiu16717.github.io/
├── _config.yml              # Main Hexo configuration
├── package.json             # Node.js dependencies
├── deploy.sh                # Deployment script
├── TODO.md                  # Blog improvement plan (Chinese)
├── scaffolds/               # Post/page templates
│   ├── draft.md
│   ├── page.md
│   └── post.md
├── source/                  # Source content (Markdown, images)
│   ├── _drafts/            # Draft posts (not published)
│   ├── _posts/             # Published blog posts
│   ├── about/              # About page
│   ├── en/                 # English content
│   └── images/             # Static images (logos, favicons, figures)
├── themes/                  # Theme directory
│   └── cactus/             # Cactus theme files
│       ├── _config.yml     # Theme configuration
│       ├── layout/         # EJS templates
│       ├── source/         # Theme assets (CSS, JS, fonts)
│       └── languages/      # i18n files
├── public/                  # Generated static site (gitignored)
├── node_modules/           # Node dependencies (gitignored)
└── .deploy_git/            # Deployment temp directory
```

### Content Organization

#### Blog Posts
- Location: `source/_posts/`
- Format: Markdown with YAML front-matter
- URL Pattern: `/:year/:month/:day/:title/`
- Example: `/2025/11/12/innodb/`

#### Drafts
- Location: `source/_drafts/`
- Drafts are not published until moved to `_posts/`

#### Multilingual Support
- Primary: Chinese (zh-CN)
- Secondary: English content in `source/en/`
- Language switcher available in navigation

### URL Patterns
| Page Type | URL Pattern |
|-----------|-------------|
| Home | `/` |
| Post | `/:year/:month/:day/:title/` |
| About | `/about/` |
| Archives | `/archives/` |
| Year Archive | `/archives/:year/` |
| Category | `/categories/:name/` |
| Tag | `/tags/:name/` |
| RSS Feed | `/atom.xml` |

## Build and Development Commands

### Prerequisites
```bash
# Install Node.js 18+ first, then:
npm install
```

### Available Scripts
```bash
# Build the site (generate static files)
npm run build
# or: hexo generate

# Clean generated files
npm run clean
# or: hexo clean

# Deploy to GitHub Pages
npm run deploy
# or: hexo deploy

# Start development server
npm run server
# or: hexo server

# Full deployment with git commit (custom script)
./deploy.sh
```

### Development Server
```bash
# Start local server at http://localhost:4000
hexo server

# With live reload
hexo server --watch
```

## Content Creation

### Creating a New Post
```bash
hexo new post "Post Title"
```
This creates `source/_posts/Post-Title.md` with template:
```markdown
---
title: Post Title
date: 2024-01-01 00:00:00
tags:
---
```

### Creating a Draft
```bash
hexo new draft "Draft Title"
```
Creates `source/_drafts/Draft-Title.md`

### Publishing a Draft
```bash
hexo publish draft "Draft Title"
```
Moves the draft from `_drafts/` to `_posts/`

### Creating a Page
```bash
hexo new page "Page Name"
```
Creates `source/page-name/index.md`

### Front-matter Options
```yaml
---
title: Post Title              # Required
date: 2024-01-01 00:00:00      # Required
tags: [tag1, tag2]             # Optional
categories: category-name      # Optional
lang: zh-CN                    # Optional (zh-CN or en)
comments: true                 # Optional (default: true)
---
```

## Theme Configuration

### Cactus Theme Settings
Theme config is in `_config.yml` under `theme_config:` section (overrides theme defaults):

```yaml
theme_config:
  # Navigation
  nav:
    home: /
    about: /about/
    articles: /archives/
    projects: https://github.com/Aqiu16717

  # Color scheme: dark, light, classic, white
  colorscheme: dark

  # Logo
  logo:
    enabled: true
    url: /images/logo.jpg

  # Social links
  social_links:
    - icon: github
      link: https://github.com/Aqiu16717
    - icon: mail
      link: mailto:aqiu16717@gmail.com

  # Posts on homepage
  posts_overview:
    show_all_posts: false
    post_count: 5

  # Copyright
  copyright:
    start_year: 2024

  # Giscus comments
  giscus:
    enabled: true
    repo: Aqiu16717/Aqiu16717.github.io
    repo_id: R_kgDOHKvpgw
    category: Announcements
    category_id: DIC_kwDOHKvpg84C1uo1
```

### Color Schemes Available
- `dark` (current) - Dark background with light text
- `light` - Light background with dark text
- `classic` - Sepia-toned classic look
- `white` - Clean white background

## Deployment Process

### Automated Deployment (Recommended)
```bash
./deploy.sh
```
This script:
1. Cleans previous build (`hexo clean`)
2. Generates and deploys to GitHub Pages (`hexo deploy`)
3. Commits source changes to git with timestamp message
4. Pushes to `source` branch

### Manual Deployment
```bash
# Generate static files
hexo clean
hexo generate

# Deploy to GitHub Pages
hexo deploy
```

### Git Branches
- `main` - Contains generated static files (deployed to GitHub Pages)
- `source` - Contains Hexo source files (posts, config, themes)

## Code Style Guidelines

### Markdown Writing
- Use Chinese for primary content
- Use English for technical terms where appropriate
- Include front-matter in all posts
- Use tags for better discoverability

### File Naming
- Post files: kebab-case (e.g., `my-post-title.md`)
- Images: descriptive names (e.g., `figure1.png`, `architecture-diagram.png`)

### Image Placement
- Static images: `source/images/`
- Reference in posts: `/images/filename.png`

## Testing Strategy

### Before Deployment
1. **Local Preview**: Run `hexo server` and verify at `http://localhost:4000`
2. **Link Check**: Verify internal links work
3. **Image Check**: Ensure all images display correctly
4. **Mobile Test**: Check responsive design in mobile view
5. **RSS Validation**: Verify `/atom.xml` is accessible

### After Deployment
1. **Live Site Check**: Visit `https://aqiu16717.github.io/`
2. **Comments Test**: Verify Giscus loads on posts
3. **RSS Feed**: Subscribe test with feed reader
4. **Social Links**: Verify all external links work

## Security Considerations

1. **No sensitive data** in repository (no API keys, passwords)
2. All comments through Giscus/GitHub (trusted platform)
3. Third-party resources loaded via CDN:
   - Giscus client from `giscus.app`
   - Other libraries from `cdnjs.cloudflare.com`
4. External links open in new tab (`target="_blank"` with `rel="noopener"`)

## Maintenance Notes

### Updating Dependencies
```bash
# Check outdated packages
npm outdated

# Update Hexo and plugins
npm update
```

Dependabot is configured to check for updates daily (see `.github/dependabot.yml`).

### Theme Updates
1. Review customizations in `_config.yml`
2. Check Cactus theme releases: https://github.com/probberechts/hexo-theme-cactus
3. Test thoroughly after theme update

### Adding New Features
1. Keep changes minimal (KISS principle)
2. Test on local server first
3. Verify mobile responsiveness
4. Update this AGENTS.md if needed

## Useful Resources

- **Hexo Documentation**: https://hexo.io/docs/
- **Cactus Theme**: https://github.com/probberechts/hexo-theme-cactus
- **Giscus Setup**: https://giscus.app/
- **Markdown Guide**: https://www.markdownguide.org/

## Contact & Links

- **GitHub**: https://github.com/Aqiu16717
- **Email**: aqiu16717@gmail.com
- **Blog**: https://aqiu16717.github.io/

---

*Last updated: 2026-04-12*
*This file is maintained for AI coding agents working on the project.*
