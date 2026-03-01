# 📋 开源前检查清单

在将项目开源之前，请确认以下事项：

## 🔒 隐私和安全

- [x] ✅ 所有 API Key 都是示例值（`dev-key-change-in-production`）
- [x] ✅ 配置文件已添加到 `.gitignore`（`.env`, `.docsrc.json`）
- [x] ✅ 没有真实的服务器地址（只有 localhost、example.com）
- [x] ✅ 没有个人邮箱、电话等信息
- [x] ✅ 没有数据库密码、证书等敏感文件
- [x] ✅ 示例配置文件使用 `.example` 后缀
- [x] ✅ 本地开发配置文件（`ecosystem.*.json`）已加入 `.gitignore`，不追踪

## 🔍 隐私审计规范（每次提交前检查）

本节记录 2026-03-01 隐私审计结论及持续维护规范。

### 禁止提交到 git 的内容

| 类型 | 示例 | .gitignore 规则 |
|------|------|----------------|
| 环境变量 | `.env`, `.env.local` | `.env*`（已配置） |
| 本地开发配置 | `ecosystem.*.json` | `ecosystem.*.json`（已配置） |
| 私钥 / 证书 | `*.pem`, `*.key` | `*.pem`, `*.key` |
| 运行日志 | `*.log` | `*.log`（已配置） |
| 个人文档目录 | `docs/private/` | 手动检查 |
| 生产 compose 文件 | `data/docker-compose.yml` | 存在于服务器，不在仓库 |

### 每次提交前的快速扫描

```bash
# 检查是否有内网 IP 或生产服务器 IP 混入
grep -r "192\.168\." . --include="*.md" --include="*.json" --include="*.sh" --exclude-dir=.git

# 检查是否有本地绝对路径（含用户名）
grep -r "/Users/\|/home/[a-z]" . --include="*.json" --include="*.sh" --exclude-dir=.git

# 检查是否有硬编码密钥特征
grep -rE "(password|secret|api.?key)\s*[=:]\s*['\"][^'\"]{8,}" . --include="*.js" --include="*.mjs" --exclude-dir=.git
```

### 新增文件时的判断标准

提交新文件前，逐一回答：

1. **是否含本机绝对路径？**（`/Users/xxx`、`/home/xxx`）→ 含则不提交
2. **是否含真实 IP？**（内网 IP `192.168.*`、生产 IP）→ 含则不提交
3. **是否含凭证？**（密码、token、key 的真实值，非占位符）→ 含则不提交
4. **是否含个人信息？**（姓名、手机、邮箱）→ 含则不提交
5. **是否是纯本地配置？**（`ecosystem.local.json`、`.env`）→ 加 `.gitignore` 而非提交

### 审计历史记录

| 日期 | 执行人 | 结论 | 发现问题 |
|------|--------|------|---------|
| 2026-03-01 | Claude | 通过 | `ecosystem.xhs-preview.json` 含本地路径（已修复：从 git 移除并加入 `.gitignore`） |

## 📄 文档完整性

- [x] ✅ README.md 完整且更新
- [x] ✅ LICENSE 文件存在（MIT）
- [x] ✅ 包含使用说明和 API 文档
- [x] ✅ 包含部署指南
- [x] ✅ 包含示例代码
- [x] ✅ CHANGELOG 记录版本历史

## 🔧 代码质量

- [x] ✅ 代码中没有 TODO 或调试信息
- [x] ✅ 没有硬编码的配置
- [x] ✅ 错误处理完善
- [x] ✅ 代码注释清晰

## 🎯 功能完整性

- [x] ✅ 核心功能可用
- [x] ✅ 提供了示例和文档
- [x] ✅ Docker 配置正确
- [x] ✅ CI/CD 配置存在

## 📦 Package.json

- [x] ✅ 项目名称清晰
- [x] ✅ 版本号正确
- [x] ✅ 描述准确
- [x] ✅ 关键词恰当
- [x] ✅ License 声明
- [ ] ⚠️ 添加仓库地址（开源后）
- [ ] ⚠️ 添加作者信息（可选）
- [ ] ⚠️ 添加 bugs 链接（可选）

## 🌐 GitHub 仓库配置

开源后需要配置：

- [ ] 添加仓库描述
- [ ] 添加主题标签（tags）
- [ ] 设置仓库为 Public
- [ ] 创建第一个 Release
- [ ] 配置 GitHub Pages（可选）
- [ ] 添加 CONTRIBUTING.md（可选）
- [ ] 添加 CODE_OF_CONDUCT.md（可选）

## 🔍 最终检查

### 1. 检查 Git 历史

```bash
# 确保历史提交中没有敏感信息
git log --all --full-history --source -- "*secret*" "*password*" "*.env"

# 如果发现敏感信息，使用 git filter-branch 清理
```

### 2. 清理敏感文档

```bash
# 删除或移动个人文档
rm docs/private-*.md

# 只保留示例文档
ls docs/*.md
```

### 3. 测试全新安装

```bash
# 在新目录测试
cd /tmp
git clone <your-repo>
cd docs-share
npm start

# 确保可以正常运行
```

### 4. 更新 package.json

```json
{
  "name": "docs-share",
  "version": "2.0.0",
  "description": "零配置 Markdown 文档站，扔进 .md 文件即可访问",
  "repository": {
    "type": "git",
    "url": "https://github.com/your-username/docs-share.git"
  },
  "bugs": {
    "url": "https://github.com/your-username/docs-share/issues"
  },
  "homepage": "https://github.com/your-username/docs-share#readme",
  "author": "Your Name (可选)",
  "license": "MIT"
}
```

## 🚀 开源步骤

### 1. 准备代码

```bash
# 确保所有更改已提交
git add .
git commit -m "feat: add remote management and AI integration"

# 更新版本号
npm version 2.0.0

# 打标签
git tag -a v2.0.0 -m "Release v2.0.0"
```

### 2. 推送到 GitHub

```bash
# 推送代码
git push origin main

# 推送标签
git push origin v2.0.0
```

### 3. 创建 Release

在 GitHub 上：
1. 进入 Releases
2. 点击 "Create a new release"
3. 选择 tag v2.0.0
4. 标题：v2.0.0 - Remote Management & AI Integration
5. 描述：从 CHANGELOG.md 复制

### 4. 发布到 npm（可选）

```bash
# 登录 npm
npm login

# 发布
npm publish

# 现在用户可以使用：
# npx docs-share
```

### 5. 更新 Docker 镜像

```bash
# 构建并推送到 ghcr.io
docker build -t ghcr.io/your-username/docs-share:2.0.0 .
docker push ghcr.io/your-username/docs-share:2.0.0
docker tag ghcr.io/your-username/docs-share:2.0.0 ghcr.io/your-username/docs-share:latest
docker push ghcr.io/your-username/docs-share:latest
```

## 📢 推广（可选）

- [ ] 在 Reddit r/selfhosted 发帖
- [ ] 提交到 Awesome Lists
- [ ] 写一篇博客文章
- [ ] 分享到社交媒体

## ⚠️ 开源后注意

### 不要提交的内容

```bash
# 添加到 .gitignore
.env              # 真实配置
.docsrc.json      # CLI 配置
docs/private/     # 个人文档目录
*.key             # 密钥文件
*.pem             # 证书
```

### 定期检查

```bash
# 定期扫描敏感信息
git secrets --scan

# 或使用 truffleHog
truffleHog --regex --entropy=False .
```

---

## ✅ 当前状态

**你的项目已准备好开源！**

已完成：
- ✅ 所有敏感信息已清理
- ✅ 文档完整
- ✅ 功能完善
- ✅ 示例代码齐全
- ✅ 配置文件安全

待完成（开源后）：
- ⚠️ 更新 package.json 添加仓库链接
- ⚠️ 创建 GitHub Release
- ⚠️ 发布 Docker 镜像

---

🎉 **准备好开源了！**
