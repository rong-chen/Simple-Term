#!/bin/bash
# Simple Term macOS Flutter 应用打包脚本
# 用法: ./build.sh [release|debug] [--dmg]

set -e

# 默认构建 Release 版本并创建 DMG
BUILD_CONFIG=${1:-release}
CREATE_DMG=true

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

echo "🔨 $APP_NAME 打包脚本 (Flutter)"
echo "================================"

# 进入项目目录
cd "$(dirname "$0")"

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装"
    exit 1
fi

# 安装依赖
echo "📦 安装 Flutter 依赖..."
flutter pub get

# 构建配置
if [ "$BUILD_CONFIG" = "release" ]; then
    echo "🚀 构建 Release 版本..."
    flutter build macos --release
    BUILD_DIR="build/macos/Build/Products/Release"
else
    echo "🔧 构建 Debug 版本..."
    flutter build macos --debug
    BUILD_DIR="build/macos/Build/Products/Debug"
fi

# 输出路径
APP_PATH="$BUILD_DIR/Simple Term.app"

if [ -d "$APP_PATH" ]; then
    echo ""
    echo "✅ 构建成功！"
    echo "================================"
    
    # 复制到项目根目录
    rm -rf "./$APP_NAME.app"
    cp -R "$APP_PATH" "./$APP_NAME.app"
    
    echo "📦 已生成: $(pwd)/$APP_NAME.app"
    
    # 创建 DMG
    if [ "$CREATE_DMG" = true ]; then
        echo ""
        echo "📀 正在创建 DMG..."
        
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
        
        # 删除 .app 文件，只保留 DMG
        rm -rf "./$APP_NAME.app"
    fi
    
    echo ""
    echo "提示: 双击 '$DMG_NAME' 安装应用"
else
    echo ""
    echo "❌ 构建失败"
    exit 1
fi
