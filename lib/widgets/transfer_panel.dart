import 'package:flutter/material.dart';
import '../models/transfer_task.dart';
import '../models/host.dart';
import '../services/storage_service.dart';
import '../services/transfer_service.dart';
import '../l10n/app_localizations.dart';

/// 传输任务回调类型
typedef TransferTaskCallback = void Function(TransferTask task);
typedef VoidCallback = void Function();

/// 传输任务面板组件
class TransferPanel extends StatelessWidget {
  final List<TransferTask> tasks;
  final VoidCallback onClose;
  final TransferTaskCallback onCancel;
  final TransferTaskCallback onDelete;
  final TransferTaskCallback onResume;

  const TransferPanel({
    super.key,
    required this.tasks,
    required this.onClose,
    required this.onCancel,
    required this.onDelete,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1e1e),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          // 标题栏
          _buildHeader(context, l10n),
          // 任务列表
          Expanded(
            child: tasks.isEmpty
                ? Center(child: Text(l10n.noTransferTasks, style: const TextStyle(color: Colors.grey, fontSize: 12)))
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const Divider(color: Color(0xFF333333), height: 1),
                    itemBuilder: (context, index) {
                      final task = tasks[tasks.length - 1 - index];  // 最新的在上面
                      return _TransferTaskItem(
                        task: task,
                        onCancel: onCancel,
                        onDelete: onDelete,
                        onResume: onResume,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF333333))),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(l10n.transferTasks, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, color: Colors.grey, size: 18),
          ),
        ],
      ),
    );
  }
}

/// 单个传输任务项
class _TransferTaskItem extends StatelessWidget {
  final TransferTask task;
  final TransferTaskCallback onCancel;
  final TransferTaskCallback onDelete;
  final TransferTaskCallback onResume;

  const _TransferTaskItem({
    required this.task,
    required this.onCancel,
    required this.onDelete,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (iconColor, statusText) = _getStatusInfo(l10n);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF333333), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文件名
          Text(
            task.fileName,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
          // 状态文字（上传中时不显示，用百分比代替）
          if (task.status != TransferStatus.uploading)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(statusText, style: TextStyle(color: iconColor, fontSize: 10)),
            ),
          // 目标信息
          _buildTargetInfo(),
          // 进度条
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(
              value: task.isComplete ? 1.0 : task.progress,
              backgroundColor: const Color(0xFF333333),
              valueColor: AlwaysStoppedAnimation<Color>(
                (task.status == TransferStatus.uploading || task.status == TransferStatus.cancelled) 
                    ? iconColor 
                    : (task.isComplete ? const Color(0xFF32d74b) : Colors.transparent),
              ),
              minHeight: 2,
            ),
          ),
          // 操作按钮
          _buildActionButtons(context, l10n),
        ],
      ),
    );
  }

  (Color, String) _getStatusInfo(AppLocalizations l10n) {
    switch (task.status) {
      case TransferStatus.pending:
        return (Colors.grey, l10n.pending);
      case TransferStatus.uploading:
        return (const Color(0xFF007AFF), l10n.uploading);
      case TransferStatus.verifying:
        return (Colors.orange, l10n.verifying);
      case TransferStatus.done:
        return (const Color(0xFF32d74b), l10n.completed);
      case TransferStatus.failed:
        return (const Color(0xFFff453a), l10n.failed);
      case TransferStatus.cancelled:
        return (Colors.grey, l10n.cancelled);
    }
  }

  Widget _buildTargetInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.computer, color: Colors.grey, size: 10),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.hostEndpoint,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.folder, color: Colors.grey, size: 10),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.remoteDirectory,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          // 百分比显示（上传中时）
          if (task.status == TransferStatus.uploading)
            Text(
              '${(task.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Color(0xFF007AFF), fontSize: 11, fontWeight: FontWeight.w500),
            ),
          const Spacer(),
          // 继续按钮（已取消时显示）
          if (task.status == TransferStatus.cancelled)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onResume(task),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(l10n.resumeTransfer, style: const TextStyle(color: Color(0xFF007AFF), fontSize: 10)),
                ),
              ),
            ),
          // 取消按钮（正在传输时显示）
          if (task.isActive)
            GestureDetector(
              onTap: () => onCancel(task),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l10n.cancelTransfer, style: const TextStyle(color: Colors.orange, fontSize: 10)),
              ),
            ),
          // 删除按钮（非传输中时显示）
          if (!task.isActive)
            GestureDetector(
              onTap: () => onDelete(task),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFff453a).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l10n.deleteWithFile, style: const TextStyle(color: Color(0xFFff453a), fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }
}
