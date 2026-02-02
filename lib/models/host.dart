import 'group.dart';

/// 认证类型枚举
enum AuthType {
  password,    // 密码认证
  privateKey,  // 私钥认证
}

/// SSH 主机数据模型
class Host {
  final String id;
  final String name;
  final String hostname;
  final int port;
  final String username;
  String? password;
  
  /// 认证类型（默认密码）
  final AuthType authType;
  /// 私钥文件路径
  final String? privateKeyPath;
  /// 私钥内容（直接粘贴的PEM格式）
  final String? privateKeyContent;
  /// 分组ID（为空则归入默认分组）
  final String? groupId;

  Host({
    required this.id,
    required this.name,
    required this.hostname,
    this.port = 22,
    required this.username,
    this.password,
    this.authType = AuthType.password,
    this.privateKeyPath,
    this.privateKeyContent,
    this.groupId,
  });

  /// 获取有效的分组ID（为空则返回默认分组ID）
  String get effectiveGroupId => groupId ?? HostGroup.defaultGroupId;

  factory Host.fromJson(Map<String, dynamic> json) {
    return Host(
      id: json['id'] as String,
      name: json['name'] as String,
      hostname: json['hostname'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      password: json['password'] as String?,
      authType: AuthType.values.firstWhere(
        (e) => e.name == json['authType'],
        orElse: () => AuthType.password,
      ),
      privateKeyPath: json['privateKeyPath'] as String?,
      privateKeyContent: json['privateKeyContent'] as String?,
      groupId: json['groupId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hostname': hostname,
      'port': port,
      'username': username,
      'authType': authType.name,
      'privateKeyPath': privateKeyPath,
      'privateKeyContent': privateKeyContent,
      'groupId': groupId,
      // 密码不序列化到 JSON，使用安全存储
    };
  }

  Host copyWith({
    String? id,
    String? name,
    String? hostname,
    int? port,
    String? username,
    String? password,
    AuthType? authType,
    String? privateKeyPath,
    String? privateKeyContent,
    String? groupId,
  }) {
    return Host(
      id: id ?? this.id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      authType: authType ?? this.authType,
      privateKeyPath: privateKeyPath ?? this.privateKeyPath,
      privateKeyContent: privateKeyContent ?? this.privateKeyContent,
      groupId: groupId ?? this.groupId,
    );
  }
}
