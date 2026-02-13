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
INSTALL_DIR="${INSTALL_DIR:-$HOME/.docs-share}"
DATA_DIR="${DATA_DIR:-$HOME/docs-share-data}"

# 打印带颜色的消息
info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

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

    # 选择安装模式
    echo "请选择安装模式："
    echo "  1) Docker 容器运行（推荐）"
    echo "  2) PM2 进程管理（需要 Node.js >= 18）"
    echo ""
    read -p "请选择 [1-2]: " mode

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

    # 生成 API Key
    API_KEY=$(openssl rand -base64 32 2>/dev/null || echo "change-this-in-production")

    # 创建 docker-compose.yml
    cat > "$DATA_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  docs-share:
    image: ghcr.io/$REPO:latest
    container_name: docs-share
    ports:
      - "3457:3457"
    volumes:
      - ./docs:/app/docs
    environment:
      - PORT=3457
      - API_KEY=$API_KEY
      - ENABLE_WEBHOOK=false
    restart: unless-stopped
EOF

    success "Docker 配置完成！"
    echo ""
    info "配置文件: $DATA_DIR/docker-compose.yml"
    info "文档目录: $DATA_DIR/docs"
    info "API Key: $API_KEY"
    echo ""

    # 创建 CLI 配置
    cat > "$HOME/.docsrc.json" << EOF
{
  "server": "http://localhost:3457",
  "apiKey": "$API_KEY"
}
EOF

    success "CLI 配置已创建: ~/.docsrc.json"
    echo ""

    # 启动
    read -p "是否现在启动服务？[Y/n] " start_now
    if [[ "$start_now" != "n" && "$start_now" != "N" ]]; then
        cd "$DATA_DIR"
        docker compose up -d
        success "服务已启动！"
        echo ""
        info "访问: http://localhost:3457"
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
    read -p "是否设置开机自启？[Y/n] " setup_startup
    if [[ "$setup_startup" != "n" && "$setup_startup" != "N" ]]; then
        pm2 startup
        success "开机自启已配置"
        echo ""
        info "请按照提示执行 sudo 命令"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "访问地址: ${GREEN}http://localhost:3457${NC}"
    info "管理命令: ${YELLOW}pm2 status${NC}"
    info "查看日志: ${YELLOW}pm2 logs docs-share${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 配置环境变量
configure_env() {
    if [ -f "$INSTALL_DIR/.env" ]; then
        warning "配置文件已存在，跳过"
        return
    fi

    info "配置环境变量..."

    # 生成 API Key
    API_KEY=$(openssl rand -base64 32 2>/dev/null || echo "change-this-in-production")

    cat > "$INSTALL_DIR/.env" << EOF
# Docs Share 配置文件

# 服务端口
PORT=3457

# API 认证密钥（用于上传/删除文档）
# 请妥善保管，不要分享给他人
API_KEY=$API_KEY

# Git Webhook（可选）
ENABLE_WEBHOOK=false
# GIT_REPO_PATH=$INSTALL_DIR

EOF

    # 创建 CLI 配置
    cat > "$HOME/.docsrc.json" << EOF
{
  "server": "http://localhost:3457",
  "apiKey": "$API_KEY"
}
EOF

    success "配置完成"
    info "API Key: $API_KEY"
    info "CLI 配置: ~/.docsrc.json"
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
        read -p "是否现在重启？[Y/n] " restart_now
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

    if [ -f "$DATA_DIR/docker-compose.yml" ]; then
        cd "$DATA_DIR"
        docker compose down
        success "Docker 容器已停止"
    elif command -v pm2 &> /dev/null && pm2 list | grep -q "docs-share"; then
        pm2 stop docs-share
        success "PM2 服务已停止"
    else
        error "未检测到运行中的服务"
        exit 1
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
            warning "运行模式: 未知"
        fi
    else
        warning "服务未运行"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "安装信息"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -d "$INSTALL_DIR" ]; then
        info "安装目录: $INSTALL_DIR"
        if [ -d "$INSTALL_DIR/.git" ]; then
            cd "$INSTALL_DIR"
            info "当前版本: $(git describe --tags --always)"
        fi
    fi

    info "文档目录: $DATA_DIR/docs"

    if [ -f "$HOME/.docsrc.json" ]; then
        success "CLI 已配置: ~/.docsrc.json"
    else
        warning "CLI 未配置"
    fi

    echo ""
}

# 卸载
uninstall() {
    print_logo
    warning "即将卸载 Docs Share"
    echo ""
    read -p "是否保留文档数据？[Y/n] " keep_data
    read -p "确认卸载？[y/N] " confirm

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

    # 删除 CLI 配置
    if [ -f "$HOME/.docsrc.json" ]; then
        rm "$HOME/.docsrc.json"
        success "已删除 CLI 配置"
    fi

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

    read -p "请选择 [0-9]: " choice

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
