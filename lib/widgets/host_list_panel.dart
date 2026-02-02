import 'package:flutter/material.dart';
import '../models/host.dart';
import '../models/group.dart';
import '../l10n/app_localizations.dart';
import '../services/import_export_service.dart';
import 'connected_shimmer.dart';

/// 主机列表面板回调类型
typedef HostCallback = void Function(Host host);
typedef HostIdCallback = void Function(String hostId);
typedef ContextMenuCallback = void Function(BuildContext context, Offset position, Host host, bool isConnected, List<HostGroup> groups);
typedef GroupCallback = void Function(HostGroup group);
typedef MoveHostCallback = void Function(Host host, String? groupId);

/// 主机列表面板组件（支持分组和拖拽）
class HostListPanel extends StatefulWidget {
  final List<Host> hosts;
  final List<HostGroup> groups;
  final Host? selectedHost;
  final String? activeSessionId;
  final bool Function(String hostId) isHostConnected;
  final bool Function(String hostId) isHostConnecting;
  final VoidCallback onAddHost;
  final VoidCallback onAddGroup;
  final HostCallback onConnect;
  final HostIdCallback onDisconnect;
  final HostIdCallback onSwitchSession;
  final HostCallback onSelectHost;
  final ContextMenuCallback onShowContextMenu;
  final GroupCallback? onEditGroup;
  final GroupCallback? onDeleteGroup;
  final MoveHostCallback? onMoveHost;
  final VoidCallback? onDataChanged;  // 导入数据后的回调

  const HostListPanel({
    super.key,
    required this.hosts,
    required this.groups,
    required this.selectedHost,
    required this.activeSessionId,
    required this.isHostConnected,
    required this.isHostConnecting,
    required this.onAddHost,
    required this.onAddGroup,
    required this.onConnect,
    required this.onDisconnect,
    required this.onSwitchSession,
    required this.onSelectHost,
    required this.onShowContextMenu,
    this.onEditGroup,
    this.onDeleteGroup,
    this.onMoveHost,
    this.onDataChanged,
  });

  @override
  State<HostListPanel> createState() => _HostListPanelState();
}

class _HostListPanelState extends State<HostListPanel> {
  final Set<String> _expandedGroups = {HostGroup.defaultGroupId};
  String? _dragTargetGroupId;
  final ImportExportService _importExportService = ImportExportService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF353535),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 标题栏
          _buildHeader(l10n),
          // 主机列表（分组显示）
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: widget.hosts.isEmpty 
                  ? _buildEmptyState(l10n) 
                  : _buildGroupedHostList(context, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            l10n.hostList,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          // 导入导出按钮
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 16),
            onPressed: () => _showImportExportMenu(context),
            tooltip: l10n.exportData,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          // 添加分组按钮
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, size: 16),
            onPressed: widget.onAddGroup,
            tooltip: l10n.newGroup,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          // 添加主机按钮
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: widget.onAddHost,
            tooltip: l10n.addHostTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showImportExportMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);
    
    _importExportService.showImportExportMenu(
      context,
      Offset(offset.dx + 12, offset.dy + 40),
      onDataChanged: () => widget.onDataChanged?.call(),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_outlined, size: 48, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(
            l10n.noHosts,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.clickToAddHost,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedHostList(BuildContext context, AppLocalizations l10n) {
    // 构建分组映射
    final Map<String, List<Host>> groupedHosts = {};
    
    // 初始化默认分组
    groupedHosts[HostGroup.defaultGroupId] = [];
    
    // 初始化自定义分组
    for (final group in widget.groups) {
      groupedHosts[group.id] = [];
    }
    
    // 将主机分配到各分组
    for (final host in widget.hosts) {
      final groupId = host.effectiveGroupId;
      if (groupedHosts.containsKey(groupId)) {
        groupedHosts[groupId]!.add(host);
      } else {
        // 分组不存在，放入默认分组
        groupedHosts[HostGroup.defaultGroupId]!.add(host);
      }
    }
    
    // 构建分组列表（默认分组在前，其他按 order 排序）
    final sortedGroups = <MapEntry<String, String>>[];
    
    // 添加默认分组
    sortedGroups.add(MapEntry(HostGroup.defaultGroupId, l10n.defaultGroup));
    
    // 添加自定义分组（按 order 排序）
    final customGroups = widget.groups.toList()..sort((a, b) => a.order.compareTo(b.order));
    for (final group in customGroups) {
      sortedGroups.add(MapEntry(group.id, group.name));
    }

    return ListView.builder(
      itemCount: sortedGroups.length,
      itemBuilder: (context, index) {
        final groupEntry = sortedGroups[index];
        final groupId = groupEntry.key;
        final groupName = groupEntry.value;
        final hosts = groupedHosts[groupId] ?? [];
        final isExpanded = _expandedGroups.contains(groupId);
        final isDefaultGroup = groupId == HostGroup.defaultGroupId;
        final isDragTarget = _dragTargetGroupId == groupId;
        
        return DragTarget<Host>(
          onWillAcceptWithDetails: (details) {
            // 只有当主机不在当前分组时才接受
            final host = details.data;
            if (host.effectiveGroupId != groupId) {
              setState(() => _dragTargetGroupId = groupId);
              return true;
            }
            return false;
          },
          onLeave: (_) {
            setState(() => _dragTargetGroupId = null);
          },
          onAcceptWithDetails: (details) {
            setState(() => _dragTargetGroupId = null);
            final host = details.data;
            widget.onMoveHost?.call(host, isDefaultGroup ? null : groupId);
          },
          builder: (context, candidateData, rejectedData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分组标题
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedGroups.remove(groupId);
                      } else {
                        _expandedGroups.add(groupId);
                      }
                    });
                  },
                  onSecondaryTapDown: isDefaultGroup ? null : (details) {
                    _showGroupContextMenu(context, details.globalPosition, widget.groups.firstWhere((g) => g.id == groupId));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDragTarget ? const Color(0xFF007AFF).withValues(alpha: 0.3) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.expand_more : Icons.chevron_right,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isDefaultGroup ? Icons.folder_special : Icons.folder,
                          size: 16,
                          color: isDragTarget ? const Color(0xFF007AFF) : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            groupName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDragTarget ? const Color(0xFF007AFF) : Colors.white70,
                            ),
                          ),
                        ),
                        Text(
                          '(${hosts.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 分组内的主机
                if (isExpanded)
                  ...hosts.map((host) => _buildDraggableHostItem(context, host, l10n)),
              ],
            );
          },
        );
      },
    );
  }

  void _showGroupContextMenu(BuildContext context, Offset position, HostGroup group) {
    final l10n = AppLocalizations.of(context);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: const Color(0xFF404040),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.edit, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Text(l10n.editGroup, style: const TextStyle(color: Colors.white)),
            ],
          ),
          onTap: () => widget.onEditGroup?.call(group),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.delete, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(l10n.deleteGroup, style: const TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () => widget.onDeleteGroup?.call(group),
        ),
      ],
    );
  }

  Widget _buildDraggableHostItem(BuildContext context, Host host, AppLocalizations l10n) {
    final isSelected = widget.selectedHost?.id == host.id;
    final connected = widget.isHostConnected(host.id);
    final connecting = widget.isHostConnecting(host.id);
    final isActiveSession = widget.activeSessionId == host.id;

    return Draggable<Host>(
      data: host,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.dns, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                host.name,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildHostItemContent(context, host, isSelected, connected, connecting, isActiveSession, l10n),
      ),
      child: GestureDetector(
        onTap: () {
          if (connected) {
            widget.onSwitchSession(host.id);
          } else {
            widget.onSelectHost(host);
          }
        },
        onSecondaryTapDown: (details) {
          widget.onShowContextMenu(context, details.globalPosition, host, connected, widget.groups);
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: _buildHostItemContent(context, host, isSelected, connected, connecting, isActiveSession, l10n),
        ),
      ),
    );
  }

  /// 构建统一的 trailing 按钮，三种状态互斥：连接中 -> loading, 已连接 -> 断开按钮, 未连接 -> 连接按钮
  Widget _buildTrailingWidget(Host host, bool connected, bool isConnecting, AppLocalizations l10n) {
    if (isConnecting) {
      // 连接中：显示 loading
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF007AFF),
        ),
      );
    } else if (connected) {
      // 已连接：显示断开按钮
      return IconButton(
        icon: const Icon(Icons.stop, size: 18),
        color: Colors.red,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: l10n.disconnect,
        onPressed: () => widget.onDisconnect(host.id),
      );
    } else {
      // 未连接：显示连接按钮
      return IconButton(
        icon: const Icon(Icons.power_settings_new, size: 18),
        color: const Color(0xFF32d74b),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: l10n.connect,
        onPressed: () => widget.onConnect(host),
      );
    }
  }

  Widget _buildHostItemContent(
    BuildContext context,
    Host host,
    bool isSelected,
    bool connected,
    bool isConnecting,
    bool isActiveSession,
    AppLocalizations l10n,
  ) {
    if (connected) {
      return _buildConnectedHostItem(context, host, isSelected, isActiveSession, l10n);
    } else {
      return _buildDisconnectedHostItem(context, host, isSelected, isConnecting, l10n);
    }
  }

  Widget _buildConnectedHostItem(
    BuildContext context,
    Host host,
    bool isSelected,
    bool isActiveSession,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConnectedShimmer(
          isActive: isActiveSession,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActiveSession ? const Color(0xFF32d74b) : Colors.transparent,
                width: 1,
              ),
            ),
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                host.name,
                style: TextStyle(
                  fontSize: 13,
                  color: isActiveSession ? Colors.white : (isSelected ? Colors.white : Colors.white70),
                  fontWeight: isActiveSession ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${host.username}@${host.hostname}',
                style: TextStyle(
                  fontSize: 11,
                  color: isActiveSession ? Colors.white70 : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              trailing: _buildTrailingWidget(host, true, false, l10n),
              onTap: () {
                widget.onSwitchSession(host.id);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedHostItem(
    BuildContext context,
    Host host,
    bool isSelected,
    bool isConnecting,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2a2a2a) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          host.name,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${host.username}@${host.hostname}',
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _buildTrailingWidget(host, false, isConnecting, l10n),
        onTap: () {
          widget.onSelectHost(host);
        },
      ),
    );
  }
}
