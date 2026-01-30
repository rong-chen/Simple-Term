import 'package:flutter/material.dart';
import '../models/host.dart';
import '../l10n/app_localizations.dart';
import 'connected_shimmer.dart';

/// 主机列表面板回调类型
typedef HostCallback = void Function(Host host);
typedef HostIdCallback = void Function(String hostId);
typedef ContextMenuCallback = void Function(BuildContext context, Offset position, Host host, bool isConnected);

/// 主机列表面板组件
class HostListPanel extends StatelessWidget {
  final List<Host> hosts;
  final Host? selectedHost;
  final String? activeSessionId;
  final bool Function(String hostId) isHostConnected;
  final bool Function(String hostId) isHostConnecting;
  final VoidCallback onAddHost;
  final HostCallback onConnect;
  final HostIdCallback onDisconnect;
  final HostIdCallback onSwitchSession;
  final HostCallback onSelectHost;
  final ContextMenuCallback onShowContextMenu;

  const HostListPanel({
    super.key,
    required this.hosts,
    required this.selectedHost,
    required this.activeSessionId,
    required this.isHostConnected,
    required this.isHostConnecting,
    required this.onAddHost,
    required this.onConnect,
    required this.onDisconnect,
    required this.onSwitchSession,
    required this.onSelectHost,
    required this.onShowContextMenu,
  });

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
          // 主机列表
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: hosts.isEmpty 
                  ? _buildEmptyState(l10n) 
                  : _buildHostList(context, l10n),
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
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: onAddHost,
            tooltip: l10n.addHostTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
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

  Widget _buildHostList(BuildContext context, AppLocalizations l10n) {
    return ListView.builder(
      itemCount: hosts.length,
      itemBuilder: (context, index) {
        final host = hosts[index];
        final isSelected = selectedHost?.id == host.id;
        final connected = isHostConnected(host.id);
        final connecting = isHostConnecting(host.id);
        final isActiveSession = activeSessionId == host.id;

        return GestureDetector(
          onTap: () {
            if (connected) {
              onSwitchSession(host.id);
            } else {
              onSelectHost(host);
            }
          },
          onSecondaryTapDown: (details) {
            onShowContextMenu(context, details.globalPosition, host, connected);
          },
          child: connected
              ? _buildConnectedHostItem(context, host, isSelected, connecting, isActiveSession, l10n)
              : _buildDisconnectedHostItem(context, host, isSelected, connecting, l10n),
        );
      },
    );
  }

  Widget _buildConnectedHostItem(
    BuildContext context,
    Host host,
    bool isSelected,
    bool isConnecting,
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isConnecting)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  if (!isConnecting)
                    IconButton(
                      icon: const Icon(Icons.stop, size: 18),
                      color: Colors.red,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: l10n.disconnect,
                      onPressed: () => onDisconnect(host.id),
                    ),
                ],
              ),
              onTap: () {
                onSwitchSession(host.id);
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnecting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF007AFF),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.power_settings_new, size: 18),
              color: const Color(0xFF32d74b),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: l10n.connect,
              onPressed: () => onConnect(host),
            ),
          ],
        ),
        onTap: () {
          onSelectHost(host);
        },
      ),
    );
  }
}
