#import "ImageCachePlugin.h"
#import <CommonCrypto/CommonDigest.h>
#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

@interface ImageCachePlugin()

@end

@implementation ImageCachePlugin {
    NSString* callbackId;
}

- (NSString *)sha1:(NSString*)str
{
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];

    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];

    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
    {
        [output appendFormat:@"%02x", digest[i]];
    }

    return output;
}

- (void)storeKey:(CDVInvokedUrlCommand*)command {
    __weak ImageCachePlugin* weakSelf = self;

    [self.commandDelegate runInBackground:^ {
        callbackId = command.callbackId;
        CDVPluginResult *result;

        NSString *key = [self sha1:command.arguments[0]];
        long timestamp = [command.arguments[1] longValue];
        NSDictionary *data = command.arguments[2];
        NSString *mime = command.arguments[3];
        int dataSize = [command.arguments[4] intValue];

        NSString* tmpDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        tmpDirectory = [tmpDirectory stringByAppendingPathComponent:@"imagecache"];
        NSString *tmpFile = [tmpDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", key, @".tmp"]];
//        NSLog(@"Temp File:%@", tmpFile);

        if (![[NSFileManager defaultManager] fileExistsAtPath:tmpDirectory])
        {
            [[NSFileManager defaultManager] createDirectoryAtPath:tmpDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
        }

        if ([[NSFileManager defaultManager] fileExistsAtPath:tmpFile])
        {
            [[NSFileManager defaultManager] removeItemAtPath:tmpFile error:NULL];
        }

        @try {
            NSOutputStream* fileStream = [NSOutputStream outputStreamToFileAtPath:tmpFile append:false];
            if (fileStream) {
                [fileStream open];
                int bytesWritten = 0;

                // write timestamp
                bytesWritten += (int)[fileStream write:(uint8_t*)&timestamp maxLength:sizeof(timestamp)];

                // write mime/type
                NSData *mimeData = [mime dataUsingEncoding:NSUTF8StringEncoding];
                NSUInteger mimeLength = [mimeData length];
                bytesWritten += (int)[fileStream write:(uint8_t*)&mimeLength maxLength:sizeof(NSUInteger)];
                bytesWritten += (int)[fileStream write:[mimeData bytes] maxLength:[mimeData length]];

                // write data
                bytesWritten += (int)[fileStream write:(uint8_t*)&dataSize maxLength:sizeof(dataSize)];

                NSArray *keys = [data allKeys];
                keys = [keys sortedArrayUsingComparator:^(id a, id b) {
                    return [a compare:b options:NSNumericSearch];
                }];
                long keysLength = keys.count;
                int i;
                for (i = 0; i < keysLength; i++) {
                    id key = [keys objectAtIndex:i];
                    uint8_t val = (uint8_t)([[data objectForKey:key] integerValue] & 0xFF);
                    bytesWritten += (int)[fileStream write:&val maxLength:1];
                }

                [fileStream close];
                if (bytesWritten > 0) {
                    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:bytesWritten];
                } else {
                    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Write error"];
                }
            }
        }
        @catch(NSException *e) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"exception"];
        }

        [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
    }];
}

- (void)appendKey:(CDVInvokedUrlCommand*)command {
    __weak ImageCachePlugin* weakSelf = self;

    [self.commandDelegate runInBackground:^ {
        callbackId = command.callbackId;
        CDVPluginResult *result;

        NSString *key = [self sha1:command.arguments[0]];
        NSDictionary *data = command.arguments[1];

        NSString* tmpDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        tmpDirectory = [tmpDirectory stringByAppendingPathComponent:@"imagecache"];
        NSString *tmpFile = [tmpDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", key, @".tmp"]];
//        NSLog(@"Temp File:%@", tmpFile);

        if (![[NSFileManager defaultManager] fileExistsAtPath:tmpFile])
        {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"tmp file to append is not found"];
            [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
            return;
        }

        @try {
            NSOutputStream* fileStream = [NSOutputStream outputStreamToFileAtPath:tmpFile append:true];
            if (fileStream) {
                [fileStream open];
                int bytesWritten = 0;

    //            NSLog(@"append data length: %d", data.count);

                NSArray *keys = [data allKeys];
                keys = [keys sortedArrayUsingComparator:^(id a, id b) {
                    return [a compare:b options:NSNumericSearch];
                }];
                long keysLength = keys.count;
                int i;
                for (i = 0; i < keysLength; i++) {
                    id key = [keys objectAtIndex:i];
                    uint8_t val = (uint8_t)([[data objectForKey:key] integerValue] & 0xFF);
                    bytesWritten += (int)[fileStream write:&val maxLength:1];
                }

                [fileStream close];
                if (bytesWritten > 0) {
                    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:bytesWritten];
                } else {
                    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Write error"];
                }
            }
        }
        @catch(NSException *e) {
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"exception"];
        }
        [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
    }];
}

- (void)getKey:(CDVInvokedUrlCommand*)command {
    __weak ImageCachePlugin* weakSelf = self;

    [self.commandDelegate runInBackground:^ {
        callbackId = command.callbackId;
        CDVPluginResult *result;

        NSString *key = [self sha1:command.arguments[0]];
        long timestamp = [command.arguments[1] longValue];

        NSData *databuffer;
        NSString *mime;
        NSMutableArray *imageData = [[NSMutableArray alloc] init];

        NSString* tmpDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        tmpDirectory = [tmpDirectory stringByAppendingPathComponent:@"imagecache"];
        NSString *tmpFile = [tmpDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@", key, @".tmp"]];
//        NSLog(@"Temp File:%@", tmpFile);
        NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:tmpFile];

        if (file == nil) {
            NSLog(@"Failed to open file: %@", tmpFile);
            result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"File not found"];
        } else {
            @try {
                databuffer = [file readDataOfLength: sizeof(long)];
                long inTimestamp = *(long*) [databuffer bytes];

                if(inTimestamp < timestamp) {
                    [file closeFile];
                    [[NSFileManager defaultManager] removeItemAtPath:tmpFile error:NULL];
                    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"timestamp is old"];
                    [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
                    return;
                }

                NSUInteger mimeLength;
                databuffer = [file readDataOfLength: sizeof(mimeLength)];
                mimeLength = *(NSUInteger*) [databuffer bytes];

                databuffer = [file readDataOfLength: mimeLength];
                mime = [NSString stringWithUTF8String:[databuffer bytes]];

                databuffer = [file readDataOfLength: sizeof(int)];
                int dataSize = *(int*) [databuffer bytes];

                int i;
                for (i = 0; i < dataSize; i++) {
                    databuffer = [file readDataOfLength: 1];
                    // eof
                    if ([databuffer length] == 0) {
                        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"eof"];
                        [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
                        return;
                    }
                    int val = *(int*)[databuffer bytes];
                    [imageData addObject:@(val)];
                }

                [file closeFile];
            }
            @catch(NSException *e) {
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"exception"];
                [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
                return;
            }

            @try {
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{
                    @"timestamp": [NSString stringWithFormat:@"%ld", timestamp],
                    @"mimeType": mime,
                    @"imageData": imageData
                    }];
            }
            @catch(NSException *e) {
                 result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"exception"];
            }
        }

        [weakSelf.commandDelegate sendPluginResult:result callbackId:callbackId];
    }];
}

@end
