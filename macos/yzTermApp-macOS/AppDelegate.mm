#import "AppDelegate.h"

#import <React/RCTBundleURLProvider.h>
#import <ReactAppDependencyProvider/RCTAppDependencyProvider.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  self.moduleName = @"yzTermApp";
  // You can add your custom initial props in the dictionary below.
  // They will be passed down to the ViewController used by React Native.
  self.initialProps = @{};
  self.dependencyProvider = [RCTAppDependencyProvider new];
  
  [super applicationDidFinishLaunching:notification];
  
  // 设置窗口大小和外观
  dispatch_async(dispatch_get_main_queue(), ^{
    NSWindow *window = [[NSApplication sharedApplication] mainWindow];
    if (window) {
      // 设置初始窗口大小 1024x768
      [window setFrame:NSMakeRect(0, 0, 1024, 768) display:YES];
      [window center];
      
      // 隐藏窗口标题栏
      window.titlebarAppearsTransparent = YES;
      window.titleVisibility = NSWindowTitleHidden;
      window.styleMask |= NSWindowStyleMaskFullSizeContentView;
      
      // 防止窗口关闭时被释放，以便可以重新打开
      window.releasedWhenClosed = NO;
    }
  });
}

// 处理点击 Dock 图标重新打开窗口
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
  if (!flag) {
    // 没有可见窗口时，重新显示主窗口
    for (NSWindow *window in sender.windows) {
      if ([window isKindOfClass:[NSWindow class]]) {
        [window makeKeyAndOrderFront:self];
        return YES;
      }
    }
  }
  return YES;
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [self bundleURL];
}

- (NSURL *)bundleURL
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

/// This method controls whether the `concurrentRoot`feature of React18 is turned on or off.
///
/// @see: https://reactjs.org/blog/2022/03/29/react-v18.html
/// @note: This requires to be rendering on Fabric (i.e. on the New Architecture).
/// @return: `true` if the `concurrentRoot` feature is enabled. Otherwise, it returns `false`.
- (BOOL)concurrentRootEnabled
{
#ifdef RN_FABRIC_ENABLED
  return true;
#else
  return false;
#endif
}

@end
