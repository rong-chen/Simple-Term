import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../l10n/app_localizations.dart';
import '../models/host.dart';

/// 终端视图面板组件
class TerminalPanel extends StatelessWidget {
  final Host? selectedHost;
  final bool isConnected;
  final Terminal? activeTerminal;
  final TerminalController terminalController;
  final ScrollController terminalScrollController;
  final bool isSearching;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<int> searchMatchLines;
  final int currentMatchIndex;
  final VoidCallback onToggleSearch;
  final VoidCallback onCloseSearch;
  final Function(String) onSearch;
  final VoidCallback onNextMatch;
  final VoidCallback onPrevMatch;
  final Function(String)? onPaste;

  const TerminalPanel({
    super.key,
    required this.selectedHost,
    required this.isConnected,
    required this.activeTerminal,
    required this.terminalController,
    required this.terminalScrollController,
    required this.isSearching,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchMatchLines,
    required this.currentMatchIndex,
    required this.onToggleSearch,
    required this.onCloseSearch,
    required this.onSearch,
    required this.onNextMatch,
    required this.onPrevMatch,
    this.onPaste,
  });

  /// 检查是否按下了修饰键 (macOS: Cmd, Windows/Linux: Ctrl)
  bool _isModifierPressed() {
    if (Platform.isMacOS) {
      return HardwareKeyboard.instance.isMetaPressed;
    } else {
      return HardwareKeyboard.instance.isControlPressed;
    }
  }

  /// 复制选中的文本到剪贴板
  Future<void> _copySelection() async {
    final selection = terminalController.selection;
    if (selection != null && activeTerminal != null) {
      final text = activeTerminal!.buffer.getText(selection);
      if (text.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: text));
      }
    }
  }

  /// 粘贴剪贴板内容到终端
  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      if (onPaste != null) {
        onPaste!(data.text!);
      } else {
        // 默认行为：直接写入终端
        activeTerminal?.textInput(data.text!);
      }
    }
  }

  /// 全选终端内容
  void _selectAll() {
    if (activeTerminal != null) {
      final buffer = activeTerminal!.buffer;
      final start = buffer.createAnchor(0, 0);
      final end = buffer.createAnchor(buffer.viewWidth, buffer.lines.length - 1);
      terminalController.setSelection(start, end);
    }
  }

  /// 清屏
  void _clearScreen() {
    activeTerminal?.textInput('\x0c'); // Ctrl+L
  }

  /// 显示右键上下文菜单
  void _showContextMenu(BuildContext context, Offset position) {
    final l10n = AppLocalizations.of(context);
    final hasSelection = terminalController.selection != null;
    final modifierKey = Platform.isMacOS ? '⌘' : 'Ctrl+';

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: const Color(0xFF2d2d2d),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          enabled: hasSelection,
          child: _buildMenuItem(
            l10n.copy,
            '${modifierKey}C',
            Icons.copy,
            enabled: hasSelection,
          ),
        ),
        PopupMenuItem<String>(
          value: 'paste',
          child: _buildMenuItem(
            l10n.paste,
            '${modifierKey}V',
            Icons.paste,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'selectAll',
          child: _buildMenuItem(
            l10n.selectAll,
            '${modifierKey}A',
            Icons.select_all,
          ),
        ),
        PopupMenuItem<String>(
          value: 'clear',
          child: _buildMenuItem(
            l10n.clearScreen,
            '${modifierKey}K',
            Icons.clear_all,
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'copy':
          _copySelection();
          break;
        case 'paste':
          _pasteClipboard();
          break;
        case 'selectAll':
          _selectAll();
          break;
        case 'clear':
          _clearScreen();
          break;
      }
    });
  }

  /// 构建菜单项
  Widget _buildMenuItem(String label, String shortcut, IconData icon, {bool enabled = true}) {
    final color = enabled ? Colors.white : Colors.grey;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 13),
          ),
        ),
        Text(
          shortcut,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      margin: const EdgeInsets.only(right: 12, bottom: 12, top: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0d0d0d),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 工具栏
          Container(
            height: 36,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (selectedHost != null)
                  Text(
                    '${selectedHost!.username}@${selectedHost!.hostname}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  )
                else
                  Text(
                    l10n.selectHostToConnect,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
          ),
          // 终端视图
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 8, left: 8),
              padding: const EdgeInsets.only(top: 8, left: 8, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0d0d0d),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: isConnected
                  ? Focus(
                      onKeyEvent: (node, event) {
                        // 搜索: Cmd/Ctrl+F
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.keyF &&
                            _isModifierPressed()) {
                          onToggleSearch();
                          return KeyEventResult.handled;
                        }
                        // 关闭搜索: Escape
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.escape &&
                            isSearching) {
                          onCloseSearch();
                          return KeyEventResult.handled;
                        }
                        // 复制: Cmd/Ctrl+C (仅当有选中内容时)
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.keyC &&
                            _isModifierPressed() &&
                            terminalController.selection != null) {
                          _copySelection();
                          return KeyEventResult.handled;
                        }
                        // 粘贴: Cmd/Ctrl+V
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.keyV &&
                            _isModifierPressed()) {
                          _pasteClipboard();
                          return KeyEventResult.handled;
                        }
                        // 全选: Cmd/Ctrl+A
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.keyA &&
                            _isModifierPressed()) {
                          _selectAll();
                          return KeyEventResult.handled;
                        }
                        // 清屏: Cmd/Ctrl+K
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.keyK &&
                            _isModifierPressed()) {
                          _clearScreen();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Stack(
                        children: [
                          GestureDetector(
                            onSecondaryTapDown: (details) {
                              _showContextMenu(context, details.globalPosition);
                            },
                            child: activeTerminal != null
                                ? TerminalView(
                                    activeTerminal!,
                                    controller: terminalController,
                                    scrollController: terminalScrollController,
                                    autofocus: true,
                                    alwaysShowCursor: true,
                                    hardwareKeyboardOnly: true,
                                    theme: const TerminalTheme(
                                      cursor: Color(0xFFFFFFFF),
                                      selection: Color(0x80FFFFFF),
                                      foreground: Color(0xFFFFFFFF),
                                      background: Color(0xFF0d0d0d),
                                      black: Color(0xFF000000),
                                      white: Color(0xFFFFFFFF),
                                      red: Color(0xFFFF5555),
                                      green: Color(0xFF50FA7B),
                                      yellow: Color(0xFFF1FA8C),
                                      blue: Color(0xFF6272A4),
                                      magenta: Color(0xFFFF79C6),
                                      cyan: Color(0xFF8BE9FD),
                                      brightBlack: Color(0xFF6272A4),
                                      brightWhite: Color(0xFFFFFFFF),
                                      brightRed: Color(0xFFFF6E6E),
                                      brightGreen: Color(0xFF69FF94),
                                      brightYellow: Color(0xFFFFFFA5),
                                      brightBlue: Color(0xFFD6ACFF),
                                      brightMagenta: Color(0xFFFF92DF),
                                      brightCyan: Color(0xFFA4FFFF),
                                      searchHitBackground: Color(0xFFFFFF00),
                                      searchHitBackgroundCurrent: Color(0xFFFF6600),
                                      searchHitForeground: Color(0xFF000000),
                                    ),
                                    textStyle: const TerminalStyle(
                                      fontSize: 14,
                                      fontFamily: 'Menlo',
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          // 搜索框
                          if (isSearching)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 280,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2d2d2d),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: searchController,
                                        focusNode: searchFocusNode,
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: l10n.searchPlaceholder,
                                          hintStyle: const TextStyle(color: Colors.grey),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                        onChanged: onSearch,
                                        onSubmitted: (_) {
                                          onNextMatch();
                                          searchFocusNode.requestFocus();
                                        },
                                      ),
                                    ),
                                    if (searchMatchLines.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          '${currentMatchIndex + 1}/${searchMatchLines.length}',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ),
                                    GestureDetector(
                                      onTap: onPrevMatch,
                                      child: const Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 20),
                                    ),
                                    GestureDetector(
                                      onTap: onNextMatch,
                                      child: const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: onCloseSearch,
                                      child: const Icon(Icons.close, color: Colors.grey, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : Center(
                      child: Text(
                        l10n.clickToConnect,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, height: 1.5),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
