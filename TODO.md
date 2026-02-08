# 博客改进计划

## 用户要求 📌

### 提交规范
- **拆分提交**：不要一次提交非常多的内容，尽量做好拆分
  - 主题安装单独提交
  - 配置修改单独提交
  - 功能添加单独提交
- **英文提交信息**：commit 信息使用英文

### 开发原则
- **KISS 原则**：Keep it simple and stupid（保持简单和直观）

### 开发规范
- **测试要求**：每次修改之后都要进行必要的测试
  - 我可以自己做的测试：代码生成、配置验证等
  - 需要用户做的测试：页面实际效果、功能交互等（我会提示你进行）

### 功能需求
- **RSS 订阅**：需要支持 RSS 订阅功能

---

## 已完成 ✅

### 1. 添加评论功能 ✅
- [x] 调研评论系统方案（Giscus/Gitalk/Disqus/Utterances）
- [x] 选择 Giscus（基于 GitHub Discussions，免费无广告）
- [x] 在 Cactus 主题中集成 Giscus 评论组件
- [x] 配置 Giscus 参数到 `_config.yml`
- [x] 获取并填入 repo_id 和 category_id
- [x] 重新生成网站

**Giscus 配置信息**：
- repo: `Aqiu16717/Aqiu16717.github.io`
- repo_id: `R_kgDOHKvpgw`
- category: `Announcements`
- category_id: `DIC_kwDOHKvpg84C1uo1`

### 2. 更换极致精简主题 ✅
- [x] 调研极简主题（选择 Cactus）
- [x] 安装 Cactus 主题（`git clone` 到 `themes/cactus`）
- [x] 配置主题（导航、社交链接、颜色方案等）
- [x] 创建 About 页面
- [x] 验证生成成功

**主题特点**：
- 响应式设计，支持深色/浅色模式
- 极简风格，专注内容
- 支持本地搜索
- 内置多种配色方案

### 3. RSS 订阅支持 ✅
- [x] 安装 hexo-generator-feed 插件
- [x] 配置 RSS 参数
- [x] 启用主题 RSS 支持

**RSS 信息**：
- 订阅地址：`https://aqiu16717.github.io/atom.xml`
- 格式：Atom
- 限制：20 篇文章

---

## 配置文件说明

### 主要修改文件
1. **`_config.yml`** - 主配置，包含：
   - 站点信息（标题、描述、作者等）
   - Cactus 主题配置
   - Giscus 评论配置
   - RSS 配置
   - 导航和社交链接

2. **`themes/cactus/layout/_partial/comments.ejs`** - 评论模板
   - 新增 Giscus 支持

3. **`source/about/index.md`** - 关于页面

---

## 后续建议

1. **启用评论**：完成 Giscus 配置后，评论功能即可使用
2. **定制主题**：可在 `_config.yml` 的 `theme_config` 中调整：
   - `colorscheme`: dark/light/classic/white
   - `page_width`: 页面宽度
   - `posts_overview`: 首页文章显示数量
3. **添加更多页面**：如友链、项目展示等
