/// SSH 主机数据模型
class Host {
  final String id;
  final String name;
  final String hostname;
  final int port;
  final String username;
  String? password;

  Host({
    required this.id,
    required this.name,
    required this.hostname,
    this.port = 22,
    required this.username,
    this.password,
  });

  factory Host.fromJson(Map<String, dynamic> json) {
    return Host(
      id: json['id'] as String,
      name: json['name'] as String,
      hostname: json['hostname'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      password: json['password'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hostname': hostname,
      'port': port,
      'username': username,
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
  }) {
    return Host(
      id: id ?? this.id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}
