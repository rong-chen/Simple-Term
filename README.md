# Simple Term

<p align="center">
  <img src="https://img.shields.io/badge/平台-macOS-blue" alt="Platform">
  <img src="https://img.shields.io/badge/React%20Native-0.81.0-61dafb" alt="React Native">
  <img src="https://img.shields.io/badge/许可证-MIT-green" alt="License">
</p>

一款现代、优雅的 macOS SSH 终端客户端，使用 React Native 构建。拥有精美的深色主题、集成文件浏览器，以及通过 macOS 钥匙串实现的安全凭证存储。
最新Mac系统可以使用，持续更新

## ✨ 功能特性

- 🖥️ **全功能终端** - 基于 xterm.js，完整支持 ANSI 颜色
- 📁 **远程文件浏览器** - 通过 SFTP 浏览、上传、下载文件
- 🔐 **安全凭证存储** - 密码存储在 macOS 钥匙串，支持 Touch ID 保护
- 🎨 **深色主题** - 精美护眼的界面设计，适合长时间使用
- ⚡ **快速原生** - React Native macOS 提供接近原生的性能
- 🔄 **会话管理** - 保存和管理多个 SSH 连接

## 📸 界面预览

应用采用三栏布局：
- **左侧边栏**：主机管理，快速连接
- **右上区域**：xterm.js 终端，完整颜色支持
- **右下区域**：SFTP 文件浏览器，支持上传/下载

## 🚀 快速开始

### 环境要求

- macOS 12.0 或更高版本
- Node.js 18+
- Xcode 14+
- CocoaPods

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/YOUR_USERNAME/simple-term.git
   cd simple-term
   ```

2. **安装依赖**
   ```bash
   npm install
   ```

3. **安装 CocoaPods 依赖**
   ```bash
   cd macos
   bundle install
   bundle exec pod install
   cd ..
   ```

4. **运行应用**
   ```bash
   npx react-native run-macos
   ```

   或者在 Xcode 中打开 `macos/yzTermApp.xcworkspace` 直接构建。

### 构建发布版本

```bash
./build.sh
```

构建完成后，应用位于 `macos/build/Build/Products/Release/` 目录。

## 🛠️ 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | React Native 0.81 for macOS |
| 终端 | xterm.js 5.3 |
| SSH/SFTP | 原生 Swift (NMSSH) |
| 存储 | AsyncStorage + macOS 钥匙串 |
| UI | 自定义深色主题，液态玻璃设计 |

## 🔒 安全特性

- 密码**从不**以明文存储
- 所有凭证安全存放在 macOS 钥匙串中
- 访问已保存密码需要 Touch ID / 密码认证
- SSH 连接使用标准加密协议

## 📂 项目结构

```
Simple Term/
├── App.tsx              # 主应用组件
├── macos/
│   ├── yzTermApp-macOS/
│   │   └── SSHManager.swift  # 原生 SSH/SFTP 模块
│   ├── Podfile
│   └── yzTermApp.xcworkspace
├── package.json
└── build.sh             # 发布构建脚本
```

## 🤝 贡献指南

欢迎贡献代码！请随时提交 Pull Request。

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m '添加某个很棒的功能'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 发起 Pull Request

## 📝 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- [React Native for macOS](https://github.com/nicklockwood/react-native-macos) - React Native 的 macOS 支持
- [xterm.js](https://xtermjs.org/) - 浏览器终端模拟器
- [NMSSH](https://github.com/NMSSH/NMSSH) - Objective-C/Swift SSH 库

---

<p align="center">用 ❤️ 为 macOS 社区打造</p>
