import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../models/host.dart';

/// SSH 服务 - 管理 SSH 连接和终端交互
class SSHService {
  SSHClient? _client;
  SSHSession? _session;
  
  bool get isConnected => _client != null;

  /// 连接到 SSH 服务器
  Future<void> connect(Host host, String password, {int width = 200, int height = 50}) async {
    final socket = await SSHSocket.connect(host.hostname, host.port);
    
    _client = SSHClient(
      socket,
      username: host.username,
      onPasswordRequest: () => password,
    );

    // 创建交互式 shell
    _session = await _client!.shell(
      pty: SSHPtyConfig(
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
    return _session!.stdout.map((data) => utf8.decode(data));
  }

  /// 写入命令
  void write(String data) {
    if (_session != null) {
      _session!.write(utf8.encode(data));
    }
  }

  /// 调整终端大小
  void resize(int width, int height) {
    _session?.resizeTerminal(width, height);
  }

  /// 断开连接
  Future<void> disconnect() async {
    _session?.close();
    _client?.close();
    _session = null;
    _client = null;
  }

  /// 列出远程目录
  Future<List<SftpFileInfo>> listDirectory(Host host, String password, String path) async {
    final socket = await SSHSocket.connect(host.hostname, host.port);
    final client = SSHClient(
      socket,
      username: host.username,
      onPasswordRequest: () => password,
    );
    
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
  Future<void> uploadFile(Host host, String password, String localPath, String remotePath, {void Function(double)? onProgress}) async {
    final socket = await SSHSocket.connect(host.hostname, host.port);
    final client = SSHClient(
      socket,
      username: host.username,
      onPasswordRequest: () => password,
    );
    
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
  Future<void> downloadFile(Host host, String password, String remotePath, String localPath, {void Function(double)? onProgress}) async {
    final socket = await SSHSocket.connect(host.hostname, host.port);
    final client = SSHClient(
      socket,
      username: host.username,
      onPasswordRequest: () => password,
    );
    
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
}

/// SFTP 文件信息
class SftpFileInfo {
  final String name;
  final bool isDirectory;
  final int size;

  SftpFileInfo({
    required this.name,
    required this.isDirectory,
    required this.size,
  });
}
