/**
 * yzTerm - SSH 远程连接工具
 * 
 * 基于 React Native macOS，采用液态玻璃设计
 */

import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  StyleSheet,
  View,
  Text,
  useColorScheme,
  StatusBar,
  TouchableOpacity,
  ScrollView,
  TextInput,
  NativeModules,
  Animated,
  Alert,
} from 'react-native';
import {
  SafeAreaProvider,
} from 'react-native-safe-area-context';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { WebView } from 'react-native-webview';

// 文本图标组件 (使用 Unicode 符号，无需原生模块)
interface IconProps {
  size?: number;
  color?: string;
  style?: any;
}

// 服务器图标 (使用服务器 Unicode 符号)
const IconServer = ({ size = 24, color = '#86868b', style }: IconProps) => (
  <Text style={[{ fontSize: size * 0.7, color, textAlign: 'center' }, style]}>▣</Text>
);

// 已连接服务器图标 (带勾的服务器)
const IconServerConnected = ({ size = 24, color = '#32d74b', style }: IconProps) => (
  <Text style={[{ fontSize: size * 0.7, color, textAlign: 'center' }, style]}>◉</Text>
);

// 铅笔/编辑图标
const IconPencil = ({ size = 24, color = '#ffffff', style }: IconProps) => (
  <Text style={[{ fontSize: size * 0.7, color, textAlign: 'center' }, style]}>✎</Text>
);

// 网络连接图标
const IconLanConnect = ({ size = 24, color = '#86868b', style }: IconProps) => (
  <Text style={[{ fontSize: size * 0.7, color, textAlign: 'center' }, style]}>◎</Text>
);


const { SSHManager } = NativeModules;

// 调试：打印所有可用的原生模块
console.log('Available NativeModules:', Object.keys(NativeModules));
console.log('SSHManager:', SSHManager);
console.log('SSHManager methods:', SSHManager ? Object.keys(SSHManager) : 'null');
console.log('SSHManager.listDirectory:', SSHManager?.listDirectory);

// 存储 key
const HOSTS_STORAGE_KEY = '@yzterm/hosts';

// 主机类型定义
interface Host {
  id: string;
  name: string;
  hostname: string;
  port: number;
  username: string;
  password?: string;
}

// 远程文件类型定义
interface FileItem {
  name: string;
  type: 'directory' | 'file' | 'link';
  size: number;
  permissions: string;
}

// xterm.js 终端 HTML（内联以避免文件加载问题）
const TERMINAL_HTML = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/xterm@5.3.0/css/xterm.css" />
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; background-color: #0d0d0d; overflow: hidden; }
    #terminal { width: 100%; height: 100%; }
    /* 深色滚动条 */
    ::-webkit-scrollbar { width: 8px; height: 8px; }
    ::-webkit-scrollbar-track { background: #0d0d0d; }
    ::-webkit-scrollbar-thumb { background: #555; border-radius: 4px; }
    ::-webkit-scrollbar-thumb:hover { background: #777; }
  </style>
</head>
<body>
  <div id="terminal"></div>
  <script src="https://cdn.jsdelivr.net/npm/xterm@5.3.0/lib/xterm.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/xterm-addon-fit@0.8.0/lib/xterm-addon-fit.min.js"></script>
  <script>
    const term = new Terminal({
      cursorBlink: true,
      cursorStyle: 'block',
      fontSize: 14,
      fontFamily: 'Menlo, Monaco, "Courier New", monospace',
      theme: {
        background: '#0d0d0d',
        foreground: '#d4d4d4',
        cursor: '#ffffff',
        selection: 'rgba(255, 255, 255, 0.3)',
        black: '#0d0d0d', red: '#f44747', green: '#6a9955', yellow: '#dcdcaa',
        blue: '#569cd6', magenta: '#c586c0', cyan: '#4ec9b0', white: '#d4d4d4',
        brightBlack: '#808080', brightRed: '#f44747', brightGreen: '#6a9955',
        brightYellow: '#dcdcaa', brightBlue: '#569cd6', brightMagenta: '#c586c0',
        brightCyan: '#4ec9b0', brightWhite: '#ffffff'
      }
    });
    
    const fitAddon = new FitAddon.FitAddon();
    term.loadAddon(fitAddon);
    term.open(document.getElementById('terminal'));
    fitAddon.fit();
    
    window.addEventListener('resize', () => fitAddon.fit());
    
    // 用户输入 -> React Native
    term.onData((data) => {
      if (window.ReactNativeWebView) {
        window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'input', data: data }));
      }
    });
    
    // React Native -> 终端
    window.addEventListener('message', (event) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === 'output') term.write(msg.data);
        else if (msg.type === 'clear') term.clear();
        else if (msg.type === 'resize') fitAddon.fit();
      } catch (e) { term.write(event.data); }
    });
    
    document.addEventListener('message', (event) => {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === 'output') term.write(msg.data);
        else if (msg.type === 'clear') term.clear();
      } catch (e) { term.write(event.data); }
    });
    
    
    if (window.ReactNativeWebView) {
      window.ReactNativeWebView.postMessage(JSON.stringify({ type: 'ready' }));
    }
  </script>
</body>
</html>
`;

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  return (
    <SafeAreaProvider>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <AppContent isDarkMode={isDarkMode} />
    </SafeAreaProvider>
  );
}

interface AppContentProps {
  isDarkMode: boolean;
}

function AppContent({ isDarkMode }: AppContentProps) {
  const [hosts, setHosts] = useState<Host[]>([]);
  const [selectedHost, setSelectedHost] = useState<Host | null>(null);
  const [editorVisible, setEditorVisible] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [editingHost, setEditingHost] = useState<Partial<Host>>({});
  const [connected, setConnected] = useState(false);
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [connecting, setConnecting] = useState(false);
  const [terminalReady, setTerminalReady] = useState(false);

  // WebView ref for xterm.js
  const webViewRef = useRef<WebView>(null);

  // 双击检测
  const lastTapRef = useRef<{ hostId: string; time: number } | null>(null);

  // 旧的输入方式的 refs（保留作为后备）
  const [terminalOutput, setTerminalOutput] = useState<string[]>(['✓ 终端已就绪', '点击连接按钮开始 SSH 会话...']);
  const scrollViewRef = useRef<ScrollView>(null);

  // 文件浏览器状态
  const [currentPath, setCurrentPath] = useState('~');
  const [fileList, setFileList] = useState<FileItem[]>([]);
  const [loadingFiles, setLoadingFiles] = useState(false);
  const [pathInput, setPathInput] = useState('~');
  const [_isEditingPath, setIsEditingPath] = useState(false);

  // 上传进度状态
  const [uploadProgress, setUploadProgress] = useState<{ fileName: string; progress: number } | null>(null);

  // 下载进度状态
  const [downloadProgress, setDownloadProgress] = useState<{ fileName: string; progress: number } | null>(null);

  // 防止重复显示认证失败弹窗
  const authErrorShownRef = useRef(false);

  // 防止快速切换竞态条件
  const connectionRequestIdRef = useRef(0);

  // 闪烁光标动画
  const cursorOpacity = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    const blink = Animated.loop(
      Animated.sequence([
        Animated.timing(cursorOpacity, {
          toValue: 0,
          duration: 500,
          useNativeDriver: true,
        }),
        Animated.timing(cursorOpacity, {
          toValue: 1,
          duration: 500,
          useNativeDriver: true,
        }),
      ])
    );
    blink.start();
    return () => blink.stop();
  }, [cursorOpacity]);



  // 自动滚动到底部
  useEffect(() => {
    setTimeout(() => {
      scrollViewRef.current?.scrollToEnd({ animated: true });
    }, 100);
  }, [terminalOutput]);

  // 加载保存的主机（不加载密码，连接时懒加载）
  useEffect(() => {
    const loadHosts = async () => {
      try {
        const saved = await AsyncStorage.getItem(HOSTS_STORAGE_KEY);
        if (saved) {
          setHosts(JSON.parse(saved));
        }
      } catch (e) {
        console.error('Failed to load hosts:', e);
      }
    };
    loadHosts();
  }, []);

  // 保存主机到本地存储（不包含密码）
  const saveHosts = useCallback(async (newHosts: Host[]) => {
    try {
      // 删除密码后再保存
      const hostsWithoutPasswords = newHosts.map(({ password: _password, ...rest }) => rest);
      await AsyncStorage.setItem(HOSTS_STORAGE_KEY, JSON.stringify(hostsWithoutPasswords));
    } catch (e) {
      console.error('Failed to save hosts:', e);
    }
  }, []);

  // 向终端写入内容（保留颜色代码）
  const writeToTerminal = useCallback((text: string) => {
    // 只清理非颜色的 ANSI 序列
    // eslint-disable-next-line no-control-regex
    const cleanText = text
      .replace(/\x1b\[\?[0-9;]*[a-zA-Z]/g, '')  // 私有模式
      // eslint-disable-next-line no-control-regex
      .replace(/\x1b\][^\x07]*\x07/g, '')       // OSC 序列
      // eslint-disable-next-line no-control-regex
      .replace(/\x1b[()][AB012]/g, '')          // 字符集序列
      .replace(/\r/g, '');
    setTerminalOutput(prev => [...prev, cleanText]);
  }, []);

  // 发送数据到 xterm.js WebView
  const sendToTerminal = useCallback((data: string) => {
    if (webViewRef.current) {
      const message = JSON.stringify({ type: 'output', data });
      webViewRef.current.postMessage(message);
    }
  }, []);

  // 处理来自 xterm.js WebView 的消息
  const handleWebViewMessage = useCallback((event: any) => {
    try {
      const message = JSON.parse(event.nativeEvent.data);
      if (message.type === 'ready') {
        setTerminalReady(true);
        console.log('xterm.js 终端已就绪');
      } else if (message.type === 'input') {
        // 用户在终端中输入 - 直接发送到 SSH
        if (sessionId && SSHManager) {
          SSHManager.write(sessionId, message.data);
        }
      }
    } catch (e) {
      console.error('WebView message error:', e);
    }
  }, [sessionId]);

  // 轮询 SSH 输出
  // 轮询终端输出 - 使用当前的 connectionRequestIdRef 来防止过期响应
  useEffect(() => {
    if (!connected || !sessionId || !SSHManager) return;

    // 记录当前的请求 ID，确保只处理当前连接的输出
    const activeRequestId = connectionRequestIdRef.current;

    const pollOutput = async () => {
      // 如果请求 ID 已经变化，停止处理
      if (activeRequestId !== connectionRequestIdRef.current) return;

      try {
        const result = await SSHManager.getOutput(sessionId);

        // 再次检查请求 ID
        if (activeRequestId !== connectionRequestIdRef.current) return;

        if (result.output && result.output.length > 0) {
          // 检测认证失败
          if (result.output.includes('Permission denied')) {
            sendToTerminal(result.output);
            // 断开连接并显示错误（只显示一次，且只处理当前连接）
            if (!authErrorShownRef.current && activeRequestId === connectionRequestIdRef.current) {
              authErrorShownRef.current = true;
              setTimeout(() => {
                if (activeRequestId === connectionRequestIdRef.current) {
                  setConnected(false);
                  setSessionId(null);
                  Alert.alert('认证失败', '密码或密钥错误，请检查后重试', [{ text: '确定' }]);
                }
              }, 500);
            }
            return;
          }
          // 直接发送原始输出到 xterm.js（它会自动处理 ANSI 序列）
          sendToTerminal(result.output);
        }
      } catch (e) {
        console.log('Poll output stopped');
      }
    };

    const interval = setInterval(pollOutput, 100);
    return () => clearInterval(interval);
  }, [connected, sessionId, sendToTerminal]);

  // 加载远程目录（使用显式 host 参数）- 必须在 handleConnect 之前定义
  const loadDirectoryWithHost = useCallback(async (path: string, host: Host) => {
    if (!SSHManager) return;

    setLoadingFiles(true);
    try {
      const result = await SSHManager.listDirectory({
        hostname: host.hostname,
        port: host.port,
        username: host.username,
        password: host.password,
        path,
      });

      if (result.success) {
        setFileList(result.files || []);
        setCurrentPath(path);
        setPathInput(path);
      }
    } catch (error: any) {
      console.log('Directory listing failed:', error.message);
      setFileList([]);
    } finally {
      setLoadingFiles(false);
    }
  }, []);

  // 连接 SSH
  const handleConnect = useCallback(async (host: Host) => {
    if (!SSHManager) {
      writeToTerminal('\x1b[31m⚠️ SSH 模块未加载，请重新构建应用\x1b[0m\r\n');
      return;
    }

    // 递增请求 ID，使之前的请求失效
    const currentRequestId = ++connectionRequestIdRef.current;

    setConnecting(true);
    authErrorShownRef.current = false;  // 重置认证错误标志
    writeToTerminal(`\x1b[33m🔗 正在连接 ${host.username}@${host.hostname}:${host.port}...\x1b[0m\r\n`);

    try {
      // 从 Keychain 获取密码（会触发 Touch ID/密码验证）
      let password = host.password;
      if (!password) {
        try {
          const result = await SSHManager.getPassword(host.id);
          password = result.password || undefined;
        } catch (error: any) {
          if (error.code === 'USER_CANCELED') {
            setConnecting(false);
            writeToTerminal('\x1b[33m⚠️ 验证已取消\x1b[0m\r\n');
            return;
          }
          // 其他错误继续尝试连接（可能没有保存密码）
        }
      }

      // 检查请求是否仍然有效（用户可能已经切换到其他主机）
      if (currentRequestId !== connectionRequestIdRef.current) {
        return;  // 请求已过期，忽略响应
      }

      const result = await SSHManager.connect({
        hostname: host.hostname,
        port: host.port,
        username: host.username,
        password: password,
      });

      // 再次检查请求是否仍然有效
      if (currentRequestId !== connectionRequestIdRef.current) {
        // 断开这个过期的连接
        try { await SSHManager.disconnect(result.sessionId); } catch { }
        return;
      }

      setSessionId(result.sessionId);
      setConnected(true);
      setTerminalReady(true);  // 隐藏加载遮罩
      writeToTerminal(`\x1b[32m✅ 已连接到 ${host.hostname}\x1b[0m\r\n`);

      // 设置 ls 默认带颜色
      setTimeout(() => {
        if (result.sessionId && SSHManager && currentRequestId === connectionRequestIdRef.current) {
          SSHManager.write(result.sessionId, "alias ls='ls --color=auto'\r");
        }
      }, 500);

      // 加载文件浏览器（使用已获取的密码，避免再次验证）
      const hostWithPassword = { ...host, password };
      setTimeout(() => {
        if (currentRequestId === connectionRequestIdRef.current) {
          loadDirectoryWithHost('~', hostWithPassword);
        }
      }, 800);
    } catch (error: any) {
      // 检查请求是否仍然有效
      if (currentRequestId !== connectionRequestIdRef.current) {
        return;  // 请求已过期，忽略错误
      }
      const errorMsg = error.message || String(error);
      setConnected(false);
      setSessionId(null);
      setTerminalReady(false);
      // 只显示一次弹窗（可能轮询已经显示过了）
      if (!authErrorShownRef.current) {
        authErrorShownRef.current = true;
        Alert.alert('连接失败', errorMsg, [{ text: '确定' }]);
      }
    } finally {
      if (currentRequestId === connectionRequestIdRef.current) {
        setConnecting(false);
      }
    }
  }, [writeToTerminal, loadDirectoryWithHost]);

  // 断开连接
  const handleDisconnect = useCallback(async () => {
    if (sessionId && SSHManager) {
      try {
        await SSHManager.disconnect(sessionId);
      } catch (e) {
        console.error('Disconnect error:', e);
      }
    }
    setConnected(false);
    setSessionId(null);
    setTerminalReady(false);
    // 清除终端内容
    if (webViewRef.current) {
      webViewRef.current.postMessage(JSON.stringify({ type: 'clear' }));
    }
  }, [sessionId]);

  // 上传文件
  const handleUploadFile = useCallback(async () => {
    if (!selectedHost || !SSHManager || !sessionId) return;

    try {
      // 打开文件选择器
      const fileResult = await SSHManager.pickFile();
      if (fileResult.cancelled) return;

      const localPath = fileResult.path;
      const fileName = fileResult.name;

      // 使用文件浏览器的当前路径
      const remotePath = `${currentPath}/${fileName}`;

      // 仅使用进度条显示上传状态，不在终端显示

      // 显示进度条
      setUploadProgress({ fileName, progress: 0 });

      // 模拟进度（由于 scp 不提供进度回调）
      let progress = 0;
      const progressInterval = setInterval(() => {
        progress = Math.min(progress + 10, 90);
        setUploadProgress({ fileName, progress });
      }, 200);

      // 后台上传
      SSHManager.uploadFile({
        hostname: selectedHost.hostname,
        port: selectedHost.port,
        username: selectedHost.username,
        password: selectedHost.password,
        localPath,
        remotePath,
      }).then(async () => {
        clearInterval(progressInterval);
        setUploadProgress({ fileName, progress: 100 });
        // 延迟清除进度条
        setTimeout(() => setUploadProgress(null), 1500);
        // 刷新文件列表（直接调用API）
        try {
          const result = await SSHManager.listDirectory({
            hostname: selectedHost.hostname,
            port: selectedHost.port,
            username: selectedHost.username,
            password: selectedHost.password,
            path: currentPath,
          });
          if (result.success) {
            setFileList(result.files || []);
          }
        } catch { }
      }).catch(() => {
        clearInterval(progressInterval);
        setUploadProgress(null);
      });

    } catch {
      // 静默处理错误
    }
  }, [selectedHost, currentPath, sessionId]);

  // 下载文件
  const handleDownloadFile = useCallback(async (file: FileItem) => {
    if (!selectedHost || !SSHManager) return;

    try {
      // 打开保存位置选择器
      const saveResult = await SSHManager.pickSaveLocation(file.name);
      if (saveResult.cancelled) return;

      const localPath = saveResult.path;
      const remotePath = currentPath === '~' ? `~/${file.name}` : `${currentPath}/${file.name}`;

      // 显示进度条
      setDownloadProgress({ fileName: file.name, progress: 0 });

      // 模拟进度（由于 scp 不提供进度回调）
      let progress = 0;
      const progressInterval = setInterval(() => {
        progress = Math.min(progress + 10, 90);
        setDownloadProgress({ fileName: file.name, progress });
      }, 200);

      // 后台下载
      SSHManager.downloadFile({
        hostname: selectedHost.hostname,
        port: selectedHost.port,
        username: selectedHost.username,
        password: selectedHost.password,
        remotePath,
        localPath,
      }).then(() => {
        clearInterval(progressInterval);
        setDownloadProgress({ fileName: file.name, progress: 100 });
        // 延迟清除进度条
        setTimeout(() => setDownloadProgress(null), 1500);
      }).catch((error: any) => {
        clearInterval(progressInterval);
        setDownloadProgress(null);
        Alert.alert('下载失败', error?.message || '未知错误', [{ text: '确定' }]);
      });

    } catch {
      // 静默处理错误
    }
  }, [selectedHost, currentPath]);


  // 加载远程目录
  const loadDirectory = useCallback(async (path: string) => {
    if (!selectedHost || !SSHManager) return;

    setLoadingFiles(true);
    try {
      const result = await SSHManager.listDirectory({
        hostname: selectedHost.hostname,
        port: selectedHost.port,
        username: selectedHost.username,
        password: selectedHost.password,
        path,
      });

      if (result.success) {
        setFileList(result.files || []);
        setCurrentPath(path);
        setPathInput(path);
      }
    } catch (error: any) {
      // 忽略 SSH 的 known hosts 警告信息
      const errorMsg = error?.message || '';
      if (!errorMsg.includes('Warning: Permanently added')) {
        console.log('Directory listing failed:', error.message);
      }
      setFileList([]);
    } finally {
      setLoadingFiles(false);
    }
  }, [selectedHost]);


  // 处理文件项双击
  const handleFileDoubleClick = useCallback((file: FileItem) => {
    if (file.type === 'directory') {
      // 进入目录
      const newPath = currentPath === '~'
        ? `~/${file.name}`
        : `${currentPath}/${file.name}`;
      loadDirectory(newPath);
    }
  }, [currentPath, loadDirectory]);

  // 返回上级目录
  const handleGoBack = useCallback(() => {
    if (currentPath === '~' || currentPath === '/') return;
    const parts = currentPath.split('/');
    parts.pop();
    const parentPath = parts.length === 1 && parts[0] === '~' ? '~' : parts.join('/') || '/';
    loadDirectory(parentPath);
  }, [currentPath, loadDirectory]);






  // 处理主机点击 - 单击选择，双击连接
  const handleHostTap = useCallback((host: Host) => {
    const now = Date.now();
    const lastTap = lastTapRef.current;

    if (lastTap && lastTap.hostId === host.id && now - lastTap.time < 300) {
      // 双击 - 连接
      lastTapRef.current = null;
      setSelectedHost(host);
      handleConnect(host);
    } else {
      // 单击 - 选择
      lastTapRef.current = { hostId: host.id, time: now };
      setSelectedHost(host);
    }
  }, [handleConnect]);

  // 添加/编辑主机
  const handleSaveHost = async () => {
    if (!editingHost.name || !editingHost.hostname || !editingHost.username) return;

    let newHosts: Host[];
    let updatedHost: Host | null = null;
    const hostId = editingHost.id || Date.now().toString();

    if (editingHost.id) {
      // 编辑现有主机
      updatedHost = { ...editingHost } as Host;
      newHosts = hosts.map(h =>
        h.id === editingHost.id ? updatedHost! : h
      );
      // 如果正在编辑的是当前选中的主机，更新 selectedHost
      if (selectedHost?.id === editingHost.id) {
        setSelectedHost(updatedHost);
      }
    } else {
      // 新建主机
      const newHost: Host = {
        id: hostId,
        name: editingHost.name,
        hostname: editingHost.hostname,
        port: editingHost.port || 22,
        username: editingHost.username,
        password: editingHost.password,
      };
      newHosts = [...hosts, newHost];
    }

    // 密码存入 Keychain
    if (editingHost.password && SSHManager) {
      try {
        await SSHManager.savePassword(hostId, editingHost.password);
      } catch (e) {
        console.error('Failed to save password to Keychain:', e);
      }
    }

    setHosts(newHosts);
    saveHosts(newHosts);
    setEditorVisible(false);
    setEditingHost({});
  };

  const openEditor = (host?: Host) => {
    setEditingHost(host || { port: 22 });
    setEditorVisible(true);
  };

  const closeEditor = () => {
    setEditorVisible(false);
    setEditingHost({});
  };

  // 删除主机
  const handleDeleteHost = useCallback(async (host: Host) => {
    Alert.alert(
      '删除主机',
      `确定要删除 "${host.name}" 吗？`,
      [
        { text: '取消', style: 'cancel' },
        {
          text: '删除',
          style: 'destructive',
          onPress: async () => {
            // 从 Keychain 删除密码
            if (SSHManager) {
              try {
                await SSHManager.deletePassword(host.id);
              } catch (e) {
                console.log('Failed to delete password from Keychain:', e);
              }
            }
            // 从列表中移除
            const newHosts = hosts.filter(h => h.id !== host.id);
            setHosts(newHosts);
            saveHosts(newHosts);
            // 如果删除的是当前选中的主机，清除选择
            if (selectedHost?.id === host.id) {
              setSelectedHost(null);
            }
          },
        },
      ]
    );
  }, [hosts, saveHosts, selectedHost]);

  return (
    <View style={[styles.container, isDarkMode && styles.containerDark]}>
      {/* 主内容区域 */}
      <View style={styles.content}>
        {/* 侧边栏 */}
        <View style={[styles.sidebar, isDarkMode && styles.sidebarDark]}>
          <View style={styles.sidebarHeader}>
            <Text style={[styles.sectionTitle, isDarkMode && styles.textDark]}>
              主机列表
            </Text>
            <TouchableOpacity style={styles.addButton} onPress={() => openEditor()}>
              <Text style={styles.addButtonText}>+</Text>
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.hostList}>
            {hosts.map(host => (
              <TouchableOpacity
                key={host.id}
                style={[
                  styles.hostItem,
                  selectedHost?.id === host.id && styles.hostItemSelected,
                ]}
                onPress={() => handleHostTap(host)}
              >
                <View style={styles.hostRow}>
                  {connected && selectedHost?.id === host.id ? (
                    <IconServerConnected size={30} color="#32d74b" style={styles.hostIcon} />
                  ) : (
                    <IconServer size={30} color="#86868b" style={styles.hostIcon} />
                  )}
                  <View style={styles.hostTextContainer}>
                    <Text style={[styles.hostName, isDarkMode && styles.textDark]}>
                      {host.name}
                    </Text>
                    <Text style={[styles.hostInfo, isDarkMode && styles.textMuted]}>
                      {host.username}@{host.hostname}
                    </Text>
                  </View>
                </View>
              </TouchableOpacity>
            ))}
          </ScrollView>

          {/* 文件浏览器 */}
          {connected && selectedHost && (
            <View style={styles.fileBrowser}>
              <View style={styles.fileHeader}>
                <TouchableOpacity
                  style={styles.backBtn}
                  onPress={handleGoBack}
                  disabled={currentPath === '~' || currentPath === '/'}
                >
                  <Text style={styles.backBtnText}>←</Text>
                </TouchableOpacity>
                <TextInput
                  style={styles.pathInput}
                  value={pathInput}
                  onChangeText={setPathInput}
                  onSubmitEditing={() => {
                    if (pathInput.trim()) {
                      loadDirectory(pathInput.trim());
                    }
                  }}
                  onFocus={() => setIsEditingPath(true)}
                  onBlur={() => setIsEditingPath(false)}
                  placeholder="输入路径..."
                  placeholderTextColor="#666"
                  multiline={false}
                  numberOfLines={1}
                />
                <TouchableOpacity
                  style={styles.refreshBtn}
                  onPress={() => loadDirectory(currentPath)}
                >
                  <Text style={styles.refreshBtnText}>↻</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.uploadBtn}
                  onPress={handleUploadFile}
                >
                  <Text style={styles.uploadBtnText}>↑</Text>
                </TouchableOpacity>
              </View>
              <ScrollView style={styles.fileList}>
                {loadingFiles ? (
                  <Text style={styles.loadingText}>加载中...</Text>
                ) : fileList.length === 0 ? (
                  <Text style={styles.emptyText}>空目录</Text>
                ) : (
                  fileList.map((file, index) => (
                    <View
                      key={`${file.name}-${index}`}
                      style={styles.fileItem}
                    >
                      <TouchableOpacity
                        style={styles.fileItemContent}
                        onPress={() => handleFileDoubleClick(file)}
                      >
                        <Text style={styles.fileIcon}>
                          {file.type === 'directory' ? '▣' : file.type === 'link' ? '⤳' : '▢'}
                        </Text>
                        <Text style={styles.fileName} numberOfLines={1}>
                          {file.name}
                        </Text>
                      </TouchableOpacity>
                      {file.type === 'file' && (
                        <TouchableOpacity
                          style={styles.downloadBtn}
                          onPress={() => handleDownloadFile(file)}
                        >
                          <Text style={styles.downloadBtnText}>↓</Text>
                        </TouchableOpacity>
                      )}
                    </View>
                  ))
                )}
              </ScrollView>
            </View>
          )}
        </View>


        {/* 终端区域 */}
        <View style={[styles.terminal, isDarkMode && styles.terminalDark]}>
          {selectedHost ? (
            <>
              <View style={styles.terminalHeader}>
                <Text style={styles.terminalHeaderText}>
                  {selectedHost.username}@{selectedHost.hostname}:{selectedHost.port}
                </Text>
                <View style={styles.terminalActions}>
                  {connected ? (
                    <TouchableOpacity style={styles.disconnectBtn} onPress={handleDisconnect}>
                      <Text style={styles.disconnectBtnText}>断开</Text>
                    </TouchableOpacity>
                  ) : (
                    <TouchableOpacity
                      style={[styles.connectBtn, connecting && styles.connectBtnDisabled]}
                      onPress={() => handleConnect(selectedHost)}
                      disabled={connecting}
                    >
                      <Text style={styles.connectBtnText}>{connecting ? '连接中...' : '连接'}</Text>
                    </TouchableOpacity>
                  )}
                </View>
              </View>
              {connected ? (
                /* 已连接时显示终端 */
                <View style={styles.terminalOutput}>
                  <WebView
                    ref={webViewRef}
                    source={{ html: TERMINAL_HTML }}
                    style={{ flex: 1, backgroundColor: '#1e1e1e' }}
                    onMessage={handleWebViewMessage}
                    onLoad={() => {
                      setTimeout(() => setTerminalReady(true), 500);
                    }}
                    javaScriptEnabled={true}
                    originWhitelist={['*']}
                  />
                  {!terminalReady && (
                    <View style={styles.terminalLoading}>
                      <Text style={styles.terminalLoadingText}>终端加载中...</Text>
                    </View>
                  )}
                </View>
              ) : (
                /* 未连接时显示可编辑的主机信息 */
                <View style={styles.hostInfoPanel}>
                  <Text style={styles.hostInfoTitle}>{selectedHost.name}</Text>

                  <View style={styles.hostEditForm}>
                    <View style={styles.hostEditRow}>
                      <Text style={styles.hostEditLabel}>主机</Text>
                      <Text style={styles.hostEditValue}>{selectedHost.hostname}</Text>
                    </View>
                    <View style={styles.hostEditRow}>
                      <Text style={styles.hostEditLabel}>端口</Text>
                      <Text style={styles.hostEditValue}>{selectedHost.port}</Text>
                    </View>
                    <View style={styles.hostEditRow}>
                      <Text style={styles.hostEditLabel}>用户</Text>
                      <Text style={styles.hostEditValue}>{selectedHost.username}</Text>
                    </View>
                    <View style={styles.hostEditRow}>
                      <Text style={styles.hostEditLabel}>密码</Text>
                      <Text style={styles.hostEditValue}>••••••••</Text>
                    </View>
                  </View>

                  <View style={styles.hostActionButtons}>
                    <TouchableOpacity
                      style={styles.editHostBtn}
                      onPress={() => openEditor(selectedHost)}
                    >
                      <IconPencil size={16} color="#ffffff" />
                      <Text style={styles.editHostBtnText}>编辑</Text>
                    </TouchableOpacity>

                    <TouchableOpacity
                      style={styles.deleteHostBtn}
                      onPress={() => handleDeleteHost(selectedHost)}
                    >
                      <Text style={styles.deleteHostBtnText}>删除</Text>
                    </TouchableOpacity>
                  </View>

                  <Text style={styles.hostInfoHint}>双击主机或点击"连接"按钮开始</Text>
                </View>
              )}
            </>
          ) : (
            <View style={styles.terminalPlaceholder}>
              <IconLanConnect size={64} color="#86868b" />
              <Text style={styles.placeholderText}>选择一个主机开始连接</Text>
            </View>
          )}
        </View>
      </View>

      {/* 上传进度条 */}
      {uploadProgress && (
        <View style={styles.uploadProgressContainer}>
          <Text style={styles.uploadFileName} numberOfLines={1}>
            上传中: {uploadProgress.fileName}
          </Text>
          <View style={styles.uploadProgressBar}>
            <View style={[styles.uploadProgressFill, { width: `${uploadProgress.progress}%` }]} />
          </View>
          <Text style={styles.uploadProgressText}>{uploadProgress.progress}%</Text>
        </View>
      )}

      {/* 下载进度条 */}
      {downloadProgress && (
        <View style={styles.uploadProgressContainer}>
          <Text style={styles.uploadFileName} numberOfLines={1}>
            下载中: {downloadProgress.fileName}
          </Text>
          <View style={styles.uploadProgressBar}>
            <View style={[styles.uploadProgressFill, { width: `${downloadProgress.progress}%` }]} />
          </View>
          <Text style={styles.uploadProgressText}>{downloadProgress.progress}%</Text>
        </View>
      )}

      {/* 底部状态栏 */}
      <View style={[styles.statusBar, isDarkMode && styles.statusBarDark]}>
        <Text style={[styles.statusText, isDarkMode && styles.textMuted]}>
          {selectedHost
            ? `● 已选择 ${selectedHost.name} | ${selectedHost.hostname}:${selectedHost.port}`
            : `○ ${hosts.length} 个主机`
          }
        </Text>
      </View>

      {/* 主机编辑器 - 使用 View 覆盖层代替 Modal */}
      {editorVisible && (
        <View style={styles.overlay}>
          <TouchableOpacity
            style={styles.overlayBackground}
            activeOpacity={1}
            onPress={closeEditor}
          />
          <View style={[styles.editorPanel, isDarkMode && styles.editorPanelDark]}>
            <Text style={[styles.editorTitle, isDarkMode && styles.textDark]}>
              {editingHost.id ? '编辑主机' : '添加主机'}
            </Text>

            <Text style={styles.label}>名称</Text>
            <TextInput
              style={[styles.input, isDarkMode && styles.inputDark]}
              value={editingHost.name}
              onChangeText={text => setEditingHost(prev => ({ ...prev, name: text }))}
              placeholder="生产服务器"
              placeholderTextColor="#888"
            />

            <Text style={styles.label}>主机地址</Text>
            <TextInput
              style={[styles.input, isDarkMode && styles.inputDark]}
              value={editingHost.hostname}
              onChangeText={text => setEditingHost(prev => ({ ...prev, hostname: text }))}
              placeholder="192.168.1.100"
              placeholderTextColor="#888"
              autoCapitalize="none"
            />

            <View style={styles.row}>
              <View style={styles.halfInput}>
                <Text style={styles.label}>端口</Text>
                <TextInput
                  style={[styles.input, isDarkMode && styles.inputDark]}
                  value={String(editingHost.port || 22)}
                  onChangeText={text => setEditingHost(prev => ({ ...prev, port: parseInt(text) || 22 }))}
                  keyboardType="number-pad"
                />
              </View>
              <View style={[styles.halfInput, { marginLeft: 12 }]}>
                <Text style={styles.label}>用户名</Text>
                <TextInput
                  style={[styles.input, isDarkMode && styles.inputDark]}
                  value={editingHost.username}
                  onChangeText={text => setEditingHost(prev => ({ ...prev, username: text }))}
                  placeholder="root"
                  placeholderTextColor="#888"
                  autoCapitalize="none"
                />
              </View>
            </View>

            <Text style={styles.label}>密码</Text>
            <View style={styles.passwordContainer}>
              <TextInput
                style={[styles.input, styles.passwordInput, isDarkMode && styles.inputDark]}
                value={editingHost.password}
                onChangeText={text => setEditingHost(prev => ({ ...prev, password: text }))}
                placeholder="可选"
                placeholderTextColor="#888"
                secureTextEntry={!showPassword}
              />
              <TouchableOpacity
                style={styles.eyeBtn}
                onPress={() => {
                  console.log('Toggle password, current:', showPassword);
                  setShowPassword(!showPassword);
                }}
              >
                <Text style={styles.eyeBtnText}>{showPassword ? '隐藏' : '显示'}</Text>
              </TouchableOpacity>
            </View>

            <View style={styles.editorButtons}>
              <TouchableOpacity style={styles.cancelButton} onPress={closeEditor} activeOpacity={0.7}>
                <Text style={styles.cancelButtonText}>取消</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.saveButton}
                onPress={handleSaveHost}
                activeOpacity={0.7}
                delayPressIn={0}
              >
                <Text style={styles.saveButtonText}>保存</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f7',
    paddingTop: 28, // 留出标题栏空间
  },
  containerDark: {
    backgroundColor: '#1e1e1e',
  },
  titleBar: {
    paddingHorizontal: 16,
    paddingBottom: 12,
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.8)',
  },
  title: {
    fontSize: 18,
    fontWeight: '700',
    color: '#1d1d1f',
  },
  titleDark: {
    color: '#ffffff',
  },
  subtitle: {
    fontSize: 12,
    color: '#86868b',
    marginTop: 2,
  },
  subtitleDark: {
    color: '#a1a1a6',
  },
  content: {
    flex: 1,
    flexDirection: 'row',
    padding: 12,
    gap: 12,
  },
  sidebar: {
    width: 240,
    padding: 12,
    backgroundColor: 'rgba(255, 255, 255, 0.6)',
    borderRadius: 12,
  },
  sidebarDark: {
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
  },
  sidebarHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  sectionTitle: {
    fontSize: 13,
    fontWeight: '600',
    color: '#1d1d1f',
  },
  addButton: {
    width: 24,
    height: 24,
    borderRadius: 6,
    backgroundColor: 'rgba(0, 122, 255, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  addButtonText: {
    fontSize: 18,
    color: '#007aff',
    fontWeight: '600',
  },
  hostList: {
    flex: 1,
  },
  hostItem: {
    padding: 10,
    marginBottom: 6,
    borderRadius: 8,
    backgroundColor: 'rgba(0, 0, 0, 0.03)',
  },
  hostItemSelected: {
    backgroundColor: 'rgba(0, 122, 255, 0.15)',
  },
  hostRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  hostIcon: {
    marginRight: 8,
  },
  editBtn: {
    padding: 6,
    marginLeft: 4,
  },
  menuBtn: {
    padding: 4,
  },
  hostTextContainer: {
    flex: 1,
  },
  hostName: {
    fontSize: 14,
    fontWeight: '500',
    color: '#1d1d1f',
  },
  hostInfo: {
    fontSize: 11,
    color: '#86868b',
    marginTop: 2,
  },
  terminal: {
    flex: 1,
    backgroundColor: '#1e1e1e',
    borderRadius: 12,
    overflow: 'hidden',
  },
  terminalDark: {
    backgroundColor: '#0d0d0d',
  },
  terminalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(255, 255, 255, 0.1)',
  },
  terminalHeaderText: {
    fontSize: 13,
    color: '#ffffff',
  },
  statusConnected: {
    fontSize: 12,
    color: '#32d74b',
  },
  terminalOutput: {
    flex: 1,
    backgroundColor: '#0d0d0d',
    paddingHorizontal: 10,
    borderRadius: 4,
  },
  terminalLoading: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: '#1e1e1e',
    justifyContent: 'center',
    alignItems: 'center',
  },
  terminalLoadingText: {
    color: '#808080',
    fontSize: 14,
  },
  terminalText: {
    fontFamily: 'Menlo',
    fontSize: 13,
    color: '#00ff00',
    lineHeight: 20,
  },
  terminalPlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderIcon: {
    fontSize: 48,
    marginBottom: 16,
  },
  placeholderText: {
    fontSize: 14,
    color: '#86868b',
  },
  hostInfoPanel: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#1e1e1e',
  },
  hostInfoTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#ffffff',
    marginTop: 16,
    marginBottom: 8,
  },
  hostInfoDetail: {
    fontSize: 14,
    color: '#a0a0a0',
    marginVertical: 4,
  },
  hostInfoHint: {
    fontSize: 12,
    color: '#666666',
    marginTop: 24,
  },
  hostEditForm: {
    width: '80%',
    maxWidth: 300,
    marginTop: 16,
  },
  hostEditRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#333333',
  },
  hostEditLabel: {
    fontSize: 14,
    color: '#888888',
  },
  hostEditValue: {
    fontSize: 14,
    color: '#ffffff',
  },
  editHostBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#0a84ff',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
  },
  editHostBtnText: {
    color: '#ffffff',
    fontSize: 14,
    marginLeft: 6,
  },
  hostActionButtons: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 20,
    gap: 12,
  },
  deleteHostBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#ff453a',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
  },
  deleteHostBtnText: {
    color: '#ffffff',
    fontSize: 14,
  },
  statusBar: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.8)',
  },
  statusBarDark: {
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
  },
  statusText: {
    fontSize: 12,
    color: '#86868b',
  },
  textDark: {
    color: '#ffffff',
  },
  textMuted: {
    color: '#a1a1a6',
  },
  // Overlay styles (替代 Modal)
  overlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
  },
  overlayBackground: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  editorPanel: {
    width: 360,
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 24,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.3,
    shadowRadius: 20,
  },
  editorPanelDark: {
    backgroundColor: '#2c2c2e',
  },
  editorTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#1d1d1f',
    marginBottom: 20,
  },
  label: {
    fontSize: 12,
    fontWeight: '500',
    color: '#86868b',
    marginBottom: 6,
    marginTop: 12,
  },
  input: {
    backgroundColor: 'rgba(0, 0, 0, 0.05)',
    borderRadius: 8,
    padding: 10,
    fontSize: 14,
    color: '#1d1d1f',
  },
  inputDark: {
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    color: '#ffffff',
  },
  passwordContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  passwordInput: {
    flex: 1,
  },
  eyeBtn: {
    paddingVertical: 10,
    paddingHorizontal: 12,
    backgroundColor: 'rgba(0, 122, 255, 0.1)',
    borderRadius: 6,
  },
  eyeBtnText: {
    fontSize: 13,
    color: '#007aff',
    fontWeight: '500',
  },
  row: {
    flexDirection: 'row',
  },
  halfInput: {
    flex: 1,
  },
  editorButtons: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginTop: 24,
    gap: 12,
  },
  cancelButton: {
    paddingVertical: 10,
    paddingHorizontal: 16,
    borderRadius: 8,
    backgroundColor: 'rgba(0, 0, 0, 0.05)',
  },
  cancelButtonText: {
    fontSize: 14,
    color: '#86868b',
    fontWeight: '500',
  },
  saveButton: {
    paddingVertical: 10,
    paddingHorizontal: 20,
    borderRadius: 8,
    backgroundColor: '#007aff',
  },
  saveButtonText: {
    fontSize: 14,
    color: '#ffffff',
    fontWeight: '600',
  },
  // Terminal action styles
  terminalActions: {
    flexDirection: 'row',
    gap: 8,
  },
  connectBtn: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 6,
    backgroundColor: '#32d74b',
  },
  connectBtnDisabled: {
    opacity: 0.5,
  },
  connectBtnText: {
    fontSize: 12,
    color: '#ffffff',
    fontWeight: '600',
  },
  disconnectBtn: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 6,
    backgroundColor: '#ff453a',
  },
  disconnectBtnText: {
    fontSize: 12,
    color: '#ffffff',
    fontWeight: '600',
  },
  fileBtn: {
    paddingVertical: 6,
    paddingHorizontal: 10,
    borderRadius: 6,
    backgroundColor: '#3a3a3c',
    marginRight: 8,
  },
  fileBtnText: {
    fontSize: 12,
    color: '#ffffff',
  },
  // 文件浏览器样式
  fileBrowser: {
    flex: 1,
    borderTopWidth: 1,
    borderTopColor: '#333',
    marginTop: 8,
  },
  fileHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 6,
    backgroundColor: '#2d2d2d',
  },
  backBtn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  backBtnText: {
    fontSize: 14,
    color: '#ffffff',
  },
  pathInput: {
    flex: 1,
    height: 24,
    paddingHorizontal: 8,
    paddingTop: 4,
    paddingBottom: 4,
    backgroundColor: '#0d0d0d',
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#333',
    color: '#e5e5e5',
    fontSize: 11,
    marginHorizontal: 6,
  },
  refreshBtn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  refreshBtnText: {
    fontSize: 12,
    color: '#ffffff',
  },
  uploadBtn: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    marginLeft: 6,
    backgroundColor: '#3a3a3a',
    borderRadius: 4,
  },
  uploadBtnText: {
    fontSize: 12,
    color: '#ffffff',
  },
  fileItemContent: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
  },
  downloadBtn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  downloadBtnText: {
    fontSize: 12,
    color: '#3b82f6',
  },
  fileList: {
    flex: 1,
  },
  loadingText: {
    color: '#9ca3af',
    fontSize: 12,
    textAlign: 'center',
    paddingVertical: 20,
  },
  emptyText: {
    color: '#9ca3af',
    fontSize: 12,
    textAlign: 'center',
    paddingVertical: 20,
  },
  fileItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderBottomWidth: 1,
    borderBottomColor: '#333',
  },
  fileIcon: {
    fontSize: 14,
    marginRight: 8,
  },
  fileName: {
    flex: 1,
    fontSize: 12,
    color: '#e5e5e5',
  },
  // Upload progress styles
  uploadProgressContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 8,
    backgroundColor: '#1a1a1a',
    borderTopWidth: 1,
    borderTopColor: '#333',
    gap: 8,
  },
  uploadFileName: {
    fontSize: 11,
    color: '#9ca3af',
    maxWidth: 150,
  },
  uploadProgressBar: {
    flex: 1,
    height: 6,
    backgroundColor: '#333',
    borderRadius: 3,
    overflow: 'hidden',
  },
  uploadProgressFill: {
    height: '100%',
    backgroundColor: '#10b981',
    borderRadius: 3,
  },
  uploadProgressText: {
    fontSize: 11,
    color: '#10b981',
    minWidth: 35,
    textAlign: 'right',
  },
  // Command input styles
  commandInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderTopWidth: 1,
    borderTopColor: '#333',
    gap: 8,
  },
  commandInput: {
    flex: 1,
    height: 36,
    paddingHorizontal: 12,
    backgroundColor: '#1a1a1a',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#444',
    color: '#00ff00',
    fontFamily: 'Menlo',
    fontSize: 13,
  },
  sendBtn: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 6,
    backgroundColor: '#007aff',
  },
  sendBtnText: {
    fontSize: 12,
    color: '#ffffff',
    fontWeight: '600',
  },
  promptText: {
    fontSize: 14,
    color: '#00ff00',
    fontFamily: 'Menlo',
    marginRight: 8,
  },
  terminalContentContainer: {
    flexGrow: 1,
    justifyContent: 'flex-start',
    paddingBottom: 200, // 底部留白让内容居中显示
  },
  terminalWebView: {
    flex: 1,
    backgroundColor: '#1e1e1e',
  },
  inlineInputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  },
  inlinePrompt: {
    fontSize: 14,
    color: '#00ff00',
    fontFamily: 'Menlo',
    marginRight: 8,
  },
  inlineInput: {
    flex: 1,
    fontSize: 14,
    color: '#00ff00',
    fontFamily: 'Menlo',
    padding: 0,
    margin: 0,
    backgroundColor: 'transparent',
    borderWidth: 0,
    height: 20,
  },
  fixedInputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 10,
    backgroundColor: '#1a1a1a',
    borderTopWidth: 1,
    borderTopColor: '#333',
  },
  terminalInputWrapper: {
    flex: 1,
    position: 'relative',
  },
  hiddenInput: {
    position: 'absolute',
    left: -9999,    // 移到屏幕外隐藏 focus ring
    width: 1,
    height: 1,
    opacity: 0,
  },
  visibleInputText: {
    fontSize: 14,
    color: '#00ff00',
    fontFamily: 'Menlo',
    height: 20,
    lineHeight: 20,
  },
  blinkingCursor: {
    color: '#00ff00',
  },
  lastLineWithInput: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
  },
});

export default App;
