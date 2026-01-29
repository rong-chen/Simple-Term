/**
 * SSHManager - React Native 原生 SSH 模块
 * 
 * 使用 PTY (伪终端) 实现真正的交互式 SSH 连接
 */

import Foundation
import AppKit

@objc(SSHManager)
class SSHManager: NSObject {
  
  private var processes: [String: Process] = [:]
  private var masterFds: [String: Int32] = [:]
  private var outputHandlers: [String: DispatchSourceRead?] = [:]
  
  // 输出缓冲区 - 用于 JS 轮询
  private var outputBuffers: [String: String] = [:]
  private let bufferQueue = DispatchQueue(label: "ssh.buffer.queue")
  
  // 当前活跃的会话 ID（用于 Tab 键补全）
  private var activeSessionId: String?
  private var tabKeyMonitor: Any?
  
  // Keep-Alive 定时器 (防止服务器端超时断开)
  private var keepAliveTimers: [String: Timer] = [:]
  private let keepAliveInterval: TimeInterval = 60  // 每60秒发送一次
  
  // 最后活动时间（用于空闲检测）
  private var lastActivityTimes: [String: Date] = [:]
  
  override init() {
    super.init()
    setupTabKeyMonitor()
  }
  
  deinit {
    if let monitor = tabKeyMonitor {
      NSEvent.removeMonitor(monitor)
    }
  }
  
  /// 设置全局 Tab 键监听器
  /// 注意：当前使用缓冲输入模式，Tab 补全暂不可用
  /// 因为 SSH 服务器不知道用户正在输入什么，直到按 Enter
  private func setupTabKeyMonitor() {
    // 暂时禁用 Tab 监听器
    // 实时按键发送模式才能支持 Tab 补全
    /*
    tabKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      // Tab 键的 keyCode 是 48
      if event.keyCode == 48, let sessionId = self?.activeSessionId {
        // 发送 Tab 到 SSH 会话
        self?.writeToSession(sessionId, data: "\t")
        // 返回 nil 表示消费了这个事件
        return nil
      }
      return event
    }
    */
  }
  
  @objc
  static func requiresMainQueueSetup() -> Bool {
    return false
  }
  
  /// 连接到 SSH 服务器
  @objc
  func connect(_ config: NSDictionary,
               resolver: @escaping RCTPromiseResolveBlock,
               rejecter: @escaping RCTPromiseRejectBlock) {
    
    guard let hostname = config["hostname"] as? String,
          let username = config["username"] as? String else {
      rejecter("INVALID_CONFIG", "Missing hostname or username", nil)
      return
    }
    
    let port = config["port"] as? Int ?? 22
    let password = config["password"] as? String
    
    DispatchQueue.global(qos: .userInitiated).async {
      let sessionId = UUID().uuidString
      
      // 初始化输出缓冲区
      self.bufferQueue.sync {
        self.outputBuffers[sessionId] = ""
      }
      
      // 创建 PTY
      var masterFd: Int32 = -1
      var slaveFd: Int32 = -1
      var winsize = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)
      
      if openpty(&masterFd, &slaveFd, nil, nil, &winsize) != 0 {
        DispatchQueue.main.async {
          rejecter("PTY_FAILED", "Failed to create PTY", nil)
        }
        return
      }
      
      // 创建进程
      let process = Process()
      
      // 如果有密码，使用 sshpass
      if let pwd = password, !pwd.isEmpty {
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sshpass")
        process.arguments = [
          "-p", pwd,
          "ssh",
          "-tt",
          "-o", "StrictHostKeyChecking=no",
          "-o", "UserKnownHostsFile=/dev/null",
          "-p", String(port),
          "\(username)@\(hostname)"
        ]
      } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
          "-tt",
          "-o", "StrictHostKeyChecking=no",
          "-o", "UserKnownHostsFile=/dev/null",
          "-p", String(port),
          "\(username)@\(hostname)"
        ]
      }
      
      var env = ProcessInfo.processInfo.environment
      env["TERM"] = "xterm-256color"
      process.environment = env
      
      let slaveHandle = FileHandle(fileDescriptor: slaveFd, closeOnDealloc: false)
      process.standardInput = slaveHandle
      process.standardOutput = slaveHandle
      process.standardError = slaveHandle
      
      do {
        try process.run()
      } catch {
        close(masterFd)
        close(slaveFd)
        DispatchQueue.main.async {
          rejecter("SSH_FAILED", "Failed to start SSH: \(error.localizedDescription)", nil)
        }
        return
      }
      
      close(slaveFd)
      
      self.processes[sessionId] = process
      self.masterFds[sessionId] = masterFd
      
      // 设置非阻塞读取
      let flags = fcntl(masterFd, F_GETFL)
      fcntl(masterFd, F_SETFL, flags | O_NONBLOCK)
      
      // 创建读取源 - 将输出存入缓冲区
      let readSource = DispatchSource.makeReadSource(fileDescriptor: masterFd, queue: .global(qos: .userInitiated))
      self.outputHandlers[sessionId] = readSource
      
      readSource.setEventHandler { [weak self] in
        guard let self = self else { return }
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(masterFd, &buffer, buffer.count)
        
        if bytesRead > 0 {
          let data = Data(bytes: buffer, count: bytesRead)
          if let output = String(data: data, encoding: .utf8) {
            self.bufferQueue.sync {
              self.outputBuffers[sessionId, default: ""] += output
            }
          }
        }
      }
      
      readSource.setCancelHandler {
        close(masterFd)
      }
      
      readSource.resume()
      
      // 设置当前活跃会话（用于 Tab 键补全）
      self.activeSessionId = sessionId
      
      // 启动 Keep-Alive 定时器
      self.startKeepAlive(sessionId: sessionId)
      
      DispatchQueue.main.async {
        resolver([
          "sessionId": sessionId,
          "connected": true,
          "hostname": hostname,
          "port": port
        ])
      }
    }
  }
  
  /// 获取输出 - 供 JS 轮询调用
  @objc
  func getOutput(_ sessionId: String,
                 resolver: @escaping RCTPromiseResolveBlock,
                 rejecter: @escaping RCTPromiseRejectBlock) {
    
    var output = ""
    bufferQueue.sync {
      output = outputBuffers[sessionId] ?? ""
      outputBuffers[sessionId] = ""  // 清空已读取的内容
    }
    
    resolver(["output": output])
  }
  
  /// 写入数据到会话
  @objc
  func write(_ sessionId: String,
             data: String,
             resolver: @escaping RCTPromiseResolveBlock,
             rejecter: @escaping RCTPromiseRejectBlock) {
    
    // 更新活动时间
    lastActivityTimes[sessionId] = Date()
    
    writeToSession(sessionId, data: data)
    resolver(["success": true])
  }
  
  private func writeToSession(_ sessionId: String, data: String) {
    guard let masterFd = masterFds[sessionId] else { return }
    
    if let inputData = data.data(using: .utf8) {
      inputData.withUnsafeBytes { bytes in
        _ = Darwin.write(masterFd, bytes.baseAddress!, inputData.count)
      }
    }
  }
  
  /// 启动 Keep-Alive 定时器
  private func startKeepAlive(sessionId: String) {
    // 初始化活动时间
    lastActivityTimes[sessionId] = Date()
    
    // 在主线程创建定时器
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      let timer = Timer.scheduledTimer(withTimeInterval: self.keepAliveInterval, repeats: true) { [weak self] _ in
        guard let self = self, self.processes[sessionId] != nil else { return }
        // 发送空操作保持连接 (不影响终端显示)
        // 注意：只是重置服务器端的空闲计时器，不需要实际发送数据
        self.lastActivityTimes[sessionId] = Date()
      }
      self.keepAliveTimers[sessionId] = timer
    }
  }
  
  /// 获取会话空闲时间（供 JS 调用）
  @objc
  func getIdleTime(_ sessionId: String,
                   resolver: @escaping RCTPromiseResolveBlock,
                   rejecter: @escaping RCTPromiseRejectBlock) {
    
    let lastActivity = lastActivityTimes[sessionId] ?? Date()
    let idleSeconds = Date().timeIntervalSince(lastActivity)
    resolver(["idleSeconds": idleSeconds])
  }
  
  /// 发送命令（兼容旧 API）
  @objc
  func execute(_ sessionId: String,
               command: String,
               resolver: @escaping RCTPromiseResolveBlock,
               rejecter: @escaping RCTPromiseRejectBlock) {
    
    writeToSession(sessionId, data: command + "\r")
    resolver(["success": true, "output": ""])
  }
  
  /// 调整终端大小
  @objc
  func resize(_ sessionId: String,
              cols: Int,
              rows: Int,
              resolver: @escaping RCTPromiseResolveBlock,
              rejecter: @escaping RCTPromiseRejectBlock) {
    
    guard let masterFd = masterFds[sessionId] else {
      rejecter("INVALID_SESSION", "Session not found", nil)
      return
    }
    
    var winsize = winsize(ws_row: UInt16(rows), ws_col: UInt16(cols), ws_xpixel: 0, ws_ypixel: 0)
    ioctl(masterFd, TIOCSWINSZ, &winsize)
    resolver(["success": true])
  }
  
  /// 断开连接
  @objc
  func disconnect(_ sessionId: String,
                  resolver: @escaping RCTPromiseResolveBlock,
                  rejecter: @escaping RCTPromiseRejectBlock) {
    
    if let source = outputHandlers[sessionId] {
      source?.cancel()
    }
    outputHandlers.removeValue(forKey: sessionId)
    
    if let process = processes[sessionId] {
      process.terminate()
    }
    processes.removeValue(forKey: sessionId)
    masterFds.removeValue(forKey: sessionId)
    
    // 停止 Keep-Alive 定时器
    keepAliveTimers[sessionId]?.invalidate()
    keepAliveTimers.removeValue(forKey: sessionId)
    lastActivityTimes.removeValue(forKey: sessionId)
    
    bufferQueue.sync {
      outputBuffers.removeValue(forKey: sessionId)
    }
    
    resolver(["disconnected": true])
  }
  
  /// 断开所有连接
  @objc
  func disconnectAll(_ resolver: @escaping RCTPromiseResolveBlock,
                     rejecter: @escaping RCTPromiseRejectBlock) {
    
    for (sessionId, _) in processes {
      if let source = outputHandlers[sessionId] {
        source?.cancel()
      }
    }
    
    for (_, process) in processes {
      process.terminate()
    }
    
    processes.removeAll()
    masterFds.removeAll()
    outputHandlers.removeAll()
    
    // 停止所有 Keep-Alive 定时器
    for (_, timer) in keepAliveTimers {
      timer.invalidate()
    }
    keepAliveTimers.removeAll()
    lastActivityTimes.removeAll()
    
    bufferQueue.sync {
      outputBuffers.removeAll()
    }
    
    resolver(["disconnected": true])
  }
  
  // MARK: - SFTP 文件传输功能
  
  /// 上传文件到远程服务器 (使用 scp)
  @objc
  func uploadFile(_ config: NSDictionary,
                  resolver: @escaping RCTPromiseResolveBlock,
                  rejecter: @escaping RCTPromiseRejectBlock) {
    
    guard let hostname = config["hostname"] as? String,
          let username = config["username"] as? String,
          let localPath = config["localPath"] as? String,
          let remotePath = config["remotePath"] as? String else {
      rejecter("INVALID_CONFIG", "Missing required parameters", nil)
      return
    }
    
    let port = config["port"] as? Int ?? 22
    let password = config["password"] as? String
    
    DispatchQueue.global(qos: .userInitiated).async {
      let process = Process()
      let pipe = Pipe()
      let errorPipe = Pipe()
      
      if let pwd = password, !pwd.isEmpty {
        // 使用 sshpass
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sshpass")
        process.arguments = [
          "-p", pwd,
          "scp",
          "-P", String(port),
          "-o", "StrictHostKeyChecking=no",
          "-o", "UserKnownHostsFile=/dev/null",
          localPath,
          "\(username)@\(hostname):\(remotePath)"
        ]
      } else {
        // 无密码（使用密钥）
        process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
        process.arguments = [
          "-P", String(port),
          "-o", "StrictHostKeyChecking=no",
          localPath,
          "\(username)@\(hostname):\(remotePath)"
        ]
      }
      
      process.standardOutput = pipe
      process.standardError = errorPipe
      
      do {
        try process.run()
        process.waitUntilExit()
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        if process.terminationStatus == 0 {
          DispatchQueue.main.async {
            resolver(["success": true, "message": "File uploaded successfully"])
          }
        } else {
          DispatchQueue.main.async {
            rejecter("UPLOAD_FAILED", errorOutput.isEmpty ? "Upload failed" : errorOutput, nil)
          }
        }
      } catch {
        DispatchQueue.main.async {
          rejecter("UPLOAD_ERROR", error.localizedDescription, nil)
        }
      }
    }
  }
  
  /// 从远程服务器下载文件 (使用 scp)
  @objc
  func downloadFile(_ config: NSDictionary,
                    resolver: @escaping RCTPromiseResolveBlock,
                    rejecter: @escaping RCTPromiseRejectBlock) {
    
    guard let hostname = config["hostname"] as? String,
          let username = config["username"] as? String,
          let remotePath = config["remotePath"] as? String,
          let localPath = config["localPath"] as? String else {
      rejecter("INVALID_CONFIG", "Missing required parameters", nil)
      return
    }
    
    let port = config["port"] as? Int ?? 22
    let password = config["password"] as? String
    
    DispatchQueue.global(qos: .userInitiated).async {
      let process = Process()
      let pipe = Pipe()
      let errorPipe = Pipe()
      
      if let pwd = password, !pwd.isEmpty {
        // 使用 sshpass
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sshpass")
        process.arguments = [
          "-p", pwd,
          "scp",
          "-P", String(port),
          "-o", "StrictHostKeyChecking=no",
          "-o", "UserKnownHostsFile=/dev/null",
          "\(username)@\(hostname):\(remotePath)",
          localPath
        ]
      } else {
        // 无密码（使用密钥）
        process.executableURL = URL(fileURLWithPath: "/usr/bin/scp")
        process.arguments = [
          "-P", String(port),
          "-o", "StrictHostKeyChecking=no",
          "\(username)@\(hostname):\(remotePath)",
          localPath
        ]
      }
      
      process.standardOutput = pipe
      process.standardError = errorPipe
      
      do {
        try process.run()
        process.waitUntilExit()
        
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        if process.terminationStatus == 0 {
          DispatchQueue.main.async {
            resolver(["success": true, "localPath": localPath, "message": "File downloaded successfully"])
          }
        } else {
          DispatchQueue.main.async {
            rejecter("DOWNLOAD_FAILED", errorOutput.isEmpty ? "Download failed" : errorOutput, nil)
          }
        }
      } catch {
        DispatchQueue.main.async {
          rejecter("DOWNLOAD_ERROR", error.localizedDescription, nil)
        }
      }
    }
  }
  
  /// 打开文件选择对话框
  @objc
  func pickFile(_ resolver: @escaping RCTPromiseResolveBlock,
                rejecter: @escaping RCTPromiseRejectBlock) {
    
    DispatchQueue.main.async {
      let panel = NSOpenPanel()
      panel.allowsMultipleSelection = false
      panel.canChooseDirectories = false
      panel.canChooseFiles = true
      panel.title = "选择要上传的文件"
      
      if panel.runModal() == .OK, let url = panel.url {
        resolver(["path": url.path, "name": url.lastPathComponent])
      } else {
        resolver(["cancelled": true])
      }
    }
  }
  
  /// 打开保存文件对话框
  @objc
  func pickSaveLocation(_ defaultName: String,
                        resolver: @escaping RCTPromiseResolveBlock,
                        rejecter: @escaping RCTPromiseRejectBlock) {
    
    DispatchQueue.main.async {
      let panel = NSSavePanel()
      panel.nameFieldStringValue = defaultName
      panel.title = "保存文件到..."
      
      if panel.runModal() == .OK, let url = panel.url {
        resolver(["path": url.path])
      } else {
        resolver(["cancelled": true])
      }
    }
  }
  
  /// 列出远程目录内容 (使用 ssh ls)
  @objc
  func listDirectory(_ config: NSDictionary,
                     resolver: @escaping RCTPromiseResolveBlock,
                     rejecter: @escaping RCTPromiseRejectBlock) {
    
    guard let hostname = config["hostname"] as? String,
          let username = config["username"] as? String,
          let path = config["path"] as? String else {
      rejecter("INVALID_CONFIG", "Missing required parameters", nil)
      return
    }
    
    let port = config["port"] as? Int ?? 22
    let password = config["password"] as? String
    
    DispatchQueue.global(qos: .userInitiated).async {
      let process = Process()
      let pipe = Pipe()
      let errorPipe = Pipe()
      
      // 使用 ls -la 获取详细目录信息
      // 处理路径：~ 需要特殊处理，其他路径用引号保护
      let command: String
      if path == "~" {
        command = "ls -la ~"
      } else if path.hasPrefix("~/") {
        // ~/xxx 形式，~ 不能加引号
        let subPath = String(path.dropFirst(2))
        command = "ls -la ~/'\(subPath)'"
      } else {
        // 绝对路径或相对路径，用引号保护
        command = "ls -la '\(path)'"
      }
      
      if let pwd = password, !pwd.isEmpty {
        // 使用 sshpass
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/sshpass")
        process.arguments = [
          "-p", pwd,
          "ssh",
          "-p", String(port),
          "-o", "StrictHostKeyChecking=no",
          "-o", "UserKnownHostsFile=/dev/null",
          "\(username)@\(hostname)",
          command
        ]
      } else {
        // 无密码（使用密钥）
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
          "-p", String(port),
          "-o", "StrictHostKeyChecking=no",
          "\(username)@\(hostname)",
          command
        ]
      }
      
      process.standardOutput = pipe
      process.standardError = errorPipe
      
      do {
        try process.run()
        process.waitUntilExit()
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        
        // 调试输出
        print("[listDirectory] terminationStatus: \(process.terminationStatus)")
        print("[listDirectory] output length: \(output.count)")
        print("[listDirectory] errorOutput: \(errorOutput)")
        
        if process.terminationStatus == 0 {
          // 解析 ls -la 输出
          var files: [[String: Any]] = []
          let lines = output.split(separator: "\n")
          
          for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 跳过 total 行和空行
            if trimmed.isEmpty || trimmed.hasPrefix("total") {
              continue
            }
            
            // 解析 ls -la 格式: drwxr-xr-x 2 root root 4096 Jan 1 00:00 dirname
            let parts = trimmed.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: true)
            if parts.count >= 9 {
              let permissions = String(parts[0])
              let name = String(parts[8])
              let size = Int(parts[4]) ?? 0
              
              // 判断类型
              let isDirectory = permissions.hasPrefix("d")
              let isLink = permissions.hasPrefix("l")
              
              // 跳过 . 和 ..
              if name == "." || name == ".." {
                continue
              }
              
              files.append([
                "name": name,
                "type": isDirectory ? "directory" : (isLink ? "link" : "file"),
                "size": size,
                "permissions": permissions
              ])
            }
          }
          
          DispatchQueue.main.async {
            resolver(["success": true, "path": path, "files": files])
          }
        } else {
          // 过滤掉 SSH 的正常警告信息
          let filteredError = errorOutput
            .split(separator: "\n")
            .filter { !$0.contains("Warning: Permanently added") }
            .joined(separator: "\n")
          
          DispatchQueue.main.async {
            rejecter("LIST_FAILED", filteredError.isEmpty ? "Failed to list directory" : filteredError, nil)
          }
        }
      } catch {
        DispatchQueue.main.async {
          rejecter("LIST_ERROR", error.localizedDescription, nil)
        }
      }
    }
  }
  
  // MARK: - Keychain 钥匙串功能
  
  private let keychainService = "com.yzterm.ssh"
  
  /// 保存密码到钥匙串（需要 Touch ID 或密码验证才能读取）
  @objc
  func savePassword(_ hostId: String,
                    password: String,
                    resolver: @escaping RCTPromiseResolveBlock,
                    rejecter: @escaping RCTPromiseRejectBlock) {
    
    guard let passwordData = password.data(using: .utf8) else {
      rejecter("INVALID_PASSWORD", "无法编码密码", nil)
      return
    }
    
    // 先删除旧密码（如果存在）
    let deleteQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: hostId
    ]
    SecItemDelete(deleteQuery as CFDictionary)
    
    // 创建访问控制 - 优先 Touch ID 指纹，回退到设备密码
    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
      kCFAllocatorDefault,
      kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
      [.biometryCurrentSet, .or, .devicePasscode],  // 优先指纹，或者设备密码
      &error
    ) else {
      rejecter("ACCESS_CONTROL_ERROR", "创建访问控制失败", nil)
      return
    }
    
    // 添加新密码（带访问控制）
    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: hostId,
      kSecValueData as String: passwordData,
      kSecAttrAccessControl as String: accessControl
    ]
    
    let status = SecItemAdd(addQuery as CFDictionary, nil)
    
    if status == errSecSuccess {
      resolver(["success": true])
    } else {
      rejecter("KEYCHAIN_ERROR", "保存密码失败: \(status)", nil)
    }
  }
  
  /// 从钥匙串获取密码（需要 Touch ID 或密码验证）
  @objc
  func getPassword(_ hostId: String,
                   resolver: @escaping RCTPromiseResolveBlock,
                   rejecter: @escaping RCTPromiseRejectBlock) {
    
    // 在后台线程执行，避免阻塞 UI
    DispatchQueue.global(qos: .userInitiated).async {
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: self.keychainService,
        kSecAttrAccount as String: hostId,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecUseOperationPrompt as String: "验证以访问 SSH 密码"
      ]
      
      var result: AnyObject?
      let status = SecItemCopyMatching(query as CFDictionary, &result)
      
      DispatchQueue.main.async {
        if status == errSecSuccess, let data = result as? Data,
           let password = String(data: data, encoding: .utf8) {
          resolver(["password": password])
        } else if status == errSecItemNotFound {
          resolver(["password": NSNull()])
        } else if status == errSecUserCanceled {
          rejecter("USER_CANCELED", "用户取消了验证", nil)
        } else if status == errSecAuthFailed {
          rejecter("AUTH_FAILED", "验证失败", nil)
        } else {
          rejecter("KEYCHAIN_ERROR", "获取密码失败: \(status)", nil)
        }
      }
    }
  }
  
  /// 从钥匙串删除密码
  @objc
  func deletePassword(_ hostId: String,
                      resolver: @escaping RCTPromiseResolveBlock,
                      rejecter: @escaping RCTPromiseRejectBlock) {
    
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: hostId
    ]
    
    let status = SecItemDelete(query as CFDictionary)
    
    if status == errSecSuccess || status == errSecItemNotFound {
      resolver(["success": true])
    } else {
      rejecter("KEYCHAIN_ERROR", "删除密码失败: \(status)", nil)
    }
  }
}
