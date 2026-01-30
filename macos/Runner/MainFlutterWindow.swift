import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    
    // 设置更大的初始窗口尺寸
    let screenSize = NSScreen.main?.frame.size ?? NSSize(width: 1920, height: 1080)
    let windowWidth: CGFloat = min(1400, screenSize.width * 0.8)
    let windowHeight: CGFloat = min(900, screenSize.height * 0.8)
    let windowFrame = NSRect(
      x: (screenSize.width - windowWidth) / 2,
      y: (screenSize.height - windowHeight) / 2,
      width: windowWidth,
      height: windowHeight
    )
    
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    
    // 设置最小窗口尺寸
    self.minSize = NSSize(width: 800, height: 600)
    
    // 隐藏标题文字，设置标题栏颜色
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.backgroundColor = NSColor(red: 0x1e/255.0, green: 0x1e/255.0, blue: 0x1e/255.0, alpha: 1.0)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
