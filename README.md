# Docs Share

零配置、零依赖的 Markdown 私有文档站。扔进 `.md` 文件，即刻可用，默认密码保护。

## 特性

### 核心功能
- **零配置** — 把 `.md` 文件放进 `docs/` 目录就完事了，自动发现、自动生成目录
- **零依赖** — 纯 Node.js 原生模块，无 npm 依赖，要求 Node.js >= 20
- **密码保护** — 单密码保护私有文档，简单安全
- **暗色主题** — 精心设计的深色界面，JetBrains Mono + Noto Sans SC 字体
- **响应式** — 桌面端侧边栏可收起展开，移动端自适应
- **实时搜索** — 支持文档标题搜索，实时过滤
- **排序** — 按时间、标题排序，支持自定义拖拽排序
- **一键刷新** — 无需刷新页面即可加载新文档
- **一键下载** — 支持下载原始 Markdown 文件
- **Docker 友好** — 一行命令部署，支持 amd64/arm64

### 远程更新
- **REST API** — HTTP API 上传、删除文档，支持 Bearer Token 认证
- **Git Webhook** — 推送到仓库自动更新服务器文档，支持 GitHub/GitLab

## 快速开始

### 一键安装脚本（推荐）

全自动安装、配置、更新：

**方式一：在线安装（快速）**
```bash
curl -fsSL https://raw.githubusercontent.com/jx453331958/docs-share-oss/main/install.sh | bash
```
适合快速尝试，运行后选择交互式菜单即可。

**方式二：克隆后安装（推荐）**
```bash
git clone https://github.com/jx453331958/docs-share-oss.git
cd docs-share-oss
./install.sh
```
适合需要频繁管理的场景，支持本地命令操作。

---

**支持功能：**
- 首次安装（Docker / PM2）
- 交互式配置 — 端口、API Key、访问密码、Webhook 全程引导，无需手动编辑配置文件
- 自动配置 Git Webhook（含私有仓库 SSH 认证）
- 自动更新到最新版
- 启动/停止/重启服务
- 状态检查和日志查看
- 一键卸载

**安装模式：**
```
1) Docker 容器运行（推荐）- 环境隔离，自动重启
2) PM2 进程管理 - 生产级进程守护，开机自启
```

**常用命令（需先克隆仓库）：**
```bash
./install.sh         # 显示交互式菜单
./install.sh install # 安装（交互式选择模式）
./install.sh update  # 更新到最新版
./install.sh config  # 重新配置（如 Webhook）
./install.sh start   # 启动服务
./install.sh status  # 查看状态
./install.sh logs    # 查看日志
```

**完整安装流程示例：**

```bash
./install.sh

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 环境配置（交互式生成）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. 服务端口配置
服务端口 [默认: 3457]: 8080  # 或直接回车使用默认

# 2. API 认证密钥
✓ 已自动生成 API Key

🔑 API Key (已自动生成，请保存):
   xxxxxxxxxxxxxxxxxxx

# 3. 访问鉴权配置
是否启用鉴权？[Y/n]  # 直接回车启用
访问密码: ********

🔒 访问密码
   密码: mypass123

# 4. Git Webhook 配置
是否启用 Webhook？[y/N]  # 可选

✅ 所有配置已完成！

# 无需手动编辑任何配置文件 ✓
```

---

### 手动安装

#### 方式一：Docker

```bash
docker run -d \
  -p 3457:3457 \
  -v /path/to/your/docs:/app/docs \
  -e ENABLE_AUTH=true \
  -e AUTH_PASSWORD=your-password \
  ghcr.io/jx453331958/docs-share-oss:latest
```

或使用 docker-compose：

```bash
git clone https://github.com/jx453331958/docs-share-oss.git
cd docs-share-oss

# 把你的 .md 文件放进 docs/ 目录
cp ~/my-notes/*.md docs/

docker compose up -d
```

#### 方式二：PM2

```bash
git clone https://github.com/jx453331958/docs-share-oss.git
cd docs-share-oss

# 配置环境
cp .env.example .env
nano .env  # 修改 AUTH_PASSWORD 和 API_KEY

# 安装 PM2
npm install -g pm2

# 启动服务
pm2 start server.mjs --name docs-share
pm2 save
pm2 startup  # 配置开机自启
```

#### 开发模式

```bash
git clone https://github.com/jx453331958/docs-share-oss.git
cd docs-share-oss

# 直接运行（热重载）
npm run dev  # 文件变更自动重启
```

## 配置

> 使用 `./install.sh` 安装时，所有环境变量都通过交互式问答自动生成，**无需手动编辑配置文件**。

### 环境变量

| 环境变量 | 默认值 | 说明 |
|---------|-------|------|
| `PORT` | `3457` | 服务端口 |
| `API_KEY` | 自动生成 | API 认证密钥（首次启动自动生成） |
| `ENABLE_AUTH` | `false` | 是否启用密码保护（install.sh 默认开启） |
| `AUTH_PASSWORD` | `admin` | 访问密码（仅 `ENABLE_AUTH=true` 时生效）|
| `ENABLE_WEBHOOK` | `false` | 是否启用 Git webhook |
| `WEBHOOK_SECRET` | - | Webhook 签名密钥（用于验证 GitHub/GitLab 请求） |
| `GIT_REPO_PATH` | 项目目录 | Git 仓库**绝对路径**（webhook 执行 `git pull` 的目录） |

**配置示例**（install.sh 自动创建）：

```bash
# 服务端口
PORT=8080

# API 认证密钥（自动生成）
API_KEY=xxxxxxxxxxxxxxxxxxx

# 访问鉴权
ENABLE_AUTH=true
AUTH_PASSWORD=mypass123

# Webhook（可选）
ENABLE_WEBHOOK=true
GIT_REPO_PATH=/home/user/my-docs
```

**手动修改配置**（仅在需要时）：

```bash
# PM2 模式
nano ~/.docs-share/.env
pm2 restart docs-share

# Docker 模式
nano ~/docs-share-data/docker-compose.yml
cd ~/docs-share-data && docker compose restart
```

### 文档格式

- 支持标准 Markdown 语法
- 文件名作为 URL 路径
- 第一个 `# 标题` 会被提取为侧边栏标题
- 默认按 Git 提交时间倒序排列，回退到文件修改时间

## 访问鉴权

### 密码保护

文档站支持单密码保护，通过 `ENABLE_AUTH=true` 启用。

#### 安装时配置（推荐）

运行 `./install.sh` 时会询问是否启用鉴权（默认启用）：

```
访问鉴权配置（保护私有文档）
是否启用鉴权？[Y/n]     # 直接回车 = 启用
访问密码: ******
```

#### 手动配置

编辑 `.env` 文件：

```bash
ENABLE_AUTH=true
AUTH_PASSWORD=your-password
```

重启服务生效：

```bash
# PM2 模式
pm2 restart docs-share

# Docker 模式
cd ~/docs-share-data && docker compose restart
```

### 禁用鉴权

设置 `ENABLE_AUTH=false` 即可改为公开访问，重启服务生效。

### 说明

- 启用后，所有页面都需要输入密码才能访问
- 登录后 Session 保持 7 天有效
- REST API 不受影响，仍使用 `Bearer Token`（`API_KEY`）认证
- 兼容 Basic Auth（密码部分匹配即可，忽略用户名）
- 建议生产环境配合 HTTPS 使用

### 从旧版迁移

如果你之前使用 `AUTH_USERS=admin:password` 格式，升级后会自动提取密码作为 `AUTH_PASSWORD`，并在启动日志中打印迁移提示。建议尽快改为 `AUTH_PASSWORD=password`。

---

## 远程更新文档

### REST API

#### 上传文档

```bash
curl -X POST http://your-server:3457/api/docs \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "my-doc.md",
    "content": "# My Document\n\nContent here..."
  }'
```

#### 删除文档

```bash
curl -X DELETE http://your-server:3457/api/docs/my-doc.md \
  -H "Authorization: Bearer your-api-key"
```

#### 列出文档

```bash
curl http://your-server:3457/api/docs
```

### Git Webhook 自动部署

> 首次安装时，`install.sh` 会自动引导配置 Webhook，包括私有仓库的 SSH 认证。
>
> 手动配置参考：
> - 快速配置：`./setup-github-ssh.sh`
> - 完整指南：[WEBHOOK-GUIDE.md](WEBHOOK-GUIDE.md)

#### 1. 启用 Webhook

在 `.env` 文件中：

```bash
ENABLE_WEBHOOK=true
WEBHOOK_SECRET=your-webhook-secret
```

> `WEBHOOK_SECRET` 用于验证请求来源。支持 GitHub 的 HMAC-SHA256 签名（`X-Hub-Signature-256`）和 GitLab 的 Token 验证（`X-Gitlab-Token`）。

#### 2. 设置 GIT_REPO_PATH

这是服务器上 Git 仓库的**本地路径**：

```bash
# 例如：你在服务器上克隆了文档仓库
GIT_REPO_PATH=/home/user/my-docs

# Docker 容器需要用容器内路径
GIT_REPO_PATH=/app/docs
```

#### 3. 配置 Git 仓库 Webhook

**GitHub:**
1. 进入仓库 Settings → Webhooks → Add webhook
2. Payload URL: `http://your-server:3457/api/webhook`
3. Content type: `application/json`
4. Secret: 填入 `WEBHOOK_SECRET` 的值
5. Events: 选择 "Just the push event"

**GitLab:**
1. 进入仓库 Settings → Webhooks
2. URL: `http://your-server:3457/api/webhook`
3. Secret Token: 填入 `WEBHOOK_SECRET` 的值
4. Trigger: 勾选 "Push events"

#### 4. 测试 Webhook

```bash
# 手动触发（GitHub 签名方式）
SECRET="your-webhook-secret"
BODY='{"ref":"refs/heads/main"}'
SIG="sha256=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | cut -d' ' -f2)"
curl -X POST http://your-server:3457/api/webhook \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: $SIG" \
  -d "$BODY"

# 手动触发（GitLab Token 方式）
curl -X POST http://your-server:3457/api/webhook \
  -H "Content-Type: application/json" \
  -H "X-Gitlab-Token: your-webhook-secret" \
  -d '{}'
```

完整配置指南见 [WEBHOOK-GUIDE.md](WEBHOOK-GUIDE.md)。

## API 端点

| 方法 | 路径 | 认证 | 说明 |
|------|------|------|------|
| `GET` | `/health` | 无 | 健康检查 |
| `GET` | `/api/docs` | Session 或 Bearer | 列出所有文档 |
| `POST` | `/api/docs` | Bearer | 上传文档 |
| `DELETE` | `/api/docs/:file` | Bearer | 删除文档 |
| `POST` | `/api/webhook` | Webhook Secret | Git webhook |
| `POST` | `/api/login` | 无 | 密码登录 |
| `POST` | `/api/logout` | 无 | 登出 |
| `GET` | `/api/me` | Session | 当前登录状态 |

## GitHub Actions

项目内置两个 workflow：

### CI（`ci.yml`）
- 触发：push 到 main / PR
- 内容：Node 20/22/24 多版本健康检查 + Docker 构建测试

### Docker 发布（`docker-publish.yml`）
- 触发：push 到 main 或 push tag（如 `v1.0.0`）
- 内容：构建 multi-arch（amd64/arm64）镜像，推送到 GitHub Container Registry

发布新版本：

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 项目结构

```
docs-share-oss/
├── server.mjs               # 服务端（零依赖，纯 Node.js）
├── install.sh               # 一键安装脚本
├── entrypoint.sh            # Docker 入口脚本
├── public/
│   ├── index.html           # 前端界面（文档列表、搜索、排序）
│   └── login.html           # 登录页
├── docs/
│   └── *.md                 # 你的文档（放这里就行）
├── examples/
│   ├── ai-integration.js    # AI 集成示例（Node.js）
│   └── ai-integration.py    # AI 集成示例（Python）
├── .env.example             # 环境变量示例
├── Dockerfile
├── docker-compose.yml
├── package.json
├── setup-github-ssh.sh      # GitHub SSH Deploy Key 配置脚本
├── webhook-setup.sh         # Webhook 快速配置脚本
├── WEBHOOK-GUIDE.md         # Webhook 完整配置指南
├── CHANGELOG.md
└── .github/workflows/
    ├── ci.yml               # CI 检查
    └── docker-publish.yml   # Docker 镜像发布
```

## 安全建议

1. **修改默认密码** — 默认密码为 `admin`，请务必修改
2. **API Key** — 首次启动会自动生成并保存到 `.env`，也可手动生成：`openssl rand -base64 32`
3. **使用 HTTPS** — 生产环境务必使用 HTTPS（通过 Nginx、Caddy 等反向代理）
4. **私有仓库使用 Deploy Key** — 运行 `./setup-github-ssh.sh` 或参考 [WEBHOOK-GUIDE.md](WEBHOOK-GUIDE.md)
5. **防火墙** — 个人使用建议限制访问 IP
6. **文件安全** — `.env` 已在 `.gitignore` 中，不会提交到仓库

## 故障排查

### API 上传失败

```bash
# 检查 API Key 是否正确
curl -X POST http://your-server:3457/api/docs \
  -H "Authorization: Bearer your-api-key" \
  -v

# 应该返回 401 如果 key 错误，400 如果缺少内容
```

### Webhook 不工作

```bash
# 1. 检查 ENABLE_WEBHOOK 是否设置为 true
echo $ENABLE_WEBHOOK

# 2. 手动测试 git pull
cd /path/to/repo && git pull

# 3. 检查服务器日志
# 应该能看到 [Webhook] 相关日志
pm2 logs docs-share  # PM2 模式
docker compose logs   # Docker 模式
```

### 登录问题

```bash
# 确认 ENABLE_AUTH 和 AUTH_PASSWORD 已正确设置
# Docker 模式检查 docker-compose.yml 中的 environment
# PM2 模式检查 .env 文件
```

## License

[MIT](LICENSE)
