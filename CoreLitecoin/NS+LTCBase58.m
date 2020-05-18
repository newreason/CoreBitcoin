// Oleg Andreev <oleganza@gmail.com>

#import "NS+LTCBase58.h"

// TODO.

@implementation NSString (LTCBase58)

- (NSMutableData*) dataFromBase58 { return LTCDataFromBase58(self); }
- (NSMutableData*) dataFromBase58Check { return LTCDataFromBase58Check(self); }
@end


@implementation NSMutableData (LTCBase58)

+ (NSMutableData*) dataFromBase58CString:(const char*)cstring {
    return LTCDataFromBase58CString(cstring);
}

+ (NSMutableData*) dataFromBase58CheckCString:(const char*)cstring {
    return LTCDataFromBase58CheckCString(cstring);
}

@end


@implementation NSData (LTCBase58)

- (char*) base58CString {
    return LTCBase58CStringWithData(self);
}

- (char*) base58CheckCString {
    return LTCBase58CheckCStringWithData(self);
}

- (NSString*) base58String {
    return LTCBase58StringWithData(self);
}

- (NSString*) base58CheckString {
    return LTCBase58CheckStringWithData(self);
}


@end
