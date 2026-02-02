/// 英文字符串
class StringsEn {
  // 应用
  static const String appTitle = 'Simple Term';
  
  // 通用按钮
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String saveChanges = 'Save Changes';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String connect = 'Connect';
  static const String disconnect = 'Disconnect';
  static const String clear = 'Clear';
  static const String close = 'Close';
  static const String upload = 'Upload';
  static const String download = 'Download';
  static const String refresh = 'Refresh';
  static const String show = 'Show';
  static const String hide = 'Hide';
  static const String optional = 'Optional';
  static const String load = 'Load';
  
  // 主机管理
  static const String addHost = 'Add Host';
  static const String editHost = 'Edit Host';
  static const String hostList = 'Host List';
  static const String hostName = 'Name';
  static const String hostname = 'Host Address';
  static const String address = 'Address';
  static const String port = 'Port';
  static const String username = 'Username';
  static const String password = 'Password';
  static const String passwordKeepEmpty = 'Password (leave empty to keep unchanged)';
  static const String newPassword = 'New Password';
  static const String serverName = 'Server Name';
  static const String ipOrDomain = 'IP or Domain';
  static const String savePassword = 'Save Password';
  static const String noHosts = 'No hosts yet';
  static const String clickToAddHost = 'Click + to add a host';
  static const String selectHostToView = 'Select a host to view details';
  static const String selectHostToConnect = 'Select a host to connect';
  static const String clickToConnect = 'Click ⏻ to connect';
  static const String addHostTooltip = 'Add Host';
  static const String hostUpdated = 'Host updated';
  
  // 对话框
  static const String clearAllData = 'Clear All Data';
  static const String clearAllDataMessage = 'This will delete all saved hosts and passwords.\\nThis action cannot be undone.';
  static const String enterPassword = 'Enter Password';
  static const String sshPassword = 'SSH Password';
  static const String confirmDelete = 'Confirm Delete';
  static const String deleteHostMessage = 'Are you sure you want to delete this host?';
  static String confirmDeleteHost(String name) => 'Are you sure you want to delete host "$name"?';
  
  // 消息
  static const String connectionFailed = 'Connection failed';
  static const String uploadSuccess = 'Upload success';
  static const String uploadFailed = 'Upload failed';
  static const String downloadSuccess = 'Download success';
  static const String downloadFailed = 'Download failed';
  static const String loadFilesFailed = 'Failed to load files';
  static const String waitForTransfer = 'Please wait for current transfer to complete';
  static const String transferInProgress = 'File Transfer in Progress';
  static const String transferContinueInBackground = 'A file transfer is in progress. If you disconnect, the transfer will continue in the background.';
  static const String allDataCleared = 'All data cleared';
  static const String uploading = 'Uploading';
  static const String downloading = 'Downloading';
  static const String verifyingMd5 = 'Verifying MD5...';
  static const String md5Mismatch = 'MD5 mismatch, retrying...';
  static const String uploadProgress = 'Uploading {current}/{total}';
  static const String connected = 'Connected';
  static const String connecting = 'Connecting';
  static const String hostSaved = 'Host saved';
  static const String hostDeleted = 'Host deleted';
  
  // 语言
  static const String language = 'Language';
  static const String english = 'English';
  static const String chinese = '中文';
  
  // 搜索
  static const String search = 'Search';
  static const String searchPlaceholder = 'Search...';
  static const String noResults = 'No results';
  
  // 文件管理
  static const String files = 'Files';
  static const String terminal = 'Terminal';
  static const String parentDirectory = 'Parent Directory';
  static const String enterPath = 'Enter path...';
  static const String clickToLoadFiles = 'Click to load files';
  static const String connectToViewFiles = 'Connect to view files';
  
  // 传输任务面板
  static const String transferTasks = 'Transfer Tasks';
  static const String noTransferTasks = 'No transfer tasks';
  static const String clearCompleted = 'Clear Completed';
  static const String viewDetails = 'View Details';
  static const String pending = 'Pending';
  static const String verifying = 'Verifying';
  static const String completed = 'Completed';
  static const String failed = 'Failed';
  static const String cancelled = 'Cancelled';
  static const String cancelTransfer = 'Cancel';
  static const String deleteWithFile = 'Delete';
  static const String resumeTransfer = 'Resume';
  
  // Terminal operations
  static const String copy = 'Copy';
  static const String paste = 'Paste';
  static const String selectAll = 'Select All';
  static const String clearScreen = 'Clear';
  
  // SSH authentication
  static const String authType = 'Authentication';
  static const String passwordAuth = 'Password';
  static const String privateKeyAuth = 'Private Key';
  static const String privateKeyPath = 'Private Key File';
  static const String selectPrivateKey = 'Select Key';
  static const String passphrase = 'Passphrase';
  static const String passphraseHint = 'Leave empty if none';
  static const String keyFileNotFound = 'Private key file not found';
  
  // Groups
  static const String defaultGroup = 'Default';
  static const String newGroup = 'New Group';
  static const String groupName = 'Group Name';
  static const String editGroup = 'Edit Group';
  static const String deleteGroup = 'Delete Group';
  static const String deleteGroupConfirm = 'Hosts in this group will be moved to default group';
  static const String group = 'Group';
  static const String noGroup = 'No Group';
  static const String moveTo = 'Move to';
  
  // File operations
  static const String deleteFile = 'Delete';
  static const String deleteFileConfirm = 'Are you sure you want to delete this file?';
  static const String deleteFolderConfirm = 'Are you sure you want to delete this folder and all its contents?';
  static const String newFolder = 'New Folder';
  static const String folderName = 'Folder Name';
  static const String fileDeleted = 'File deleted';
  static const String folderCreated = 'Folder created';
  static const String renamed = 'Renamed successfully';
  static const String deleteFailed = 'Delete failed';
  static const String operationFailed = 'Operation failed';
  static const String rename = 'Rename';
  
  // Import/Export
  static const String exportData = 'Export';
  static const String importData = 'Import';
  static const String exportSuccess = 'Export successful';
  static const String importSuccess = 'Import successful';
  static const String importFailed = 'Import failed';
  static const String exportFailed = 'Export failed';
  static const String invalidFileFormat = 'Invalid file format';
  static String importResult(int hosts, int groups) => 'Imported $hosts hosts and $groups groups';
  static const String mergeImport = 'Merge';
  static const String overwriteImport = 'Overwrite';
  static const String importModeTitle = 'Choose Import Mode';
  static const String mergeImportDesc = 'Keep existing data, only add new hosts and groups';
  static const String overwriteImportDesc = 'Clear existing data and use imported configuration';
}
