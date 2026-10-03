// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];

  FlutterViewController *controller = (FlutterViewController *)self.window.rootViewController;
  FlutterMethodChannel *deviceInfoChannel =
      [FlutterMethodChannel methodChannelWithName:@"savestream/device_info"
                                  binaryMessenger:controller.binaryMessenger];
  [deviceInfoChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    if ([call.method isEqualToString:@"freeStorageBytes"]) {
      NSError *error = nil;
      NSDictionary<NSFileAttributeKey, id> *attributes =
          [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory()
                                                                   error:&error];
      if (error != nil) {
        result([FlutterError errorWithCode:@"storage_unavailable"
                                   message:error.localizedDescription
                                   details:nil]);
        return;
      }
      result(attributes[NSFileSystemFreeSize] ?: @0);
      return;
    }
    result(FlutterMethodNotImplemented);
  }];

  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}
@end
