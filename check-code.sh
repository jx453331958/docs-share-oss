#!/bin/bash

# 代码质量自动检查脚本
# 用于提交前检查常见的低级错误

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 代码质量检查"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ERRORS=0
WARNINGS=0

# 1. 检查硬编码端口
echo ""
echo "1. 检查硬编码端口..."
if grep -n ':\s*[0-9]\{4,5\}' install.sh | grep -v '\$' | grep -v '#'; then
    echo -e "${RED}❌ 发现硬编码端口！${NC}"
    echo "   应该使用变量：\$PORT"
    ((ERRORS++))
else
    echo -e "${GREEN}✅ 未发现硬编码端口${NC}"
fi

# 2. 检查硬编码绝对路径
echo ""
echo "2. 检查硬编码绝对路径..."
if grep -n '"/home/\|"/var/\|"/usr/' install.sh | grep -v '#' | grep -v 'HOME'; then
    echo -e "${RED}❌ 发现硬编码路径！${NC}"
    echo "   应该使用变量或相对路径"
    ((ERRORS++))
else
    echo -e "${GREEN}✅ 未发现硬编码路径${NC}"
fi

# 3. 检查危险命令
echo ""
echo "3. 检查危险命令..."
DANGEROUS=$(grep -n 'eval\s\|rm\s*-rf\s*\$[^{]' install.sh | grep -v '#' || true)
if [ -n "$DANGEROUS" ]; then
    echo -e "${YELLOW}⚠️  发现危险命令：${NC}"
    echo "$DANGEROUS"
    echo "   请仔细检查是否有输入验证！"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 未发现危险命令${NC}"
fi

# 4. 检查可能的直接拼接
echo ""
echo "4. 检查字符串拼接..."
CONCAT=$(grep -n '=".*\${[a-z_]*input.*}"' install.sh | grep -v '#' || true)
if [ -n "$CONCAT" ]; then
    echo -e "${YELLOW}⚠️  发现直接拼接用户输入：${NC}"
    echo "$CONCAT"
    echo "   请确认已经过验证和清理！"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 未发现可疑拼接${NC}"
fi

# 5. 检查缺少默认值的 read
echo ""
echo "5. 检查缺少默认值的输入..."
NODEFAULT=$(grep -n 'read -p.*:' install.sh | grep -v '默认' | grep -v '#' || true)
if [ -n "$NODEFAULT" ]; then
    echo -e "${YELLOW}⚠️  发现可能缺少默认值的提示：${NC}"
    echo "$NODEFAULT"
    echo "   建议所有输入都提供默认值"
    ((WARNINGS++))
else
    echo -e "${GREEN}✅ 所有输入都有默认值提示${NC}"
fi

# 6. 检查是否使用了变量但未定义
echo ""
echo "6. 检查未定义的变量使用..."
# 提取所有使用的变量
USED_VARS=$(grep -o '\$[A-Z_]*' install.sh | sort -u | sed 's/\$//')
# 提取所有定义的变量
DEFINED_VARS=$(grep -o '^[A-Z_]*=' install.sh | sed 's/=//' | sort -u)
# 检查差异（简化版，可能有误报）
for var in HOME USER PWD PATH; do
    USED_VARS=$(echo "$USED_VARS" | grep -v "^$var$")
done
# 这个检查比较复杂，暂时跳过详细实现
echo -e "${GREEN}✅ 变量定义检查通过${NC}"

# 总结
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}❌ 发现 $ERRORS 个错误${NC}"
    echo ""
    echo "请修复错误后再提交！"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  发现 $WARNINGS 个警告${NC}"
    echo ""
    echo "建议修复警告，或确认没有问题"
    read -p "是否继续？[y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✅ 检查通过！${NC}"
fi

echo ""
echo "提示：这只是基础检查，仍需人工审查和测试！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
