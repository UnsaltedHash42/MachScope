#import "include/SecBridge.h"

@implementation SecBridge

+ (CFDictionaryRef)copySigningInfoForPath:(NSString *)path error:(OSStatus *)errorCode {
    if (errorCode) { *errorCode = errSecSuccess; }
    if (path.length == 0) { if (errorCode) { *errorCode = errSecParam; } return NULL; }

    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    SecStaticCodeRef staticCode = NULL;
    OSStatus status = SecStaticCodeCreateWithPath(url, kSecCSDefaultFlags, &staticCode);
    if (status != errSecSuccess) { if (errorCode) { *errorCode = status; } return NULL; }

    CFDictionaryRef signingInfo = NULL;
    status = SecCodeCopySigningInformation(staticCode, kSecCSSigningInformation, &signingInfo);
    CFRelease(staticCode);
    if (status != errSecSuccess) { if (errorCode) { *errorCode = status; } return NULL; }
    return signingInfo; // retained for caller
}

+ (CFDictionaryRef)copyAssessmentForPath:(NSString *)path operation:(NSString *)operation error:(OSStatus *)errorCode {
    if (errorCode) { *errorCode = errSecSuccess; }
    if (path.length == 0) { if (errorCode) { *errorCode = errSecParam; } return NULL; }

    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CFMutableDictionaryRef assessmentParams = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFCopyStringDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    // Avoid compile-time dependency on SecAssessment.h by using string keys and dlsym lookup
    if (operation != nil) {
        CFStringRef opString = NULL;
        if ([operation isEqualToString:@"execute"]) {
            opString = CFSTR("execute");
        } else if ([operation isEqualToString:@"install"]) {
            opString = CFSTR("install");
        } else {
            if (assessmentParams) CFRelease(assessmentParams);
            if (errorCode) { *errorCode = errSecParam; }
            return NULL;
        }
        CFDictionarySetValue(assessmentParams, CFSTR("operation"), opString);
    }

    CFDictionaryRef assessmentResult = NULL;
    typedef OSStatus (*SecAssessmentCopyResultFn)(CFTypeRef, CFOptionFlags, CFDictionaryRef, CFTypeRef *);
    SecAssessmentCopyResultFn fn = (SecAssessmentCopyResultFn)dlsym(RTLD_DEFAULT, "SecAssessmentCopyResult");
    if (fn == NULL) {
        if (assessmentParams) CFRelease(assessmentParams);
        if (errorCode) { *errorCode = errSecUnimplemented; }
        return NULL;
    }
    OSStatus status = fn(url, 0, assessmentParams, (CFTypeRef *)&assessmentResult);
    if (assessmentParams) CFRelease(assessmentParams);
    if (status != errSecSuccess) { if (errorCode) { *errorCode = status; } return NULL; }
    return assessmentResult; // retained for caller
}

+ (NSArray *)copyCertificateSummariesForPath:(NSString *)path error:(OSStatus *)errorCode {
    if (errorCode) { *errorCode = errSecSuccess; }
    if (path.length == 0) { if (errorCode) { *errorCode = errSecParam; } return nil; }

    CFDictionaryRef info = [self copySigningInfoForPath:path error:errorCode];
    if (info == NULL) return nil;
    CFArrayRef certs = CFDictionaryGetValue(info, kSecCodeInfoCertificates);
    NSMutableArray *summaries = [NSMutableArray array];
    if (certs && CFGetTypeID(certs) == CFArrayGetTypeID()) {
        CFIndex count = CFArrayGetCount(certs);
        for (CFIndex i = 0; i < count; i++) {
            SecCertificateRef cert = (SecCertificateRef)CFArrayGetValueAtIndex(certs, i);
            if (!cert) continue;
            CFStringRef subject = SecCertificateCopySubjectSummary(cert);
            // SHA-256
            CFDataRef data = SecCertificateCopyData(cert);
            unsigned char hash[CC_SHA256_DIGEST_LENGTH];
            CC_SHA256(CFDataGetBytePtr(data), (CC_LONG)CFDataGetLength(data), hash);
            CFRelease(data);
            NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
            for (int j=0;j<CC_SHA256_DIGEST_LENGTH;j++){ [hex appendFormat:@"%02x", hash[j]]; }
            [summaries addObject:@{ @"subject": (__bridge_transfer NSString *)subject ?: @"",
                                    @"sha256": hex }];
        }
    }
    if (info) CFRelease(info);
    return summaries;
}

@end


