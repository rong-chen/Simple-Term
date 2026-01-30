import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/host.dart';

/// 存储服务 - 管理主机配置和密码
class StorageService {
  static const String _hostsKey = 'simple_term_hosts';
  static const String _passwordsKey = 'simple_term_passwords';

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

  /// 添加主机
  Future<void> addHost(Host host) async {
    final hosts = await getHosts();
    hosts.add(host);
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
}
