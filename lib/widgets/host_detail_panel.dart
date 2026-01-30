import 'package:flutter/material.dart';
import '../models/host.dart';
import '../l10n/app_localizations.dart';

/// 主机更新回调
typedef HostUpdateCallback = void Function(
  Host host,
  String name,
  String hostname,
  int port,
  String username,
  String? password,
);

/// 主机删除回调
typedef HostDeleteCallback = void Function(Host host);

/// 主机详情编辑面板
class HostDetailPanel extends StatelessWidget {
  final Host? host;
  final HostUpdateCallback onUpdate;
  final HostDeleteCallback onDelete;
  final InputDecoration Function(String hint) inputDecoration;

  const HostDetailPanel({
    super.key,
    required this.host,
    required this.onUpdate,
    required this.onDelete,
    required this.inputDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    if (host == null) {
      return Center(
        child: Text(
          l10n.selectHostToView,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    final currentHost = host!;
    final nameController = TextEditingController(text: currentHost.name);
    final hostnameController = TextEditingController(text: currentHost.hostname);
    final portController = TextEditingController(text: currentHost.port.toString());
    final usernameController = TextEditingController(text: currentHost.username);
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
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration(l10n.newPassword),
              ),
              const SizedBox(height: 32),

              // 保存和删除按钮
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onUpdate(
                        currentHost,
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
                      child: Text(l10n.saveChanges, style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => onDelete(currentHost),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(l10n.delete, style: const TextStyle(fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
