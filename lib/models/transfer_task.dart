import 'host.dart';

/// 文件传输任务模型
enum TransferStatus {
  pending,    // 等待传输
  uploading,  // 正在上传
  verifying,  // 正在校验 MD5
  done,       // 完成
  failed,     // 失败
  cancelled,  // 已取消（可续传）
}

class TransferTask {
  final String localPath;
  final String remotePath;
  final String fileName;
  final int totalSize;
  final Host host;              // 目标主机对象
  final String hostName;        // 目标主机名称
  final String hostEndpoint;    // 目标端点 (user@host:port)
  int transferredBytes;
  String? localMd5;
  String? remoteMd5;
  TransferStatus status;
  String? errorMessage;
  bool isCancelled = false;     // 取消标志（用于中断上传循环）

  TransferTask({
    required this.localPath,
    required this.remotePath,
    required this.fileName,
    required this.totalSize,
    required this.host,
    required this.hostName,
    required this.hostEndpoint,
    this.transferredBytes = 0,
    this.localMd5,
    this.remoteMd5,
    this.status = TransferStatus.pending,
    this.errorMessage,
    this.isCancelled = false,
  });

  double get progress => totalSize > 0 ? transferredBytes / totalSize : 0.0;
  
  /// 获取远程目录（不含文件名）
  String get remoteDirectory => remotePath.substring(0, remotePath.lastIndexOf('/'));
  
  bool get isComplete => status == TransferStatus.done;
  bool get isFailed => status == TransferStatus.failed;
  bool get isActive => status == TransferStatus.uploading || status == TransferStatus.verifying;
  
  /// 取消传输（不删除远程文件）
  void cancel() {
    isCancelled = true;
    if (isActive) {
      status = TransferStatus.cancelled;
    }
  }

  /// 转换为 JSON（用于持久化存储）
  Map<String, dynamic> toJson() => {
    'localPath': localPath,
    'remotePath': remotePath,
    'fileName': fileName,
    'totalSize': totalSize,
    'host': host.toJson(),
    'hostName': hostName,
    'hostEndpoint': hostEndpoint,
    'transferredBytes': transferredBytes,
    'localMd5': localMd5,
    'remoteMd5': remoteMd5,
    'status': status.index,
    'errorMessage': errorMessage,
    'isCancelled': isCancelled,
  };

  /// 从 JSON 创建（用于持久化存储）
  factory TransferTask.fromJson(Map<String, dynamic> json) {
    return TransferTask(
      localPath: json['localPath'] as String,
      remotePath: json['remotePath'] as String,
      fileName: json['fileName'] as String,
      totalSize: json['totalSize'] as int,
      host: Host.fromJson(json['host'] as Map<String, dynamic>),
      hostName: json['hostName'] as String,
      hostEndpoint: json['hostEndpoint'] as String,
      transferredBytes: json['transferredBytes'] as int? ?? 0,
      localMd5: json['localMd5'] as String?,
      remoteMd5: json['remoteMd5'] as String?,
      status: TransferStatus.values[json['status'] as int? ?? 0],
      errorMessage: json['errorMessage'] as String?,
      isCancelled: json['isCancelled'] as bool? ?? false,
    );
  }
}
