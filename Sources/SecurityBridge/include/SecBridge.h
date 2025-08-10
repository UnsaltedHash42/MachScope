#import <Foundation/Foundation.h>
#import <Security/Security.h>
#include <dlfcn.h>

NS_ASSUME_NONNULL_BEGIN

/// Minimal Objective-C bridge for Security.framework C APIs used by MachScope.
@interface SecBridge : NSObject

/// Returns a retained CFDictionaryRef with signing information or NULL on failure. Caller owns returned object.
+ (CFDictionaryRef _Nullable)copySigningInfoForPath:(NSString *)path error:(OSStatus *_Nullable)errorCode;

/// Returns a retained CFDictionaryRef with assessment result or NULL on failure. Caller owns returned object.
/// operation: "execute" or "install". Any other value results in no-op (returns NULL and sets errSecParam).
+ (CFDictionaryRef _Nullable)copyAssessmentForPath:(NSString *)path operation:(NSString * _Nullable)operation error:(OSStatus *_Nullable)errorCode;

@end

NS_ASSUME_NONNULL_END


