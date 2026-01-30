import 'dart:async';
import 'package:xterm/xterm.dart';
import '../services/ssh_service.dart';

/// 终端会话 - 封装单个 SSH 连接的所有状态
class TerminalSession {
  final String hostId;
  final SSHService sshService;
  final Terminal terminal;
  StreamSubscription<String>? outputSubscription;
  bool isConnecting;

  TerminalSession({
    required this.hostId,
    SSHService? sshService,
    Terminal? terminal,
    this.isConnecting = false,
  })  : sshService = sshService ?? SSHService(),
        terminal = terminal ?? Terminal(maxLines: 10000);

  bool get isConnected => sshService.isConnected;

  /// 清理会话资源
  Future<void> dispose() async {
    await outputSubscription?.cancel();
    outputSubscription = null;
    await sshService.disconnect();
  }
}
