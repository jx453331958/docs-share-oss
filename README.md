# 📚 Docs Share

零配置、零依赖的 Markdown 私有文档站。扔进 `.md` 文件，即刻可用，默认鉴权保护。

## ✨ 特性

### 核心功能
- **零配置** — 把 `.md` 文件放进 `docs/` 目录就完事了，自动发现、自动生成目录
- **零依赖** — 纯 Node.js 原生模块，无 npm 依赖
- **访问鉴权** — 内置 HTTP Basic Auth，保护私有文档，Web 端用户管理
- **用户管理** — 管理员通过 Web 界面添加/删除用户，无需编辑配置文件
- **暗色主题** — 精心设计的深色界面，JetBrains Mono + Noto Sans SC 字体
- **响应式** — 桌面端侧边栏可收起展开，移动端自适应
- **实时搜索** — 支持文档标题和内容搜索，实时过滤
- **一键刷新** — 无需刷新页面即可加载新文档
- **一键下载** — 支持下载原始 Markdown 文件
- **Docker 友好** — 一行命令部署，支持 amd64/arm64

### 远程更新
- **REST API** — HTTP API 上传、删除文档，支持 Bearer Token 认证
- **Git Webhook** — 推送到仓库自动更新服务器文档
- **AI 集成** — 简单的 API 调用，方便 AI 自动发布文档

## 📸 截图

<!-- TODO: 添加截图 -->

## 🚀 快速开始

### 一键安装脚本（推荐）⭐

全自动安装、配置、更新：

```bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/jx453331958/docs-share-oss/main/install.sh | bash

# 或克隆后运行
git clone https://github.com/jx453331958/docs-share-oss.git
cd docs-share-oss
./install.sh
```

**支持功能：**
- ✅ 首次安装（Docker / PM2）
- ✅ **交互式配置** — 端口、API Key、访问鉴权、Webhook 全程引导，无需手动编辑配置文件
- ✅ 自动配置 Git Webhook（含私有仓库 SSH 认证）
- ✅ 自动更新到最新版
- ✅ 启动/停止/重启服务
- ✅ 状态检查和日志查看
- ✅ 一键卸载

**安装模式：**
```bash
1) Docker 容器运行（推荐）- 环境隔离，自动重启
2) PM2 进程管理 - 生产级进程守护，开机自启
```

**常用命令：**
```bash
./install.sh install  # 安装（交互式选择模式）
./install.sh update   # 更新到最新版
./install.sh start    # 启动服务
./install.sh status   # 查看状态
./install.sh logs     # 查看日志
```

**完整安装流程示例：**

```bash
./install.sh

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ⚙️  环境配置（交互式生成）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. 服务端口配置
服务端口 [默认: 3457]: 8080  # 或直接回车使用默认

# 2. API 认证密钥
✓ 已自动生成 API Key

🔑 API Key (已自动生成，请保存):
   xxxxxxxxxxxxxxxxxxx

# 3. 访问鉴权配置
是否启用鉴权？[Y/n]  # 直接回车启用
用户名 [默认: admin]: alice
密码: ********

🔒 登录凭证
   用户名: alice
   密码:   mypass123

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
  ghcr.io/jx453331958/docs-share-oss:latest
```

或使用 docker-compose：

```bash
git clone https://github.com/jx453331958/docs-share-oss.git
cd docs-share

# 把你的 .md 文件放进 docs/ 目录
cp ~/my-notes/*.md docs/

docker compose up -d
```

#### 方式二：PM2（生产推荐）

```bash
git clone https://github.com/jx453331958/docs-share-oss.git
cd docs-share-oss

# 配置环境
cp .env.example .env
nano .env  # 修改 API_KEY

# 安装 PM2
npm install -g pm2

# 启动服务
pm2 start server.mjs --name docs-share
pm2 save
pm2 startup  # 配置开机自启
```

#### 开发模式

```bash
# 克隆仓库
git clone https://github.com/jx453331958/docs-share-oss.git
cd docs-share-oss

# 直接运行（热重载）
npm run dev  # 文件变更自动重启
```

## ⚙️ 配置

> **💡 一键脚本自动生成配置**
> 使用 `./install.sh` 安装时，所有环境变量都通过交互式问答自动生成，**无需手动编辑配置文件**。

### 环境变量

| 环境变量 | 默认值 | 说明 |
|---------|-------|------|
| `PORT` | `3457` | 服务端口 |
| `API_KEY` | 自动生成 | API 认证密钥（首次启动自动生成） |
| `ENABLE_AUTH` | `true` | 是否启用前端访问鉴权（默认启用，保护私有文档） |
| `AUTH_USERS` | `admin:admin` | 授权用户列表（格式：`user1:pass1,user2:pass2`）⚠️ 请修改默认密码 |
| `ENABLE_WEBHOOK` | `false` | 是否启用 Git webhook |
| `GIT_REPO_PATH` | 项目目录 | Git 仓库**绝对路径**（webhook 执行 `git pull` 的目录） |

**自动生成的配置示例** （安装脚本自动创建）：

```bash
# Docs Share 配置文件
# 自动生成于: 2026-02-13 10:30:00

# 服务端口（安装时询问）
PORT=8080

# API 认证密钥（自动生成）
API_KEY=xxxxxxxxxxxxxxxxxxx

# 访问鉴权（安装时配置）
ENABLE_AUTH=true
AUTH_USERS=alice:mypass123

# Webhook（可选，安装时配置）
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
- 按文件修改时间倒序排列（最新的排最前）

## 🔒 访问鉴权

### 默认启用，保护私有文档

文档站**默认启用** HTTP Basic Auth 鉴权，保护私有文档：

#### 方式一：安装时配置（推荐）

运行 `./install.sh` 时会询问是否启用鉴权（默认启用）：

```
访问鉴权配置（保护私有文档）
是否启用鉴权？[Y/n]     # 直接回车 = 启用（推荐）
用户名 [默认: admin]: alice
密码: ******
```

**禁用鉴权（改为公开访问）**：输入 `n`

#### 方式二：手动配置

编辑 `.env` 文件：

```bash
# 启用访问鉴权
ENABLE_AUTH=true

# 单用户
AUTH_USERS=admin:your-password

# 多用户（用逗号分隔）
AUTH_USERS=alice:pass123,bob:pass456,admin:admin123
```

重启服务生效：

```bash
# PM2 模式
pm2 restart docs-share

# Docker 模式
cd ~/docs-share-data && docker compose restart
```

### 用户管理（Web 界面）

管理员可以通过 Web 界面管理用户，无需手动编辑配置文件：

#### 添加用户

```bash
# 方式 1: Web 界面（推荐）
1. 使用管理员账号登录文档站
2. 访问 /users.html 或点击用户管理菜单
3. 输入新用户名和密码
4. 点击"添加用户"

# 方式 2: API 调用
curl -X POST http://localhost:3457/api/users \
  -u admin:password \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","password":"pass123"}'
```

#### 删除用户

```bash
# Web 界面
1. 在用户列表中找到要删除的用户
2. 点击"删除"按钮

# API 调用
curl -X DELETE http://localhost:3457/api/users/alice \
  -u admin:password
```

#### 查看用户列表

```bash
# API 调用
curl http://localhost:3457/api/users \
  -u admin:password
```

**权限说明：**
- **管理员** — 可以添加/删除用户，查看所有文档
- **普通用户** — 只能查看文档，无法管理用户
- 管理员账号在安装时配置，无法通过 Web 界面删除

---

### 禁用鉴权（改为公开访问）

如需将文档站改为公开访问（如开源项目文档）：

**PM2 模式：**

```bash
# 编辑配置
nano ~/.docs-share/.env

# 修改为
ENABLE_AUTH=false

# 重启服务
pm2 restart docs-share
```

**Docker 模式：**

```bash
# 编辑配置
nano ~/docs-share-data/docker-compose.yml

# 修改环境变量
environment:
  - ENABLE_AUTH=false

# 重启容器
cd ~/docs-share-data
docker compose restart
```

### 访问体验

启用鉴权后，浏览器访问文档站会弹出登录框：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔒 需要登录

此文档站受保护，请输入用户名和密码。
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

输入用户名和密码后，浏览器会记住凭证（直到关闭浏览器）。

### 重要说明

- ✅ **保护前端访问** — 所有页面（首页、文档内容）都需要登录
- ✅ **不影响 API** — REST API 仍使用 `Bearer Token`（`API_KEY`）认证
- ✅ **支持多用户** — 团队协作，每人独立账号
- ✅ **浏览器原生** — HTTP Basic Auth，无需额外依赖
- ⚠️ **建议配合 HTTPS** — 生产环境务必使用 HTTPS，避免密码明文传输

---

## 📡 远程更新文档

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

> **💡 一键脚本已集成自动配置**
> 首次安装时，`install.sh` 会自动引导配置 Webhook，包括私有仓库的 SSH 认证。
>
> 手动配置参考：
> - 快速配置：`./setup-github-ssh.sh`
> - 完整指南：[WEBHOOK-GUIDE.md](WEBHOOK-GUIDE.md#-github-认证配置重要)

#### 1. 启用 Webhook

在服务器上设置环境变量：

```bash
export ENABLE_WEBHOOK=true
```

或在 `.env` 文件中：

```
ENABLE_WEBHOOK=true
```

#### 2. 设置 GIT_REPO_PATH

**关键概念：** 这是服务器上 Git 仓库的**本地路径**

```bash
# 例如：你在服务器上克隆了文档仓库
cd /home/user
git clone https://github.com/yourname/my-docs.git

# 那么 GIT_REPO_PATH 就是
GIT_REPO_PATH=/home/user/my-docs

# Docker 容器需要用容器内路径
GIT_REPO_PATH=/app/docs
```

#### 3. 配置 Git 仓库 Webhook

**GitHub:**
1. 进入仓库 Settings → Webhooks → Add webhook
2. Payload URL: `http://your-server:3457/api/webhook`
3. Content type: `application/json`
4. Events: 选择 "Just the push event"

**GitLab:**
1. 进入仓库 Settings → Webhooks
2. URL: `http://your-server:3457/api/webhook`
3. Trigger: 勾选 "Push events"

#### 4. 测试 Webhook

```bash
# 手动触发
curl -X POST http://your-server:3457/api/webhook

# 本地推送测试
git push  # 服务器应该自动 git pull
```

**📖 完整配置指南：** 查看 [WEBHOOK-GUIDE.md](WEBHOOK-GUIDE.md) 了解详细示例和故障排查

## 🤖 AI 集成示例

### JavaScript/Node.js

```javascript
// AI 生成文档后自动上传
async function uploadDoc(filename, content) {
  const response = await fetch('http://your-server:3457/api/docs', {
    method: 'POST',
    headers: {
      'Authorization': 'Bearer your-api-key',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ filename, content }),
  });
  return response.json();
}

// 使用 Claude 4.6 生成并上传
import Anthropic from '@anthropic-ai/sdk';

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

async function generateAndUpload(topic) {
  // 1. AI 生成内容
  const message = await anthropic.messages.create({
    model: 'claude-opus-4-6',
    max_tokens: 8192,
    messages: [{
      role: 'user',
      content: `写一篇关于${topic}的技术文档，使用 Markdown 格式`
    }],
  });

  const content = message.content[0].text;

  // 2. 自动上传
  const filename = `${topic.replace(/\s+/g, '-')}.md`;
  return uploadDoc(filename, content);
}

// 执行
await generateAndUpload('React Hooks 详解');
```

### Python

```python
import anthropic
import requests

def upload_doc(server, api_key, filename, content):
    response = requests.post(
        f'{server}/api/docs',
        headers={'Authorization': f'Bearer {api_key}'},
        json={'filename': filename, 'content': content}
    )
    return response.json()

def generate_and_upload(topic):
    # 1. AI 生成内容
    client = anthropic.Anthropic(api_key='your-anthropic-key')
    message = client.messages.create(
        model='claude-opus-4-6',
        max_tokens=8192,
        messages=[{
            'role': 'user',
            'content': f'写一篇关于{topic}的技术文档，使用 Markdown 格式'
        }]
    )
    content = message.content[0].text

    # 2. 自动上传
    filename = f'{topic.replace(" ", "-")}.md'
    return upload_doc('http://localhost:3457', 'your-api-key', filename, content)

# 执行
result = generate_and_upload('FastAPI 最佳实践')
print('发布成功:', result)
```

### Shell 脚本

```bash
#!/bin/bash
# AI 生成并上传文档

API_KEY="your-api-key"
SERVER="http://localhost:3457"
FILENAME="$1"
CONTENT="$2"

curl -X POST "$SERVER/api/docs" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"filename\":\"$FILENAME\",\"content\":\"$CONTENT\"}"
```

## 🏗️ GitHub Actions

项目内置两个 workflow：

### CI（`ci.yml`）
- 触发：push 到 main / PR
- 内容：Node 20/22/24 LTS 多版本测试 + Docker 构建测试

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
├── server.mjs               # 服务端（零依赖，纯 Node.js）
├── install.sh               # 一键安装脚本
├── docs/
│   ├── index.html           # 前端界面（搜索、刷新等功能）
│   └── *.md                 # 你的文档（放这里就行）
├── examples/                # 示例代码（AI 集成等）
├── .env.example             # 环境变量示例
├── webhook-setup.sh         # Webhook 配置脚本
├── Dockerfile
├── docker-compose.yml
├── package.json
└── .github/workflows/
    ├── ci.yml
    └── docker-publish.yml
```

## 🎯 完整工作流示例

### 场景 1：个人笔记站

```bash
# 1. 部署到服务器
docker run -d -p 3457:3457 \
  -v ~/my-docs:/app/docs \
  -e API_KEY=$(openssl rand -base64 32) \
  ghcr.io/jx453331958/docs-share-oss:latest

# 2. 直接放置文档
cp my-note.md ~/my-docs/

# 或通过 API 上传
curl -X POST http://localhost:3457/api/docs \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"filename":"note.md","content":"# My Note\n\nContent..."}'
```

### 场景 2：团队文档站 + Git Webhook

```bash
# 1. 文档存储在 Git 仓库
git clone https://github.com/your-team/docs.git
cd docs

# 2. 服务器启用 webhook
# .env 中设置 ENABLE_WEBHOOK=true

# 3. 配置 GitHub webhook 指向服务器

# 4. 团队成员提交文档
git add new-doc.md
git commit -m "Add new documentation"
git push

# 服务器自动更新！
```

### 场景 3：AI 自动发布

```bash
# AI 生成文档脚本
cat > publish-ai-doc.sh << 'EOF'
#!/bin/bash
API_KEY="your-api-key"
SERVER="http://localhost:3457"

# AI 生成的文档
CONTENT=$(cat ai-output.md)
FILENAME="ai-generated-$(date +%Y%m%d).md"

# 上传到文档站
curl -X POST "$SERVER/api/docs" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"filename\":\"$FILENAME\",\"content\":$(echo "$CONTENT" | jq -Rs .)}"

echo "AI 文档已发布到文档站"
EOF

chmod +x publish-ai-doc.sh
```

## 🔒 安全建议

1. **API Key 自动生成**
   ```bash
   # 首次启动会自动生成并保存到 .env
   # 或手动生成：
   openssl rand -base64 32
   ```

2. **私有仓库使用 Deploy Key**
   ```bash
   # 运行自动配置脚本
   ./setup-github-ssh.sh

   # 或查看完整指南
   cat WEBHOOK-GUIDE.md
   ```

2. **使用 HTTPS**
   - 生产环境务必使用 HTTPS（通过 Nginx、Caddy 等反向代理）
   - Webhook 和 API 都应该通过 HTTPS 访问

3. **防火墙配置**
   - 如果只是个人使用，考虑限制访问 IP
   - API 端点建议配置速率限制

4. **文件安全**
   - `.env` 和 `.docsrc.json` 已在 `.gitignore` 中，不会提交到仓库
   - 不要在文档中包含敏感信息

## 🐛 故障排查

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

# 2. 检查 Git 配置
cd /path/to/repo
git config user.name
git config user.email

# 3. 手动测试 git pull
git pull

# 4. 检查服务器日志
# 应该能看到 [Webhook] 相关日志
```

### CLI 连接失败

```bash
# 1. 检查服务器是否可访问
curl http://your-server:3457/api/docs

# 2. 检查配置文件
cat .docsrc.json

# 3. 使用 verbose 模式（如果支持）
DEBUG=* npx docs-share upload test.md
```

## 📄 License

[MIT](LICENSE)
