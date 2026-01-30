import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    if let flutterController = controller {
      methodChannel = FlutterMethodChannel(
        name: "com.simpleterm/menu",
        binaryMessenger: flutterController.engine.binaryMessenger
      )
      NSLog("MethodChannel initialized: %@", methodChannel != nil ? "true" : "false")
    }
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  @IBAction func clearAllData(_ sender: Any) {
    NSLog("clearAllData called")
    methodChannel?.invokeMethod("clearAllData", arguments: nil)
  }
  
  @IBAction func setLanguageChinese(_ sender: Any) {
    NSLog("setLanguageChinese called, channel exists: %@", methodChannel != nil ? "true" : "false")
    methodChannel?.invokeMethod("setLanguage", arguments: "zh")
  }
  
  @IBAction func setLanguageEnglish(_ sender: Any) {
    NSLog("setLanguageEnglish called, channel exists: %@", methodChannel != nil ? "true" : "false")
    methodChannel?.invokeMethod("setLanguage", arguments: "en")
  }
}


