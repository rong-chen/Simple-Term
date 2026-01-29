//
//  LiquidGlassViewManager.m
//  yzTermApp-macOS
//
//  Objective-C bridge for LiquidGlassViewManager
//

#import <React/RCTViewManager.h>

@interface RCT_EXTERN_MODULE(LiquidGlassViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(blendMode, NSString)
RCT_EXPORT_VIEW_PROPERTY(materialType, NSString)
RCT_EXPORT_VIEW_PROPERTY(effectState, NSString)
RCT_EXPORT_VIEW_PROPERTY(borderRadius, CGFloat)

@end
