/// 中文字符串
class StringsZh {
  // 应用
  static const String appTitle = 'Simple Term';
  
  // 通用按钮
  static const String cancel = '取消';
  static const String confirm = '确定';
  static const String save = '保存';
  static const String saveChanges = '保存修改';
  static const String delete = '删除';
  static const String edit = '编辑';
  static const String connect = '连接';
  static const String disconnect = '断开';
  static const String clear = '清除';
  static const String close = '关闭';
  static const String upload = '上传';
  static const String download = '下载';
  static const String refresh = '刷新';
  static const String show = '显示';
  static const String hide = '隐藏';
  static const String optional = '可选';
  static const String load = '加载';
  
  // 主机管理
  static const String addHost = '添加主机';
  static const String editHost = '编辑主机';
  static const String hostList = '主机列表';
  static const String hostName = '名称';
  static const String hostname = '主机地址';
  static const String address = '地址';
  static const String port = '端口';
  static const String username = '用户名';
  static const String password = '密码';
  static const String passwordKeepEmpty = '密码（留空保持不变）';
  static const String newPassword = '新密码';
  static const String serverName = '服务器名称';
  static const String ipOrDomain = 'IP 或域名';
  static const String savePassword = '保存密码';
  static const String noHosts = '暂无主机';
  static const String clickToAddHost = '点击 + 添加主机';
  static const String selectHostToView = '选择一个主机查看详情';
  static const String selectHostToConnect = '选择一个主机开始连接';
  static const String clickToConnect = '点击 ⏻ 按钮开始连接';
  static const String addHostTooltip = '添加主机';
  static const String hostUpdated = '已更新主机';
  
  // 对话框
  static const String clearAllData = '清除所有数据';
  static const String clearAllDataMessage = '这将删除所有保存的主机和密码。\n此操作不可撤销。';
  static const String enterPassword = '输入密码';
  static const String sshPassword = 'SSH 密码';
  static const String confirmDelete = '确认删除';
  static const String deleteHostMessage = '确定要删除这个主机吗？';
  static String confirmDeleteHost(String name) => '确定要删除主机 "$name" 吗？';
  
  // 消息
  static const String connectionFailed = '连接失败';
  static const String uploadSuccess = '上传成功';
  static const String uploadFailed = '上传失败';
  static const String downloadSuccess = '下载成功';
  static const String downloadFailed = '下载失败';
  static const String loadFilesFailed = '加载文件失败';
  static const String waitForTransfer = '请等待当前传输完成';
  static const String transferInProgress = '文件传输中';
  static const String transferContinueInBackground = '当前有文件正在传输，断开连接后传输将在后台继续。';
  static const String allDataCleared = '所有数据已清除';
  static const String uploading = '正在上传';
  static const String downloading = '正在下载';
  static const String verifyingMd5 = '正在校验 MD5...';
  static const String md5Mismatch = 'MD5 不匹配，正在重传...';
  static const String uploadProgress = '上传中 {current}/{total}';
  static const String connected = '已连接';
  static const String connecting = '连接中';
  static const String hostSaved = '主机已保存';
  static const String hostDeleted = '主机已删除';
  
  // 语言
  static const String language = '语言';
  static const String english = 'English';
  static const String chinese = '中文';
  
  // 搜索
  static const String search = '搜索';
  static const String searchPlaceholder = '搜索...';
  static const String noResults = '无结果';
  
  // 文件管理
  static const String files = '文件';
  static const String terminal = '终端';
  static const String parentDirectory = '上级目录';
  static const String enterPath = '输入路径...';
  static const String clickToLoadFiles = '点击加载文件';
  static const String connectToViewFiles = '连接后查看文件';
  
  // 传输任务面板
  static const String transferTasks = '传输任务';
  static const String noTransferTasks = '暂无传输任务';
  static const String clearCompleted = '清除已完成';
  static const String viewDetails = '查看详情';
  static const String pending = '等待中';
  static const String verifying = '校验中';
  static const String completed = '已完成';
  static const String failed = '失败';
  static const String cancelled = '已取消';
  static const String cancelTransfer = '取消';
  static const String deleteWithFile = '删除';
  static const String resumeTransfer = '继续';
}
