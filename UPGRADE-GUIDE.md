# 🎉 v2.0 升级指南

恭喜！你的 Docs Share 已经升级到 v2.0，新增了强大的远程管理和 AI 集成功能。

## 🆕 新功能概览

### 1️⃣ 远程文档管理

现在可以从任何地方管理文档，无需直接访问服务器！

**三种方式：**
- **CLI 工具** - 命令行快速操作
- **REST API** - 编程接口集成
- **Git Webhook** - 自动同步部署

### 2️⃣ 前端增强

- ✅ 实时搜索文档
- ✅ 一键刷新列表
- ✅ 文档计数显示
- ✅ 更流畅的动画

### 3️⃣ AI 友好

- ✅ 简化的 API
- ✅ 示例代码（JS/Python）
- ✅ 一键发布脚本

## 🚀 快速开始新功能

### 使用 CLI 工具

```bash
# 1. 初始化配置
npx docs-share init

# 2. 编辑配置文件
nano .docsrc.json

# 3. 上传文档
npx docs-share upload my-doc.md
```

### 配置 Webhook

```bash
# 1. 启用 webhook
echo "ENABLE_WEBHOOK=true" >> .env

# 2. 重启服务器
pm2 restart docs-share  # 或 docker compose restart

# 3. 配置 GitHub webhook
# URL: http://your-server:3457/api/webhook
```

### AI 自动发布

```bash
# 运行示例
node examples/ai-integration.js "你的主题"
```

## ⚙️ 升级步骤

### 如果你使用 Docker

```bash
# 1. 拉取最新镜像
docker compose pull

# 2. 重启容器
docker compose up -d
```

### 如果你使用 Node.js

```bash
# 1. 拉取最新代码
git pull origin main

# 2. 创建配置文件（可选）
cp .env.example .env
nano .env  # 设置 API_KEY

# 3. 重启服务
pm2 restart docs-share
# 或
npm start
```

## 🔐 安全配置（重要！）

### 更改 API Key

```bash
# 生成强密码
API_KEY=$(openssl rand -base64 32)
echo "API_KEY=$API_KEY" >> .env

# 重启服务器使配置生效
```

### 使用 HTTPS

生产环境务必使用 HTTPS：

```nginx
# Nginx 配置示例
server {
    listen 443 ssl;
    server_name docs.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:3457;
    }
}
```

或使用 Caddy（自动 HTTPS）：

```
docs.example.com {
    reverse_proxy localhost:3457
}
```

## 📚 新增文件说明

| 文件 | 说明 |
|------|------|
| `cli.mjs` | CLI 工具（上传、删除、列表） |
| `.env.example` | 环境变量示例 |
| `.docsrc.example.json` | CLI 配置示例 |
| `webhook-setup.sh` | Webhook 配置向导 |
| `DEPLOYMENT.md` | 部署检查清单 |
| `CHANGELOG.md` | 版本更新日志 |
| `examples/` | 示例代码目录 |
| `docs/API-参考.md` | API 文档 |
| `docs/使用指南.md` | 使用说明 |

## 🎯 推荐工作流

### 个人使用

```bash
# 本地写文档
vim my-notes.md

# 一键上传
npx docs-share upload my-notes.md

# 访问文档站查看
```

### 团队协作

```bash
# 1. 文档放在 Git 仓库
# 2. 配置 webhook 自动部署
# 3. 团队成员 git push 即可

git add new-doc.md
git commit -m "Add new doc"
git push  # 自动部署！
```

### AI 集成

```bash
# AI 生成文档后
ai-tool generate > output.md

# 自动发布
npx docs-share upload output.md
```

## 🔄 向后兼容

v2.0 完全向后兼容 v1.0：

- ✅ 原有的文件直接放入 `docs/` 的方式仍然有效
- ✅ 前端界面保持相同的设计风格
- ✅ Docker 配置不变
- ✅ 所有现有文档自动迁移

**无需修改任何现有配置即可使用！**

## 📖 文档资源

- **README.md** - 完整功能说明
- **API-参考.md** - API 详细文档
- **使用指南.md** - 新手教程
- **DEPLOYMENT.md** - 部署指南
- **examples/** - 示例代码

## 💡 使用技巧

### 批量上传

```bash
# 上传所有 markdown 文件
npx docs-share upload *.md

# 上传指定目录
npx docs-share upload notes/*.md
```

### 自动化脚本

```bash
#!/bin/bash
# 每天定时备份并上传笔记

cd ~/Documents/notes
npx docs-share upload *.md
echo "Notes synced at $(date)"
```

### CI/CD 集成

```yaml
# GitHub Actions
- name: Deploy docs
  run: |
    echo '{"server":"${{ secrets.SERVER }}","apiKey":"${{ secrets.API_KEY }}"}' > .docsrc.json
    npx docs-share upload docs/*.md
```

## 🆘 需要帮助？

- 查看文档：`README.md`
- 运行示例：`./examples/quick-start.sh`
- 查看 API：访问 `/docs/API-参考.md`
- 报告问题：GitHub Issues

## 🎊 开始探索

```bash
# 试试搜索功能
# 在前端界面的搜索框输入关键词

# 试试刷新功能
# 添加新文档后点击刷新按钮

# 试试 CLI
npx docs-share --help

# 试试 API
curl http://localhost:3457/api/docs
```

---

🚀 **享受全新的 Docs Share v2.0！**
