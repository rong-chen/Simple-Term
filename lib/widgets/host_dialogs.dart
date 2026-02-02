import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/host.dart';
import '../models/group.dart';
import '../l10n/app_localizations.dart';
import '../services/storage_service.dart';

/// 主机对话框工具类
class HostDialogs {
  /// 显示添加主机对话框
  static void showAddHostDialog({
    required BuildContext context,
    required StorageService storageService,
    required List<HostGroup> groups,
    required InputDecoration Function(String hint) inputDecoration,
    required VoidCallback onHostAdded,
  }) {
    final nameController = TextEditingController();
    final hostnameController = TextEditingController();
    final portController = TextEditingController(text: '22');
    final usernameController = TextEditingController(text: 'root');
    final passwordController = TextEditingController();
    final passphraseController = TextEditingController();
    final keyContentController = TextEditingController();
    bool obscurePassword = true;
    AuthType authType = AuthType.password;
    String? selectedGroupId;

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
              width: 500,
              height: 560,
              child: SingleChildScrollView(
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
                    
                    // 名称和分组 - 同一行
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.hostName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: inputDecoration('My Server'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.group, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF404040),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: selectedGroupId,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF404040),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    hint: Text(l10n.defaultGroup, style: const TextStyle(color: Colors.grey)),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(l10n.defaultGroup),
                                      ),
                                      ...groups.map((g) => DropdownMenuItem<String?>(
                                        value: g.id,
                                        child: Text(g.name),
                                      )),
                                    ],
                                    onChanged: (value) => setDialogState(() => selectedGroupId = value),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    
                    // 认证方式选择
                    Text(l10n.authType, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAuthTypeButton(
                            label: l10n.passwordAuth,
                            icon: Icons.password,
                            isSelected: authType == AuthType.password,
                            onTap: () => setDialogState(() => authType = AuthType.password),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildAuthTypeButton(
                            label: l10n.privateKeyAuth,
                            icon: Icons.key,
                            isSelected: authType == AuthType.privateKey,
                            onTap: () => setDialogState(() => authType = AuthType.privateKey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 根据认证类型显示不同的输入
                    if (authType == AuthType.password) ...[
                      // 密码输入
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
                    ] else ...[
                      // 私钥内容输入
                      Row(
                        children: [
                          Expanded(
                            child: Text(l10n.privateKeyPath, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles();
                              if (result != null && result.files.single.path != null) {
                                final file = File(result.files.single.path!);
                                if (await file.exists()) {
                                  final content = await file.readAsString();
                                  setDialogState(() {
                                    keyContentController.text = content;
                                  });
                                }
                              }
                            },
                            icon: const Icon(Icons.folder_open, size: 16),
                            label: Text(l10n.selectPrivateKey),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF007AFF),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: keyContentController,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                        maxLines: 6,
                        decoration: inputDecoration('-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----').copyWith(
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 私钥密码
                      Text(l10n.passphrase, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passphraseController,
                        obscureText: obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration(l10n.passphraseHint).copyWith(
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
                              authType: authType,
                              privateKeyContent: authType == AuthType.privateKey ? keyContentController.text : null,
                              groupId: selectedGroupId,
                            );
                            await storageService.addHost(host);
                            
                            // 保存密码或私钥密码
                            if (authType == AuthType.password && passwordController.text.isNotEmpty) {
                              await storageService.savePassword(host.id, passwordController.text);
                            } else if (authType == AuthType.privateKey && passphraseController.text.isNotEmpty) {
                              await storageService.savePassword(host.id, passphraseController.text);
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
    required List<HostGroup> groups,
    required InputDecoration Function(String hint) inputDecoration,
    required Future<void> Function(Host, String, String, int, String, String?, AuthType, String?, String?) onUpdate,
  }) {
    final nameController = TextEditingController(text: host.name);
    final hostnameController = TextEditingController(text: host.hostname);
    final portController = TextEditingController(text: host.port.toString());
    final usernameController = TextEditingController(text: host.username);
    final passwordController = TextEditingController();
    final passphraseController = TextEditingController();
    final keyContentController = TextEditingController(text: host.privateKeyContent ?? '');
    bool obscurePassword = true;
    AuthType authType = host.authType;
    String? selectedGroupId = host.groupId;

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
              width: 500,
              height: 560,
              child: SingleChildScrollView(
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
                    
                    // 名称和分组 - 同一行
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.hostName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: nameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: inputDecoration(l10n.serverName),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.group, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF404040),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: selectedGroupId,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF404040),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    hint: Text(l10n.defaultGroup, style: const TextStyle(color: Colors.grey)),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(l10n.defaultGroup),
                                      ),
                                      ...groups.map((g) => DropdownMenuItem<String?>(
                                        value: g.id,
                                        child: Text(g.name),
                                      )),
                                    ],
                                    onChanged: (value) => setDialogState(() => selectedGroupId = value),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    
                    // 认证方式选择
                    Text(l10n.authType, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAuthTypeButton(
                            label: l10n.passwordAuth,
                            icon: Icons.password,
                            isSelected: authType == AuthType.password,
                            onTap: () => setDialogState(() => authType = AuthType.password),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildAuthTypeButton(
                            label: l10n.privateKeyAuth,
                            icon: Icons.key,
                            isSelected: authType == AuthType.privateKey,
                            onTap: () => setDialogState(() => authType = AuthType.privateKey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // 根据认证类型显示不同的输入
                    if (authType == AuthType.password) ...[
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
                    ] else ...[
                      // 私钥内容输入
                      Row(
                        children: [
                          Expanded(
                            child: Text(l10n.privateKeyPath, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles();
                              if (result != null && result.files.single.path != null) {
                                final file = File(result.files.single.path!);
                                if (await file.exists()) {
                                  final content = await file.readAsString();
                                  setDialogState(() {
                                    keyContentController.text = content;
                                  });
                                }
                              }
                            },
                            icon: const Icon(Icons.folder_open, size: 16),
                            label: Text(l10n.selectPrivateKey),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF007AFF),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: keyContentController,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                        maxLines: 6,
                        decoration: inputDecoration('-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----').copyWith(
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 私钥密码
                      Text(l10n.passphrase, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passphraseController,
                        obscureText: obscurePassword,
                        style: const TextStyle(color: Colors.white),
                        decoration: inputDecoration(l10n.passphraseHint).copyWith(
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
                  ],
                ),
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
                  final password = authType == AuthType.password 
                      ? (passwordController.text.isEmpty ? null : passwordController.text)
                      : (passphraseController.text.isEmpty ? null : passphraseController.text);
                  await onUpdate(
                    host,
                    nameController.text,
                    hostnameController.text,
                    int.tryParse(portController.text) ?? 22,
                    usernameController.text,
                    password,
                    authType,
                    authType == AuthType.privateKey ? keyContentController.text : null,
                    selectedGroupId,
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

  /// 显示新建分组对话框
  static Future<HostGroup?> showNewGroupDialog({
    required BuildContext context,
    required InputDecoration Function(String hint) inputDecoration,
  }) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();

    return showDialog<HostGroup>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.newGroup, style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.groupName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration(l10n.newGroup),
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
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final group = HostGroup(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  order: DateTime.now().millisecondsSinceEpoch,
                );
                Navigator.pop(dialogContext, group);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  /// 显示编辑分组对话框
  static Future<HostGroup?> showEditGroupDialog({
    required BuildContext context,
    required HostGroup group,
    required InputDecoration Function(String hint) inputDecoration,
  }) async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: group.name);

    return showDialog<HostGroup>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.editGroup, style: const TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.groupName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecoration(group.name),
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
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(dialogContext, group.copyWith(name: nameController.text));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  /// 显示删除分组确认对话框
  static Future<bool> showDeleteGroupDialog({
    required BuildContext context,
    required HostGroup group,
  }) async {
    final l10n = AppLocalizations.of(context);
    
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.deleteGroup, style: const TextStyle(color: Colors.white)),
        content: Text(
          '${l10n.deleteGroupConfirm}\n\n"${group.name}"',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    ) ?? false;
  }
  
  /// 构建认证类型选择按钮
  static Widget _buildAuthTypeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF404040),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
