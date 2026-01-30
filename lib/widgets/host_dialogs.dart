import 'package:flutter/material.dart';
import '../models/host.dart';
import '../l10n/app_localizations.dart';
import '../services/storage_service.dart';

/// 主机对话框工具类
class HostDialogs {
  /// 显示添加主机对话框
  static void showAddHostDialog({
    required BuildContext context,
    required StorageService storageService,
    required InputDecoration Function(String hint) inputDecoration,
    required VoidCallback onHostAdded,
  }) {
    final nameController = TextEditingController();
    final hostnameController = TextEditingController();
    final portController = TextEditingController(text: '22');
    final usernameController = TextEditingController(text: 'root');
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
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
                  Text(
                    l10n.addHost,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 名称
                  Text(l10n.hostName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration('My Server'),
                  ),
                  const SizedBox(height: 16),
                  
                  // 主机地址
                  Text(l10n.hostname, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hostnameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration('192.168.1.100'),
                  ),
                  const SizedBox(height: 16),
                  
                  // 端口和用户名 - 同一行
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.port, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: portController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: inputDecoration('22'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.username, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: usernameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: inputDecoration('root'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 密码
                  Text(l10n.password, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: inputDecoration(l10n.optional),
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
                        child: Text(obscurePassword ? l10n.show : l10n.hide),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // 按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(l10n.cancel, style: const TextStyle(fontSize: 15)),
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
                          await storageService.addHost(host);
                          if (passwordController.text.isNotEmpty) {
                            await storageService.savePassword(host.id, passwordController.text);
                          }
                          onHostAdded();
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(l10n.save, style: const TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 显示编辑主机对话框
  static void showEditHostDialog({
    required BuildContext context,
    required Host host,
    required InputDecoration Function(String hint) inputDecoration,
    required Future<void> Function(Host, String, String, int, String, String?) onUpdate,
  }) {
    final nameController = TextEditingController(text: host.name);
    final hostnameController = TextEditingController(text: host.hostname);
    final portController = TextEditingController(text: host.port.toString());
    final usernameController = TextEditingController(text: host.username);
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
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
                  Text(
                    l10n.editHost,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 名称
                  Text(l10n.hostName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration(l10n.serverName),
                  ),
                  const SizedBox(height: 16),
          
                  // 主机地址
                  Text(l10n.hostname, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hostnameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration(l10n.ipOrDomain),
                  ),
                  const SizedBox(height: 16),
          
                  // 端口和用户名
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.port, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: portController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration: inputDecoration('22'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.username, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: usernameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: inputDecoration('root'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
          
                  // 密码
                  Text(l10n.passwordKeepEmpty, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: inputDecoration(l10n.newPassword).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await onUpdate(
                    host,
                    nameController.text,
                    hostnameController.text,
                    int.tryParse(portController.text) ?? 22,
                    usernameController.text,
                    passwordController.text.isEmpty ? null : passwordController.text,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }
}
