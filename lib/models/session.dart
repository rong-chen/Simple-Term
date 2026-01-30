import 'dart:async';
import 'package:xterm/xterm.dart';
import '../services/ssh_service.dart';
import '../services/transfer_service.dart';

/// SFTP 文件信息（从 SSHService 移出，避免循环依赖）
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

/// 终端会话 - 封装单个 SSH 连接的所有状态
class TerminalSession {
  final String hostId;
  final SSHService sshService;          // 终端交互
  final SSHService sftpService;         // 文件浏览（独立连接）
  final TransferService transferService; // 文件传输
  final Terminal terminal;
  StreamSubscription<String>? outputSubscription;
  bool isConnecting;
  
  // SFTP 文件状态（每会话独立）
  List<SftpFileInfo> files = [];
  String currentPath = '~';
  bool isLoadingFiles = false;
  bool isSftpConnected = false;  // SFTP 连接状态

  TerminalSession({
    required this.hostId,
    SSHService? sshService,
    SSHService? sftpService,
    TransferService? transferService,
    Terminal? terminal,
    this.isConnecting = false,
  })  : sshService = sshService ?? SSHService(),
        sftpService = sftpService ?? SSHService(),
        transferService = transferService ?? TransferService(),
        terminal = terminal ?? Terminal(maxLines: 10000);

  bool get isConnected => sshService.isConnected;

  /// 清理会话资源
  Future<void> dispose() async {
    await outputSubscription?.cancel();
    outputSubscription = null;
    await sshService.disconnect();
    files.clear();
    currentPath = '~';
  }
}
