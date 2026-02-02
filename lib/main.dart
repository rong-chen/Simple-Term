import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:xterm/xterm.dart';
import 'package:file_picker/file_picker.dart';
import 'models/host.dart';
import 'models/group.dart';
import 'models/session.dart';
import 'models/transfer_task.dart';
import 'services/storage_service.dart';
import 'services/transfer_service.dart';
import 'services/update_service.dart';
import 'l10n/app_localizations.dart';
import 'widgets/transfer_panel.dart';
import 'widgets/host_detail_panel.dart';
import 'widgets/connected_shimmer.dart';
import 'widgets/host_dialogs.dart';
import 'widgets/file_browser_panel.dart';
import 'widgets/host_list_panel.dart';
import 'widgets/terminal_panel.dart';

void main() {
  runApp(const SimpleTermApp());
}

class SimpleTermApp extends StatefulWidget {
  const SimpleTermApp({super.key});

  @override
  State<SimpleTermApp> createState() => SimpleTermAppState();
  
  /// 全局访问语言切换
  static SimpleTermAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<SimpleTermAppState>();
  }
}

class SimpleTermAppState extends State<SimpleTermApp> {
  final StorageService _storageService = StorageService();
  Locale _locale = const Locale('zh', 'CN');
  
  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _setupLanguageChannel();
  }
  
  /// 加载保存的语言偏好
  Future<void> _loadLanguage() async {
    final languageCode = await _storageService.getLanguage();
    if (languageCode != null) {
      setState(() {
        _locale = languageCode == 'en' ? const Locale('en', 'US') : const Locale('zh', 'CN');
      });
    }
  }
  
  /// 设置语言切换通道
  void _setupLanguageChannel() {
    const channel = MethodChannel('com.simpleterm/menu');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'setLanguage') {
        final languageCode = call.arguments as String;
        await setLocale(languageCode == 'en' ? const Locale('en', 'US') : const Locale('zh', 'CN'));
      }
    });
  }
  
  /// 切换语言
  Future<void> setLocale(Locale locale) async {
    await _storageService.saveLanguage(locale.languageCode);
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Term',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  
  List<Host> _hosts = [];
  List<HostGroup> _groups = [];  // 分组列表
  Host? _selectedHost;
  
  // 多会话管理
  final Map<String, TerminalSession> _sessions = {};
  String? _activeSessionId;
  
  // 便捷访问当前活动会话
  TerminalSession? get _activeSession => _activeSessionId != null ? _sessions[_activeSessionId] : null;
  Terminal? get _activeTerminal => _activeSession?.terminal;
  bool get _isConnected => _activeSession?.isConnected ?? false;
  bool get _isSftpConnected => _activeSession?.isSftpConnected ?? false;
  bool get _isConnecting => _activeSession?.isConnecting ?? false;
  
  // 便捷访问当前会话的文件状态
  List<SftpFileInfo> get _files => _activeSession?.files ?? [];
  String get _currentPath => _activeSession?.currentPath ?? '~';
  bool get _isLoadingFiles => _activeSession?.isLoadingFiles ?? false;
  
  
  // 传输进度
  bool _isTransferring = false;
  String _transferMessage = '';
  double _transferProgress = 0.0;
  List<TransferTask> _transferTasks = [];  // 全局传输任务列表
  bool _showTransferPanel = false;  // 传输面板展开状态
  
  // 终端控制器（用于搜索高亮）
  late TerminalController _terminalController;
  
  // 搜索
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<dynamic> _searchHighlights = [];  // 存储搜索高亮
  List<int> _searchMatchLines = [];  // 存储匹配的行号
  int _currentMatchIndex = -1;  // 当前匹配索引
  final ScrollController _terminalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _terminalController = TerminalController();
    _loadHosts();
    _setupMenuChannel();
    _initUpdateService();
  }
  
  /// 初始化自动更新服务
  void _initUpdateService() {
    UpdateService.init();
  }
  
  /// 设置系统菜单通道
  void _setupMenuChannel() {
    const channel = MethodChannel('com.simpleterm/menu');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'clearAllData') {
        _showClearDataDialog();
      } else if (call.method == 'setLanguage') {
        final languageCode = call.arguments as String;
        final appState = SimpleTermApp.of(context);
        appState?.setLocale(
          languageCode == 'en' ? const Locale('en', 'US') : const Locale('zh', 'CN'),
        );
      } else if (call.method == 'checkForUpdates') {
        UpdateService.checkForUpdates();
      }
    });
  }
  
  /// 显示清除数据确认对话框
  void _showClearDataDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.clearAllData, style: const TextStyle(color: Colors.white)),
        content: Text(
          l10n.clearAllDataMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              // 断开所有连接
              for (final session in _sessions.values) {
                await session.dispose();
              }
              _sessions.clear();
              
              // 清除存储的数据
              await _storageService.clearAllData();
              
              setState(() {
                _hosts = [];
                _selectedHost = null;
                _activeSessionId = null;
                // 文件列表现在从 session 获取，不需要手动清空
              });
              
              Navigator.pop(context);
              _showSuccess(l10n.allDataCleared);
            },
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }

  Future<void> _loadHosts() async {
    final hosts = await _storageService.getHosts();
    final groups = await _storageService.getGroups();
    setState(() {
      _hosts = hosts;
      _groups = groups;
    });
    // 加载持久化的传输任务
    await _loadTransferTasks();
  }

  /// 加载持久化的传输任务
  Future<void> _loadTransferTasks() async {
    final tasksJson = await _storageService.getTransferTasks();
    if (tasksJson.isNotEmpty) {
      setState(() {
        _transferTasks = tasksJson.map((json) => TransferTask.fromJson(json)).toList();
      });
    }
  }

  /// 保存传输任务（仅保存失败/取消的任务）
  Future<void> _saveTransferTasks() async {
    final tasksToSave = _transferTasks
        .where((t) => t.isFailed || t.status == TransferStatus.cancelled)
        .map((t) => t.toJson())
        .toList();
    await _storageService.saveTransferTasks(tasksToSave);
  }

  /// 检查主机是否已连接
  bool _isHostConnected(String hostId) => _sessions[hostId]?.isConnected ?? false;
  
  /// 检查主机是否正在连接
  bool _isHostConnecting(String hostId) => _sessions[hostId]?.isConnecting ?? false;

  /// 连接到主机（支持多会话）
  Future<void> _connectToHost(Host host) async {
    // 如果已经连接，直接切换到该会话
    if (_isHostConnected(host.id)) {
      _switchToSession(host.id);
      return;
    }

    // 如果正在连接，忽略重复点击
    if (_isHostConnecting(host.id)) {
      return;
    }

    // 创建或获取会话
    var session = _sessions[host.id];
    if (session == null) {
      session = TerminalSession(hostId: host.id);
      _sessions[host.id] = session;
    }
    
    setState(() {
      session!.isConnecting = true;
      _activeSessionId = host.id;
      _selectedHost = host;
    });
    
    try {
      // 根据认证类型获取凭据
      String? password;
      if (host.authType == AuthType.password) {
        password = await _storageService.getPassword(host.id);
        if (password == null) {
          _showPasswordDialog(host);
          setState(() => session!.isConnecting = false);
          return;
        }
      }
      // 密钥认证时 password 为 null，ssh_service 会使用 privateKeyContent

      // 使用终端的实际尺寸连接（如果可用）
      final termWidth = session.terminal.viewWidth;
      final termHeight = session.terminal.viewHeight;
      await session.sshService.connect(host, password, width: termWidth, height: termHeight);
      
      // 设置空闲断线回调
      session.sshService.onIdleDisconnect = () {
        _onSessionDisconnected(host.id);
      };
      
      // 设置远程断线回调（服务器主动断开、网络中断等）
      session.sshService.onDisconnected = () {
        _onSessionDisconnected(host.id);
      };
      
      // 监听输出（包含错误和完成事件以检测断线）
      session.outputSubscription = session.sshService.output.listen(
        (data) {
          session!.terminal.write(data);
        },
        onError: (error) {
          // 输出流出错，连接可能已断开
          _onSessionDisconnected(host.id);
        },
        onDone: () {
          // 输出流结束，连接已断开
          _onSessionDisconnected(host.id);
        },
      );

      // 监听终端输入
      session.terminal.onOutput = (data) {
        session!.sshService.write(data);
      };

      // 监听终端尺寸变化
      session.terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        session!.sshService.resize(width, height);
      };

      setState(() {
        session!.isConnecting = false;
        _selectedHost = host;
      });
      
      // 等待 UI 渲染完成后，同步实际的终端尺寸到远程服务器
      // 使用延迟确保 TerminalView 已完成布局计算
      Future.delayed(const Duration(milliseconds: 300), () {
        if (session == null || !session.isConnected) return;
        final actualWidth = session.terminal.viewWidth;
        final actualHeight = session.terminal.viewHeight;
        session.sshService.resize(actualWidth, actualHeight);
      });
      
      // SSH 连接成功后，自动加载 SFTP 文件列表
      _loadFilesForSession(session, host, password);
    } catch (e) {
      // 认证失败，清理会话
      _sessions.remove(host.id);
      setState(() {
        _activeSessionId = null;
      });
      final l10n = AppLocalizations.of(context);
      _showError('${l10n.connectionFailed}: $e');
    }
  }

  /// 切换到指定会话
  void _switchToSession(String hostId) {
    if (_sessions.containsKey(hostId)) {
      setState(() {
        _activeSessionId = hostId;
        _selectedHost = _hosts.firstWhere((h) => h.id == hostId, orElse: () => _selectedHost!);
        // 文件列表现在从 session 获取，不需要手动清空
      });
    }
  }

  /// 会话断线回调（防止重复调用）
  void _onSessionDisconnected(String hostId) {
    // 防止重复调用：检查会话是否还存在
    if (!_sessions.containsKey(hostId)) return;
    
    setState(() {
      _sessions.remove(hostId);
      if (_activeSessionId == hostId) {
        // 切换到另一个活动会话，或清空
        _activeSessionId = _sessions.keys.isNotEmpty ? _sessions.keys.first : null;
        // 文件列表现在从 session 获取，不需要手动清空
      }
    });
  }

  /// 断开当前活动会话
  Future<void> _disconnect() async {
    if (_activeSessionId == null) return;
    await _disconnectHost(_activeSessionId!);
  }

  /// 断开指定主机的连接
  Future<void> _disconnectHost(String hostId) async {
    // 检查是否正在传输
    if (_isTransferring && _activeSessionId == hostId) {
      final confirmed = await _showTransferWarningDialog();
      if (!confirmed) return;
    }
    
    final session = _sessions[hostId];
    if (session != null) {
      await session.dispose();
      _sessions.remove(hostId);
    }
    
    setState(() {
      // 如果断开的是当前活动会话，切换到另一个
      if (_activeSessionId == hostId) {
        _activeSessionId = _sessions.keys.isNotEmpty ? _sessions.keys.first : null;
        // 文件列表现在从 session 获取，不需要手动清空
      }
    });
  }

  /// 显示传输中警告对话框
  Future<bool> _showTransferWarningDialog() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.transferInProgress, style: const TextStyle(color: Colors.white)),
        content: Text(
          l10n.transferContinueInBackground,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.disconnect),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _loadFiles(String path) async {
    if (_selectedHost == null || _activeSession == null) return;
    
    setState(() => _activeSession!.isLoadingFiles = true);
    
    try {
      // 只有密码认证才需要获取密码
      String? password;
      if (_selectedHost!.authType == AuthType.password) {
        password = await _storageService.getPassword(_selectedHost!.id);
        if (password == null) {
          setState(() => _activeSession!.isLoadingFiles = false);
          return;
        }
      }
      
      final files = await _activeSession!.sftpService.listDirectory(_selectedHost!, password, path);
      // 排序：文件夹在前，然后按名称排序
      files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.compareTo(b.name);
      });
      
      setState(() {
        _activeSession!.files = files;
        _activeSession!.currentPath = path;
        _activeSession!.isLoadingFiles = false;
        _activeSession!.isSftpConnected = true;  // SFTP 已连接
      });
    } catch (e) {
      setState(() => _activeSession!.isLoadingFiles = false);
      final l10n = AppLocalizations.of(context);
      _showError('${l10n.loadFilesFailed}: $e');
    }
  }

  /// SSH 连接后自动加载 SFTP 文件列表
  Future<void> _loadFilesForSession(TerminalSession session, Host host, String? password) async {
    setState(() => session.isLoadingFiles = true);
    
    try {
      final files = await session.sftpService.listDirectory(host, password, '~');
      files.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.compareTo(b.name);
      });
      
      setState(() {
        session.files = files;
        session.currentPath = '~';
        session.isLoadingFiles = false;
        session.isSftpConnected = true;  // SFTP 已连接
      });
    } catch (e) {
      setState(() => session.isLoadingFiles = false);
      // SFTP 连接失败，不显示错误（SSH 仍可用）
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedHost == null) return;
    
    // 如果正在传输，提示用户等待
    if (_isTransferring) {
      final l10n = AppLocalizations.of(context);
      _showError(l10n.waitForTransfer);
      return;
    }
    
    // 启用多文件选择
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    
    // 仅密码认证需要密码，密钥认证可以没有密码
    String? password;
    if (_selectedHost!.authType == AuthType.password) {
      password = await _storageService.getPassword(_selectedHost!.id);
      if (password == null) return;
    }
    
    // 处理远程路径
    String remotePath = _currentPath;
    if (remotePath == '~' || remotePath.startsWith('~/')) {
      final homePath = _selectedHost!.username == 'root' ? '/root' : '/home/${_selectedHost!.username}';
      remotePath = remotePath == '~' ? homePath : remotePath.replaceFirst('~', homePath);
    }
    
    // 创建传输任务列表
    final hostEndpoint = '${_selectedHost!.username}@${_selectedHost!.hostname}:${_selectedHost!.port}';
    final tasks = <TransferTask>[];
    for (final file in result.files) {
      if (file.path == null) continue;
      final localFile = File(file.path!);
      final fileSize = await localFile.length();
      tasks.add(TransferTask(
        localPath: file.path!,
        remotePath: '$remotePath/${file.name}',
        fileName: file.name,
        totalSize: fileSize,
        host: _selectedHost!,
        hostName: _selectedHost!.name,
        hostEndpoint: hostEndpoint,
      ));
    }
    
    if (tasks.isEmpty) return;
    
    final l10n = AppLocalizations.of(context);
    int completedCount = 0;
    
    setState(() {
      _isTransferring = true;
      _transferTasks.addAll(tasks);  // 添加到全局任务列表
      _transferMessage = l10n.uploadProgressText(1, tasks.length);
      _transferProgress = 0.0;
    });
    
    // 上传期间暂停空闲计时器
    _activeSession?.sshService.pauseIdleTimer();
    
    try {
      await _activeSession!.transferService.uploadFiles(
        host: _selectedHost!,
        password: password,
        tasks: tasks,
        onTaskUpdate: (task) {
          setState(() {
            // 更新当前任务信息
            if (task.status == TransferStatus.uploading) {
              _transferMessage = '${l10n.uploading}: ${task.fileName}';
              _transferProgress = task.progress;
            } else if (task.status == TransferStatus.verifying) {
              _transferMessage = '${l10n.verifyingMd5}: ${task.fileName}';
            } else if (task.status == TransferStatus.done) {
              completedCount++;
              _transferMessage = l10n.uploadProgressText(completedCount, tasks.length);
              // 成功完成后自动从列表移除
              _transferTasks.remove(task);
            }
          });
        },
      );
      
      setState(() => _isTransferring = false);
      _loadFiles(_currentPath);
      
      // 统计成功和失败数
      final successCount = tasks.where((t) => t.isComplete).length;
      final failCount = tasks.where((t) => t.isFailed).length;
      
      if (failCount == 0) {
        _showSuccess('${l10n.uploadSuccess}: $successCount ${l10n.files}');
      } else {
        _showError('${l10n.uploadFailed}: $failCount / ${tasks.length}');
      }
      
      // 保存失败/取消的任务
      _saveTransferTasks();
    } catch (e) {
      setState(() => _isTransferring = false);
      _showError('${l10n.uploadFailed}: $e');
      _saveTransferTasks();  // 保存失败的任务
    } finally {
      // 上传完成后恢复空闲计时器
      _activeSession?.sshService.resetIdleTimer();
    }
  }

  /// 拖放上传文件
  Future<void> _uploadDroppedFiles(List<String> filePaths) async {
    if (_selectedHost == null || filePaths.isEmpty) return;
    
    // 如果正在传输，提示用户等待
    if (_isTransferring) {
      final l10n = AppLocalizations.of(context);
      _showError(l10n.waitForTransfer);
      return;
    }
    
    // 仅密码认证需要密码，密钥认证可以没有密码
    String? password;
    if (_selectedHost!.authType == AuthType.password) {
      password = await _storageService.getPassword(_selectedHost!.id);
      if (password == null) return;
    }
    
    // 处理远程路径
    String remotePath = _currentPath;
    if (remotePath == '~' || remotePath.startsWith('~/')) {
      final homePath = _selectedHost!.username == 'root' ? '/root' : '/home/${_selectedHost!.username}';
      remotePath = remotePath == '~' ? homePath : remotePath.replaceFirst('~', homePath);
    }
    
    // 创建传输任务列表
    final hostEndpoint = '${_selectedHost!.username}@${_selectedHost!.hostname}:${_selectedHost!.port}';
    final tasks = <TransferTask>[];
    for (final path in filePaths) {
      final localFile = File(path);
      if (!await localFile.exists()) continue;
      final fileSize = await localFile.length();
      final fileName = path.split('/').last;
      tasks.add(TransferTask(
        localPath: path,
        remotePath: '$remotePath/$fileName',
        fileName: fileName,
        totalSize: fileSize,
        host: _selectedHost!,
        hostName: _selectedHost!.name,
        hostEndpoint: hostEndpoint,
      ));
    }
    
    if (tasks.isEmpty) return;
    
    final l10n = AppLocalizations.of(context);
    int completedCount = 0;
    
    setState(() {
      _isTransferring = true;
      _transferTasks.addAll(tasks);
      _transferMessage = l10n.uploadProgressText(1, tasks.length);
      _transferProgress = 0.0;
    });
    
    _activeSession?.sshService.pauseIdleTimer();
    
    try {
      await _activeSession!.transferService.uploadFiles(
        host: _selectedHost!,
        password: password,
        tasks: tasks,
        onTaskUpdate: (task) {
          setState(() {
            if (task.status == TransferStatus.uploading) {
              _transferMessage = '${l10n.uploading}: ${task.fileName}';
              _transferProgress = task.progress;
            } else if (task.status == TransferStatus.verifying) {
              _transferMessage = '${l10n.verifyingMd5}: ${task.fileName}';
            } else if (task.status == TransferStatus.done) {
              completedCount++;
              _transferMessage = l10n.uploadProgressText(completedCount, tasks.length);
              _transferTasks.remove(task);
            }
          });
        },
      );
      
      setState(() => _isTransferring = false);
      _loadFiles(_currentPath);
      
      final successCount = tasks.where((t) => t.isComplete).length;
      final failCount = tasks.where((t) => t.isFailed).length;
      
      if (failCount == 0) {
        _showSuccess('${l10n.uploadSuccess}: $successCount ${l10n.files}');
      } else {
        _showError('${l10n.uploadFailed}: $failCount / ${tasks.length}');
      }
      
      _saveTransferTasks();
    } catch (e) {
      setState(() => _isTransferring = false);
      _showError('${l10n.uploadFailed}: $e');
      _saveTransferTasks();
    } finally {
      _activeSession?.sshService.resetIdleTimer();
    }
  }

  /// 删除远程文件/文件夹
  Future<void> _deleteRemoteFile(String path, bool isDirectory) async {
    if (_selectedHost == null) return;
    
    final l10n = AppLocalizations.of(context);
    String? password;
    if (_selectedHost!.authType == AuthType.password) {
      password = await _storageService.getPassword(_selectedHost!.id);
    }
    
    try {
      if (isDirectory) {
        await _activeSession?.sftpService.deleteDirectory(_selectedHost!, password, path);
      } else {
        await _activeSession?.sftpService.deleteFile(_selectedHost!, password, path);
      }
      _loadFiles(_currentPath);
      _showSuccess(l10n.fileDeleted);
    } catch (e) {
      _showError('${l10n.deleteFailed}: $e');
    }
  }

  /// 创建远程文件夹
  Future<void> _createRemoteFolder(String path) async {
    if (_selectedHost == null) return;
    
    final l10n = AppLocalizations.of(context);
    String? password;
    if (_selectedHost!.authType == AuthType.password) {
      password = await _storageService.getPassword(_selectedHost!.id);
    }
    
    try {
      await _activeSession?.sftpService.createDirectory(_selectedHost!, password, path);
      _loadFiles(_currentPath);
      _showSuccess(l10n.folderCreated);
    } catch (e) {
      _showError('${l10n.operationFailed}: $e');
    }
  }

  /// 重命名远程文件/文件夹
  Future<void> _renameRemoteFile(String oldPath, String newName) async {
    if (_selectedHost == null) return;
    
    final l10n = AppLocalizations.of(context);
    String? password;
    if (_selectedHost!.authType == AuthType.password) {
      password = await _storageService.getPassword(_selectedHost!.id);
    }
    
    // 构建新路径
    final parts = oldPath.split('/');
    parts[parts.length - 1] = newName;
    final newPath = parts.join('/');
    
    try {
      await _activeSession?.sftpService.rename(_selectedHost!, password, oldPath, newPath);
      _loadFiles(_currentPath);
      _showSuccess(l10n.renamed);
    } catch (e) {
      _showError('${l10n.operationFailed}: $e');
    }
  }

  Future<void> _downloadFile(String fileName) async {
    if (_selectedHost == null) return;
    
    // 如果正在传输，提示用户等待
    if (_isTransferring) {
      final l10n = AppLocalizations.of(context);
      _showError(l10n.waitForTransfer);
      return;
    }
    
    final downloadDir = await FilePicker.platform.getDirectoryPath();
    if (downloadDir == null) return;
    
    final l10n = AppLocalizations.of(context);
    // 显示底部进度条
    setState(() {
      _isTransferring = true;
      _transferMessage = '${l10n.downloading}: $fileName';
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
      
      await _activeSession!.sftpService.downloadFile(
        _selectedHost!,
        password,
        '$remotePath/$fileName',
        '$downloadDir/$fileName',
        onProgress: (progress) {
          setState(() => _transferProgress = progress);
        },
      );
      
      setState(() => _isTransferring = false);
      final l10n2 = AppLocalizations.of(context);
      _showSuccess('${l10n2.downloadSuccess}: $fileName');
    } catch (e) {
      setState(() => _isTransferring = false);
      final l10n2 = AppLocalizations.of(context);
      _showError('${l10n2.downloadFailed}: $e');
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
    if (query.isEmpty || _activeTerminal == null) return;
    
    final buffer = _activeTerminal!.buffer;
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Text(l10n.enterPassword),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.sshPassword,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _storageService.savePassword(host.id, controller.text);
              _connectToHost(host);
            },
            child: Text(l10n.connect),
          ),
        ],
      ),
    );
  }

  /// 显示主机右键菜单
  void _showHostContextMenu(BuildContext context, Offset position, Host host, bool isConnected, List<HostGroup> groups) async {
    final l10n = AppLocalizations.of(context);
    
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: const Color(0xFF2d2d2d),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 200),
      items: [
        PopupMenuItem(
          value: 'edit',
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit, size: 14, color: Colors.white70),
              const SizedBox(width: 8),
              Text(l10n.edit, style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        // 移动到分组
        PopupMenuItem(
          enabled: false,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.drive_file_move_outline, size: 14, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.moveTo, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const Icon(Icons.arrow_right, size: 14, color: Colors.white70),
            ],
          ),
        ),
        // 默认分组选项
        PopupMenuItem(
          value: 'move_default',
          height: 28,
          padding: const EdgeInsets.only(left: 32, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_special, size: 12, 
                color: host.groupId == null ? const Color(0xFF007AFF) : Colors.white54),
              const SizedBox(width: 6),
              Text(l10n.defaultGroup, 
                style: TextStyle(
                  color: host.groupId == null ? const Color(0xFF007AFF) : Colors.white70, 
                  fontSize: 12,
                ),
              ),
              if (host.groupId == null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check, size: 12, color: Color(0xFF007AFF)),
              ],
            ],
          ),
        ),
        // 自定义分组选项
        ...groups.map((g) => PopupMenuItem(
          value: 'move_${g.id}',
          height: 28,
          padding: const EdgeInsets.only(left: 32, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder, size: 12, 
                color: host.groupId == g.id ? const Color(0xFF007AFF) : Colors.white54),
              const SizedBox(width: 6),
              Text(g.name, 
                style: TextStyle(
                  color: host.groupId == g.id ? const Color(0xFF007AFF) : Colors.white70, 
                  fontSize: 12,
                ),
              ),
              if (host.groupId == g.id) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check, size: 12, color: Color(0xFF007AFF)),
              ],
            ],
          ),
        )),
        if (!isConnected)
          PopupMenuItem(
            value: 'delete',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete, size: 14, color: Colors.red),
                const SizedBox(width: 8),
                Text(l10n.delete, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ),
          ),
      ],
    );
    
    if (result == 'edit') {
      _showEditHostDialog(host);
    } else if (result == 'delete') {
      _confirmDeleteHost(host);
    } else if (result == 'move_default') {
      _moveHostToGroup(host, null);
    } else if (result != null && result.startsWith('move_')) {
      final groupId = result.substring(5);
      _moveHostToGroup(host, groupId);
    }
  }
  
  /// 确认删除主机
  void _confirmDeleteHost(Host host) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.confirmDelete, style: const TextStyle(color: Colors.white)),
        content: Text(
          l10n.deleteHostMessage,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _storageService.deleteHost(host.id);
              await _loadHosts();
              if (_selectedHost?.id == host.id) {
                setState(() => _selectedHost = null);
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  /// 显示编辑主机对话框（使用抽离的组件）
  void _showEditHostDialog(Host host) {
    HostDialogs.showEditHostDialog(
      context: context,
      host: host,
      inputDecoration: _inputDecoration,
      onUpdate: _updateHost,
      groups: _groups,
    );
  }

  /// 显示添加主机对话框（使用抽离的组件）
  void _showAddHostDialog() {
    HostDialogs.showAddHostDialog(
      context: context,
      storageService: _storageService,
      groups: _groups,
      inputDecoration: _inputDecoration,
      onHostAdded: _loadHosts,
    );
  }
  
  /// 显示新建分组对话框
  void _showAddGroupDialog() async {
    final group = await HostDialogs.showNewGroupDialog(
      context: context,
      inputDecoration: _inputDecoration,
    );
    if (group != null) {
      await _storageService.addGroup(group);
      await _loadHosts();
    }
  }
  
  /// 显示编辑分组对话框
  void _showEditGroupDialog(HostGroup group) async {
    final updatedGroup = await HostDialogs.showEditGroupDialog(
      context: context,
      group: group,
      inputDecoration: _inputDecoration,
    );
    if (updatedGroup != null) {
      await _storageService.updateGroup(updatedGroup);
      await _loadHosts();
    }
  }
  
  /// 删除分组
  void _deleteGroup(HostGroup group) async {
    final confirmed = await HostDialogs.showDeleteGroupDialog(
      context: context,
      group: group,
    );
    if (confirmed) {
      await _storageService.deleteGroup(group.id);
      await _loadHosts();
    }
  }
  
  /// 移动主机到指定分组
  void _moveHostToGroup(Host host, String? groupId) async {
    final updatedHost = host.copyWith(groupId: groupId);
    await _storageService.updateHost(updatedHost);
    await _loadHosts();
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Text(l10n.confirmDelete),
        content: Text(l10n.confirmDeleteHost(host.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
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
      _showSuccess(l10n.hostDeleted);
    }
  }

  Future<void> _updateHost(Host host, String name, String hostname, int port, String username, String? password, AuthType authType, String? privateKeyContent, String? groupId) async {
    final updatedHost = Host(
      id: host.id,
      name: name,
      hostname: hostname,
      port: port,
      username: username,
      authType: authType,
      privateKeyContent: privateKeyContent,
      groupId: groupId,
    );
    await _storageService.updateHost(updatedHost);
    if (password != null && password.isNotEmpty) {
      await _storageService.savePassword(host.id, password);
    }
    await _loadHosts();
    setState(() => _selectedHost = updatedHost);
    _showSuccess(AppLocalizations.of(context).hostUpdated);
  }

  /// 构建传输任务面板（使用抽离的组件）
  Widget _buildTransferPanel() {
    return TransferPanel(
      tasks: _transferTasks,
      onClose: () => setState(() => _showTransferPanel = false),
      onCancel: _cancelTransfer,
      onDelete: _deleteTransferAndRemoteFile,
      onResume: _resumeTransfer,
    );
  }


  /// 取消传输（保留远程文件，可续传）
  void _cancelTransfer(TransferTask task) {
    task.cancel();
    setState(() {});
    _saveTransferTasks();  // 持久化保存
  }

  /// 删除传输并删除远程文件
  Future<void> _deleteTransferAndRemoteFile(TransferTask task) async {
    // 先取消传输（如果正在进行）
    task.cancel();
    
    // 尝试删除远程文件（使用任务保存的主机信息）
    final password = await _storageService.getPassword(task.host.id);
    if (password != null) {
      try {
        // 创建临时的 TransferService 来删除远程文件
        final transferService = TransferService();
        await transferService.deleteRemoteFile(
          host: task.host,
          password: password,
          remotePath: task.remotePath,
        );
      } catch (e) {
        // 显示删除失败提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除远程文件失败: $e')),
          );
        }
      }
    }
    
    // 从列表移除并保存
    setState(() => _transferTasks.remove(task));
    _saveTransferTasks();  // 持久化保存
  }

  /// 继续传输（复用已取消的任务记录）
  Future<void> _resumeTransfer(TransferTask task) async {
    if (_selectedHost == null) return;
    
    final password = await _storageService.getPassword(_selectedHost!.id);
    if (password == null) return;
    
    // 重置任务状态
    task.isCancelled = false;
    task.status = TransferStatus.pending;
    task.errorMessage = null;
    setState(() {});
    
    // 暂停空闲计时器
    _activeSession?.sshService.pauseIdleTimer();
    
    try {
      await _activeSession!.transferService.uploadFiles(
        host: _selectedHost!,
        password: password,
        tasks: [task],
        onTaskUpdate: (t) => setState(() {}),
      );
    } catch (e) {
      task.status = TransferStatus.failed;
      task.errorMessage = e.toString();
      setState(() {});
    } finally {
      _activeSession?.sshService.resetIdleTimer();
    }
  }

  Widget _buildHostDetailPanel() {
    return HostDetailPanel(
      host: _selectedHost,
      onUpdate: _updateHost,
      onDelete: _deleteHost,
      inputDecoration: _inputDecoration,
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
                      // 主机列表容器（使用抽离的组件）
                      Expanded(
                        flex: 1,
                        child: HostListPanel(
                          hosts: _hosts,
                          groups: _groups,
                          selectedHost: _selectedHost,
                          activeSessionId: _activeSessionId,
                          isHostConnected: _isHostConnected,
                          isHostConnecting: _isHostConnecting,
                          onAddHost: _showAddHostDialog,
                          onAddGroup: _showAddGroupDialog,
                          onConnect: _connectToHost,
                          onDisconnect: _disconnectHost,
                          onSwitchSession: _switchToSession,
                          onSelectHost: (host) => setState(() => _selectedHost = host),
                          onShowContextMenu: _showHostContextMenu,
                          onEditGroup: _showEditGroupDialog,
                          onDeleteGroup: _deleteGroup,
                          onMoveHost: _moveHostToGroup,
                          onDataChanged: _loadHosts,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 文件管理器容器（使用抽离的组件）
                      Expanded(
                        flex: 1,
                        child: FileBrowserPanel(
                          isConnected: _isSftpConnected,
                          isLoading: _isLoadingFiles,
                          currentPath: _currentPath,
                          files: _files,
                          onLoadFiles: _loadFiles,
                          onUpload: _uploadFile,
                          onDownload: _downloadFile,
                          onFilesDropped: _uploadDroppedFiles,
                          onDelete: _deleteRemoteFile,
                          onCreateFolder: _createRemoteFolder,
                          onRename: _renameRemoteFile,
                        ),
                      ),
                    ],
                  ),
                ),
                // 主内容区 - 终端（使用抽离的组件）
                Expanded(
                  child: TerminalPanel(
                    selectedHost: _selectedHost,
                    isConnected: _isConnected,
                    activeTerminal: _activeTerminal,
                    terminalController: _terminalController,
                    terminalScrollController: _terminalScrollController,
                    isSearching: _isSearching,
                    searchController: _searchController,
                    searchFocusNode: _searchFocusNode,
                    searchMatchLines: _searchMatchLines,
                    currentMatchIndex: _currentMatchIndex,
                    onToggleSearch: () {
                      setState(() => _isSearching = !_isSearching);
                      if (_isSearching) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _searchFocusNode.requestFocus();
                        });
                      }
                    },
                    onCloseSearch: () {
                      _clearSearchHighlights();
                      setState(() => _isSearching = false);
                      _searchController.clear();
                    },
                    onSearch: _searchTerminal,
                    onNextMatch: _nextMatch,
                    onPrevMatch: _prevMatch,
                  ),
                ),
                // 传输任务面板（右侧可收起）
                if (_showTransferPanel)
                  _buildTransferPanel(),
              ],
            ),
          ),
          // 底部进度条
          if (_isTransferring || _transferTasks.isNotEmpty)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: const Color(0xFF1e1e1e),
                  child: Row(
                    children: [
                      Text(
                        _isTransferring ? _transferMessage : AppLocalizations.of(context).transferTasks,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Spacer(),
                      if (_isTransferring)
                        Text(
                          '${(_transferProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() => _showTransferPanel = !_showTransferPanel),
                        child: Text(
                          AppLocalizations.of(context).viewDetails,
                          style: const TextStyle(color: Color(0xFF007AFF), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isTransferring)
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
    // 清理所有会话
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
    super.dispose();
  }
}
