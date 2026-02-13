# 更新日志

## v2.0.0 (2026-02-13)

### 🔄 简化更新 (Latest)

**移除 CLI 工具：**
- 删除 `cli.mjs` - 不再提供命令行工具
- 删除 `.docsrc.json` 配置文件
- 简化远程上传方式，只保留 REST API

**保留的上传方式：**
- ✅ REST API - 直接 HTTP 调用，更通用
- ✅ Git Webhook - 推送自动更新
- ✅ 示例代码 - JS/Python/Shell 完整示例

**理由：**
- REST API 更通用，适合任何编程语言
- 减少维护负担，专注核心功能
- AI 集成直接调用 API 更简单

---

## v2.0.0 (2026-02-13) - Initial Release

### 🎉 重大更新

#### 远程文档管理

- **REST API**: 新增文档上传、删除 API 端点
  - `POST /api/docs` - 上传或更新文档
  - `DELETE /api/docs/:filename` - 删除文档
  - 使用 Bearer Token 认证保护 API

- **CLI 工具**: 全新的命令行工具 (`cli.mjs`)
  - `docs-share upload <file>` - 上传文档
  - `docs-share delete <file>` - 删除文档
  - `docs-share list` - 列出所有文档
  - `docs-share init` - 初始化配置文件
  - 支持批量上传：`docs-share upload *.md`

- **Git Webhook**: 支持 GitHub/GitLab webhook 自动部署
  - 推送到仓库自动执行 `git pull`
  - 通过 `ENABLE_WEBHOOK=true` 启用
  - 适合团队协作和 CI/CD 集成

#### 前端增强

- **搜索功能**: 实时搜索文档标题、描述和文件名
  - 高亮匹配结果
  - 支持键盘快捷键（ESC 清除）
  - 显示过滤后的文档数量

- **刷新功能**: 无需刷新页面即可加载新文档
  - 一键刷新按钮
  - 加载动画反馈
  - 保持当前搜索状态

- **UI 改进**:
  - 文档计数显示
  - 更流畅的动画效果
  - 改进的响应式布局

#### 配置和部署

- **环境变量支持**: 通过 `.env` 文件配置
  - `PORT` - 服务器端口
  - `API_KEY` - API 认证密钥
  - `ENABLE_WEBHOOK` - 启用 webhook
  - `GIT_REPO_PATH` - Git 仓库路径

- **配置文件**: CLI 工具配置 (`.docsrc.json`)
  - 服务器地址
  - API 密钥
  - 支持项目级和用户级配置

#### 文档和工具

- **新增文档**:
  - `API-参考.md` - 完整的 API 文档
  - `使用指南.md` - 详细使用说明
  - `DEPLOYMENT.md` - 部署检查清单
  - 更新的 `README.md` - 包含所有新功能

- **脚本工具**:
  - `webhook-setup.sh` - Webhook 配置向导
  - `.env.example` - 环境变量示例
  - `.docsrc.example.json` - CLI 配置示例

### 🔒 安全改进

- API 认证保护上传和删除操作
- 文件名清理防止路径遍历
- CORS 配置
- 配置文件自动添加到 `.gitignore`

### 🎨 用户体验

- 服务器启动时显示详细信息（端口、API 状态等）
- 更好的错误消息和日志
- 搜索结果高亮显示

### 📚 AI 集成支持

- 提供 JavaScript/Python/Shell 示例代码
- 简化的 API 接口方便 AI 自动发布文档
- CLI 工具支持脚本化操作

---

## v1.0.0 (2026-02-13)

### 初始版本

- 零配置 Markdown 文档站
- 自动扫描 `docs/` 目录
- 暗色主题界面
- 响应式设计
- 文档下载功能
- Docker 支持
- GitHub Actions CI/CD
