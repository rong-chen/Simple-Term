//
//  SSHManager.m
//  yzTermApp
//
//  Objective-C bridge for SSHManager Swift module
//

#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(SSHManager, NSObject)

RCT_EXTERN_METHOD(connect:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(getOutput:(NSString *)sessionId
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(write:(NSString *)sessionId
                  data:(NSString *)data
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(execute:(NSString *)sessionId
                  command:(NSString *)command
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(resize:(NSString *)sessionId
                  cols:(NSInteger)cols
                  rows:(NSInteger)rows
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(disconnect:(NSString *)sessionId
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(disconnectAll:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

// 空闲时间检测
RCT_EXTERN_METHOD(getIdleTime:(NSString *)sessionId
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

// SFTP 文件传输方法
RCT_EXTERN_METHOD(uploadFile:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(downloadFile:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(pickFile:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(pickSaveLocation:(NSString *)defaultName
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(listDirectory:(NSDictionary *)config
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

// Keychain 钥匙串方法
RCT_EXTERN_METHOD(savePassword:(NSString *)hostId
                  password:(NSString *)password
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(getPassword:(NSString *)hostId
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

RCT_EXTERN_METHOD(deletePassword:(NSString *)hostId
                  resolver:(RCTPromiseResolveBlock)resolver
                  rejecter:(RCTPromiseRejectBlock)rejecter)

@end
