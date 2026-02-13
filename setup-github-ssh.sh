#!/bin/bash

###############################################################################
# GitHub SSH Deploy Key 自动配置脚本
# 用于配置服务器访问私有 GitHub 仓库
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warning() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔑 GitHub SSH Deploy Key 配置"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 检查是否在服务器上
if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ]; then
    warning "建议在服务器上运行此脚本"
fi

# 获取仓库信息
read -p "GitHub 仓库地址 (如: yourname/my-docs): " REPO
if [ -z "$REPO" ]; then
    error "仓库地址不能为空"
    exit 1
fi

# SSH 密钥路径
SSH_DIR="$HOME/.ssh"
KEY_NAME="github_docs_${REPO//\//_}"
KEY_PATH="$SSH_DIR/${KEY_NAME}"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# 检查密钥是否已存在
if [ -f "$KEY_PATH" ]; then
    warning "密钥已存在: $KEY_PATH"
    read -p "是否覆盖？[y/N] " overwrite
    if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
        info "使用现有密钥"
    else
        rm -f "$KEY_PATH" "$KEY_PATH.pub"
    fi
fi

# 生成 SSH 密钥
if [ ! -f "$KEY_PATH" ]; then
    info "生成 SSH 密钥..."
    ssh-keygen -t ed25519 -C "docs-deploy-${REPO}" -f "$KEY_PATH" -N ""
    success "密钥生成完成"
fi

# 显示公钥
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 公钥内容（复制以下内容）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cat "$KEY_PATH.pub"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 配置 SSH config
info "配置 SSH..."

SSH_CONFIG="$SSH_DIR/config"
HOST_NAME="github-${REPO//\//-}"

# 检查是否已配置
if grep -q "Host $HOST_NAME" "$SSH_CONFIG" 2>/dev/null; then
    warning "SSH 配置已存在，跳过"
else
    cat >> "$SSH_CONFIG" << EOF

# Deploy key for $REPO
Host $HOST_NAME
    HostName github.com
    User git
    IdentityFile $KEY_PATH
    IdentitiesOnly yes
    StrictHostKeyChecking no
EOF
    success "SSH 配置完成"
fi

chmod 600 "$SSH_CONFIG"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 下一步操作"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. 打开 GitHub 仓库："
echo "   ${BLUE}https://github.com/$REPO/settings/keys${NC}"
echo ""
echo "2. 点击 ${GREEN}Add deploy key${NC}"
echo ""
echo "3. 填写表单："
echo "   Title: Docs Share Server ($(hostname))"
echo "   Key: [粘贴上面的公钥]"
echo "   Allow write access: ${RED}❌ 不勾选${NC}"
echo ""
echo "4. 点击 ${GREEN}Add key${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "已完成 GitHub 配置？按回车继续测试连接... "

# 测试连接
echo ""
info "测试 SSH 连接..."

if ssh -T "$HOST_NAME" 2>&1 | grep -q "successfully authenticated"; then
    success "SSH 连接成功！"
else
    error "SSH 连接失败"
    echo ""
    echo "请检查："
    echo "1. 是否已将公钥添加到 GitHub Deploy Keys"
    echo "2. 仓库地址是否正确：$REPO"
    echo ""
    echo "手动测试命令："
    echo "  ssh -T $HOST_NAME"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 配置完成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "克隆仓库命令："
echo ""
echo "  ${GREEN}git clone $HOST_NAME:$REPO.git${NC}"
echo ""
echo "或修改已有仓库："
echo ""
echo "  ${GREEN}git remote set-url origin $HOST_NAME:$REPO.git${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
