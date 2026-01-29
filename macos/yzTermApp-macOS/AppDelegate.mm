#import "AppDelegate.h"

#import <React/RCTBundleURLProvider.h>
#import <ReactAppDependencyProvider/RCTAppDependencyProvider.h>
#import <objc/runtime.h>

// 拦截 Find 相关 action，防止 WebView 崩溃
@interface NSApplication (FindPanelOverride)
@end

@implementation NSApplication (FindPanelOverride)

// 拦截 sendAction，阻止 Find 相关操作
- (BOOL)custom_sendAction:(SEL)action to:(id)target from:(id)sender {
  NSString *actionName = NSStringFromSelector(action);
  // 拦截所有 Find 相关的 action
  if ([actionName containsString:@"find"] || 
      [actionName containsString:@"Find"] ||
      [actionName isEqualToString:@"performFindPanelAction:"] ||
      [actionName isEqualToString:@"performTextFinderAction:"]) {
    NSLog(@"Blocked find action: %@", actionName);
    return NO;  // 阻止这个 action
  }
  return [self custom_sendAction:action to:target from:sender];
}

+ (void)load {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    // 交换 sendAction:to:from: 方法
    Class class = [NSApplication class];
    SEL originalSelector = @selector(sendAction:to:from:);
    SEL swizzledSelector = @selector(custom_sendAction:to:from:);
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    if (originalMethod && swizzledMethod) {
      method_exchangeImplementations(originalMethod, swizzledMethod);
    }
  });
}

@end

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
    
    // 添加全局和本地事件监控器拦截 Cmd+F
    // 全局监控器 - 拦截所有事件（包括其他应用，但我们只消费自己窗口的）
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
      // 检测 Cmd+F (keyCode 3 = F 键)
      if ((event.modifierFlags & NSEventModifierFlagCommand) && 
          !(event.modifierFlags & NSEventModifierFlagShift) &&
          !(event.modifierFlags & NSEventModifierFlagOption) &&
          event.keyCode == 3) {
        NSLog(@"[AppDelegate] Intercepted Cmd+F - blocking to prevent WebView crash");
        return nil;  // 消费事件，不传递
      }
      return event;
    }];
  });
  
  // 拦截 Cmd+F 防止 WebView 查找功能崩溃
  // 方法：直接移除 Edit 菜单中的 Find 相关菜单项
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMenu *mainMenu = [[NSApplication sharedApplication] mainMenu];
    for (NSMenuItem *menuItem in [mainMenu itemArray]) {
      if ([[menuItem title] isEqualToString:@"Edit"]) {
        NSMenu *editMenu = [menuItem submenu];
        // 找到并移除 Find 子菜单
        NSArray *itemsToRemove = @[@"Find", @"Find and Replace", @"Find Next", @"Find Previous", @"Use Selection for Find"];
        for (NSString *title in itemsToRemove) {
          NSInteger index = [editMenu indexOfItemWithTitle:title];
          if (index >= 0) {
            [editMenu removeItemAtIndex:index];
          }
        }
        // 也尝试移除包含 "Find" 的任何项
        NSMutableArray *indicesToRemove = [NSMutableArray array];
        for (NSInteger i = 0; i < [editMenu numberOfItems]; i++) {
          NSMenuItem *item = [editMenu itemAtIndex:i];
          if ([[item title] containsString:@"Find"]) {
            [indicesToRemove addObject:@(i)];
          }
        }
        // 从后往前删除
        for (NSNumber *idx in [[indicesToRemove reverseObjectEnumerator] allObjects]) {
          [editMenu removeItemAtIndex:[idx integerValue]];
        }
        break;
      }
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
