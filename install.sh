#!/bin/bash

###############################################################################
# Docs Share - 一键安装/管理脚本
# 支持：首次安装、更新、配置、启动、停止、卸载
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 版本信息
VERSION="2.0.0"
REPO="jx453331958/docs-share-oss"
# 默认安装路径（可通过环境变量覆盖）
INSTALL_DIR="${INSTALL_DIR:-./install}"
DATA_DIR="${DATA_DIR:-./data}"

# 打印带颜色的消息
info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

# 检测端口是否被占用
is_port_in_use() {
    local port=$1
    # 使用 lsof 或 netstat 检测端口
    if command -v lsof &> /dev/null; then
        lsof -i ":$port" -sTCP:LISTEN -t &> /dev/null
    elif command -v netstat &> /dev/null; then
        netstat -tuln 2>/dev/null | grep -q ":$port "
    elif command -v ss &> /dev/null; then
        ss -tuln 2>/dev/null | grep -q ":$port "
    else
        # 如果没有工具可用，尝试绑定端口测试
        (echo > /dev/tcp/127.0.0.1/$port) &> /dev/null
    fi
}

# 生成一个未被占用的随机端口
generate_available_port() {
    local min_port=${1:-3000}
    local max_port=${2:-9999}
    local port
    local max_attempts=50

    for ((i=0; i<max_attempts; i++)); do
        # 生成随机端口号
        port=$((RANDOM % (max_port - min_port + 1) + min_port))

        # 检测端口是否被占用
        if ! is_port_in_use "$port"; then
            echo "$port"
            return 0
        fi
    done

    # 如果 50 次都没找到，返回一个基础端口
    echo "3457"
    return 1
}

# 打印 Logo
print_logo() {
    cat << "EOF"
    ____                   ____  __
   / __ \____  __________/ ___\/  |  ____  ______  ____
  / / / / __ \/ ___/ ___/\__ \|  | /  _ \/  ___/_/ __ \
 / /_/ / /_/ / /__(__  )__/ / |  |(  <_> )___ \ \  ___/
/_____/\____/\___/____/____/  |  | \____/____  > \___  >
                              \__|           \/      \/
EOF
    echo -e "${BLUE}v${VERSION}${NC} - 零配置 Markdown 文档站"
    echo ""
}

# 检测系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
}

# 检查依赖
check_dependencies() {
    local missing=()

    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi

    if ! command -v node &> /dev/null; then
        missing+=("node (>=18)")
    else
        local node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$node_version" -lt 18 ]; then
            warning "Node.js 版本过低（当前: $node_version，需要: >=18）"
            missing+=("node (>=18)")
        fi
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        error "缺少依赖: ${missing[*]}"
        echo ""
        echo "安装依赖："
        if [[ "$OS" == "macos" ]]; then
            echo "  brew install git node"
        elif [[ "$OS" == "linux" ]]; then
            echo "  Ubuntu/Debian: sudo apt install git nodejs"
            echo "  CentOS/RHEL:   sudo yum install git nodejs"
        fi
        echo ""
        echo "或使用 Docker 模式（自动安装 Docker）"
        exit 1
    fi
}

# 安装
install() {
    print_logo
    info "开始安装 Docs Share..."
    echo ""

    detect_os

    # 交互式选择安装路径
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 安装路径配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "选择安装位置："
    echo "  1) 当前目录 - $(pwd)/install 和 $(pwd)/data（推荐）"
    echo "  2) 自定义路径"
    echo ""
    read -p "请选择 [1-2, 默认 1]: " path_choice < /dev/tty

    case ${path_choice:-1} in
        1)
            INSTALL_DIR="$(pwd)/install"
            DATA_DIR="$(pwd)/data"
            ;;
        2)
            echo ""
            read -p "安装目录 (程序文件) [默认: $(pwd)/install]: " custom_install_dir < /dev/tty
            read -p "数据目录 (文档和配置) [默认: $(pwd)/data]: " custom_data_dir < /dev/tty
            INSTALL_DIR="${custom_install_dir:-$(pwd)/install}"
            DATA_DIR="${custom_data_dir:-$(pwd)/data}"
            ;;
        *)
            INSTALL_DIR="$(pwd)/install"
            DATA_DIR="$(pwd)/data"
            ;;
    esac

    success "安装目录: $INSTALL_DIR"
    success "数据目录: $DATA_DIR"
    echo ""

    # 选择安装模式
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🚀 安装模式"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "请选择安装模式："
    echo "  1) Docker 容器运行（推荐）"
    echo "  2) PM2 进程管理（需要 Node.js >= 20）"
    echo ""
    read -p "请选择 [1-2, 默认 1]: " mode < /dev/tty
    mode=${mode:-1}

    case $mode in
        1) install_docker ;;
        2) install_pm2 ;;
        *) error "无效选择"; exit 1 ;;
    esac
}

# PM2 基础安装（不再调用 install_nodejs）
install_pm2_base() {
    info "准备 PM2 安装环境..."

    check_dependencies

    # 创建安装目录
    if [ -d "$INSTALL_DIR" ]; then
        warning "检测到已有安装，将进行更新..."
        update
        return
    fi

    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR/docs"

    # 克隆仓库
    info "下载源码..."
    git clone "https://github.com/$REPO.git" "$INSTALL_DIR" --quiet

    cd "$INSTALL_DIR"

    # 复制示例文档
    if [ ! -f "$DATA_DIR/docs/hello.md" ]; then
        cp docs/hello.md "$DATA_DIR/docs/" 2>/dev/null || true
    fi

    # 创建符号链接
    rm -rf "$INSTALL_DIR/docs"
    ln -s "$DATA_DIR/docs" "$INSTALL_DIR/docs"

    # 配置环境变量
    configure_env

    success "基础安装完成！"
}

# Docker 安装
install_docker() {
    info "使用 Docker 模式安装..."

    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        warning "未检测到 Docker，正在安装..."

        if [[ "$OS" == "linux" ]]; then
            curl -fsSL https://get.docker.com | sh
            sudo usermod -aG docker $USER
            success "Docker 安装完成（需要重新登录以生效）"
        else
            error "请先安装 Docker Desktop: https://www.docker.com/products/docker-desktop"
            exit 1
        fi
    fi

    mkdir -p "$DATA_DIR/docs"

    # 复制示例文档
    if [ ! -f "$DATA_DIR/docs/hello.md" ]; then
        cat > "$DATA_DIR/docs/hello.md" << 'EOF'
# Welcome to Docs Share

This is a sample document. Drop any `.md` files into the docs directory and they will appear automatically.

## Features

- Zero configuration
- Real-time search
- AI integration support
- Remote management via API/CLI
EOF
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚙️  环境配置（交互式生成）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 1. 配置端口
    info "1. 服务端口配置"
    echo ""

    # 生成一个未被占用的端口
    local default_port=$(generate_available_port 3000 9999)
    info "自动检测到可用端口: $default_port"
    echo ""

    read -p "服务端口 [默认: $default_port]: " custom_port < /dev/tty
    PORT=${custom_port:-$default_port}

    # 验证端口号
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        warning "端口号无效，使用自动检测的端口 $default_port"
        PORT=$default_port
    fi

    # 检查用户输入的端口是否被占用
    if [ -n "$custom_port" ] && is_port_in_use "$PORT"; then
        warning "端口 $PORT 已被占用"
        PORT=$(generate_available_port 3000 9999)
        success "已切换到可用端口: $PORT"
    fi

    success "端口: $PORT"
    echo ""

    # 2. 生成 API Key
    info "2. API 认证密钥"
    echo ""
    API_KEY=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
    success "已自动生成 API Key"
    echo ""

    # 创建 docker-compose.yml
    cat > "$DATA_DIR/docker-compose.yml" << EOF
services:
  docs-share:
    image: ghcr.io/jx453331958/docs-share-oss:latest
    container_name: docs-share
    ports:
      - "$PORT:$PORT"
    volumes:
      - ./docs:/app/docs
    environment:
      - PORT=$PORT
      - API_KEY=$API_KEY
      - ENABLE_WEBHOOK=false
    restart: unless-stopped
EOF

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔑 API Key (已自动生成，请保存):"
    echo ""
    echo "   $API_KEY"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    warning "用于 REST API 调用，请妥善保管"
    info "配置文件: $DATA_DIR/docker-compose.yml"
    echo ""

    # 3. 配置访问鉴权（Docker 模式）
    info "3. 访问鉴权配置"
    configure_auth_docker

    # 4. 配置 Webhook（Docker 模式）
    info "4. Git Webhook 配置"

    while true; do
        configure_webhook_docker
        local result=$?

        if [ $result -eq 2 ]; then
            # 用户选择跳过
            break
        elif [ $result -eq 0 ]; then
            # 配置成功
            success "Webhook 配置成功"
            break
        else
            # 配置失败
            echo ""
            warning "Webhook 配置失败"
            echo ""
            echo "可能的原因："
            echo "  - 仓库地址格式错误"
            echo "  - SSH 密钥未添加到 GitHub Deploy Keys"
            echo "  - 网络连接问题"
            echo "  - 仓库不存在或无权限访问"
            echo ""
            read -p "是否重试 Webhook 配置？[y/n, 默认 n] " retry_webhook < /dev/tty
            retry_webhook=${retry_webhook:-n}

            if [[ "$retry_webhook" != "y" && "$retry_webhook" != "Y" ]]; then
                warning "已跳过 Webhook 配置（不影响基本功能）"
                echo ""
                info "稍后可重新配置 Webhook："
                echo "  curl -fsSL https://raw.githubusercontent.com/jx453331958/docs-share-oss/main/install.sh | bash"
                echo "  选择菜单中的 '8) 配置管理'"
                break
            fi

            echo ""
            info "重新配置 Webhook..."
        fi
    done

    echo ""
    success "✅ 基础配置已完成！"
    echo ""

    # 启动
    read -p "是否现在启动服务？[y/n, 默认 y] " start_now < /dev/tty
    start_now=${start_now:-y}
    if [[ "$start_now" != "n" && "$start_now" != "N" ]]; then
        cd "$DATA_DIR"
        docker compose up -d
        success "服务已启动！"
        echo ""
        info "访问: http://localhost:$PORT"
        info "查看日志: cd $DATA_DIR && docker compose logs -f"
    fi
}

# PM2 安装
install_pm2() {
    info "使用 PM2 模式安装..."

    check_dependencies

    # 检查 PM2
    if ! command -v pm2 &> /dev/null; then
        info "正在安装 PM2..."
        npm install -g pm2
        success "PM2 安装完成"
    fi

    # 执行基础安装
    install_pm2_base

    # 使用 PM2 启动
    cd "$INSTALL_DIR"
    pm2 start server.mjs --name docs-share
    pm2 save

    success "已使用 PM2 启动服务"
    echo ""
    info "安装目录: $INSTALL_DIR"
    info "文档目录: $DATA_DIR/docs"
    echo ""

    # 设置开机自启
    read -p "是否设置开机自启？[y/n, 默认 y] " setup_startup < /dev/tty
    setup_startup=${setup_startup:-y}
    if [[ "$setup_startup" != "n" && "$setup_startup" != "N" ]]; then
        pm2 startup
        success "开机自启已配置"
        echo ""
        info "请按照提示执行 sudo 命令"
    fi

    # 从 .env 文件读取端口
    if [ -f "$INSTALL_DIR/.env" ]; then
        PORT=$(grep "^PORT=" "$INSTALL_DIR/.env" | cut -d'=' -f2)
        PORT=${PORT:-3457}
    else
        PORT=3457
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "访问地址: ${GREEN}http://localhost:$PORT${NC}"
    info "管理命令: ${YELLOW}pm2 status${NC}"
    info "查看日志: ${YELLOW}pm2 logs docs-share${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 配置访问鉴权（Docker 模式）
configure_auth_docker() {
    echo ""
    info "访问鉴权配置（保护私有文档）"
    echo ""
    echo "功能说明："
    echo "  - 默认启用访问鉴权，保护私有文档"
    echo "  - 访问文档站需要输入用户名和密码"
    echo "  - 使用 HTTP Basic Auth（浏览器原生支持）"
    echo "  - 不影响 API 调用（API 仍使用 Bearer Token）"
    echo ""
    read -p "是否启用鉴权？[y/n, 默认 y] " enable_auth < /dev/tty
    enable_auth=${enable_auth:-y}

    if [[ "$enable_auth" == "n" || "$enable_auth" == "N" ]]; then
        warning "已禁用鉴权，文档站将公开访问"
        return
    fi

    echo ""
    info "配置管理员账号"
    echo "  - 管理员可以通过 Web 界面添加更多用户"
    echo "  - 其他用户登录后只能查看文档"
    echo ""

    # 管理员账号配置
    read -p "管理员用户名 [默认: admin]: " auth_user < /dev/tty
    auth_user=${auth_user:-admin}

    # 密码输入（不回显）
    read -sp "管理员密码: " auth_pass < /dev/tty
    echo ""

    if [ -z "$auth_pass" ]; then
        warning "密码不能为空，使用默认密码: admin"
        auth_pass="admin"
    fi

    # 更新 docker-compose.yml 添加认证环境变量
    # 备份
    cp "$DATA_DIR/docker-compose.yml" "$DATA_DIR/docker-compose.yml.bak"

    # 在 environment 部分添加认证配置
    # 使用 sed 在 ENABLE_WEBHOOK=false 后添加
    sed -i.tmp "/ENABLE_WEBHOOK=false/a\\
      - ENABLE_AUTH=true\\
      - AUTH_USERS=$auth_user:$auth_pass" "$DATA_DIR/docker-compose.yml"
    rm -f "$DATA_DIR/docker-compose.yml.tmp"

    success "鉴权配置完成"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔒 管理员凭证"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   用户名: $auth_user"
    echo "   密码:   $auth_pass"
    echo "   权限:   管理员（可添加其他用户）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    warning "请妥善保管管理员凭证"
    echo ""
    info "添加更多用户:"
    echo "  1. 使用管理员账号登录文档站"
    echo "  2. 访问用户管理页面 (点击侧边栏用户图标)"
    echo "  3. 在 Web 界面中添加新用户"
    echo ""
}

# 配置 Git Webhook（Docker 模式）
configure_webhook_docker() {
    echo ""
    info "是否需要配置 Git Webhook 自动部署？"
    echo ""
    echo "功能说明："
    echo "  - 将文档托管在 Git 仓库（GitHub/GitLab）"
    echo "  - 推送代码后，服务器自动执行 git pull 更新文档"
    echo ""
    read -p "是否启用 Webhook？[y/n, 默认 n] " enable_webhook < /dev/tty
    enable_webhook=${enable_webhook:-n}

    if [[ "$enable_webhook" != "y" && "$enable_webhook" != "Y" ]]; then
        info "跳过 Webhook 配置"
        return 2
    fi

    echo ""
    echo "请输入 Git 仓库地址，支持以下格式："
    echo "  • yourname/my-docs"
    echo "  • https://github.com/yourname/my-docs"
    echo "  • git@github.com:yourname/my-docs.git"
    echo ""
    read -p "仓库地址: " REPO < /dev/tty

    if [ -z "$REPO" ]; then
        warning "未输入仓库地址，跳过 Webhook 配置"
        return 0
    fi

    # 标准化仓库地址：支持完整 URL 或 username/repo 格式
    # 移除可能的 https:// 或 http:// 或 git@ 前缀
    REPO=$(echo "$REPO" | sed -E \
        -e 's|^(https?://)?github\.com/||' \
        -e 's|^git@github\.com:||' \
        -e 's|\.git$||')

    # 验证格式是否正确 (应该是 username/repo)
    if ! echo "$REPO" | grep -qE '^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$'; then
        error "仓库地址格式不正确: $REPO"
        warning "正确格式: username/repo (例如: jx453331958/my-docs)"
        return 1
    fi

    success "仓库: $REPO"

    echo ""
    read -p "这是私有仓库吗？[y/n, 默认 n] " is_private < /dev/tty
    is_private=${is_private:-n}

    # 询问文档仓库克隆位置
    echo ""
    info "请选择文档仓库克隆位置："
    echo "  1) 数据目录内（跟随安装目录）: $DATA_DIR/repo"
    echo "  2) 独立目录: $HOME/${REPO##*/}"
    echo "  3) 自定义路径"
    read -p "请选择 [1-3, 默认 1]: " repo_location < /dev/tty

    case ${repo_location:-1} in
        1)
            DOCS_REPO_PATH="$DATA_DIR/repo"
            ;;
        2)
            DOCS_REPO_PATH="$HOME/${REPO##*/}"
            ;;
        3)
            read -p "请输入仓库克隆路径 [默认: $DATA_DIR/repo]: " custom_repo_path < /dev/tty
            DOCS_REPO_PATH="${custom_repo_path:-$DATA_DIR/repo}"
            ;;
        *)
            DOCS_REPO_PATH="$DATA_DIR/repo"
            ;;
    esac

    # 询问文档在仓库中的位置
    echo ""
    info "文档文件在仓库中的位置："
    echo "  1) 仓库根目录（所有 .md 文件在根目录）"
    echo "  2) docs/ 子目录（.md 文件在 docs/ 文件夹内）"
    echo "  3) 其他自定义路径"
    read -p "请选择 [1-3, 默认 1]: " docs_location < /dev/tty

    case ${docs_location:-1} in
        1) DOCS_SUBDIR="." ;;
        2) DOCS_SUBDIR="docs" ;;
        3)
            read -p "请输入文档所在子目录 [默认: . (根目录)]: " custom_dir < /dev/tty
            DOCS_SUBDIR="${custom_dir:-.}"
            ;;
        *) DOCS_SUBDIR="." ;;
    esac

    # 如果是私有仓库，配置 SSH Deploy Key
    if [[ "$is_private" == "y" || "$is_private" == "Y" ]]; then
        info "检测到私有仓库，需要配置 SSH Deploy Key"
        echo ""

        setup_github_ssh "$REPO"

        # 使用 SSH 克隆仓库
        if [ ! -d "$DOCS_REPO_PATH" ]; then
            info "克隆私有仓库..."
            HOST_NAME="github-${REPO//\//-}"
            info "使用 SSH 主机: $HOST_NAME"
            git clone "$HOST_NAME:$REPO.git" "$DOCS_REPO_PATH" 2>&1 || {
                error "克隆失败，请检查 SSH 配置"
                error "命令: git clone $HOST_NAME:$REPO.git $DOCS_REPO_PATH"
                return 1
            }
            success "仓库克隆完成"
        fi
    else
        # 公开仓库，直接使用 HTTPS 克隆
        if [ ! -d "$DOCS_REPO_PATH" ]; then
            info "克隆公开仓库..."
            git clone "https://github.com/$REPO.git" "$DOCS_REPO_PATH" 2>&1 || {
                error "克隆失败"
                error "命令: git clone https://github.com/$REPO.git $DOCS_REPO_PATH"
                return 1
            }
            success "仓库克隆完成"
        fi
    fi

    # 确定实际文档目录
    if [ "$DOCS_SUBDIR" = "." ]; then
        ACTUAL_DOCS_DIR="$DOCS_REPO_PATH"
    else
        ACTUAL_DOCS_DIR="$DOCS_REPO_PATH/$DOCS_SUBDIR"
    fi

    # 检查文档目录是否存在
    if [ ! -d "$ACTUAL_DOCS_DIR" ]; then
        error "文档目录不存在: $ACTUAL_DOCS_DIR"
        error "请检查仓库克隆是否成功，或文档子目录路径是否正确"
        return 1
    fi

    # 统计文档数量
    DOC_COUNT=$(find "$ACTUAL_DOCS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
    success "发现 $DOC_COUNT 个 Markdown 文档"

    # 更新 docker-compose.yml
    info "更新 Docker 配置..."

    # 备份原配置
    cp "$DATA_DIR/docker-compose.yml" "$DATA_DIR/docker-compose.yml.backup"

    # 更新 volumes 挂载点和环境变量
    cat > "$DATA_DIR/docker-compose.yml" << EOF
services:
  docs-share:
    image: ghcr.io/jx453331958/docs-share-oss:latest
    container_name: docs-share
    ports:
      - "3457:3457"
    volumes:
      - $ACTUAL_DOCS_DIR:/app/docs
EOF

    # 如果是私有仓库，需要挂载 SSH 密钥
    if [[ "$is_private" == "y" || "$is_private" == "Y" ]]; then
        cat >> "$DATA_DIR/docker-compose.yml" << EOF
      - $HOME/.ssh:/root/.ssh:ro
EOF
    fi

    cat >> "$DATA_DIR/docker-compose.yml" << EOF
    environment:
      - PORT=3457
      - API_KEY=$(grep "API_KEY" "$DATA_DIR/docker-compose.yml.backup" | cut -d'=' -f2)
      - ENABLE_WEBHOOK=true
      - GIT_REPO_PATH=/app/docs
EOF

    # 如果是私有仓库，添加 SSH 环境变量
    if [[ "$is_private" == "y" || "$is_private" == "Y" ]]; then
        SSH_KEY_NAME="github_docs_${REPO//\//_}"
        cat >> "$DATA_DIR/docker-compose.yml" << EOF
      - GIT_SSH_COMMAND=ssh -i /root/.ssh/$SSH_KEY_NAME -o StrictHostKeyChecking=no
EOF
    fi

    cat >> "$DATA_DIR/docker-compose.yml" << EOF
    restart: unless-stopped
EOF

    success "Webhook 配置完成"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 文档目录配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "Git 仓库: $DOCS_REPO_PATH"
    info "文档目录: $ACTUAL_DOCS_DIR"
    info "文档数量: $DOC_COUNT 个 .md 文件"
    echo ""

    # 获取配置的端口
    local webhook_port=3457
    if [ -f "$DATA_DIR/docker-compose.yml" ]; then
        webhook_port=$(grep "PORT=" "$DATA_DIR/docker-compose.yml" | head -1 | cut -d'=' -f2 | tr -d ' "')
    elif [ -f "$INSTALL_DIR/.env" ]; then
        webhook_port=$(grep "^PORT=" "$INSTALL_DIR/.env" | cut -d'=' -f2)
    fi
    webhook_port=${webhook_port:-3457}

    # 尝试自动检测服务器地址
    local server_addr=""
    if command -v curl &> /dev/null; then
        local detected_ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || curl -s --max-time 3 icanhazip.com 2>/dev/null || curl -s --max-time 3 api.ipify.org 2>/dev/null)
        # 验证是否为有效 IP 地址（IPv4 或 IPv6）
        if echo "$detected_ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$|^([0-9a-fA-F:]+)$'; then
            server_addr="$detected_ip"
        fi
    fi

    # 询问用户外网访问地址
    echo ""
    info "请输入服务器的外网访问地址"
    echo "  • 使用域名（如: docs.example.com）"
    echo "  • 使用 IP（如: 123.45.67.89）"
    echo "  • 可包含协议（如: https://docs.example.com）"
    echo ""
    if [ -n "$server_addr" ]; then
        echo -e "自动检测到 IP: ${GREEN}$server_addr${NC}"
        read -p "直接回车使用检测值，或输入自定义地址: " custom_addr < /dev/tty
        server_addr="${custom_addr:-$server_addr}"
    else
        warning "未能自动检测到公网地址"
        read -p "请输入外网访问地址: " custom_addr < /dev/tty
        server_addr="${custom_addr:-your-server}"
    fi

    # 解析用户输入的 URL
    local protocol="http"
    local host="$server_addr"
    local port=""

    # 提取协议（如果有）
    if [[ "$server_addr" =~ ^https:// ]]; then
        protocol="https"
        host="${server_addr#https://}"
    elif [[ "$server_addr" =~ ^http:// ]]; then
        protocol="http"
        host="${server_addr#http://}"
    fi

    # 提取端口（如果有）
    if [[ "$host" =~ :[0-9]+$ ]]; then
        port="${host##*:}"
        host="${host%:*}"
    fi

    # 智能判断是否需要端口号
    local webhook_url=""
    if [ -n "$port" ]; then
        # 用户明确指定了端口
        webhook_url="${protocol}://${host}:${port}/api/webhook"
    elif [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # 是 IP 地址，使用配置的端口
        webhook_url="${protocol}://${host}:${webhook_port}/api/webhook"
    else
        # 是域名，询问是否需要端口号
        echo ""
        info "检测到域名: $host"
        read -p "是否使用标准端口（80/443）？[y/n, 默认 y] " use_standard_port < /dev/tty
        use_standard_port=${use_standard_port:-y}

        if [[ "$use_standard_port" == "y" || "$use_standard_port" == "Y" ]]; then
            webhook_url="${protocol}://${host}/api/webhook"
        else
            webhook_url="${protocol}://${host}:${webhook_port}/api/webhook"
        fi
    fi

    echo ""
    success "Webhook URL: $webhook_url"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 稍后配置 GitHub Webhook（服务启动后）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "等服务启动完成后，按以下步骤配置："
    echo ""
    echo "1. 打开仓库: https://github.com/$REPO/settings/hooks"
    echo "2. 点击 Add webhook"
    echo -e "3. Payload URL: ${GREEN}$webhook_url${NC}"
    echo "4. Content type: application/json"
    echo "5. Events: Just the push event"
    echo "6. 点击 Add webhook"
    echo ""
    info "详细配置见: cat WEBHOOK-GUIDE.md"
    echo ""
}

# 配置 Git Webhook（PM2 模式，包含 SSH 认证）
configure_webhook() {
    echo ""
    info "是否需要配置 Git Webhook 自动部署？"
    echo ""
    echo "功能说明："
    echo "  - 将文档托管在 Git 仓库（GitHub/GitLab）"
    echo "  - 推送代码后，服务器自动执行 git pull 更新文档"
    echo ""
    read -p "是否启用 Webhook？[y/n, 默认 n] " enable_webhook < /dev/tty
    enable_webhook=${enable_webhook:-n}

    if [[ "$enable_webhook" != "y" && "$enable_webhook" != "Y" ]]; then
        echo "ENABLE_WEBHOOK=false" >> "$INSTALL_DIR/.env"
        info "跳过 Webhook 配置"
        return 2
    fi

    echo ""
    echo "请输入 Git 仓库地址，支持以下格式："
    echo "  • yourname/my-docs"
    echo "  • https://github.com/yourname/my-docs"
    echo "  • git@github.com:yourname/my-docs.git"
    echo ""
    read -p "仓库地址: " REPO < /dev/tty

    if [ -z "$REPO" ]; then
        warning "未输入仓库地址，跳过 Webhook 配置"
        echo "ENABLE_WEBHOOK=false" >> "$INSTALL_DIR/.env"
        return 0
    fi

    # 标准化仓库地址：支持完整 URL 或 username/repo 格式
    # 移除可能的 https:// 或 http:// 或 git@ 前缀
    REPO=$(echo "$REPO" | sed -E \
        -e 's|^(https?://)?github\.com/||' \
        -e 's|^git@github\.com:||' \
        -e 's|\.git$||')

    # 验证格式是否正确 (应该是 username/repo)
    if ! echo "$REPO" | grep -qE '^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$'; then
        error "仓库地址格式不正确: $REPO"
        warning "正确格式: username/repo (例如: jx453331958/my-docs)"
        echo "ENABLE_WEBHOOK=false" >> "$INSTALL_DIR/.env"
        return 1
    fi

    success "仓库: $REPO"

    echo ""
    read -p "这是私有仓库吗？[y/n, 默认 n] " is_private < /dev/tty
    is_private=${is_private:-n}

    # 询问文档仓库克隆位置
    echo ""
    info "请选择文档仓库克隆位置："
    echo "  1) 使用独立目录（推荐）: $HOME/my-docs"
    echo "  2) 使用当前项目目录: $INSTALL_DIR"
    read -p "请选择 [1-2, 默认 1]: " repo_location < /dev/tty

    case ${repo_location:-1} in
        1)
            DOCS_REPO_PATH="$HOME/${REPO##*/}"
            ;;
        2)
            DOCS_REPO_PATH="$INSTALL_DIR"
            ;;
        *)
            DOCS_REPO_PATH="$HOME/${REPO##*/}"
            ;;
    esac

    # 询问文档在仓库中的位置
    echo ""
    info "文档文件在仓库中的位置："
    echo "  1) 仓库根目录（所有 .md 文件在根目录）"
    echo "  2) docs/ 子目录（.md 文件在 docs/ 文件夹内）"
    echo "  3) 其他自定义路径"
    read -p "请选择 [1-3, 默认 1]: " docs_location < /dev/tty

    case ${docs_location:-1} in
        1) DOCS_SUBDIR="." ;;
        2) DOCS_SUBDIR="docs" ;;
        3)
            read -p "请输入文档所在子目录 [默认: . (根目录)]: " custom_dir < /dev/tty
            DOCS_SUBDIR="${custom_dir:-.}"
            ;;
        *) DOCS_SUBDIR="." ;;
    esac

    # 如果是私有仓库，配置 SSH Deploy Key
    if [[ "$is_private" == "y" || "$is_private" == "Y" ]]; then
        info "检测到私有仓库，需要配置 SSH Deploy Key"
        echo ""

        setup_github_ssh "$REPO"

        # 使用 SSH 克隆仓库
        if [ ! -d "$DOCS_REPO_PATH" ]; then
            info "克隆私有仓库..."
            HOST_NAME="github-${REPO//\//-}"
            info "使用 SSH 主机: $HOST_NAME"
            git clone "$HOST_NAME:$REPO.git" "$DOCS_REPO_PATH" 2>&1 || {
                error "克隆失败，请检查 SSH 配置"
                error "命令: git clone $HOST_NAME:$REPO.git $DOCS_REPO_PATH"
                echo "ENABLE_WEBHOOK=false" >> "$INSTALL_DIR/.env"
                return 1
            }
            success "仓库克隆完成"
        fi
    else
        # 公开仓库，直接使用 HTTPS 克隆
        if [ ! -d "$DOCS_REPO_PATH" ]; then
            info "克隆公开仓库..."
            git clone "https://github.com/$REPO.git" "$DOCS_REPO_PATH" 2>&1 || {
                error "克隆失败"
                error "命令: git clone https://github.com/$REPO.git $DOCS_REPO_PATH"
                echo "ENABLE_WEBHOOK=false" >> "$INSTALL_DIR/.env"
                return 1
            }
            success "仓库克隆完成"
        fi
    fi

    # 确定实际文档目录
    if [ "$DOCS_SUBDIR" = "." ]; then
        ACTUAL_DOCS_DIR="$DOCS_REPO_PATH"
    else
        ACTUAL_DOCS_DIR="$DOCS_REPO_PATH/$DOCS_SUBDIR"
    fi

    # 检查文档目录是否存在
    if [ ! -d "$ACTUAL_DOCS_DIR" ]; then
        error "文档目录不存在: $ACTUAL_DOCS_DIR"
        error "请检查仓库克隆是否成功，或文档子目录路径是否正确"
        echo "ENABLE_WEBHOOK=false" >> "$INSTALL_DIR/.env"
        return 1
    fi

    # 统计文档数量
    DOC_COUNT=$(find "$ACTUAL_DOCS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
    success "发现 $DOC_COUNT 个 Markdown 文档"

    # 链接文档目录到服务读取位置
    if [ -d "$DATA_DIR/docs" ] && [ ! -L "$DATA_DIR/docs" ]; then
        # 备份原有文档
        mv "$DATA_DIR/docs" "$DATA_DIR/docs.backup.$(date +%s)"
        warning "已备份原有文档目录"
    fi

    # 删除旧的符号链接（如果存在）
    rm -f "$DATA_DIR/docs"

    # 创建新的符号链接
    ln -s "$ACTUAL_DOCS_DIR" "$DATA_DIR/docs"
    success "已链接文档目录: $ACTUAL_DOCS_DIR → $DATA_DIR/docs"

    # 对于 Docker 模式，还需要更新 docker-compose.yml
    if [ -f "$DATA_DIR/docker-compose.yml" ]; then
        info "检测到 Docker 模式，正在更新配置..."

        # 备份原配置
        cp "$DATA_DIR/docker-compose.yml" "$DATA_DIR/docker-compose.yml.backup"

        # 更新 volumes 挂载点
        sed -i.bak "s|./docs:/app/docs|$ACTUAL_DOCS_DIR:/app/docs|g" "$DATA_DIR/docker-compose.yml"
        rm -f "$DATA_DIR/docker-compose.yml.bak"

        success "已更新 Docker 配置"
    fi

    # 写入配置
    cat >> "$INSTALL_DIR/.env" << EOF

# Git Webhook 配置
ENABLE_WEBHOOK=true
GIT_REPO_PATH=$DOCS_REPO_PATH
EOF

    success "Webhook 配置完成"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📂 文档目录配置"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "Git 仓库: $DOCS_REPO_PATH"
    info "文档目录: $ACTUAL_DOCS_DIR"
    info "服务读取: $DATA_DIR/docs → $ACTUAL_DOCS_DIR"
    info "文档数量: $DOC_COUNT 个 .md 文件"
    echo ""

    # 获取配置的端口
    local webhook_port=3457
    if [ -f "$DATA_DIR/docker-compose.yml" ]; then
        webhook_port=$(grep "PORT=" "$DATA_DIR/docker-compose.yml" | head -1 | cut -d'=' -f2 | tr -d ' "')
    elif [ -f "$INSTALL_DIR/.env" ]; then
        webhook_port=$(grep "^PORT=" "$INSTALL_DIR/.env" | cut -d'=' -f2)
    fi
    webhook_port=${webhook_port:-3457}

    # 尝试自动检测服务器地址
    local server_addr=""
    if command -v curl &> /dev/null; then
        local detected_ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || curl -s --max-time 3 icanhazip.com 2>/dev/null || curl -s --max-time 3 api.ipify.org 2>/dev/null)
        # 验证是否为有效 IP 地址（IPv4 或 IPv6）
        if echo "$detected_ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$|^([0-9a-fA-F:]+)$'; then
            server_addr="$detected_ip"
        fi
    fi

    # 询问用户外网访问地址
    echo ""
    info "请输入服务器的外网访问地址"
    echo "  • 使用域名（如: docs.example.com）"
    echo "  • 使用 IP（如: 123.45.67.89）"
    echo "  • 可包含协议（如: https://docs.example.com）"
    echo ""
    if [ -n "$server_addr" ]; then
        echo -e "自动检测到 IP: ${GREEN}$server_addr${NC}"
        read -p "直接回车使用检测值，或输入自定义地址: " custom_addr < /dev/tty
        server_addr="${custom_addr:-$server_addr}"
    else
        warning "未能自动检测到公网地址"
        read -p "请输入外网访问地址: " custom_addr < /dev/tty
        server_addr="${custom_addr:-your-server}"
    fi

    # 解析用户输入的 URL
    local protocol="http"
    local host="$server_addr"
    local port=""

    # 提取协议（如果有）
    if [[ "$server_addr" =~ ^https:// ]]; then
        protocol="https"
        host="${server_addr#https://}"
    elif [[ "$server_addr" =~ ^http:// ]]; then
        protocol="http"
        host="${server_addr#http://}"
    fi

    # 提取端口（如果有）
    if [[ "$host" =~ :[0-9]+$ ]]; then
        port="${host##*:}"
        host="${host%:*}"
    fi

    # 智能判断是否需要端口号
    local webhook_url=""
    if [ -n "$port" ]; then
        # 用户明确指定了端口
        webhook_url="${protocol}://${host}:${port}/api/webhook"
    elif [[ "$host" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # 是 IP 地址，使用配置的端口
        webhook_url="${protocol}://${host}:${webhook_port}/api/webhook"
    else
        # 是域名，询问是否需要端口号
        echo ""
        info "检测到域名: $host"
        read -p "是否使用标准端口（80/443）？[y/n, 默认 y] " use_standard_port < /dev/tty
        use_standard_port=${use_standard_port:-y}

        if [[ "$use_standard_port" == "y" || "$use_standard_port" == "Y" ]]; then
            webhook_url="${protocol}://${host}/api/webhook"
        else
            webhook_url="${protocol}://${host}:${webhook_port}/api/webhook"
        fi
    fi

    echo ""
    success "Webhook URL: $webhook_url"
    echo ""

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 稍后配置 GitHub Webhook（服务启动后）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "等服务启动完成后，按以下步骤配置："
    echo ""
    echo "1. 打开仓库: https://github.com/$REPO/settings/hooks"
    echo "2. 点击 Add webhook"
    echo -e "3. Payload URL: ${GREEN}$webhook_url${NC}"
    echo "4. Content type: application/json"
    echo "5. Events: Just the push event"
    echo "6. 点击 Add webhook"
    echo ""
    info "详细配置见: cat WEBHOOK-GUIDE.md"
    echo ""
}

# 配置访问鉴权
configure_auth() {
    echo ""
    info "访问鉴权配置（保护私有文档）"
    echo ""
    echo "功能说明："
    echo "  - 默认启用访问鉴权，保护私有文档"
    echo "  - 访问文档站需要输入用户名和密码"
    echo "  - 使用 HTTP Basic Auth（浏览器原生支持）"
    echo "  - 不影响 API 调用（API 仍使用 Bearer Token）"
    echo ""
    read -p "是否启用鉴权？[y/n, 默认 y] " enable_auth < /dev/tty
    enable_auth=${enable_auth:-y}

    if [[ "$enable_auth" == "n" || "$enable_auth" == "N" ]]; then
        cat >> "$INSTALL_DIR/.env" << EOF

# 访问鉴权（已禁用 - 公开访问）
ENABLE_AUTH=false
EOF
        warning "已禁用鉴权，文档站将公开访问"
        return
    fi

    echo ""
    info "配置管理员账号"
    echo "  - 管理员可以通过 Web 界面添加更多用户"
    echo "  - 其他用户登录后只能查看文档"
    echo ""

    # 管理员账号配置
    read -p "管理员用户名 [默认: admin]: " auth_user < /dev/tty
    auth_user=${auth_user:-admin}

    # 密码输入（不回显）
    read -sp "管理员密码: " auth_pass < /dev/tty
    echo ""

    if [ -z "$auth_pass" ]; then
        warning "密码不能为空，使用默认密码: admin"
        auth_pass="admin"
    fi

    # 写入配置
    cat >> "$INSTALL_DIR/.env" << EOF

# 访问鉴权配置
ENABLE_AUTH=true
AUTH_USERS=$auth_user:$auth_pass
EOF

    success "鉴权配置完成"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔒 管理员凭证"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   用户名: $auth_user"
    echo "   密码:   $auth_pass"
    echo "   权限:   管理员（可添加其他用户）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    warning "请妥善保管管理员凭证"
    echo ""
    info "添加更多用户:"
    echo "  1. 使用管理员账号登录文档站"
    echo "  2. 在 Web 界面的用户管理中添加"
    echo ""
}

# 配置 GitHub SSH Deploy Key（集成到安装流程）
setup_github_ssh() {
    local REPO="$1"

    # SSH 密钥路径
    local SSH_DIR="$HOME/.ssh"
    local KEY_NAME="github_docs_${REPO//\//_}"
    local KEY_PATH="$SSH_DIR/${KEY_NAME}"
    local HOST_NAME="github-${REPO//\//-}"

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    # 检查密钥是否已存在
    if [ -f "$KEY_PATH" ]; then
        success "检测到已有 SSH 密钥: $KEY_NAME"
        info "将复用现有密钥（避免重复创建）"
    else
        # 生成 SSH 密钥
        info "生成 SSH Deploy Key..."
        ssh-keygen -t ed25519 -C "docs-deploy-${REPO}" -f "$KEY_PATH" -N "" -q
        success "密钥生成完成"
    fi

    # 配置 SSH config
    local SSH_CONFIG="$SSH_DIR/config"

    if ! grep -q "Host $HOST_NAME" "$SSH_CONFIG" 2>/dev/null; then
        cat >> "$SSH_CONFIG" << EOF

# Deploy key for $REPO
Host $HOST_NAME
    HostName github.com
    User git
    IdentityFile $KEY_PATH
    IdentitiesOnly yes
    StrictHostKeyChecking no
EOF
        chmod 600 "$SSH_CONFIG"
        success "SSH 配置已添加"
    else
        info "SSH 配置已存在，跳过"
    fi

    # 显示公钥
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 请将以下公钥添加到 GitHub Deploy Keys"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    cat "$KEY_PATH.pub"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "操作步骤："
    echo -e "1. 打开: ${BLUE}https://github.com/$REPO/settings/keys${NC}"
    echo -e "2. 点击 ${GREEN}Add deploy key${NC}"
    echo "3. Title: Docs Share Server ($(hostname))"
    echo "4. Key: [粘贴上面的公钥]"
    echo -e "5. Allow write access: ${RED}❌ 不勾选${NC}"
    echo -e "6. 点击 ${GREEN}Add key${NC}"
    echo ""

    read -p "完成后按回车继续..." < /dev/tty

    # 测试连接
    echo ""
    info "测试 SSH 连接..."

    if ssh -T "$HOST_NAME" 2>&1 | grep -q "successfully authenticated"; then
        success "SSH 连接成功！"
    else
        warning "SSH 连接测试失败，但可以继续"
        echo ""
        echo "请确保已将公钥添加到 GitHub Deploy Keys"
        echo "手动测试: ssh -T $HOST_NAME"
        echo ""
        read -p "按回车继续..." < /dev/tty
    fi
}

# 配置环境变量
configure_env() {
    if [ -f "$INSTALL_DIR/.env" ]; then
        warning "配置文件已存在，跳过"
        return
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚙️  环境配置（交互式生成）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # 1. 配置端口
    info "1. 服务端口配置"
    echo ""

    # 生成一个未被占用的端口
    local default_port=$(generate_available_port 3000 9999)
    info "自动检测到可用端口: $default_port"
    echo ""

    read -p "服务端口 [默认: $default_port]: " custom_port < /dev/tty
    PORT=${custom_port:-$default_port}

    # 验证端口号
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        warning "端口号无效，使用自动检测的端口 $default_port"
        PORT=$default_port
    fi

    # 检查用户输入的端口是否被占用
    if [ -n "$custom_port" ] && is_port_in_use "$PORT"; then
        warning "端口 $PORT 已被占用"
        PORT=$(generate_available_port 3000 9999)
        success "已切换到可用端口: $PORT"
    fi

    success "端口: $PORT"
    echo ""

    # 2. 生成 API Key
    info "2. API 认证密钥"
    echo ""
    API_KEY=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
    success "已自动生成 API Key"
    echo ""

    # 写入基础配置
    cat > "$INSTALL_DIR/.env" << EOF
# Docs Share 配置文件
# 自动生成于: $(date '+%Y-%m-%d %H:%M:%S')

# 服务端口
PORT=$PORT

# API 认证密钥（用于上传/删除文档）
# 请妥善保管，不要分享给他人
API_KEY=$API_KEY
EOF

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔑 API Key (已自动生成，请保存):"
    echo ""
    echo "   $API_KEY"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    warning "用于 REST API 调用，请妥善保管"
    info "配置文件: $INSTALL_DIR/.env"
    echo ""

    # 3. 配置访问鉴权
    info "3. 访问鉴权配置"
    configure_auth

    # 4. 配置 Webhook
    info "4. Git Webhook 配置"

    while true; do
        configure_webhook
        local result=$?

        if [ $result -eq 2 ]; then
            # 用户选择跳过
            break
        elif [ $result -eq 0 ]; then
            # 配置成功
            success "Webhook 配置成功"
            break
        else
            # 配置失败
            echo ""
            warning "Webhook 配置失败"
            echo ""
            echo "可能的原因："
            echo "  - 仓库地址格式错误"
            echo "  - SSH 密钥未添加到 GitHub Deploy Keys"
            echo "  - 网络连接问题"
            echo "  - 仓库不存在或无权限访问"
            echo ""
            read -p "是否重试 Webhook 配置？[y/n, 默认 n] " retry_webhook < /dev/tty
            retry_webhook=${retry_webhook:-n}

            if [[ "$retry_webhook" != "y" && "$retry_webhook" != "Y" ]]; then
                warning "已跳过 Webhook 配置（不影响基本功能）"
                echo ""
                info "稍后可重新配置 Webhook："
                echo "  curl -fsSL https://raw.githubusercontent.com/jx453331958/docs-share-oss/main/install.sh | bash"
                echo "  选择菜单中的 '8) 配置管理'"
                break
            fi

            echo ""
            info "重新配置 Webhook..."
        fi
    done

    echo ""
    success "✅ 所有配置已完成！"
}

# 更新
update() {
    print_logo
    info "检查更新..."

    if [ ! -d "$INSTALL_DIR/.git" ]; then
        error "未找到安装目录，请先运行安装"
        exit 1
    fi

    cd "$INSTALL_DIR"

    # 备份配置
    if [ -f ".env" ]; then
        cp .env .env.backup
        info "已备份配置文件"
    fi

    # 拉取更新
    git fetch origin --quiet
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/main)

    if [ "$LOCAL" = "$REMOTE" ]; then
        success "已是最新版本！"
        return
    fi

    info "发现新版本，正在更新..."
    git pull origin main --quiet

    # 恢复配置
    if [ -f ".env.backup" ]; then
        mv .env.backup .env
        success "已恢复配置文件"
    fi

    success "更新完成！"

    # 重启服务
    if pgrep -f "node.*server.mjs" > /dev/null; then
        info "检测到服务正在运行，建议重启"
        read -p "是否现在重启？[y/n, 默认 y] " restart_now < /dev/tty
        restart_now=${restart_now:-y}
        if [[ "$restart_now" != "n" && "$restart_now" != "N" ]]; then
            restart_service
        fi
    fi
}

# 启动服务
start_service() {
    info "启动服务..."

    if [ -f "$DATA_DIR/docker-compose.yml" ]; then
        cd "$DATA_DIR"
        docker compose up -d
        sleep 2
    elif command -v pm2 &> /dev/null && pm2 list | grep -q "docs-share"; then
        pm2 start docs-share
        sleep 1
    else
        error "未检测到安装，请先运行: $0 install"
        exit 1
    fi

    if curl -s http://localhost:3457/api/docs > /dev/null 2>&1; then
        success "服务启动成功！"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        info "访问地址: ${GREEN}http://localhost:3457${NC}"
        info "文档目录: ${BLUE}$DATA_DIR/docs${NC}"

        if [ -f "$DATA_DIR/docker-compose.yml" ]; then
            info "查看日志: ${YELLOW}cd $DATA_DIR && docker compose logs -f${NC}"
        else
            info "查看日志: ${YELLOW}pm2 logs docs-share${NC}"
        fi
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    else
        error "服务启动失败，请检查日志"
        if [ -f "$DATA_DIR/docker-compose.yml" ]; then
            echo "  查看日志: cd $DATA_DIR && docker compose logs"
        else
            echo "  查看日志: pm2 logs docs-share"
        fi
    fi
}

# 停止服务
stop_service() {
    info "停止服务..."

    local stopped=false

    if [ -f "$DATA_DIR/docker-compose.yml" ]; then
        cd "$DATA_DIR"
        docker compose down
        success "Docker 容器已停止"
        stopped=true
    fi

    if command -v pm2 &> /dev/null && pm2 list | grep -q "docs-share"; then
        pm2 stop docs-share
        pm2 delete docs-share
        success "PM2 服务已停止"
        stopped=true
    fi

    # 检测并提示手动启动的进程
    local manual_procs=$(ps aux | grep -E "node.*server\.mjs" | grep -v grep)
    if [ -n "$manual_procs" ]; then
        echo ""
        warning "检测到手动启动的进程，未自动停止："
        echo "$manual_procs" | awk '{print "  PID " $2 ": " $NF}'
        echo ""
        read -p "是否停止这些进程？[y/n, 默认 n] " kill_manual < /dev/tty
        kill_manual=${kill_manual:-n}
        if [[ "$kill_manual" == "y" || "$kill_manual" == "Y" ]]; then
            echo "$manual_procs" | awk '{print $2}' | while read pid; do
                kill -9 "$pid" 2>/dev/null && success "已停止进程: $pid" || warning "无法停止进程: $pid"
            done
            stopped=true
        fi
    fi

    if [ "$stopped" = false ]; then
        warning "未检测到运行中的服务"
    fi
}

# 重启服务
restart_service() {
    stop_service
    sleep 1
    start_service
}

# 状态检查
check_status() {
    print_logo

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "服务状态"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 检查服务是否运行
    if curl -s http://localhost:3457/api/docs > /dev/null 2>&1; then
        success "服务运行中"

        # 获取文档数量
        DOC_COUNT=$(curl -s http://localhost:3457/api/docs | jq '. | length' 2>/dev/null || echo "?")
        info "文档数量: $DOC_COUNT"

        # 检查运行方式
        if [ -f "$DATA_DIR/docker-compose.yml" ]; then
            info "运行模式: Docker"
            echo ""
            docker compose -f "$DATA_DIR/docker-compose.yml" ps
        elif command -v pm2 &> /dev/null && pm2 list | grep -q "docs-share"; then
            info "运行模式: PM2"
            echo ""
            pm2 info docs-share
        else
            warning "运行模式: 未知（可能是手动启动）"
            # 检测手动启动的进程
            local manual_procs=$(ps aux | grep -E "node.*server\.mjs" | grep -v grep | awk '{print $2, $NF}')
            if [ -n "$manual_procs" ]; then
                echo ""
                warning "检测到手动启动的进程："
                echo "$manual_procs" | while read pid cmd; do
                    echo "  PID $pid: $cmd"
                done
            fi
        fi
    else
        warning "服务未运行"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "安装信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local has_installation=false

    if [ -d "$INSTALL_DIR" ]; then
        info "安装目录: $INSTALL_DIR"
        if [ -d "$INSTALL_DIR/.git" ]; then
            cd "$INSTALL_DIR"
            info "当前版本: $(git describe --tags --always)"
        fi
        has_installation=true
    fi

    if [ -d "$DATA_DIR" ]; then
        info "数据目录: $DATA_DIR"
        if [ -d "$DATA_DIR/docs" ]; then
            local doc_count=$(find "$DATA_DIR/docs" -name "*.md" 2>/dev/null | wc -l)
            info "文档文件: $doc_count 个 .md"
        fi
        has_installation=true
    fi

    if [ -f "$INSTALL_DIR/.env" ] || [ -f "$DATA_DIR/.env" ]; then
        success "环境配置已完成"
        if [ -f "$INSTALL_DIR/.env" ]; then
            info "配置文件: $INSTALL_DIR/.env"
        elif [ -f "$DATA_DIR/.env" ]; then
            info "配置文件: $DATA_DIR/.env"
        fi
        has_installation=true
    fi

    if [ "$has_installation" = false ]; then
        warning "未检测到安装（可能已卸载或使用了不同的路径）"
    fi

    echo ""
}

# 卸载
uninstall() {
    print_logo
    warning "即将卸载 Docs Share"
    echo ""

    # 检测是否有 Webhook 配置的仓库
    local git_repos=()
    local ssh_keys=()

    # 查找克隆的 Git 仓库（从 docker-compose.yml 或 .env 中提取）
    if [ -f "$DATA_DIR/docker-compose.yml" ]; then
        local repo_path=$(grep "volumes:" -A1 "$DATA_DIR/docker-compose.yml" | grep -v "^#" | grep -v "volumes:" | grep -v ".ssh" | head -1 | cut -d':' -f1 | xargs)
        if [ -n "$repo_path" ] && [ -d "$repo_path" ] && [ -d "$repo_path/.git" ]; then
            git_repos+=("$repo_path")
        fi
    fi

    if [ -f "$INSTALL_DIR/.env" ]; then
        local repo_path=$(grep "^GIT_REPO_PATH=" "$INSTALL_DIR/.env" | cut -d'=' -f2)
        if [ -n "$repo_path" ] && [ -d "$repo_path" ] && [ -d "$repo_path/.git" ]; then
            if [[ ! " ${git_repos[@]} " =~ " ${repo_path} " ]]; then
                git_repos+=("$repo_path")
            fi
        fi
    fi

    # 查找生成的 SSH 密钥
    if [ -d "$HOME/.ssh" ]; then
        while IFS= read -r key; do
            ssh_keys+=("$key")
        done < <(find "$HOME/.ssh" -name "github_docs_*" -type f ! -name "*.pub" 2>/dev/null)
    fi

    # 显示将要删除的内容
    echo "将删除以下内容："
    echo ""
    echo "  • 安装目录: $INSTALL_DIR"
    echo "  • 数据目录: $DATA_DIR"

    if [ ${#git_repos[@]} -gt 0 ]; then
        echo "  • Git 仓库: ${git_repos[@]}"
    fi

    if [ ${#ssh_keys[@]} -gt 0 ]; then
        echo "  • SSH 密钥: ${#ssh_keys[@]} 个"
    fi

    echo ""
    read -p "是否保留文档数据？[y/n, 默认 y] " keep_data < /dev/tty
    keep_data=${keep_data:-y}
    read -p "确认卸载？[y/n, 默认 n] " confirm < /dev/tty
    confirm=${confirm:-n}

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "取消卸载"
        exit 0
    fi

    # 停止服务
    stop_service

    # 删除安装目录
    if [ -d "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"
        success "已删除安装目录"
    fi

    # 删除数据（如果用户选择）
    if [[ "$keep_data" == "n" || "$keep_data" == "N" ]]; then
        if [ -d "$DATA_DIR" ]; then
            rm -rf "$DATA_DIR"
            success "已删除数据目录"
        fi
    else
        info "保留数据目录: $DATA_DIR"
    fi

    # 删除 Git 仓库（如果有）
    if [ ${#git_repos[@]} -gt 0 ]; then
        echo ""
        read -p "是否删除克隆的 Git 仓库？[y/n, 默认 n] " delete_repos < /dev/tty
        delete_repos=${delete_repos:-n}
        if [[ "$delete_repos" == "y" || "$delete_repos" == "Y" ]]; then
            for repo in "${git_repos[@]}"; do
                rm -rf "$repo"
                success "已删除仓库: $repo"
            done
        else
            info "保留 Git 仓库"
        fi
    fi

    # 删除 SSH 密钥（如果有）
    if [ ${#ssh_keys[@]} -gt 0 ]; then
        echo ""
        read -p "是否删除生成的 SSH Deploy Keys？[y/n, 默认 n] " delete_keys < /dev/tty
        delete_keys=${delete_keys:-n}
        if [[ "$delete_keys" == "y" || "$delete_keys" == "Y" ]]; then
            for key in "${ssh_keys[@]}"; do
                rm -f "$key" "$key.pub"
                success "已删除密钥: $(basename $key)"

                # 从 SSH config 中删除对应的配置
                if [ -f "$HOME/.ssh/config" ]; then
                    local key_name=$(basename "$key")
                    local host_name="github-${key_name#github_docs_}"
                    host_name="${host_name//_/-}"

                    # 删除相关的 Host 配置块
                    sed -i.bak "/# Deploy key for.*$host_name/,/^$/d" "$HOME/.ssh/config" 2>/dev/null || true
                    sed -i.bak "/^Host $host_name$/,/^$/d" "$HOME/.ssh/config" 2>/dev/null || true
                    rm -f "$HOME/.ssh/config.bak"
                fi
            done
            success "已删除 SSH 密钥和配置"
        else
            info "保留 SSH 密钥"
        fi
    fi

    # 清理完成
    success "清理完成"

    # PM2
    if command -v pm2 &> /dev/null && pm2 list | grep -q "docs-share"; then
        pm2 delete docs-share
        pm2 save
    fi

    success "卸载完成！"
}

# 日志查看
view_logs() {
    if [ -f "$DATA_DIR/docker-compose.yml" ]; then
        cd "$DATA_DIR"
        docker compose logs -f
    elif command -v pm2 &> /dev/null && pm2 list | grep -q "docs-share"; then
        pm2 logs docs-share
    else
        warning "无法查看日志（请使用 Docker 或 PM2 模式）"
    fi
}

# 主菜单
main_menu() {
    print_logo

    echo "请选择操作："
    echo ""
    echo "  1) 首次安装"
    echo "  2) 更新到最新版"
    echo "  3) 启动服务"
    echo "  4) 停止服务"
    echo "  5) 重启服务"
    echo "  6) 查看状态"
    echo "  7) 查看日志"
    echo "  8) 配置管理"
    echo "  9) 卸载"
    echo "  0) 退出"
    echo ""

    read -p "请选择 [0-9]: " choice < /dev/tty

    case $choice in
        1) install ;;
        2) update ;;
        3) start_service ;;
        4) stop_service ;;
        5) restart_service ;;
        6) check_status ;;
        7) view_logs ;;
        8) configure_env ;;
        9) uninstall ;;
        0) exit 0 ;;
        *) error "无效选择"; exit 1 ;;
    esac
}

# 命令行参数处理
case "${1:-menu}" in
    install|i)
        install
        ;;
    update|u)
        update
        ;;
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart|r)
        restart_service
        ;;
    status|s)
        check_status
        ;;
    logs|l)
        view_logs
        ;;
    config|c)
        configure_env
        ;;
    uninstall)
        uninstall
        ;;
    menu|m|*)
        main_menu
        ;;
esac
