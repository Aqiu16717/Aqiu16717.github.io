# AGENTS.md - Aqiu's Blog

## Project Overview

This is a **personal technical blog** hosted on GitHub Pages, generated using the [Hexo](https://hexo.io/) static site generator (version 8.0.0). The blog is written in Chinese (zh-CN) and focuses on programming, databases, and distributed systems.

- **Website**: https://aqiu16717.github.io/
- **Repository**: https://github.com/Aqiu16717/Aqiu16717.github.io
- **Author**: Aqiu
- **Generator**: Hexo 8.0.0
- **Theme**: Cactus (a clean, responsive theme for Hexo)

## Technology Stack

### Core Technologies
- **Hexo 8.0.0** - Fast, simple & powerful blog framework
- **Node.js** - Runtime for Hexo (required for development)
- **EJS/Markdown** - Template and content formats

### Frontend Libraries
| Library | Version | Purpose |
|---------|---------|---------|
| jQuery | 3.x | DOM manipulation and event handling |
| Font Awesome | 6.x | Icon library |
| Clipboard.js | 2.x | Code block copy functionality |
| Justified Gallery | - | Image gallery layout |

### Comments & Analytics
- **Giscus** - GitHub Discussions-based comment system (configured for this repo)
- Reserved placeholders for: Google Analytics, Umami, Baidu Analytics, Cloudflare Analytics

## Project Structure

```
Aqiu16717.github.io/
├── index.html              # Homepage
├── 404.html                # 404 error page
├── atom.xml                # RSS/Atom feed
├── about/                  # About page
│   └── index.html
├── archives/               # Archives organized by year/month
│   ├── 2025/
│   ├── 2026/
│   └── index.html
├── categories/             # Category pages
│   └── 数据库/
├── tags/                   # Tag pages
│   ├── MVCC/
│   ├── 事务/
│   ├── 数据库/
│   ├── 隔离级别/
│   └── innodb-B-tree-B-tree/
├── 2025/                   # Blog posts by year/month/day
│   └── 11/
│       └── 12/
│           └── innodb/
│               └── index.html
├── 2026/
│   └── 02/
│       └── 09/
│           └── snapshot-isolation/
│               └── index.html
├── css/                    # Stylesheets
│   ├── style.css           # Main stylesheet (custom + basscss)
│   └── rtl.css             # Right-to-left language support
├── js/                     # JavaScript files
│   ├── main.js             # Main UI interactions (menu, scroll, etc.)
│   └── search.js           # Local search functionality
├── lib/                    # Third-party libraries
│   ├── clipboard/          # Clipboard.js
│   ├── font-awesome/       # Font Awesome icons
│   ├── jquery/             # jQuery
│   ├── justified-gallery/  # Image gallery
│   ├── meslo-LG/           # Meslo LG font files
│   └── vazir-font/         # Vazir Persian/Arabic font
└── images/                 # Static images
    ├── logo.jpg/png        # Site logo
    ├── favicon.ico         # Favicon
    ├── favicon-192x192.png # Large favicon
    └── apple-touch-icon.png # iOS icon
```

## Content Organization

### Blog Posts
- Posts are organized by date: `/YYYY/MM/DD/post-name/index.html`
- Each post has its own directory with an `index.html` file
- Post URLs are clean (without `.html` extension in the path)

### Categories & Tags
- Categories: Blog posts can be organized into categories (e.g., "数据库")
- Tags: Posts can have multiple tags for better discoverability
- Both categories and tags have their own index pages

### URL Patterns
| Page Type | URL Pattern |
|-----------|-------------|
| Home | `/` |
| Post | `/YYYY/MM/DD/post-name/` |
| About | `/about/` |
| Archives | `/archives/` |
| Year Archive | `/archives/YYYY/` |
| Category | `/categories/category-name/` |
| Tag | `/tags/tag-name/` |
| RSS Feed | `/atom.xml` |

## Development Workflow

> **Important**: This repository contains the **generated static files**, not the Hexo source files. The actual source (Markdown posts, theme config, _config.yml) is maintained in a separate repository or local environment.

### How Content is Published
1. Author writes posts in Markdown in the Hexo source project
2. Run `hexo generate` to build static files
3. Run `hexo deploy` or manually push generated files to this repository
4. GitHub Pages automatically serves the content

### Typical Hexo Commands (for reference)
```bash
# Create a new post
hexo new post "Post Title"

# Generate static files
hexo generate

# Start local server for preview
hexo server

# Deploy to GitHub Pages
hexo deploy
```

## File Modification Guidelines

### Safe to Modify Directly
- **images/** - Add new images or replace existing ones
- **css/style.css** - Custom CSS (note: theme updates may overwrite)
- **lib/** - Update third-party libraries (maintain same structure)

### Do NOT Modify Directly
- HTML files in post directories (will be overwritten on next generate)
- Archives, category, and tag index pages (auto-generated)
- `atom.xml` (auto-generated)

### Adding New Posts
Since this is the generated output repository:
1. Modify the **Hexo source project** instead
2. Or manually create a new post directory following the existing structure
3. Update related index pages (homepage, archives, categories, tags, RSS)

## Key Features

### 1. Responsive Navigation
- Mobile-friendly hamburger menu
- Auto-hiding navigation on scroll (desktop)
- Sticky footer navigation on mobile

### 2. Social Sharing
- Share buttons for: Facebook, Twitter, LinkedIn, Pinterest, Email, Pocket, Reddit, StumbleUpon, Digg, Tumblr, HackerNews
- Appears on every blog post

### 3. Table of Contents (TOC)
- Auto-generated TOC for posts with headings
- Desktop: Sidebar TOC
- Mobile: Footer TOC toggle

### 4. Code Copy
- "Copy to clipboard" button on all code blocks
- Visual feedback on successful copy

### 5. Comments (Giscus)
- GitHub Discussions-based commenting
- Configured repository: `Aqiu16717/Aqiu16717.github.io`
- Language: Chinese (zh-CN)

### 6. Local Search
- Client-side search functionality
- Searches through post titles and content
- Results displayed with context snippets

### 7. RSS Feed
- Atom format feed at `/atom.xml`
- Includes all published posts with metadata

## Code Style Guidelines

### HTML
- Indentation: 2 spaces
- Semantic HTML5 elements
- Schema.org microdata for SEO (`itemscope`, `itemtype`, `itemprop`)
- h-card microformat for author information

### CSS
- Main stylesheet uses a utility-first approach (similar to Basscss)
- Class naming: lowercase with hyphens
- RTL support via separate `rtl.css`

### JavaScript
- jQuery-based
- Comments in English (inherited from theme)
- Event delegation for dynamic elements

## SEO & Meta Tags

Each page includes:
- Open Graph tags (`og:*`)
- Twitter Card tags
- Article metadata (published time, modified time, author, tags)
- Viewport meta for mobile
- Canonical URLs

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- IE 11+ (with polyfills)
- Mobile browsers (iOS Safari, Chrome Mobile)

## Deployment

- **Platform**: GitHub Pages
- **Branch**: `main` (default)
- **Custom Domain**: Not configured (uses default github.io domain)
- **HTTPS**: Enabled by default

## Security Considerations

1. **No sensitive data** should be stored in this repository
2. All user input (comments) goes through Giscus/GitHub
3. Third-party scripts loaded from CDNs:
   - Giscus client from `giscus.app`
   - All other libraries are self-hosted in `/lib/`

## Maintenance Notes

### When Updating Theme
1. Backup custom modifications in `css/style.css`
2. Re-apply custom CSS after theme update
3. Verify all pages render correctly

### When Adding Features
- Keep changes minimal and non-breaking
- Test on both desktop and mobile
- Ensure RSS feed remains valid

## Contact & Links

- **GitHub**: https://github.com/Aqiu16717
- **Email**: aqiu16717@gmail.com
- **Blog**: https://aqiu16717.github.io/

---

*This file was generated for AI coding agents working on the project. For the actual blog content and Hexo source, please refer to the separate source repository or the author's local development environment.*
