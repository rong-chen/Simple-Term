import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import '../models/host.dart';
import '../models/transfer_task.dart';

/// 文件传输服务 - 支持多文件上传、断点续传、MD5 校验
class TransferService {
  /// 批量上传文件（复用单个 SFTP 连接）
  /// 
  /// [tasks] 传输任务列表
  /// [onTaskUpdate] 任务状态更新回调
  Future<void> uploadFiles({
    required Host host,
    required String password,
    required List<TransferTask> tasks,
    required void Function(TransferTask task) onTaskUpdate,
  }) async {
    final socket = await SSHSocket.connect(host.hostname, host.port);
    final client = SSHClient(
      socket,
      username: host.username,
      onPasswordRequest: () => password,
    );

    try {
      final sftp = await client.sftp();

      for (final task in tasks) {
        // 跳过已取消的任务
        if (task.isCancelled) {
          task.status = TransferStatus.cancelled;
          onTaskUpdate(task);
          continue;
        }
        
        try {
          await _uploadSingleFile(
            client: client,
            sftp: sftp,
            task: task,
            onTaskUpdate: onTaskUpdate,
          );
        } catch (e) {
          if (task.isCancelled) {
            task.status = TransferStatus.cancelled;
          } else {
            task.status = TransferStatus.failed;
            task.errorMessage = e.toString();
          }
          onTaskUpdate(task);
        }
      }
    } finally {
      client.close();
    }
  }

  /// 上传单个文件（支持断点续传和 MD5 校验）
  Future<void> _uploadSingleFile({
    required SSHClient client,
    required SftpClient sftp,
    required TransferTask task,
    required void Function(TransferTask task) onTaskUpdate,
  }) async {
    task.status = TransferStatus.uploading;
    onTaskUpdate(task);

    // 1. 计算本地文件 MD5
    task.localMd5 = await _calculateLocalMd5(task.localPath);
    
    // 2. 检查远程文件是否存在，获取已传输大小
    int remoteSize = await _getRemoteFileSize(sftp, task.remotePath);
    
    // 3. 如果远程文件已存在且大小相同，直接校验 MD5
    if (remoteSize == task.totalSize) {
      task.transferredBytes = remoteSize;
      onTaskUpdate(task);
      
      // 校验 MD5
      final verified = await _verifyRemoteMd5(client, task);
      if (verified) {
        task.status = TransferStatus.done;
        onTaskUpdate(task);
        return;
      } else {
        // MD5 不匹配，删除远程文件重传
        await _deleteRemoteFile(sftp, task.remotePath);
        remoteSize = 0;
      }
    }

    // 4. 断点续传：从 remoteSize 位置继续写入
    final localFile = File(task.localPath);
    final fileStream = localFile.openRead(remoteSize);
    
    // 打开远程文件（追加模式）
    final mode = remoteSize > 0
        ? SftpFileOpenMode.write | SftpFileOpenMode.append
        : SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate;
    
    final remoteFile = await sftp.open(task.remotePath, mode: mode);
    
    try {
      int offset = remoteSize;
      task.transferredBytes = offset;
      
      await for (final chunk in fileStream) {
        // 检查取消标志
        if (task.isCancelled) {
          throw Exception('用户取消');
        }
        
        final data = Uint8List.fromList(chunk);
        await remoteFile.write(Stream.value(data), offset: offset);
        offset += data.length;
        task.transferredBytes = offset;
        onTaskUpdate(task);
      }
    } finally {
      await remoteFile.close();
    }

    // 检查是否在完成后被取消
    if (task.isCancelled) {
      task.status = TransferStatus.cancelled;
      onTaskUpdate(task);
      return;
    }

    // 5. 校验 MD5
    task.status = TransferStatus.verifying;
    onTaskUpdate(task);
    
    final verified = await _verifyRemoteMd5(client, task);
    if (verified) {
      task.status = TransferStatus.done;
    } else {
      task.status = TransferStatus.failed;
      task.errorMessage = 'MD5 校验失败';
    }
    onTaskUpdate(task);
  }

  /// 删除远程文件（用于删除操作）
  Future<void> deleteRemoteFile({
    required Host host,
    required String password,
    required String remotePath,
  }) async {
    final socket = await SSHSocket.connect(host.hostname, host.port);
    final client = SSHClient(
      socket,
      username: host.username,
      onPasswordRequest: () => password,
    );

    try {
      final sftp = await client.sftp();
      await _deleteRemoteFile(sftp, remotePath);
    } finally {
      client.close();
    }
  }

  /// 计算本地文件 MD5
  Future<String> _calculateLocalMd5(String filePath) async {
    final file = File(filePath);
    final digest = await md5.bind(file.openRead()).first;
    return digest.toString();
  }

  /// 获取远程文件大小（不存在返回 0）
  Future<int> _getRemoteFileSize(SftpClient sftp, String remotePath) async {
    try {
      final stat = await sftp.stat(remotePath);
      return stat.size ?? 0;
    } catch (e) {
      return 0; // 文件不存在
    }
  }

  /// 删除远程文件
  Future<void> _deleteRemoteFile(SftpClient sftp, String remotePath) async {
    try {
      await sftp.remove(remotePath);
    } catch (_) {
      // 忽略删除失败
    }
  }

  /// 通过 SSH 执行 md5sum 校验远程文件 MD5
  Future<bool> _verifyRemoteMd5(SSHClient client, TransferTask task) async {
    try {
      final result = await client.run('md5sum "${task.remotePath}"');
      final output = utf8.decode(result);
      // md5sum 输出格式: "hash  filename"
      final remoteMd5 = output.split(' ').first.trim();
      task.remoteMd5 = remoteMd5;
      return remoteMd5 == task.localMd5;
    } catch (e) {
      return false;
    }
  }
}
