import 'package:flutter/material.dart';
import 'strings_en.dart';
import 'strings_zh.dart';

/// 应用本地化类
class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);
  
  /// 便捷访问方法
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }
  
  /// 支持的语言列表
  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ];
  
  /// 获取语言显示名称
  static String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'zh':
        return '中文';
      case 'en':
        return 'English';
      default:
        return locale.languageCode;
    }
  }
  
  bool get isZh => locale.languageCode == 'zh';
  
  // 应用
  String get appTitle => isZh ? StringsZh.appTitle : StringsEn.appTitle;
  
  // 通用按钮
  String get cancel => isZh ? StringsZh.cancel : StringsEn.cancel;
  String get confirm => isZh ? StringsZh.confirm : StringsEn.confirm;
  String get save => isZh ? StringsZh.save : StringsEn.save;
  String get saveChanges => isZh ? StringsZh.saveChanges : StringsEn.saveChanges;
  String get delete => isZh ? StringsZh.delete : StringsEn.delete;
  String get edit => isZh ? StringsZh.edit : StringsEn.edit;
  String get connect => isZh ? StringsZh.connect : StringsEn.connect;
  String get disconnect => isZh ? StringsZh.disconnect : StringsEn.disconnect;
  String get clear => isZh ? StringsZh.clear : StringsEn.clear;
  String get close => isZh ? StringsZh.close : StringsEn.close;
  String get upload => isZh ? StringsZh.upload : StringsEn.upload;
  String get download => isZh ? StringsZh.download : StringsEn.download;
  String get refresh => isZh ? StringsZh.refresh : StringsEn.refresh;
  String get show => isZh ? StringsZh.show : StringsEn.show;
  String get hide => isZh ? StringsZh.hide : StringsEn.hide;
  String get optional => isZh ? StringsZh.optional : StringsEn.optional;
  String get load => isZh ? StringsZh.load : StringsEn.load;
  
  // 主机管理
  String get addHost => isZh ? StringsZh.addHost : StringsEn.addHost;
  String get editHost => isZh ? StringsZh.editHost : StringsEn.editHost;
  String get hostList => isZh ? StringsZh.hostList : StringsEn.hostList;
  String get hostName => isZh ? StringsZh.hostName : StringsEn.hostName;
  String get hostname => isZh ? StringsZh.hostname : StringsEn.hostname;
  String get address => isZh ? StringsZh.address : StringsEn.address;
  String get port => isZh ? StringsZh.port : StringsEn.port;
  String get username => isZh ? StringsZh.username : StringsEn.username;
  String get password => isZh ? StringsZh.password : StringsEn.password;
  String get passwordKeepEmpty => isZh ? StringsZh.passwordKeepEmpty : StringsEn.passwordKeepEmpty;
  String get newPassword => isZh ? StringsZh.newPassword : StringsEn.newPassword;
  String get serverName => isZh ? StringsZh.serverName : StringsEn.serverName;
  String get ipOrDomain => isZh ? StringsZh.ipOrDomain : StringsEn.ipOrDomain;
  String get savePassword => isZh ? StringsZh.savePassword : StringsEn.savePassword;
  String get noHosts => isZh ? StringsZh.noHosts : StringsEn.noHosts;
  String get clickToAddHost => isZh ? StringsZh.clickToAddHost : StringsEn.clickToAddHost;
  String get selectHostToView => isZh ? StringsZh.selectHostToView : StringsEn.selectHostToView;
  String get selectHostToConnect => isZh ? StringsZh.selectHostToConnect : StringsEn.selectHostToConnect;
  String get clickToConnect => isZh ? StringsZh.clickToConnect : StringsEn.clickToConnect;
  String get addHostTooltip => isZh ? StringsZh.addHostTooltip : StringsEn.addHostTooltip;
  String get hostUpdated => isZh ? StringsZh.hostUpdated : StringsEn.hostUpdated;
  
  // 对话框
  String get clearAllData => isZh ? StringsZh.clearAllData : StringsEn.clearAllData;
  String get clearAllDataMessage => isZh ? StringsZh.clearAllDataMessage : StringsEn.clearAllDataMessage;
  String get enterPassword => isZh ? StringsZh.enterPassword : StringsEn.enterPassword;
  String get sshPassword => isZh ? StringsZh.sshPassword : StringsEn.sshPassword;
  String get confirmDelete => isZh ? StringsZh.confirmDelete : StringsEn.confirmDelete;
  String get deleteHostMessage => isZh ? StringsZh.deleteHostMessage : StringsEn.deleteHostMessage;
  String confirmDeleteHost(String name) => isZh ? StringsZh.confirmDeleteHost(name) : StringsEn.confirmDeleteHost(name);
  
  // 消息
  String get connectionFailed => isZh ? StringsZh.connectionFailed : StringsEn.connectionFailed;
  String get uploadSuccess => isZh ? StringsZh.uploadSuccess : StringsEn.uploadSuccess;
  String get uploadFailed => isZh ? StringsZh.uploadFailed : StringsEn.uploadFailed;
  String get downloadSuccess => isZh ? StringsZh.downloadSuccess : StringsEn.downloadSuccess;
  String get downloadFailed => isZh ? StringsZh.downloadFailed : StringsEn.downloadFailed;
  String get loadFilesFailed => isZh ? StringsZh.loadFilesFailed : StringsEn.loadFilesFailed;
  String get waitForTransfer => isZh ? StringsZh.waitForTransfer : StringsEn.waitForTransfer;
  String get transferInProgress => isZh ? StringsZh.transferInProgress : StringsEn.transferInProgress;
  String get transferContinueInBackground => isZh ? StringsZh.transferContinueInBackground : StringsEn.transferContinueInBackground;
  String get allDataCleared => isZh ? StringsZh.allDataCleared : StringsEn.allDataCleared;
  String get uploading => isZh ? StringsZh.uploading : StringsEn.uploading;
  String get downloading => isZh ? StringsZh.downloading : StringsEn.downloading;
  String get connected => isZh ? StringsZh.connected : StringsEn.connected;
  String get connecting => isZh ? StringsZh.connecting : StringsEn.connecting;
  String get hostSaved => isZh ? StringsZh.hostSaved : StringsEn.hostSaved;
  String get hostDeleted => isZh ? StringsZh.hostDeleted : StringsEn.hostDeleted;
  String get verifyingMd5 => isZh ? StringsZh.verifyingMd5 : StringsEn.verifyingMd5;
  String get md5Mismatch => isZh ? StringsZh.md5Mismatch : StringsEn.md5Mismatch;
  String uploadProgressText(int current, int total) => 
      (isZh ? StringsZh.uploadProgress : StringsEn.uploadProgress)
          .replaceAll('{current}', current.toString())
          .replaceAll('{total}', total.toString());
  
  // 语言
  String get language => isZh ? StringsZh.language : StringsEn.language;
  String get english => isZh ? StringsZh.english : StringsEn.english;
  String get chinese => isZh ? StringsZh.chinese : StringsEn.chinese;
  
  // 搜索
  String get search => isZh ? StringsZh.search : StringsEn.search;
  String get searchPlaceholder => isZh ? StringsZh.searchPlaceholder : StringsEn.searchPlaceholder;
  String get noResults => isZh ? StringsZh.noResults : StringsEn.noResults;
  
  // 文件管理
  String get files => isZh ? StringsZh.files : StringsEn.files;
  String get terminal => isZh ? StringsZh.terminal : StringsEn.terminal;
  String get parentDirectory => isZh ? StringsZh.parentDirectory : StringsEn.parentDirectory;
  String get enterPath => isZh ? StringsZh.enterPath : StringsEn.enterPath;
  String get clickToLoadFiles => isZh ? StringsZh.clickToLoadFiles : StringsEn.clickToLoadFiles;
  String get connectToViewFiles => isZh ? StringsZh.connectToViewFiles : StringsEn.connectToViewFiles;
  
  // 传输任务面板
  String get transferTasks => isZh ? StringsZh.transferTasks : StringsEn.transferTasks;
  String get noTransferTasks => isZh ? StringsZh.noTransferTasks : StringsEn.noTransferTasks;
  String get clearCompleted => isZh ? StringsZh.clearCompleted : StringsEn.clearCompleted;
  String get viewDetails => isZh ? StringsZh.viewDetails : StringsEn.viewDetails;
  String get pending => isZh ? StringsZh.pending : StringsEn.pending;
  String get verifying => isZh ? StringsZh.verifying : StringsEn.verifying;
  String get completed => isZh ? StringsZh.completed : StringsEn.completed;
  String get failed => isZh ? StringsZh.failed : StringsEn.failed;
  String get cancelled => isZh ? StringsZh.cancelled : StringsEn.cancelled;
  String get cancelTransfer => isZh ? StringsZh.cancelTransfer : StringsEn.cancelTransfer;
  String get deleteWithFile => isZh ? StringsZh.deleteWithFile : StringsEn.deleteWithFile;
  String get resumeTransfer => isZh ? StringsZh.resumeTransfer : StringsEn.resumeTransfer;
}

/// 本地化代理
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();
  
  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh'].contains(locale.languageCode);
  }
  
  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }
  
  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
