import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/host.dart';
import '../models/group.dart';

/// 存储服务 - 管理主机配置、分组和密码
class StorageService {
  static const String _hostsKey = 'simple_term_hosts';
  static const String _passwordsKey = 'simple_term_passwords';
  static const String _groupsKey = 'simple_term_groups';

  // ========== 分组管理 ==========

  /// 获取所有分组
  Future<List<HostGroup>> getGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final groupsJson = prefs.getString(_groupsKey);
    if (groupsJson == null) return [];

    final List<dynamic> groupsList = jsonDecode(groupsJson);
    return groupsList.map((json) => HostGroup.fromJson(json)).toList();
  }

  /// 保存所有分组
  Future<void> saveGroups(List<HostGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final groupsJson = jsonEncode(groups.map((g) => g.toJson()).toList());
    await prefs.setString(_groupsKey, groupsJson);
  }

  /// 添加分组
  Future<void> addGroup(HostGroup group) async {
    final groups = await getGroups();
    groups.add(group);
    await saveGroups(groups);
  }

  /// 更新分组
  Future<void> updateGroup(HostGroup group) async {
    final groups = await getGroups();
    final index = groups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      groups[index] = group;
      await saveGroups(groups);
    }
  }

  /// 删除分组（将分组内的主机移到默认分组）
  Future<void> deleteGroup(String groupId) async {
    // 不能删除默认分组
    if (groupId == HostGroup.defaultGroupId) return;
    
    // 删除分组
    final groups = await getGroups();
    groups.removeWhere((g) => g.id == groupId);
    await saveGroups(groups);
    
    // 将该分组的主机移到默认分组
    final hosts = await getHosts();
    bool updated = false;
    for (int i = 0; i < hosts.length; i++) {
      if (hosts[i].groupId == groupId) {
        hosts[i] = hosts[i].copyWith(groupId: null);
        updated = true;
      }
    }
    if (updated) {
      await saveHosts(hosts);
    }
  }

  // ========== 主机管理 ==========

  /// 获取所有主机
  Future<List<Host>> getHosts() async {
    final prefs = await SharedPreferences.getInstance();
    final hostsJson = prefs.getString(_hostsKey);
    if (hostsJson == null) return [];

    final List<dynamic> hostsList = jsonDecode(hostsJson);
    return hostsList.map((json) => Host.fromJson(json)).toList();
  }

  /// 保存所有主机
  Future<void> saveHosts(List<Host> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    final hostsJson = jsonEncode(hosts.map((h) => h.toJson()).toList());
    await prefs.setString(_hostsKey, hostsJson);
  }

  /// 添加主机（如果存在相同 hostname+port+username 的主机则覆盖）
  Future<void> addHost(Host host) async {
    final hosts = await getHosts();
    
    // 检查是否存在相同的主机（hostname + port + username）
    final existingIndex = hosts.indexWhere((h) => 
      h.hostname == host.hostname && 
      h.port == host.port && 
      h.username == host.username &&
      h.id != host.id
    );
    
    if (existingIndex != -1) {
      // 覆盖已存在的主机，保留旧的 ID
      final oldHost = hosts[existingIndex];
      hosts[existingIndex] = host.copyWith(id: oldHost.id);
      // 如果有密码，也需要更新
      await deletePassword(oldHost.id);
    } else {
      hosts.add(host);
    }
    
    await saveHosts(hosts);
  }

  /// 更新主机
  Future<void> updateHost(Host host) async {
    final hosts = await getHosts();
    final index = hosts.indexWhere((h) => h.id == host.id);
    if (index != -1) {
      hosts[index] = host;
      await saveHosts(hosts);
    }
  }

  /// 删除主机
  Future<void> deleteHost(String hostId) async {
    final hosts = await getHosts();
    hosts.removeWhere((h) => h.id == hostId);
    await saveHosts(hosts);
    await deletePassword(hostId);
  }

  // ========== 密码管理 ==========

  /// 保存密码（Base64 编码存储）
  Future<void> savePassword(String hostId, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final passwords = await _getPasswords(prefs);
    
    // 使用 Base64 编码混淆
    final encoded = base64Encode(utf8.encode(password));
    passwords[hostId] = encoded;
    
    await prefs.setString(_passwordsKey, jsonEncode(passwords));
  }

  /// 获取密码（Base64 解码）
  Future<String?> getPassword(String hostId) async {
    final prefs = await SharedPreferences.getInstance();
    final passwords = await _getPasswords(prefs);
    final encoded = passwords[hostId];
    
    if (encoded == null) return null;
    
    try {
      // Base64 解码
      return utf8.decode(base64Decode(encoded));
    } catch (e) {
      // 如果解码失败，可能是旧的明文密码
      return encoded;
    }
  }

  /// 删除密码
  Future<void> deletePassword(String hostId) async {
    final prefs = await SharedPreferences.getInstance();
    final passwords = await _getPasswords(prefs);
    passwords.remove(hostId);
    await prefs.setString(_passwordsKey, jsonEncode(passwords));
  }

  Future<Map<String, String>> _getPasswords(SharedPreferences prefs) async {
    final json = prefs.getString(_passwordsKey);
    if (json == null) return {};
    final Map<String, dynamic> map = jsonDecode(json);
    return map.map((k, v) => MapEntry(k, v.toString()));
  }

  /// 获取编码后的密码（用于导出，不解码）
  Future<String?> _getEncodedPassword(String hostId) async {
    final prefs = await SharedPreferences.getInstance();
    final passwords = await _getPasswords(prefs);
    return passwords[hostId];
  }

  /// 直接保存编码后的密码（用于导入，不再编码）
  Future<void> _saveEncodedPassword(String hostId, String encodedPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final passwords = await _getPasswords(prefs);
    passwords[hostId] = encodedPassword;
    await prefs.setString(_passwordsKey, jsonEncode(passwords));
  }
  
  /// 清除所有数据（主机、分组和密码）
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hostsKey);
    await prefs.remove(_passwordsKey);
    await prefs.remove(_groupsKey);
  }
  
  /// 保存语言偏好
  Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('simple_term_language', languageCode);
  }
  
  /// 获取语言偏好
  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('simple_term_language');
  }
  
  // ========== 传输任务持久化 ==========
  static const String _transferTasksKey = 'simple_term_transfer_tasks';
  
  /// 保存传输任务列表（仅保存失败/取消的任务）
  Future<void> saveTransferTasks(List<Map<String, dynamic>> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_transferTasksKey, jsonEncode(tasks));
  }
  
  /// 获取传输任务列表
  Future<List<Map<String, dynamic>>> getTransferTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_transferTasksKey);
    if (json == null) return [];
    final List<dynamic> list = jsonDecode(json);
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  
  /// 清除传输任务列表
  Future<void> clearTransferTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transferTasksKey);
  }

  /// 导出所有数据（主机、分组、密码）为 JSON 字符串
  /// 密码保持 Base64 编码状态，不会明文导出
  Future<String> exportData() async {
    final hosts = await getHosts();
    final groups = await getGroups();
    
    // 收集所有密码（保持编码状态）
    final Map<String, String?> passwords = {};
    for (final host in hosts) {
      passwords[host.id] = await _getEncodedPassword(host.id);
    }
    
    final exportData = {
      'version': 1,
      'exportTime': DateTime.now().toIso8601String(),
      'hosts': hosts.map((h) => h.toJson()).toList(),
      'groups': groups.map((g) => g.toJson()).toList(),
      'passwords': passwords,
    };
    
    return jsonEncode(exportData);
  }

  /// 从 JSON 字符串导入数据
  /// [mergeMode] 为 true 时合并数据（跳过已存在的主机），为 false 时覆盖所有数据
  Future<({int hostsImported, int groupsImported})> importData(String jsonString, {bool mergeMode = true}) async {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    
    // 解析导入的数据
    final List<dynamic> hostsJson = data['hosts'] ?? [];
    final List<dynamic> groupsJson = data['groups'] ?? [];
    final Map<String, dynamic> passwordsJson = data['passwords'] ?? {};
    
    final importedHosts = hostsJson.map((json) => Host.fromJson(json)).toList();
    final importedGroups = groupsJson.map((json) => HostGroup.fromJson(json)).toList();
    
    int hostsImported = 0;
    int groupsImported = 0;
    
    if (mergeMode) {
      // 合并模式：只添加不存在的数据
      final existingHosts = await getHosts();
      final existingGroups = await getGroups();
      
      // 合并分组
      for (final group in importedGroups) {
        final exists = existingGroups.any((g) => g.id == group.id || g.name == group.name);
        if (!exists) {
          existingGroups.add(group);
          groupsImported++;
        }
      }
      await saveGroups(existingGroups);
      
      // 合并主机（检查 hostname+port+username 是否重复）
      for (final host in importedHosts) {
        final exists = existingHosts.any((h) => 
          h.hostname == host.hostname && 
          h.port == host.port && 
          h.username == host.username
        );
        if (!exists) {
          existingHosts.add(host);
          hostsImported++;
          // 导入密码（直接保存编码后的密码，不再二次编码）
          final password = passwordsJson[host.id];
          if (password != null && password.toString().isNotEmpty) {
            await _saveEncodedPassword(host.id, password.toString());
          }
        }
      }
      await saveHosts(existingHosts);
    } else {
      // 覆盖模式：清除现有数据并导入
      await clearAllData();
      
      await saveGroups(importedGroups);
      groupsImported = importedGroups.length;
      
      await saveHosts(importedHosts);
      hostsImported = importedHosts.length;
      
      // 导入所有密码（直接保存编码后的密码，不再二次编码）
      for (final host in importedHosts) {
        final password = passwordsJson[host.id];
        if (password != null && password.toString().isNotEmpty) {
          await _saveEncodedPassword(host.id, password.toString());
        }
      }
    }
    
    return (hostsImported: hostsImported, groupsImported: groupsImported);
  }
}
