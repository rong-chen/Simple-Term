import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'models/host.dart';
import 'services/storage_service.dart';
import 'services/ssh_service.dart';

void main() {
  runApp(const SimpleTermApp());
}

class SimpleTermApp extends StatelessWidget {
  const SimpleTermApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Term',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1e1e1e),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF007AFF),
          secondary: Color(0xFF32d74b),
          surface: Color(0xFF2d2d2d),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF007AFF),
          selectionColor: Color(0x40007AFF),
          selectionHandleColor: Color(0xFF007AFF),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();
  final SSHService _sshService = SSHService();
  
  List<Host> _hosts = [];
  Host? _selectedHost;
  bool _isConnected = false;
  bool _isConnecting = false;
  
  // 文件管理器
  List<SftpFileInfo> _files = [];
  String _currentPath = '~';
  bool _isLoadingFiles = false;
  
  // 传输进度
  bool _isTransferring = false;
  String _transferMessage = '';
  double _transferProgress = 0.0;
  
  // 终端
  late Terminal _terminal;
  late TerminalController _terminalController;
  
  // 搜索
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<dynamic> _searchHighlights = [];  // 存储搜索高亮
  List<int> _searchMatchLines = [];  // 存储匹配的行号
  int _currentMatchIndex = -1;  // 当前匹配索引
  final ScrollController _terminalScrollController = ScrollController();
  
  // SSH 输出订阅
  StreamSubscription<String>? _outputSubscription;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _terminalController = TerminalController();
    _loadHosts();
    
    // 设置空闲断线回调
    _sshService.onIdleDisconnect = () {
      setState(() {
        _isConnected = false;
        _terminal.buffer.clear();
        _files = [];
      });
    };
  }

  Future<void> _loadHosts() async {
    final hosts = await _storageService.getHosts();
    setState(() => _hosts = hosts);
  }

  Future<void> _connectToHost(Host host) async {
    setState(() {
      _isConnecting = true;
      _selectedHost = host;
    });
    
    try {
      // 获取密码
      String? password = await _storageService.getPassword(host.id);
      if (password == null) {
        _showPasswordDialog(host);
        setState(() => _isConnecting = false);
        return;
      }

      // 取消旧的输出订阅
      await _outputSubscription?.cancel();
      _outputSubscription = null;
      
      // 重新创建 Terminal 对象（确保干净状态）
      _terminal = Terminal(maxLines: 10000);
      
      await _sshService.connect(host, password);
      
      // 监听输出（保存订阅引用）
      _outputSubscription = _sshService.output.listen((data) {
        _terminal.write(data);
      });

      // 监听终端输入
      _terminal.onOutput = (data) {
        _sshService.write(data);
      };

      // 监听终端尺寸变化
      _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        _sshService.resize(width, height);
      };

      setState(() {
        _isConnected = true;
        _isConnecting = false;
        _selectedHost = host;
      });
    } catch (e) {
      setState(() => _isConnecting = false);
      _showError('连接失败: $e');
    }
  }

  Future<void> _disconnect() async {
    await _outputSubscription?.cancel();
    _outputSubscription = null;
    await _sshService.disconnect();
    setState(() {
      _isConnected = false;
      _terminal.buffer.clear();
      _files = [];
    });
  }

  Future<void> _loadFiles(String path) async {
    if (_selectedHost == null) return;
    
    setState(() => _isLoadingFiles = true);
    
    try {
      final password = await _storageService.getPassword(_selectedHost!.id);
      if (password == null) return;
      
      final files = await _sshService.listDirectory(_selectedHost!, password, path);
      // 排序：文件夹在前，然后按名称排序
      files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.compareTo(b.name);
      });
      
      setState(() {
        _files = files;
        _currentPath = path;
        _isLoadingFiles = false;
      });
    } catch (e) {
      setState(() => _isLoadingFiles = false);
      _showError('加载文件失败: $e');
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedHost == null) return;
    
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    
    final file = result.files.first;
    if (file.path == null) return;
    
    // 显示底部进度条
    setState(() {
      _isTransferring = true;
      _transferMessage = '正在上传: ${file.name}';
      _transferProgress = 0.0;
    });
    
    try {
      final password = await _storageService.getPassword(_selectedHost!.id);
      if (password == null) {
        setState(() => _isTransferring = false);
        return;
      }
      
      // 处理远程路径
      String remotePath = _currentPath;
      if (remotePath == '~' || remotePath.startsWith('~/')) {
        final homePath = _selectedHost!.username == 'root' ? '/root' : '/home/${_selectedHost!.username}';
        remotePath = remotePath == '~' ? homePath : remotePath.replaceFirst('~', homePath);
      }
      
      await _sshService.uploadFile(
        _selectedHost!,
        password,
        file.path!,
        '$remotePath/${file.name}',
        onProgress: (progress) {
          setState(() => _transferProgress = progress);
        },
      );
      
      setState(() => _isTransferring = false);
      _loadFiles(_currentPath);
      _showSuccess('上传成功: ${file.name}');
    } catch (e) {
      setState(() => _isTransferring = false);
      _showError('上传失败: $e');
    }
  }

  Future<void> _downloadFile(String fileName) async {
    if (_selectedHost == null) return;
    
    final downloadDir = await FilePicker.platform.getDirectoryPath();
    if (downloadDir == null) return;
    
    // 显示底部进度条
    setState(() {
      _isTransferring = true;
      _transferMessage = '正在下载: $fileName';
      _transferProgress = 0.0;
    });
    
    try {
      final password = await _storageService.getPassword(_selectedHost!.id);
      if (password == null) {
        setState(() => _isTransferring = false);
        return;
      }
      
      // 处理远程路径
      String remotePath = _currentPath;
      if (remotePath == '~' || remotePath.startsWith('~/')) {
        final homePath = _selectedHost!.username == 'root' ? '/root' : '/home/${_selectedHost!.username}';
        remotePath = remotePath == '~' ? homePath : remotePath.replaceFirst('~', homePath);
      }
      
      await _sshService.downloadFile(
        _selectedHost!,
        password,
        '$remotePath/$fileName',
        '$downloadDir/$fileName',
        onProgress: (progress) {
          setState(() => _transferProgress = progress);
        },
      );
      
      setState(() => _isTransferring = false);
      _showSuccess('下载成功: $fileName');
    } catch (e) {
      setState(() => _isTransferring = false);
      _showError('下载失败: $e');
    }
  }

  void _showSuccess(String message) {
    _showToast(message, const Color(0xFF32d74b));
  }

  void _showError(String message) {
    _showToast(message, Colors.red);
  }

  void _showToast(String message, Color bgColor) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).size.height * 0.4,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () => entry.remove());
  }

  void _clearSearchHighlights() {
    for (final h in _searchHighlights) {
      h.dispose();
    }
    _searchHighlights.clear();
    _searchMatchLines.clear();
    _currentMatchIndex = -1;
  }

  void _searchTerminal(String query) {
    _clearSearchHighlights();
    if (query.isEmpty) return;
    
    final buffer = _terminal.buffer;
    final lines = buffer.lines;
    
    for (int y = 0; y < lines.length; y++) {
      final line = lines[y];
      final text = line.getText();
      int startIndex = 0;
      
      while (true) {
        final index = text.indexOf(query, startIndex);
        if (index == -1) break;
        
        final p1 = buffer.createAnchor(index, y);
        final p2 = buffer.createAnchor(index + query.length, y);
        
        // 先用黄色创建高亮
        final highlight = _terminalController.highlight(
          p1: p1,
          p2: p2,
          color: const Color(0xFFFFFF00),
        );
        _searchHighlights.add(highlight);
        _searchMatchLines.add(y);
        
        startIndex = index + 1;
      }
    }
    
    // 自动跳转到第一个匹配
    if (_searchMatchLines.isNotEmpty) {
      _currentMatchIndex = 0;
      _jumpToMatch(_currentMatchIndex);
    }
    setState(() {});
  }

  void _jumpToMatch(int index) {
    if (index < 0 || index >= _searchMatchLines.length) return;
    if (!_terminalScrollController.hasClients) return;
    
    final line = _searchMatchLines[index];
    // 每行高度约 18 像素，滚动到匹配行附近
    const lineHeight = 18.0;
    final targetOffset = line * lineHeight;
    final maxOffset = _terminalScrollController.position.maxScrollExtent;
    final scrollTo = targetOffset.clamp(0.0, maxOffset);
    
    _terminalScrollController.jumpTo(scrollTo);
  }

  void _nextMatch() {
    if (_searchMatchLines.isEmpty) return;
    _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatchLines.length;
    _jumpToMatch(_currentMatchIndex);
    setState(() {});
  }

  void _prevMatch() {
    if (_searchMatchLines.isEmpty) return;
    _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatchLines.length) % _searchMatchLines.length;
    _jumpToMatch(_currentMatchIndex);
    setState(() {});
  }

  void _showPasswordDialog(Host host) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text('输入密码'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'SSH 密码',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _storageService.savePassword(host.id, controller.text);
              _connectToHost(host);
            },
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }

  void _showAddHostDialog() {
    final nameController = TextEditingController();
    final hostnameController = TextEditingController();
    final portController = TextEditingController(text: '22');
    final usernameController = TextEditingController(text: 'root');
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2d2d2d),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(24),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                const Text(
                  '添加主机',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                
                // 名称
                const Text('名称', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('生产服务器'),
                ),
                const SizedBox(height: 16),
                
                // 主机地址
                const Text('主机地址', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: hostnameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('192.168.1.100'),
                ),
                const SizedBox(height: 16),
                
                // 端口和用户名 - 同一行
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('端口', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: portController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('22'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('用户名', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: usernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDecoration('root'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 密码
                const Text('密码', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('可选'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(obscurePassword ? '显示' : '隐藏'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // 按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('取消', style: TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty || hostnameController.text.isEmpty) {
                          return;
                        }
                        final host = Host(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameController.text,
                          hostname: hostnameController.text,
                          port: int.tryParse(portController.text) ?? 22,
                          username: usernameController.text.isEmpty ? 'root' : usernameController.text,
                        );
                        await _storageService.addHost(host);
                        if (passwordController.text.isNotEmpty) {
                          await _storageService.savePassword(host.id, passwordController.text);
                        }
                        await _loadHosts();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('保存', style: TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFF404040),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _deleteHost(Host host) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text('确认删除'),
        content: Text('确定要删除主机 "${host.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.deleteHost(host.id);
      await _loadHosts();
      setState(() {
        if (_selectedHost?.id == host.id) {
          _selectedHost = null;
        }
      });
      _showSuccess('已删除主机');
    }
  }

  Future<void> _updateHost(Host host, String name, String hostname, int port, String username, String? password) async {
    final updatedHost = Host(
      id: host.id,
      name: name,
      hostname: hostname,
      port: port,
      username: username,
    );
    await _storageService.updateHost(updatedHost);
    if (password != null && password.isNotEmpty) {
      await _storageService.savePassword(host.id, password);
    }
    await _loadHosts();
    setState(() => _selectedHost = updatedHost);
    _showSuccess('已更新主机');
  }

  Widget _buildHostDetailPanel() {
    if (_selectedHost == null) {
      return const Center(
        child: Text(
          '选择一个主机查看详情',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final host = _selectedHost!;
    final nameController = TextEditingController(text: host.name);
    final hostnameController = TextEditingController(text: host.hostname);
    final portController = TextEditingController(text: host.port.toString());
    final usernameController = TextEditingController(text: host.username);
    final passwordController = TextEditingController();

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名称
              const Text('名称', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('服务器名称'),
              ),
              const SizedBox(height: 16),

              // 主机地址
              const Text('主机地址', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: hostnameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('IP 或域名'),
              ),
              const SizedBox(height: 16),

              // 端口和用户名
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('端口', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: portController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('22'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('用户名', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('root'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 密码
              const Text('密码（留空保持不变）', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('新密码'),
              ),
              const SizedBox(height: 32),

              // 保存和删除按钮
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateHost(
                        host,
                        nameController.text,
                        hostnameController.text,
                        int.tryParse(portController.text) ?? 22,
                        usernameController.text,
                        passwordController.text.isEmpty ? null : passwordController.text,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('保存修改', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _deleteHost(host),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('删除', style: TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
        children: [
          // 侧边栏 - 主机列表和文件管理器
          Container(
            width: 250,
            color: const Color(0xFF1e1e1e),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // 主机列表容器
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF353535),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                  // 标题栏（在圆角容器内）
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Text(
                          '主机列表',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: _showAddHostDialog,
                          tooltip: '添加主机',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // 主机列表
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: ListView.builder(
                        itemCount: _hosts.length,
                        itemBuilder: (context, index) {
                          final host = _hosts[index];
                          final isSelected = _selectedHost?.id == host.id;
                      
                      return GestureDetector(
                        onTap: () {
                          if (!_isConnected) {
                            setState(() => _selectedHost = host);
                          }
                        },
                        onDoubleTap: () {
                          if (!_isConnected) {
                            _connectToHost(host);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF323f54) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(
                              host.name,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${host.username}@${host.hostname}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected ? Colors.white70 : Colors.grey,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isConnecting && isSelected)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF007AFF),
                                    ),
                                  ),
                                if (!_isConnecting && !(_isConnected && isSelected))
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow, size: 18),
                                    color: const Color(0xFF32d74b),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: '连接',
                                    onPressed: () => _connectToHost(host),
                                  ),
                                if (_isConnected && isSelected)
                                  IconButton(
                                    icon: const Icon(Icons.stop, size: 18),
                                    color: Colors.red,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: '断开',
                                    onPressed: _disconnect,
                                  ),
                              ],
                            ),
                            onTap: () {
                              setState(() => _selectedHost = host);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
        const SizedBox(height: 12),
                // 文件管理器容器
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF353535),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // 标题栏
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_outlined, color: Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                '文件',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (_isConnected)
                                IconButton(
                                  icon: const Icon(Icons.upload, size: 16),
                                  color: Colors.white70,
                                  onPressed: _uploadFile,
                                  tooltip: '上传',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              if (_isConnected) const SizedBox(width: 8),
                              if (_isConnected)
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 16),
                                  color: Colors.white70,
                                  onPressed: () => _loadFiles(_currentPath),
                                  tooltip: '刷新',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                        ),
                        // 路径输入框
                        if (_isConnected)
                          Container(
                            height: 32,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            child: TextField(
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '输入路径...',
                                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFF0d0d0d),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              controller: TextEditingController(text: _currentPath),
                              onSubmitted: (value) => _loadFiles(value),
                            ),
                          ),
                        if (_isConnected) const SizedBox(height: 8),
                        // 文件列表
                        Expanded(
                          child: _isConnected
                              ? _isLoadingFiles
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : _files.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                '点击加载文件',
                                                style: TextStyle(color: Colors.grey, fontSize: 12),
                                              ),
                                              const SizedBox(height: 8),
                                              ElevatedButton(
                                                onPressed: () => _loadFiles('~'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF007AFF),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                child: const Text('加载', style: TextStyle(fontSize: 12)),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _files.length,
                                          itemBuilder: (context, index) {
                                            final file = _files[index];
                                            if (file.name.startsWith('.')) return const SizedBox.shrink();
                                            return ListTile(
                                              dense: true,
                                              visualDensity: VisualDensity.compact,
                                              leading: Icon(
                                                file.isDirectory ? Icons.folder : Icons.insert_drive_file_outlined,
                                                color: file.isDirectory ? const Color(0xFF007AFF) : Colors.grey,
                                                size: 18,
                                              ),
                                              title: Text(
                                                file.name,
                                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              trailing: file.isDirectory
                                                  ? null
                                                  : IconButton(
                                                      icon: const Icon(Icons.download, size: 16),
                                                      color: Colors.white70,
                                                      onPressed: () => _downloadFile(file.name),
                                                      tooltip: '下载',
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                    ),
                                              onTap: file.isDirectory
                                                  ? () => _loadFiles('$_currentPath/${file.name}')
                                                  : null,
                                            );
                                          },
                                        )
                              : const Center(
                                  child: Text(
                                    '连接后查看文件',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
      // 主内容区 - 终端
      Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 12, bottom: 12, top: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0d0d0d),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // 工具栏（在终端容器内部）
                  Container(
                    height: 36,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        if (_selectedHost != null)
                          Text(
                            '${_selectedHost!.username}@${_selectedHost!.hostname}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          )
                        else
                          const Text(
                            '选择一个主机开始连接',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  // 终端视图
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, left: 8, right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0d0d0d),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _isConnected
                          ? Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent &&
                                    event.logicalKey == LogicalKeyboardKey.keyF &&
                                    HardwareKeyboard.instance.isMetaPressed) {
                                  setState(() => _isSearching = !_isSearching);
                                  if (_isSearching) {
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      _searchFocusNode.requestFocus();
                                    });
                                  }
                                  return KeyEventResult.handled;
                                }
                                if (event is KeyDownEvent &&
                                    event.logicalKey == LogicalKeyboardKey.escape &&
                                    _isSearching) {
                                  _clearSearchHighlights();
                                  setState(() => _isSearching = false);
                                  _searchController.clear();
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: Stack(
                                children: [
                                  ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                                    child: TerminalView(
                                      _terminal,
                                      controller: _terminalController,
                                      scrollController: _terminalScrollController,
                                      autofocus: true,
                                      alwaysShowCursor: true,
                                      theme: const TerminalTheme(
                                        cursor: Color(0xFFFFFFFF),
                                        selection: Color(0x80FFFFFF),
                                        foreground: Color(0xFFFFFFFF),
                                        background: Color(0xFF0d0d0d),
                                        black: Color(0xFF000000),
                                        white: Color(0xFFFFFFFF),
                                        red: Color(0xFFFF5555),
                                        green: Color(0xFF50FA7B),
                                        yellow: Color(0xFFF1FA8C),
                                        blue: Color(0xFF6272A4),
                                        magenta: Color(0xFFFF79C6),
                                        cyan: Color(0xFF8BE9FD),
                                        brightBlack: Color(0xFF6272A4),
                                        brightWhite: Color(0xFFFFFFFF),
                                        brightRed: Color(0xFFFF6E6E),
                                        brightGreen: Color(0xFF69FF94),
                                        brightYellow: Color(0xFFFFFFA5),
                                        brightBlue: Color(0xFFD6ACFF),
                                        brightMagenta: Color(0xFFFF92DF),
                                        brightCyan: Color(0xFFA4FFFF),
                                        searchHitBackground: Color(0xFFFFFF00),
                                        searchHitBackgroundCurrent: Color(0xFFFF6600),
                                        searchHitForeground: Color(0xFF000000),
                                      ),
                                      textStyle: const TerminalStyle(
                                        fontSize: 14,
                                        fontFamily: 'Menlo',
                                      ),
                                    ),
                                  ),
                                  // 搜索框
                                  if (_isSearching)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 280,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2d2d2d),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: _searchController,
                                                focusNode: _searchFocusNode,
                                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                                decoration: const InputDecoration(
                                                  hintText: '搜索...',
                                                  hintStyle: TextStyle(color: Colors.grey),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                                onChanged: (value) {
                                                  _searchTerminal(value);
                                                },
                                                onSubmitted: (_) {
                                                  _nextMatch();
                                                  _searchFocusNode.requestFocus();
                                                },
                                              ),
                                            ),
                                            if (_searchMatchLines.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                child: Text(
                                                  '${_currentMatchIndex + 1}/${_searchMatchLines.length}',
                                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                ),
                                              ),
                                            GestureDetector(
                                              onTap: _prevMatch,
                                              child: const Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 20),
                                            ),
                                            GestureDetector(
                                              onTap: _nextMatch,
                                              child: const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
                                            ),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTap: () {
                                                _clearSearchHighlights();
                                                setState(() => _isSearching = false);
                                                _searchController.clear();
                                              },
                                              child: const Icon(Icons.close, color: Colors.grey, size: 18),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : _selectedHost != null
                              ? _buildHostDetailPanel()
                              : const Center(
                                  child: Text(
                                    '选择一个主机查看详情\n双击主机开始连接',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, height: 1.5),
                                  ),
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
            ),
          // 底部进度条
          if (_isTransferring)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: const Color(0xFF1e1e1e),
                  child: Row(
                    children: [
                      Text(
                        _transferMessage,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '${(_transferProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                LinearProgressIndicator(
                  value: _transferProgress,
                  backgroundColor: const Color(0xFF333333),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                  minHeight: 3,
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sshService.disconnect();
    super.dispose();
  }
}
