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
  });

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
              margin: const EdgeInsets.only(top: 8, left: 8, right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0d0d0d),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: isConnected
                  ? Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.keyF &&
                            HardwareKeyboard.instance.isMetaPressed) {
                          onToggleSearch();
                          return KeyEventResult.handled;
                        }
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.escape &&
                            isSearching) {
                          onCloseSearch();
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Stack(
                        children: [
                          ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
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
