# 🚀 部署检查清单

## 首次部署

### 1. 环境准备

- [ ] Node.js 18+ 已安装
- [ ] Git 已安装（如使用 webhook）
- [ ] 防火墙已配置允许访问端口

### 2. 配置

**复制并编辑环境变量：**

```bash
cp .env.example .env
nano .env
```

**必须修改的配置：**

```bash
# 生成强密码作为 API Key
API_KEY=$(openssl rand -base64 32)
echo "API_KEY=$API_KEY" >> .env

# 如果需要 webhook
echo "ENABLE_WEBHOOK=true" >> .env
```

### 3. 启动服务

**开发环境：**

```bash
npm run dev
```

**生产环境（Docker）：**

```bash
docker compose up -d
```

**生产环境（Node.js）：**

```bash
# 使用 PM2
npm install -g pm2
pm2 start server.mjs --name docs-share
pm2 save
pm2 startup
```

### 4. 验证

```bash
# 检查服务器
curl http://localhost:3457/api/docs

# 检查 API（需要替换 API_KEY）
curl -X POST http://localhost:3457/api/docs \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.md","content":"# Test"}'
```

## 客户端配置

### CLI 工具

在本地电脑或 CI/CD 环境：

```bash
# 创建配置文件
cat > .docsrc.json << EOF
{
  "server": "https://docs.example.com",
  "apiKey": "your-api-key-here"
}
EOF

# 测试上传
echo "# Test" > test.md
npx docs-share upload test.md
```

### Git Webhook

1. 在 Git 托管平台配置 webhook：
   - URL: `https://your-server/api/webhook`
   - Method: POST
   - Events: Push events

2. 测试 webhook：

```bash
curl -X POST https://your-server/api/webhook
```

## 安全检查

- [ ] API_KEY 已更改（不是默认值）
- [ ] 使用 HTTPS（通过反向代理）
- [ ] .env 文件已添加到 .gitignore
- [ ] .docsrc.json 已添加到 .gitignore
- [ ] 配置了防火墙规则
- [ ] 考虑设置速率限制（通过 Nginx 等）

## 反向代理配置

### Nginx

```nginx
server {
    listen 80;
    server_name docs.example.com;

    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name docs.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # 速率限制
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    location / {
        proxy_pass http://localhost:3457;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api/ {
        limit_req zone=api burst=20;
        proxy_pass http://localhost:3457;
    }
}
```

### Caddy（更简单）

```
docs.example.com {
    reverse_proxy localhost:3457
}
```

Caddy 自动配置 HTTPS！

## 监控

### 使用 PM2

```bash
# 查看状态
pm2 status

# 查看日志
pm2 logs docs-share

# 重启
pm2 restart docs-share
```

### 使用 Docker

```bash
# 查看日志
docker compose logs -f

# 重启
docker compose restart

# 查看状态
docker compose ps
```

## 备份

### 备份文档

```bash
# 定时备份脚本
cat > /etc/cron.daily/docs-backup << 'EOF'
#!/bin/bash
tar -czf /backup/docs-$(date +%Y%m%d).tar.gz /path/to/docs-share/docs/
# 保留最近 30 天
find /backup -name "docs-*.tar.gz" -mtime +30 -delete
EOF

chmod +x /etc/cron.daily/docs-backup
```

### Git 备份

如果使用 Git，文档已经有版本控制：

```bash
# 设置自动推送到远程仓库
cd /path/to/docs-share
git remote add backup https://github.com/your/backup-repo.git

# 添加到 crontab
echo "0 2 * * * cd /path/to/docs-share && git push backup main" | crontab -
```

## 更新

### 标准更新流程（必须遵守）

本项目通过 GitHub Actions 自动构建 Docker 镜像并推送至 GHCR。**生产服务器只需拉取镜像，无需克隆源码。**

```
本地修改 → git commit → git push → GitHub Actions 自动构建镜像 → 服务器 docker compose pull && up
```

**本地：**

```bash
git add <files>
git commit -m "描述变更"
git push  # 推送后 GitHub Actions 自动构建新镜像
```

**服务器（等 Actions 完成后）：**

```bash
cd /path/to/docs-share-oss   # 只含 docker-compose.yml + docs/ 数据目录
docker compose pull
docker compose up -d
```

或直接用一键脚本：

```bash
curl -fsSL https://raw.githubusercontent.com/jx453331958/docs-share-oss/main/install.sh | bash -s update
```

### 生产服务器目录结构

生产服务器上**只应存在**以下内容，不需要克隆完整源码：

```
docs-share-oss/
├── docker-compose.yml   # 使用 image: ghcr.io/...，不是 build: .
└── docs/                # 文档数据（持久化）
```

`docker-compose.yml` 示例：

```yaml
services:
  docs-share:
    image: ghcr.io/jx453331958/docs-share-oss:latest
    container_name: docs-share
    ports:
      - "3191:3457"
    volumes:
      - ./docs:/app/docs
    restart: unless-stopped
```

### 禁止事项

| 禁止做法 | 原因 | 正确做法 |
|---------|------|---------|
| `scp`/`rsync` 直接覆盖服务器文件 | 绕过版本控制，且会破坏服务器本地配置 | git push，等 CI 构建镜像后 pull |
| 未 commit 直接部署 | 无法回滚，无法复现 | 先 commit + push，再部署 |
| 服务器用 `build: .` 从源码构建 | 需要克隆完整源码，且不经过 CI，可能与发布镜像不一致 | 使用 `image: ghcr.io/...` 拉取预构建镜像 |
| 将源码 clone 到生产服务器 | 生产只需数据目录和 compose 文件，源码是多余的 | 仅保留 `docker-compose.yml` + `docs/` |

## 故障排查

### 服务器无法启动

```bash
# 检查端口占用
lsof -i :3457

# 检查日志
pm2 logs docs-share --lines 50

# 或 Docker
docker compose logs --tail 50
```

### API 认证失败

```bash
# 确认 API Key
cat .env | grep API_KEY

# 测试认证
curl -v -X POST http://localhost:3457/api/docs \
  -H "Authorization: Bearer $(grep API_KEY .env | cut -d= -f2)" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.md","content":"test"}'
```

### Webhook 不工作

```bash
# 检查环境变量
echo $ENABLE_WEBHOOK  # 应该是 true

# 检查 Git 配置
git config --list

# 手动测试 git pull
cd /path/to/repo
git pull

# 查看 webhook 日志（应该有 [Webhook] 前缀）
pm2 logs docs-share | grep Webhook
```

## 性能优化

### 启用 gzip（Nginx）

```nginx
location / {
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml;
    proxy_pass http://localhost:3457;
}
```

### 缓存静态资源（Nginx）

```nginx
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    proxy_pass http://localhost:3457;
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

## 扩展

### 多实例负载均衡

```nginx
upstream docs_backend {
    server 127.0.0.1:3457;
    server 127.0.0.1:3458;
    server 127.0.0.1:3459;
}

server {
    location / {
        proxy_pass http://docs_backend;
    }
}
```

启动多个实例：

```bash
PORT=3457 pm2 start server.mjs --name docs-1
PORT=3458 pm2 start server.mjs --name docs-2
PORT=3459 pm2 start server.mjs --name docs-3
```

---

✅ 完成这些步骤后，你的文档站就已经安全、稳定地运行了！
