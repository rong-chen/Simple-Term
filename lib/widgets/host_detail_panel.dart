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
  AuthType authType,
  String? privateKeyContent,
  String? groupId,
);

/// 主机删除回调
typedef HostDeleteCallback = void Function(Host host);

/// 主机详情编辑面板
class HostDetailPanel extends StatefulWidget {
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
  State<HostDetailPanel> createState() => _HostDetailPanelState();
}

class _HostDetailPanelState extends State<HostDetailPanel> {
  late TextEditingController _nameController;
  late TextEditingController _hostnameController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  String? _lastHostId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _hostnameController = TextEditingController();
    _portController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant HostDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.host?.id != _lastHostId) {
      _syncControllers();
    }
  }

  void _syncControllers() {
    _lastHostId = widget.host?.id;
    if (widget.host != null) {
      _nameController.text = widget.host!.name;
      _hostnameController.text = widget.host!.hostname;
      _portController.text = widget.host!.port.toString();
      _usernameController.text = widget.host!.username;
      _passwordController.clear();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    if (widget.host == null) {
      return Center(
        child: Text(
          l10n.selectHostToView,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    final currentHost = widget.host!;

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
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: widget.inputDecoration(l10n.serverName),
              ),
              const SizedBox(height: 16),

              // 主机地址
              Text(l10n.hostname, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _hostnameController,
                style: const TextStyle(color: Colors.white),
                decoration: widget.inputDecoration(l10n.ipOrDomain),
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
                          controller: _portController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: widget.inputDecoration('22'),
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
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: widget.inputDecoration('root'),
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
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: widget.inputDecoration(l10n.newPassword),
              ),
              const SizedBox(height: 32),

              // 保存和删除按钮
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onUpdate(
                        currentHost,
                        _nameController.text,
                        _hostnameController.text,
                        int.tryParse(_portController.text) ?? 22,
                        _usernameController.text,
                        _passwordController.text.isEmpty ? null : _passwordController.text,
                        currentHost.authType,
                        currentHost.privateKeyContent,
                        currentHost.groupId,
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
                    onPressed: () => widget.onDelete(currentHost),
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
