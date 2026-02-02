import 'dart:io';
import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

/// 应用自动更新服务
/// 
/// 基于 Sparkle (macOS) 和 WinSparkle (Windows) 实现自动下载和安装更新
class UpdateService {
  // appcast.xml 托管地址（GitHub Pages）
  static const String _feedUrl = 
    'https://rong-chen.github.io/Simple-Term/appcast.xml';
  
  /// 初始化更新服务（应用启动时调用）
  static Future<void> init() async {
    // 仅桌面端支持
    if (!Platform.isMacOS && !Platform.isWindows) return;
    
    try {
      await autoUpdater.setFeedURL(_feedUrl);
      // 每小时检查一次更新
      await autoUpdater.setScheduledCheckInterval(3600);
      // 静默检查更新（不显示 UI，除非有更新）
      await autoUpdater.checkForUpdates(inBackground: true);
      
      if (kDebugMode) {
        print('[UpdateService] 初始化完成，Feed URL: $_feedUrl');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[UpdateService] 初始化失败: $e');
      }
    }
  }
  
  /// 手动检查更新（菜单触发）
  /// 
  /// 会显示 Sparkle/WinSparkle 的原生 UI
  static Future<void> checkForUpdates() async {
    if (!Platform.isMacOS && !Platform.isWindows) return;
    
    try {
      await autoUpdater.checkForUpdates();
    } catch (e) {
      if (kDebugMode) {
        print('[UpdateService] 检查更新失败: $e');
      }
      rethrow;
    }
  }
}
