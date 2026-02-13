# 🔗 Git Webhook 配置完整指南

## 📖 工作原理

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   GitHub    │  Push   │   Webhook    │  POST   │ Docs Share  │
│   (远程)     │ ──────> │   触发器      │ ──────> │   服务器     │
└─────────────┘         └──────────────┘         └─────────────┘
                                                         │
                                                         │ git pull
                                                         ↓
                                                  ┌─────────────┐
                                                  │  本地 Git   │
                                                  │   仓库      │
                                                  └─────────────┘
```

**核心概念：**
1. 服务器上有一个 Git 仓库的**本地克隆**
2. 这个本地克隆就是文档目录（docs/）
3. 当你 push 到 GitHub 时，触发 webhook
4. Webhook 告诉服务器："有新提交了"
5. 服务器在本地仓库执行 `git pull`
6. 文档自动更新！

---

## 🎯 完整配置步骤

### 场景 1：文档在独立的 Git 仓库（推荐）

假设你的文档在单独的仓库：`https://github.com/yourname/my-docs.git`

#### 第 1 步：在服务器上克隆文档仓库

```bash
# SSH 到服务器
ssh user@your-server.com

# 克隆文档仓库到指定位置
cd ~
git clone https://github.com/yourname/my-docs.git

# 文档仓库路径
/home/user/my-docs
```

#### 第 2 步：配置 Docs Share 使用这个仓库

**方法 A：Docker 模式**

```bash
# 修改 docker-compose.yml
cat > ~/docs-share-data/docker-compose.yml << EOF
version: '3.8'

services:
  docs-share:
    image: ghcr.io/jx453331958/docs-share-oss:latest
    container_name: docs-share
    ports:
      - "3457:3457"
    volumes:
      - /home/user/my-docs:/app/docs  # ← 挂载你的 Git 仓库
    environment:
      - PORT=3457
      - API_KEY=your-api-key
      - ENABLE_WEBHOOK=true             # ← 启用 webhook
      - GIT_REPO_PATH=/app/docs         # ← 容器内的路径
    restart: unless-stopped
EOF

# 重启容器
cd ~/docs-share-data
docker compose down
docker compose up -d
```

**方法 B：PM2 模式**

```bash
# 创建软链接（让 docs/ 指向你的 Git 仓库）
cd ~/.docs-share
rm -rf docs
ln -s /home/user/my-docs docs

# 配置环境变量
cat > .env << EOF
PORT=3457
API_KEY=your-api-key
ENABLE_WEBHOOK=true
GIT_REPO_PATH=/home/user/my-docs  # ← 你的 Git 仓库路径
EOF

# 重启服务
pm2 restart docs-share
```

#### 第 3 步：配置 GitHub Webhook

1. 打开仓库：https://github.com/yourname/my-docs
2. 进入 **Settings** → **Webhooks** → **Add webhook**
3. 填写配置：

```
Payload URL:  http://your-server.com:3457/api/webhook
Content type: application/json
Secret:       (留空)
SSL:          Enable (如果你用了 HTTPS)
Events:       Just the push event (只选推送事件)
Active:       ✓ (勾选)
```

4. 点击 **Add webhook**

#### 第 4 步：测试

```bash
# 在本地修改文档
cd ~/my-docs-local
echo "# New Doc" > new.md
git add new.md
git commit -m "Add new doc"
git push

# 查看服务器日志
# Docker:
docker compose logs -f

# PM2:
pm2 logs docs-share

# 应该看到：
# [Webhook] Received push event, pulling latest changes...
# [Webhook] Git pull output: ...
```

---

### 场景 2：文档在 Docs Share 项目内

假设你用的是 Docs Share 项目本身的 docs/ 目录

#### 第 1 步：将整个项目变成 Git 仓库

```bash
# SSH 到服务器
ssh user@your-server.com

# 如果是用安装脚本装的
cd ~/.docs-share

# 创建 Git 仓库
git init
git add docs/
git commit -m "Initial docs"

# 关联远程仓库
git remote add origin https://github.com/yourname/docs-share-deploy.git
git push -u origin main
```

#### 第 2 步：配置环境变量

```bash
# 编辑 .env
cat > .env << EOF
PORT=3457
API_KEY=your-api-key
ENABLE_WEBHOOK=true
GIT_REPO_PATH=/home/user/.docs-share  # ← 项目根目录
EOF

# 重启
pm2 restart docs-share
```

#### 第 3 步：配置 GitHub Webhook

同场景 1 的第 3 步

---

## 📝 GIT_REPO_PATH 详解

### 这个路径是什么？

**它是服务器上 Git 仓库的本地路径**，webhook 会在这个目录执行 `git pull`。

### 示例对比

| 场景 | GIT_REPO_PATH 值 | 说明 |
|------|-----------------|------|
| **独立文档仓库** | `/home/user/my-docs` | 你克隆的文档仓库位置 |
| **项目内 docs/** | `/home/user/.docs-share` | Docs Share 安装目录 |
| **Docker 容器** | `/app/docs` | 容器内挂载的路径 |
| **自定义位置** | `/var/www/docs` | 你放文档的任意位置 |

### Docker 特别说明

Docker 容器内外路径不同：

```yaml
volumes:
  - /home/user/my-docs:/app/docs  # 主机路径:容器路径

environment:
  - GIT_REPO_PATH=/app/docs  # ← 使用容器内路径！
```

---

## 🔍 完整配置示例

### 示例 1：个人博客文档（独立仓库 + Docker）

```bash
# 服务器上的目录结构
/home/user/
├── blog-docs/              # ← Git 仓库（文档）
│   ├── .git/
│   ├── intro.md
│   └── guide.md
└── docs-share-data/
    └── docker-compose.yml

# docker-compose.yml 内容
version: '3.8'
services:
  docs-share:
    image: ghcr.io/jx453331958/docs-share-oss:latest
    ports:
      - "3457:3457"
    volumes:
      - /home/user/blog-docs:/app/docs  # 挂载文档仓库
    environment:
      - API_KEY=abc123xyz
      - ENABLE_WEBHOOK=true
      - GIT_REPO_PATH=/app/docs         # 容器内路径

# GitHub Webhook URL
http://myblog.com:3457/api/webhook

# 工作流程
本地: git push origin main
  ↓
GitHub 触发 webhook
  ↓
POST → http://myblog.com:3457/api/webhook
  ↓
服务器在 /app/docs (容器内) 执行 git pull
  ↓
实际拉取到 /home/user/blog-docs (主机上)
  ↓
文档自动更新！
```

---

### 示例 2：团队知识库（独立仓库 + PM2）

```bash
# 服务器上的目录结构
/var/www/
└── team-wiki/              # ← Git 仓库（团队知识库）
    ├── .git/
    ├── README.md
    ├── api.md
    └── deployment.md

/home/user/.docs-share/
├── server.mjs
├── .env
└── docs -> /var/www/team-wiki  # ← 软链接

# .env 内容
PORT=3457
API_KEY=team-secret-key-2024
ENABLE_WEBHOOK=true
GIT_REPO_PATH=/var/www/team-wiki  # ← Git 仓库实际路径

# 启动
pm2 start server.mjs --name docs-share

# GitHub Webhook URL
https://wiki.company.com/api/webhook

# 工作流程
团队成员: git push origin main
  ↓
GitHub 触发 webhook
  ↓
POST → https://wiki.company.com/api/webhook
  ↓
服务器在 /var/www/team-wiki 执行 git pull
  ↓
所有人看到最新文档！
```

---

### 示例 3：项目内文档（PM2）

```bash
# 服务器上的目录结构
/home/user/.docs-share/     # ← Git 仓库（整个项目）
├── .git/
├── server.mjs
├── .env
└── docs/
    ├── guide.md
    └── api.md

# .env 内容
PORT=3457
API_KEY=my-api-key
ENABLE_WEBHOOK=true
GIT_REPO_PATH=/home/user/.docs-share  # ← 项目根目录

# GitHub 仓库
https://github.com/yourname/my-docs-share

# Webhook URL
http://server.com:3457/api/webhook

# 工作流程
本地:
  cd docs/
  echo "# New" > new.md
  git add docs/new.md
  git commit -m "Add new doc"
  git push
    ↓
GitHub 触发 webhook
    ↓
服务器在 /home/user/.docs-share 执行 git pull
    ↓
docs/new.md 自动出现在服务器上！
```

---

## ⚙️ 环境变量配置模板

### Docker 模式

```yaml
# docker-compose.yml
version: '3.8'

services:
  docs-share:
    image: ghcr.io/jx453331958/docs-share-oss:latest
    ports:
      - "3457:3457"
    volumes:
      - /absolute/path/to/git/repo:/app/docs  # ← 主机上的 Git 仓库
    environment:
      - PORT=3457
      - API_KEY=your-generated-api-key
      - ENABLE_WEBHOOK=true                    # ← 启用
      - GIT_REPO_PATH=/app/docs                # ← 容器内路径（固定）
    restart: unless-stopped
```

### PM2 模式

```bash
# .env
PORT=3457
API_KEY=your-generated-api-key
ENABLE_WEBHOOK=true
GIT_REPO_PATH=/absolute/path/to/git/repo  # ← 主机上的 Git 仓库绝对路径

# 例如：
# GIT_REPO_PATH=/home/user/my-docs
# GIT_REPO_PATH=/var/www/wiki
# GIT_REPO_PATH=/home/user/.docs-share
```

---

## 🔐 安全配置（可选）

### 使用 Webhook Secret

GitHub 支持 webhook secret 验证（防止伪造请求）。

**TODO:** 当前版本暂不支持，可以通过 Nginx 配置 IP 白名单：

```nginx
# 只允许 GitHub 的 webhook IP
location /api/webhook {
    allow 140.82.112.0/20;   # GitHub webhook IP 段
    allow 192.30.252.0/22;
    deny all;
    proxy_pass http://localhost:3457;
}
```

---

## 🧪 测试 Webhook

### 手动触发

```bash
# 直接调用 webhook 端点
curl -X POST http://your-server:3457/api/webhook

# 应该看到响应
{
  "success": true,
  "message": "Updated from git",
  "output": "Already up to date."
}
```

### 查看 GitHub Webhook 日志

1. 进入仓库 Settings → Webhooks
2. 点击你配置的 webhook
3. 查看 **Recent Deliveries**
4. 绿色勾 ✓ = 成功，红色叉 ✗ = 失败

---

## 🐛 常见问题

### Q: Webhook 返回 404

**原因：** `ENABLE_WEBHOOK` 未设置为 `true`

**解决：**
```bash
# 检查配置
cat .env | grep ENABLE_WEBHOOK

# 应该是
ENABLE_WEBHOOK=true  # 不是 false

# 重启服务
pm2 restart docs-share
# 或
docker compose restart
```

---

### Q: Webhook 触发但文档没更新

**原因：** `GIT_REPO_PATH` 路径不对

**解决：**
```bash
# 1. 检查路径是否存在
ls -la $GIT_REPO_PATH

# 2. 检查是否是 Git 仓库
cd $GIT_REPO_PATH
git status

# 3. 手动测试 git pull
git pull

# 4. 查看日志
pm2 logs docs-share | grep Webhook
```

---

### Q: Docker 容器内 git pull 失败

**原因：** 容器内没有 Git 凭证（私有仓库）

**解决：**

**方法 1：使用公开仓库（推荐）**

**方法 2：使用 SSH 密钥**
```yaml
volumes:
  - /home/user/my-docs:/app/docs
  - /home/user/.ssh:/root/.ssh:ro  # 挂载 SSH 密钥
```

**方法 3：使用 Personal Access Token**
```bash
# 在服务器仓库中配置
cd /home/user/my-docs
git remote set-url origin https://TOKEN@github.com/user/repo.git
```

---

### Q: GIT_REPO_PATH 应该填什么？

**答：填写服务器上 Git 仓库的绝对路径**

```bash
# 如何找到？
# 1. SSH 到服务器
# 2. 进入你的文档目录
cd /path/to/your/docs
# 3. 打印当前路径
pwd
# 输出：/home/user/my-docs  ← 这就是 GIT_REPO_PATH

# Docker 特殊情况：使用容器内路径
# 如果 volumes: /host/path:/container/path
# 则 GIT_REPO_PATH=/container/path
```

---

## 📚 更多资源

- [GitHub Webhooks 文档](https://docs.github.com/en/webhooks)
- [GitLab Webhooks 文档](https://docs.gitlab.com/ee/user/project/integrations/webhooks.html)
- [webhook-setup.sh](./webhook-setup.sh) - 自动配置脚本

---

🎉 **配置完成后，你只需 `git push`，文档就会自动更新！**
