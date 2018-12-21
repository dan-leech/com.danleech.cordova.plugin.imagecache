#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>

@interface ImageCachePlugin : CDVPlugin;

- (void)storeKey:(CDVInvokedUrlCommand*)command;
- (void)appendKey:(CDVInvokedUrlCommand*)command;
- (void)getKey:(CDVInvokedUrlCommand*)command;

@end
