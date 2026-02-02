import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';
import '../l10n/app_localizations.dart';

/// 导入导出服务类
/// 封装导入导出的 UI 和逻辑
class ImportExportService {
  final StorageService _storageService = StorageService();

  /// 导出配置到文件
  Future<bool> exportToFile(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    
    try {
      // 选择保存位置
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportData,
        fileName: 'simple_term_config_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (savePath == null) return false;
      
      // 导出数据
      final jsonString = await _storageService.exportData();
      
      // 写入文件
      final file = File(savePath);
      await file.writeAsString(jsonString);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 从文件导入配置
  /// 返回 (success, hostsImported, groupsImported)
  Future<({bool success, int hosts, int groups, String? error})> importFromFile(BuildContext context, {bool mergeMode = true}) async {
    final l10n = AppLocalizations.of(context);
    
    try {
      // 选择文件
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: l10n.importDataLabel,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (result == null || result.files.isEmpty || result.files.first.path == null) {
        return (success: false, hosts: 0, groups: 0, error: null);
      }
      
      // 读取文件
      final file = File(result.files.first.path!);
      final jsonString = await file.readAsString();
      
      // 导入数据
      final importResult = await _storageService.importData(jsonString, mergeMode: mergeMode);
      
      return (success: true, hosts: importResult.hostsImported, groups: importResult.groupsImported, error: null);
    } catch (e) {
      return (success: false, hosts: 0, groups: 0, error: e.toString());
    }
  }

  /// 显示导入模式选择对话框
  Future<bool?> showImportModeDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l10n.importModeTitle, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildModeOption(
              context,
              icon: Icons.merge_type,
              title: l10n.mergeImport,
              description: l10n.mergeImportDesc,
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 12),
            _buildModeOption(
              context,
              icon: Icons.sync,
              title: l10n.overwriteImport,
              description: l10n.overwriteImportDesc,
              isDestructive: true,
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDestructive ? Colors.orange.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.orange : const Color(0xFF007AFF),
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive ? Colors.orange : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示导入导出菜单
  Future<void> showImportExportMenu(
    BuildContext context,
    Offset position, {
    required VoidCallback onDataChanged,
  }) async {
    final l10n = AppLocalizations.of(context);
    
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: const Color(0xFF404040),
      items: [
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(Icons.upload_file, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Text(l10n.exportData, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'import',
          child: Row(
            children: [
              const Icon(Icons.download, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Text(l10n.importDataLabel, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ],
    );
    
    if (result == null) return;
    
    if (result == 'export') {
      final success = await exportToFile(context);
      if (context.mounted) {
        _showMessage(context, success ? l10n.exportSuccess : l10n.exportFailed, success);
      }
    } else if (result == 'import') {
      // 先选择导入模式
      final mergeMode = await showImportModeDialog(context);
      if (mergeMode == null) return;
      
      if (context.mounted) {
        final importResult = await importFromFile(context, mergeMode: mergeMode);
        if (context.mounted) {
          if (importResult.success) {
            _showMessage(context, l10n.importResult(importResult.hosts, importResult.groups), true);
            onDataChanged();
          } else if (importResult.error != null) {
            _showMessage(context, '${l10n.importFailed}: ${importResult.error}', false);
          }
        }
      }
    }
  }

  void _showMessage(BuildContext context, String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF32d74b) : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
