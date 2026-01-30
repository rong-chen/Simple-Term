#!/bin/bash
# Simple Term Git 推送脚本
# 用法: ./git.sh

set -e

echo "🚀 Simple Term 发布脚本"
echo "========================"
echo ""

# 显示当前状态
echo "📋 当前 Git 状态:"
git status --short
echo ""

# 输入 commit message
read -p "📝 请输入 Commit 信息: " COMMIT_MSG

if [ -z "$COMMIT_MSG" ]; then
    echo "❌ Commit 信息不能为空"
    exit 1
fi

# 输入 tag
read -p "🏷️  请输入版本 Tag (例如 v1.0.0，留空则不创建 tag): " TAG

echo ""
echo "========================"
echo "📋 确认信息:"
echo "   Commit: $COMMIT_MSG"
if [ -n "$TAG" ]; then
    echo "   Tag: $TAG"
fi
echo ""

read -p "确认提交? (Y/n): " CONFIRM
CONFIRM=${CONFIRM:-y}  # 默认为 y
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "❌ 已取消"
    exit 0
fi

echo ""

# 添加所有更改
echo "📦 添加文件..."
git add .

# 提交
echo "💾 提交更改..."
git commit -m "$COMMIT_MSG"

# 获取当前分支名称
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 推送代码
echo "⬆️  推送代码到 $BRANCH..."
git push origin "$BRANCH"

# 如果有 tag，创建并推送
if [ -n "$TAG" ]; then
    echo "🏷️  创建 Tag: $TAG"
    git tag "$TAG"
    
    echo "⬆️  推送 Tag..."
    git push origin "$TAG"
    
    echo ""
    echo "✅ 完成！GitHub Actions 将自动构建并发布到 Releases"
    echo "🔗 查看进度: https://github.com/rong-chen/Simple-Term/actions"
else
    echo ""
    echo "✅ 代码已推送（未创建 Tag，不会触发自动发布）"
fi
