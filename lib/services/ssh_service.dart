import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../models/host.dart';
import '../models/session.dart';  // SftpFileInfo

/// SSH 服务 - 管理 SSH 连接和终端交互
class SSHService {
  SSHClient? _client;
  SSHSession? _session;
  Timer? _idleTimer;
  
  /// 空闲超时时间（5分钟）
  static const Duration idleTimeout = Duration(minutes: 5);
  
  /// 空闲超时断线回调
  void Function()? onIdleDisconnect;
  
  /// 远程断线回调（服务器主动断开、网络中断等）
  void Function()? onDisconnected;
  
  /// 是否已连接（检查客户端存在且未关闭）
  bool get isConnected => _client != null && !(_client!.isClosed);

  /// 重置空闲计时器（每次有用户操作时调用）
  void resetIdleTimer() {
    _idleTimer?.cancel();
    if (_client != null) {
      _idleTimer = Timer(idleTimeout, () {
        disconnect();
        onIdleDisconnect?.call();
      });
    }
  }

  /// 暂停空闲计时器（文件传输期间调用）
  void pauseIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// 获取私钥内容（优先使用 privateKeyContent，否则从文件读取）
  Future<String?> _getKeyContent(Host host) async {
    // 优先使用直接输入的密钥内容
    if (host.privateKeyContent != null && host.privateKeyContent!.isNotEmpty) {
      return host.privateKeyContent;
    }
    // 否则从文件读取
    if (host.privateKeyPath != null && host.privateKeyPath!.isNotEmpty) {
      final keyFile = File(host.privateKeyPath!);
      if (await keyFile.exists()) {
        return await keyFile.readAsString();
      }
    }
    return null;
  }

  /// 连接到 SSH 服务器
  /// [password] - 密码（密码认证）或私钥密码（密钥认证）
  Future<void> connect(Host host, String? password, {int width = 200, int height = 50}) async {
    final socket = await SSHSocket.connect(host.hostname, host.port);
    
    if (host.authType == AuthType.privateKey) {
      // 密钥认证
      var keyContent = await _getKeyContent(host);
      if (keyContent == null) {
        throw Exception('Private key not found');
      }
      // 标准化换行符（兼容 Windows/Mac/Linux 的 PEM 文件）
      keyContent = keyContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final keypairs = SSHKeyPair.fromPem(keyContent, password);
      
      _client = SSHClient(
        socket,
        username: host.username,
        identities: [...keypairs],
        keepAliveInterval: const Duration(seconds: 30),
      );
    } else {
      // 密码认证
      _client = SSHClient(
        socket,
        username: host.username,
        onPasswordRequest: () => password ?? '',
        keepAliveInterval: const Duration(seconds: 30),
      );
    }
    
    // 启动空闲计时器
    resetIdleTimer();
    
    // 监听连接关闭事件（服务器断开、网络中断等）
    _client!.done.then((_) {
      // 连接已关闭，执行清理和回调
      _handleDisconnected();
    }).catchError((error) {
      // 连接异常关闭
      _handleDisconnected();
    });

    // 创建交互式 shell，显式设置终端类型为 xterm-256color
    _session = await _client!.shell(
      pty: SSHPtyConfig(
        type: 'xterm-256color',
        width: width,
        height: height,
      ),
    );

    // 自动设置 ls 别名为彩色输出
    await Future.delayed(const Duration(milliseconds: 500));
    _session!.write(utf8.encode("alias ls='ls --color=auto'\n"));
  }

  /// 获取输出流
  Stream<String> get output {
    if (_session == null) {
      return const Stream.empty();
    }
    return _session!.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true));
  }

  /// 写入命令
  void write(String data) {
    if (_session != null) {
      _session!.write(utf8.encode(data));
      resetIdleTimer();  // 用户有输入，重置空闲计时器
    }
  }

  /// 调整终端大小
  void resize(int width, int height) {
    _session?.resizeTerminal(width, height);
  }

  /// 断开连接
  Future<void> disconnect() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    _session?.close();
    _client?.close();
    _session = null;
    _client = null;
  }
  
  /// 处理远程断线事件
  void _handleDisconnected() {
    // 避免重复调用（主动断开时 _client 已为 null）
    if (_client == null) return;
    
    _idleTimer?.cancel();
    _idleTimer = null;
    _session = null;
    _client = null;
    
    // 通知上层断线
    onDisconnected?.call();
  }

  /// 创建 SSH 客户端（用于 SFTP 操作）
  Future<SSHClient> _createClient(Host host, String? password) async {
    final socket = await SSHSocket.connect(host.hostname, host.port);
    
    if (host.authType == AuthType.privateKey) {
      var keyContent = await _getKeyContent(host);
      if (keyContent == null) {
        throw Exception('Private key not found');
      }
      // 标准化换行符（兼容 Windows/Mac/Linux 的 PEM 文件）
      keyContent = keyContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final keypairs = SSHKeyPair.fromPem(keyContent, password);
      return SSHClient(socket, username: host.username, identities: [...keypairs]);
    } else {
      return SSHClient(socket, username: host.username, onPasswordRequest: () => password ?? '');
    }
  }

  /// 列出远程目录
  Future<List<SftpFileInfo>> listDirectory(Host host, String? password, String path) async {
    final client = await _createClient(host, password);
    
    try {
      final sftp = await client.sftp();
      
      // 处理 ~ 路径
      String realPath = path;
      if (path == '~' || path.startsWith('~/')) {
        final homePath = host.username == 'root' ? '/root' : '/home/${host.username}';
        realPath = path == '~' ? homePath : path.replaceFirst('~', homePath);
      }
      
      final items = await sftp.listdir(realPath);
      return items.map((item) => SftpFileInfo(
        name: item.filename,
        isDirectory: item.attr.isDirectory,
        size: item.attr.size ?? 0,
      )).toList();
    } finally {
      client.close();
    }
  }

  /// 上传文件（带进度）
  Future<void> uploadFile(Host host, String? password, String localPath, String remotePath, {void Function(double)? onProgress}) async {
    final client = await _createClient(host, password);
    
    try {
      final sftp = await client.sftp();
      final file = await sftp.open(remotePath, mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate);
      final localFile = File(localPath);
      final fileSize = await localFile.length();
      final stream = localFile.openRead();
      
      int offset = 0;
      await for (final chunk in stream) {
        final data = Uint8List.fromList(chunk);
        await file.write(Stream.value(data), offset: offset);
        offset += data.length;
        onProgress?.call(offset / fileSize);
      }
      await file.close();
    } finally {
      client.close();
    }
  }

  /// 下载文件（带进度）
  Future<void> downloadFile(Host host, String? password, String remotePath, String localPath, {void Function(double)? onProgress}) async {
    final client = await _createClient(host, password);
    
    try {
      final sftp = await client.sftp();
      final remoteFile = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
      final stat = await remoteFile.stat();
      final fileSize = stat.size ?? 0;
      
      final localFile = File(localPath);
      final sink = localFile.openWrite();
      
      int downloaded = 0;
      await for (final chunk in remoteFile.read()) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (fileSize > 0) onProgress?.call(downloaded / fileSize);
      }
      await sink.close();
      await remoteFile.close();
    } finally {
      client.close();
    }
  }

  /// 删除文件
  Future<void> deleteFile(Host host, String? password, String path) async {
    final client = await _createClient(host, password);
    try {
      final sftp = await client.sftp();
      final realPath = _resolvePath(host, path);
      await sftp.remove(realPath);
    } finally {
      client.close();
    }
  }

  /// 删除文件夹（递归）
  Future<void> deleteDirectory(Host host, String? password, String path) async {
    final client = await _createClient(host, password);
    try {
      final sftp = await client.sftp();
      final realPath = _resolvePath(host, path);
      // 先删除目录内所有文件和子目录
      await _deleteDirectoryRecursive(sftp, realPath);
    } finally {
      client.close();
    }
  }

  /// 递归删除目录内容
  Future<void> _deleteDirectoryRecursive(SftpClient sftp, String path) async {
    final items = await sftp.listdir(path);
    for (final item in items) {
      if (item.filename == '.' || item.filename == '..') continue;
      final itemPath = '$path/${item.filename}';
      if (item.attr.isDirectory) {
        await _deleteDirectoryRecursive(sftp, itemPath);
      } else {
        await sftp.remove(itemPath);
      }
    }
    await sftp.rmdir(path);
  }

  /// 创建文件夹
  Future<void> createDirectory(Host host, String? password, String path) async {
    final client = await _createClient(host, password);
    try {
      final sftp = await client.sftp();
      final realPath = _resolvePath(host, path);
      await sftp.mkdir(realPath);
    } finally {
      client.close();
    }
  }

  /// 重命名/移动文件或文件夹
  Future<void> rename(Host host, String? password, String oldPath, String newPath) async {
    final client = await _createClient(host, password);
    try {
      final sftp = await client.sftp();
      final realOldPath = _resolvePath(host, oldPath);
      final realNewPath = _resolvePath(host, newPath);
      await sftp.rename(realOldPath, realNewPath);
    } finally {
      client.close();
    }
  }

  /// 解析路径（处理 ~ 符号）
  String _resolvePath(Host host, String path) {
    if (path == '~' || path.startsWith('~/')) {
      final homePath = host.username == 'root' ? '/root' : '/home/${host.username}';
      return path == '~' ? homePath : path.replaceFirst('~', homePath);
    }
    return path;
  }
}
