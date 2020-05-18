// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCAssetAddress.h"
#import "LTCData.h"
#import "LTCBase58.h"

@interface LTCAssetAddress ()
@property(nonatomic, readwrite) LTCAddress* bitcoinAddress;
@end

// OpenAssets Address, e.g. akB4NBW9UuCmHuepksob6yfZs6naHtRCPNy (corresponds to 16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM)
@implementation LTCAssetAddress

#define LTCAssetAddressNamespace 0x13

+ (void) load {
    [LTCAddress registerAddressClass:self version:LTCAssetAddressNamespace];
}

+ (instancetype) addressWithBitcoinAddress:(LTCAddress*)btcAddress {
    if (!btcAddress) return nil;
    LTCAssetAddress* addr = [[self alloc] init];
    addr.bitcoinAddress = btcAddress;
    return addr;
}

+ (instancetype) addressWithString:(NSString*)string {
    NSMutableData* composedData = LTCDataFromBase58Check(string);
    uint8_t version = ((unsigned char*)composedData.bytes)[0];
    return [self addressWithComposedData:composedData cstring:[string cStringUsingEncoding:NSUTF8StringEncoding] version:version];
}

+ (instancetype) addressWithComposedData:(NSData*)composedData cstring:(const char*)cstring version:(uint8_t)version {
    if (!composedData) return nil;
    if (composedData.length < 2) return nil;

    if (version == LTCAssetAddressNamespace) { // same for testnet and mainnet
        LTCAddress* btcAddr = [LTCAddress addressWithString:LTCBase58CheckStringWithData([composedData subdataWithRange:NSMakeRange(1, composedData.length - 1)])];
        return [self addressWithBitcoinAddress:btcAddr];
    } else {
        return nil;
    }
}

- (NSMutableData*) dataForBase58Encoding {
    NSMutableData* data = [NSMutableData dataWithLength:1];
    char* buf = data.mutableBytes;
    buf[0] = LTCAssetAddressNamespace;
    [data appendData:[(LTCAssetAddress* /* cast only to expose the method that is defined in LTCAddress anyway */)self.bitcoinAddress dataForBase58Encoding]];
    return data;
}

- (unsigned char) versionByte {
    return LTCAssetAddressNamespace;
}

- (BOOL) isTestnet {
    return self.bitcoinAddress.isTestnet;
}

@end
