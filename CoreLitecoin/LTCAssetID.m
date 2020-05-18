// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCAssetID.h"
#import "LTCAddressSubclass.h"

static const uint8_t LTCAssetIDVersionMainnet = 23; // "A" prefix
static const uint8_t LTCAssetIDVersionTestnet = 115;

@implementation LTCAssetID

+ (void) load {
    [LTCAddress registerAddressClass:self version:LTCAssetIDVersionMainnet];
    [LTCAddress registerAddressClass:self version:LTCAssetIDVersionTestnet];
}

#define LTCAssetIDLength 20

+ (instancetype) assetIDWithString:(NSString*)string {
    return [self addressWithString:string];
}

+ (instancetype) assetIDWithHash:(NSData*)data {
    if (!data) return nil;
    if (data.length != LTCAssetIDLength) {
        NSLog(@"+[LTCAssetID addressWithData] cannot init with hash %d bytes long", (int)data.length);
        return nil;
    }
    LTCAssetID* addr = [[self alloc] init];
    addr.data = [NSMutableData dataWithData:data];
    return addr;
}

+ (instancetype) addressWithComposedData:(NSData*)composedData cstring:(const char*)cstring version:(uint8_t)version {
    if (composedData.length != (1 + LTCAssetIDLength)) {
        NSLog(@"LTCAssetID: cannot init with %d bytes (need 20+1 bytes)", (int)composedData.length);
        return nil;
    }
    LTCAssetID* addr = [[self alloc] init];
    addr.data = [[NSMutableData alloc] initWithBytes:((const char*)composedData.bytes) + 1 length:composedData.length - 1];
    return addr;
}

- (NSMutableData*) dataForBase58Encoding {
    NSMutableData* data = [NSMutableData dataWithLength:1 + LTCAssetIDLength];
    char* buf = data.mutableBytes;
    buf[0] = [self versionByte];
    memcpy(buf + 1, self.data.bytes, LTCAssetIDLength);
    return data;
}

- (uint8_t) versionByte {
// TODO: support testnet
    return LTCAssetIDVersionMainnet;
}


@end
