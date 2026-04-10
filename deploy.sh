#!/bin/bash
set -e

echo "=== 部署博客 ==="

# 1. 部署到 GitHub Pages
hexo clean
hexo deploy

# 2. 提交并推送源文件
git add .
git commit -m "feat: $(date '+%Y-%m-%d') update posts" || echo "No changes to commit"
git push origin source

echo "=== 部署完成 ==="
