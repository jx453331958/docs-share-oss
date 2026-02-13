#!/bin/bash

# Docs Share 快速开始脚本
# 演示如何使用 CLI 工具管理文档

set -e

echo "📚 Docs Share - 快速开始示例"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查是否已有配置
if [ ! -f .docsrc.json ]; then
    echo -e "${BLUE}步骤 1: 创建配置文件${NC}"
    echo ""

    read -p "服务器地址 (默认: http://localhost:3457): " SERVER
    SERVER=${SERVER:-http://localhost:3457}

    read -p "API Key (默认: dev-key-change-in-production): " API_KEY
    API_KEY=${API_KEY:-dev-key-change-in-production}

    cat > .docsrc.json << EOF
{
  "server": "$SERVER",
  "apiKey": "$API_KEY"
}
EOF

    echo -e "${GREEN}✓ 配置文件已创建：.docsrc.json${NC}"
    echo ""
else
    echo -e "${GREEN}✓ 配置文件已存在${NC}"
    echo ""
fi

# 创建示例文档
echo -e "${BLUE}步骤 2: 创建示例文档${NC}"
echo ""

cat > example-doc.md << 'EOF'
# 示例文档

这是一个通过 CLI 工具上传的示例文档。

## 功能特性

- ✅ 自动上传
- ✅ 搜索功能
- ✅ 实时刷新
- ✅ 暗色主题

## 代码示例

\`\`\`bash
# 上传文档
npx docs-share upload example-doc.md

# 查看所有文档
npx docs-share list
\`\`\`

## 下一步

尝试编辑这个文件，然后重新上传：

\`\`\`bash
npx docs-share upload example-doc.md
\`\`\`

文档会自动更新！
EOF

echo -e "${GREEN}✓ 示例文档已创建：example-doc.md${NC}"
echo ""

# 上传文档
echo -e "${BLUE}步骤 3: 上传文档到服务器${NC}"
echo ""

if command -v npx &> /dev/null; then
    if npx docs-share upload example-doc.md; then
        echo ""
        echo -e "${GREEN}✓ 上传成功！${NC}"
        echo ""
    else
        echo ""
        echo "❌ 上传失败。请检查："
        echo "  1. 服务器是否运行？"
        echo "  2. 服务器地址是否正确？"
        echo "  3. API Key 是否正确？"
        echo ""
        exit 1
    fi
else
    echo "⚠️  npx 未找到，请手动运行："
    echo "  npx docs-share upload example-doc.md"
    echo ""
fi

# 列出文档
echo -e "${BLUE}步骤 4: 查看所有文档${NC}"
echo ""

if command -v npx &> /dev/null; then
    npx docs-share list
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 完成！${NC}"
echo ""
echo "下一步："
echo "  1. 访问服务器查看文档"
echo "  2. 尝试搜索功能"
echo "  3. 编辑 example-doc.md 并重新上传"
echo "  4. 上传更多文档：npx docs-share upload *.md"
echo ""
echo "查看帮助："
echo "  npx docs-share help"
echo ""
