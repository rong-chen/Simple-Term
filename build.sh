#!/bin/bash
# Simple Term macOS 应用打包脚本
# 用法: ./build.sh [release|debug] [--dmg]

set -e

# 默认构建 Release 版本
BUILD_CONFIG=${1:-release}
CREATE_DMG=false

# 检查参数
for arg in "$@"; do
    case $arg in
        --dmg)
            CREATE_DMG=true
            ;;
    esac
done

APP_NAME="Simple Term"
VERSION="1.0.0"

echo "🔨 $APP_NAME 打包脚本"
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
    
    # 复制到项目根目录，并重命名
    rm -rf "../$APP_NAME.app"
    cp -R "$APP_PATH" "../$APP_NAME.app"
    
    echo "📦 已生成: $(cd .. && pwd)/$APP_NAME.app"
    
    # 创建 DMG
    if [ "$CREATE_DMG" = true ]; then
        echo ""
        echo "📀 正在创建 DMG..."
        
        cd ..
        DMG_NAME="${APP_NAME}_v${VERSION}.dmg"
        DMG_TEMP="dmg_temp"
        
        # 清理旧文件
        rm -rf "$DMG_TEMP" "$DMG_NAME"
        
        # 创建临时目录
        mkdir -p "$DMG_TEMP"
        cp -R "$APP_NAME.app" "$DMG_TEMP/"
        
        # 创建指向 Applications 的符号链接
        ln -s /Applications "$DMG_TEMP/Applications"
        
        # 创建 DMG
        hdiutil create -volname "$APP_NAME" \
            -srcfolder "$DMG_TEMP" \
            -ov -format UDZO \
            "$DMG_NAME"
        
        # 清理临时目录
        rm -rf "$DMG_TEMP"
        
        echo "✅ DMG 已创建: $(pwd)/$DMG_NAME"
    fi
    
    echo ""
    echo "提示: 双击 '$APP_NAME.app' 即可运行"
else
    echo ""
    echo "❌ 构建失败"
    exit 1
fi
