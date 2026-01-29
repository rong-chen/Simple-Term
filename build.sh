#!/bin/bash
# Simple Term macOS 应用打包脚本
# 用法: ./build.sh [release|debug]

set -e

# 默认构建 Release 版本
BUILD_CONFIG=${1:-release}

echo "🔨 yzTerm 打包脚本"
echo "================================"

# 进入项目目录
cd "$(dirname "$0")"

# 安装依赖
echo "📦 检查依赖..."
if [ ! -d "node_modules" ]; then
    echo "安装 npm 依赖..."
    npm install
fi

# 进入 macos 目录
cd macos

# 安装 Pod 依赖
echo "📦 检查 CocoaPods..."
if [ ! -d "Pods" ]; then
    echo "安装 Pod 依赖..."
    pod install
fi

# 构建配置
if [ "$BUILD_CONFIG" = "release" ]; then
    CONFIGURATION="Release"
    echo "🚀 构建 Release 版本..."
else
    CONFIGURATION="Debug"
    echo "🔧 构建 Debug 版本..."
fi

# 构建应用
echo "🏗️  开始构建..."
xcodebuild -workspace yzTermApp.xcworkspace \
    -configuration "$CONFIGURATION" \
    -scheme yzTermApp-macOS \
    -derivedDataPath build \
    build

# 输出路径
APP_PATH="build/Build/Products/$CONFIGURATION/yzTermApp.app"

if [ -f "$APP_PATH/Contents/MacOS/yzTermApp" ]; then
    echo ""
    echo "✅ 构建成功！"
    echo "================================"
    
    # 复制到项目根目录，并重命名为 Simple Term.app
    rm -rf "../Simple Term.app"
    cp -R "$APP_PATH" "../Simple Term.app"
    
    echo "📦 已生成: $(cd .. && pwd)/Simple Term.app"
    echo ""
    echo "提示: 双击 'Simple Term.app' 即可运行"
else
    echo ""
    echo "❌ 构建失败"
    exit 1
fi
