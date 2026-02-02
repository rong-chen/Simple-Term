/// 主机分组数据模型
class HostGroup {
  final String id;
  final String name;
  final int order;  // 排序顺序，数字越小越靠前

  HostGroup({
    required this.id,
    required this.name,
    this.order = 0,
  });

  /// 默认分组ID
  static const String defaultGroupId = 'default';

  /// 创建默认分组
  factory HostGroup.defaultGroup(String name) {
    return HostGroup(
      id: defaultGroupId,
      name: name,
      order: -1,  // 默认分组始终在最前面
    );
  }

  factory HostGroup.fromJson(Map<String, dynamic> json) {
    return HostGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
    };
  }

  HostGroup copyWith({
    String? id,
    String? name,
    int? order,
  }) {
    return HostGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
    );
  }
}
