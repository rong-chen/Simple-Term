import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../models/session.dart';
import '../l10n/app_localizations.dart';

/// 文件浏览器面板回调类型
typedef FileLoadCallback = void Function(String path);
typedef FileDownloadCallback = void Function(String fileName);
typedef FileDropCallback = void Function(List<String> paths);
typedef FileDeleteCallback = void Function(String path, bool isDirectory);
typedef FolderCreateCallback = void Function(String path);
typedef FileRenameCallback = void Function(String oldPath, String newName);

/// 文件浏览器面板组件
class FileBrowserPanel extends StatefulWidget {
  final bool isConnected;
  final bool isLoading;
  final String currentPath;
  final List<SftpFileInfo> files;
  final FileLoadCallback onLoadFiles;
  final VoidCallback onUpload;
  final FileDownloadCallback onDownload;
  final FileDropCallback? onFilesDropped;
  final FileDeleteCallback? onDelete;
  final FolderCreateCallback? onCreateFolder;
  final FileRenameCallback? onRename;

  const FileBrowserPanel({
    super.key,
    required this.isConnected,
    required this.isLoading,
    required this.currentPath,
    required this.files,
    required this.onLoadFiles,
    required this.onUpload,
    required this.onDownload,
    this.onFilesDropped,
    this.onDelete,
    this.onCreateFolder,
    this.onRename,
  });

  @override
  State<FileBrowserPanel> createState() => _FileBrowserPanelState();
}


class _FileBrowserPanelState extends State<FileBrowserPanel> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        if (widget.isConnected && widget.onFilesDropped != null) {
          final paths = details.files.map((f) => f.path).toList();
          widget.onFilesDropped!(paths);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF353535),
          borderRadius: BorderRadius.circular(12),
          border: _isDragging
              ? Border.all(color: const Color(0xFF007AFF), width: 2)
              : null,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // 标题栏
                _buildHeader(context, l10n),
                // 路径输入框
                if (widget.isConnected) _buildPathInput(l10n),
                if (widget.isConnected) const SizedBox(height: 8),
                // 文件列表
                Expanded(child: _buildFileList(context, l10n)),
              ],
            ),
            // 拖放提示
            if (_isDragging && widget.isConnected)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_upload, color: Color(0xFF007AFF), size: 48),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context).dropToUpload,
                        style: const TextStyle(color: Color(0xFF007AFF), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(
            l10n.files,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (widget.isConnected && widget.onCreateFolder != null)
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined, size: 16),
              color: Colors.white70,
              onPressed: () => _showNewFolderDialog(context, l10n),
              tooltip: l10n.newFolder,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (widget.isConnected) const SizedBox(width: 8),
          if (widget.isConnected)
            IconButton(
              icon: const Icon(Icons.upload, size: 16),
              color: Colors.white70,
              onPressed: widget.onUpload,
              tooltip: l10n.upload,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (widget.isConnected) const SizedBox(width: 8),
          if (widget.isConnected)
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              color: Colors.white70,
              onPressed: () => widget.onLoadFiles(widget.currentPath),
              tooltip: l10n.refresh,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  /// 显示新建文件夹对话框
  void _showNewFolderDialog(BuildContext context, AppLocalizations l10n) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Text(l10n.newFolder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.folderName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                final newPath = '${widget.currentPath}/${controller.text}';
                widget.onCreateFolder?.call(newPath);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildPathInput(AppLocalizations l10n) {
    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        style: const TextStyle(fontSize: 12, color: Colors.white),
        decoration: InputDecoration(
          hintText: l10n.enterPath,
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
          filled: true,
          fillColor: const Color(0xFF0d0d0d),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
        controller: TextEditingController(text: widget.currentPath),
        onSubmitted: widget.onLoadFiles,
      ),
    );
  }

  Widget _buildFileList(BuildContext context, AppLocalizations l10n) {
    if (!widget.isConnected) {
      return Center(
        child: Text(
          l10n.connectToViewFiles,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    if (widget.isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (widget.files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.clickToLoadFiles,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => widget.onLoadFiles('~'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.load, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.files.length,
      itemBuilder: (context, index) {
        final file = widget.files[index];
        if (file.name.startsWith('.')) return const SizedBox.shrink();
        
        final filePath = '${widget.currentPath}/${file.name}';
        
        return GestureDetector(
          onSecondaryTapDown: (details) {
            _showFileContextMenu(context, l10n, file, filePath, details.globalPosition);
          },
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: Icon(
              file.isDirectory ? Icons.folder : Icons.insert_drive_file_outlined,
              color: file.isDirectory ? const Color(0xFF007AFF) : Colors.grey,
              size: 18,
            ),
            title: Text(
              file.name,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: file.isDirectory
                ? null
                : IconButton(
                    icon: const Icon(Icons.download, size: 16),
                    color: Colors.white70,
                    onPressed: () => widget.onDownload(file.name),
                    tooltip: l10n.download,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
            onTap: file.isDirectory
                ? () => widget.onLoadFiles(filePath)
                : null,
          ),
        );
      },
    );
  }

  /// 显示文件右键菜单
  void _showFileContextMenu(BuildContext context, AppLocalizations l10n, SftpFileInfo file, String filePath, Offset position) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: const Color(0xFF3d3d3d),
      items: [
        if (widget.onRename != null)
          PopupMenuItem(
            value: 'rename',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 14, color: Colors.white70),
                const SizedBox(width: 8),
                Text(l10n.rename, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        if (widget.onDelete != null)
          PopupMenuItem(
            value: 'delete',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.delete_outline, size: 14, color: Color(0xFFff453a)),
                const SizedBox(width: 8),
                Text(l10n.deleteFile, style: const TextStyle(color: Color(0xFFff453a), fontSize: 13)),
              ],
            ),
          ),
      ],
    );

    if (!context.mounted) return;
    
    if (result == 'rename') {
      _showRenameDialog(context, l10n, file, filePath);
    } else if (result == 'delete') {
      _confirmDelete(context, l10n, file, filePath);
    }
  }

  /// 显示重命名对话框
  void _showRenameDialog(BuildContext context, AppLocalizations l10n, SftpFileInfo file, String filePath) {
    final controller = TextEditingController(text: file.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Text(l10n.rename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: file.name,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty && controller.text != file.name) {
                widget.onRename?.call(filePath, controller.text);
              }
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  /// 确认删除对话框
  void _confirmDelete(BuildContext context, AppLocalizations l10n, SftpFileInfo file, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: Text(l10n.deleteFile, style: const TextStyle(color: Colors.white)),
        content: Text(
          file.isDirectory ? l10n.deleteFolderConfirm : l10n.deleteFileConfirm,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFff453a),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call(filePath, file.isDirectory);
            },
            child: Text(l10n.deleteFile),
          ),
        ],
      ),
    );
  }
}
