# 📚 Docs Share

零配置、零依赖的 Markdown 文档站。扔进 `.md` 文件，即刻可用。

## ✨ 特性

- **零配置** — 把 `.md` 文件放进 `docs/` 目录就完事了，自动发现、自动生成目录
- **零依赖** — 纯 Node.js 原生模块，无 npm 依赖
- **暗色主题** — 精心设计的深色界面，JetBrains Mono + Noto Sans SC 字体
- **响应式** — 桌面端侧边栏可收起展开，移动端自适应
- **一键下载** — 支持下载原始 Markdown 文件
- **Docker 友好** — 一行命令部署，支持 amd64/arm64

## 📸 截图

<!-- TODO: 添加截图 -->

## 🚀 快速开始

### 方式一：Docker（推荐）

```bash
docker run -d \
  -p 3457:3457 \
  -v /path/to/your/docs:/app/docs \
  ghcr.io/jx453331958/docs-share:latest
```

或使用 docker-compose：

```bash
git clone https://github.com/jx453331958/docs-share.git
cd docs-share

# 把你的 .md 文件放进 docs/ 目录
cp ~/my-notes/*.md docs/

docker compose up -d
```

### 方式二：Node.js

```bash
git clone https://github.com/jx453331958/docs-share.git
cd docs-share

# 把你的 .md 文件放进 docs/ 目录
cp ~/my-notes/*.md docs/

npm start
```

打开 http://localhost:3457 即可。

### 开发模式

```bash
npm run dev  # 文件变更自动重启
```

## ⚙️ 配置

| 环境变量 | 默认值 | 说明 |
|---------|-------|------|
| `PORT` | `3457` | 服务端口（需修改 server.mjs） |

文档目录默认为项目根目录下的 `docs/`。Docker 部署时通过 volume 挂载即可替换。

### 文档格式

- 支持标准 Markdown 语法
- 文件名作为 URL 路径
- 第一个 `# 标题` 会被提取为侧边栏标题
- 按文件修改时间倒序排列（最新的排最前）

## 🏗️ GitHub Actions

项目内置两个 workflow：

### CI（`ci.yml`）
- 触发：push 到 main / PR
- 内容：Node 18/20/22 多版本测试 + Docker 构建测试

### Docker 发布（`docker-publish.yml`）
- 触发：push tag（如 `v1.0.0`）
- 内容：构建 multi-arch（amd64/arm64）镜像，推送到 GitHub Container Registry

发布新版本：

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 📁 项目结构

```
docs-share/
├── server.mjs          # 服务端（零依赖，纯 Node.js）
├── docs/
│   ├── index.html      # 前端界面
│   └── *.md            # 你的文档（放这里就行）
├── Dockerfile
├── docker-compose.yml
├── package.json
└── .github/workflows/
    ├── ci.yml
    └── docker-publish.yml
```

## 📄 License

[MIT](LICENSE)
