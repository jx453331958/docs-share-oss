# 📦 安装指南

## 快速安装

### 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/jx453331958/docs-share-oss/main/install.sh | bash
```

或交互式安装：

```bash
git clone https://github.com/jx453331958/docs-share-oss.git
cd docs-share-oss
./install.sh
```

## 安装模式

### 1. Node.js 模式（推荐）

**适合：** 开发、个人使用

```bash
./install.sh install
# 选择: 1) Node.js 直接运行
```

**特点：**
- ✅ 安装简单，启动快速
- ✅ 方便调试和开发
- ✅ 占用资源少

**安装后：**
- 安装目录: `~/.docs-share`
- 文档目录: `~/docs-share-data/docs`
- 配置文件: `~/.docs-share/.env`
- CLI 配置: `~/.docsrc.json`

### 2. Docker 模式

**适合：** 生产环境、隔离部署

```bash
./install.sh install
# 选择: 2) Docker 容器运行
```

**特点：**
- ✅ 环境隔离，不污染系统
- ✅ 一键启停，方便管理
- ✅ 支持自动重启

**安装后：**
- 配置文件: `~/docs-share-data/docker-compose.yml`
- 文档目录: `~/docs-share-data/docs`
- CLI 配置: `~/.docsrc.json`

**管理命令：**
```bash
cd ~/docs-share-data
docker compose up -d      # 启动
docker compose down       # 停止
docker compose logs -f    # 查看日志
docker compose restart    # 重启
```

### 3. PM2 模式（生产推荐）

**适合：** 生产环境、需要进程管理

```bash
./install.sh install
# 选择: 3) PM2 进程管理
```

**特点：**
- ✅ 自动重启（崩溃恢复）
- ✅ 开机自启
- ✅ 日志管理
- ✅ 多进程负载均衡

**管理命令：**
```bash
pm2 status              # 查看状态
pm2 logs docs-share     # 查看日志
pm2 restart docs-share  # 重启
pm2 stop docs-share     # 停止
pm2 start docs-share    # 启动
```

## 脚本命令参考

### 安装和更新

```bash
./install.sh install   # 首次安装
./install.sh update    # 更新到最新版
```

### 服务管理

```bash
./install.sh start     # 启动服务
./install.sh stop      # 停止服务
./install.sh restart   # 重启服务
./install.sh status    # 查看状态
./install.sh logs      # 查看日志
```

### 配置和卸载

```bash
./install.sh config      # 重新配置
./install.sh uninstall   # 卸载（可选保留数据）
```

### 交互式菜单

```bash
./install.sh           # 显示主菜单
./install.sh menu      # 显示主菜单
```

## 环境要求

### Node.js 模式

- **必需：** Node.js >= 18
- **必需：** Git
- **可选：** PM2（生产环境）

**安装依赖：**

```bash
# macOS
brew install node git

# Ubuntu/Debian
sudo apt update
sudo apt install nodejs npm git

# CentOS/RHEL
sudo yum install nodejs git
```

### Docker 模式

- **必需：** Docker >= 20.10
- **可选：** Docker Compose（通常随 Docker 安装）

**安装 Docker：**

```bash
# 自动安装（Linux）
curl -fsSL https://get.docker.com | sh

# macOS/Windows
# 下载 Docker Desktop: https://www.docker.com/products/docker-desktop
```

## 自定义安装

### 自定义安装目录

```bash
# 设置环境变量
export INSTALL_DIR="/opt/docs-share"
export DATA_DIR="/var/docs-share"

./install.sh install
```

### 只下载不安装

```bash
git clone https://github.com/jx453331958/docs-share-oss.git
cd docs-share-oss

# 手动配置
cp .env.example .env
nano .env  # 编辑配置

# 手动启动
node server.mjs
```

## 配置说明

### 环境变量 (.env)

```bash
# 服务端口
PORT=3457

# API 密钥（重要！请修改）
API_KEY=your-secret-key-here

# Webhook（可选）
ENABLE_WEBHOOK=false
```

### CLI 配置 (~/.docsrc.json)

```json
{
  "server": "http://localhost:3457",
  "apiKey": "your-secret-key-here"
}
```

安装脚本会自动生成一致的 API Key。

## 验证安装

### 检查服务

```bash
# 方式 1：使用脚本
./install.sh status

# 方式 2：手动检查
curl http://localhost:3457/api/docs
```

**成功响应：** JSON 数组（文档列表）

### 测试上传

```bash
# 创建测试文档
echo "# Test" > test.md

# 使用 CLI 上传
npx docs-share upload test.md

# 或使用 API
curl -X POST http://localhost:3457/api/docs \
  -H "Authorization: Bearer $(jq -r .apiKey ~/.docsrc.json)" \
  -H "Content-Type: application/json" \
  -d '{"filename":"test.md","content":"# Test"}'
```

### 访问界面

打开浏览器访问：http://localhost:3457

## 升级指南

### 从 v1.x 升级到 v2.x

```bash
# 1. 备份数据
cp -r docs docs.backup

# 2. 运行更新
./install.sh update

# 3. 重启服务
./install.sh restart
```

**v2.0 新功能：**
- ✅ 完全向后兼容 v1.x
- ✅ 自动保留配置文件
- ✅ 文档无需迁移

## 故障排查

### 服务无法启动

```bash
# 检查端口占用
lsof -i :3457

# 查看日志
./install.sh logs

# 或手动运行查看错误
cd ~/.docs-share
node server.mjs
```

### 更新失败

```bash
# 清理并重新安装
./install.sh uninstall
./install.sh install
```

### CLI 无法连接

```bash
# 检查配置
cat ~/.docsrc.json

# 检查服务
curl http://localhost:3457/api/docs

# 重新配置
./install.sh config
```

## 卸载

### 完全卸载

```bash
./install.sh uninstall
```

**会询问：**
1. 是否保留文档数据？
2. 确认卸载？

### 手动卸载

```bash
# 停止服务
pm2 delete docs-share  # 如使用 PM2
# 或
cd ~/docs-share-data && docker compose down  # 如使用 Docker

# 删除文件
rm -rf ~/.docs-share
rm -rf ~/docs-share-data
rm ~/.docsrc.json
```

## 生产部署建议

### 使用 PM2 + Nginx

```bash
# 1. 安装 Docs Share（PM2 模式）
./install.sh install
# 选择: 3) PM2 进程管理

# 2. 配置 Nginx 反向代理
sudo nano /etc/nginx/sites-available/docs-share
```

```nginx
server {
    listen 80;
    server_name docs.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name docs.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:3457;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

```bash
# 3. 启用配置
sudo ln -s /etc/nginx/sites-available/docs-share /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 使用 Caddy（自动 HTTPS）

```bash
# 1. 安装 Caddy
curl -fsSL https://getcaddy.com | sh

# 2. 配置 Caddyfile
cat > Caddyfile << EOF
docs.example.com {
    reverse_proxy localhost:3457
}
EOF

# 3. 启动 Caddy
caddy start
```

### 定期备份

```bash
# 添加到 crontab
crontab -e
```

```cron
# 每天凌晨 2 点备份
0 2 * * * tar -czf ~/backups/docs-$(date +\%Y\%m\%d).tar.gz ~/docs-share-data/docs
```

## 技术支持

- 📖 **完整文档**: [README.md](README.md)
- 🐛 **问题反馈**: [GitHub Issues](https://github.com/jx453331958/docs-share-oss/issues)
- 💬 **讨论**: [GitHub Discussions](https://github.com/jx453331958/docs-share-oss/discussions)

---

🚀 **享受 Docs Share！**
