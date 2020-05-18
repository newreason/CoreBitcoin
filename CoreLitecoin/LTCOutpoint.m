// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCOutpoint.h"
#import "LTCTransaction.h"
#import "LTCHashID.h"

@implementation LTCOutpoint

- (id) initWithHash:(NSData*)hash index:(uint32_t)index {
    if (hash.length != 32) return nil;
    if (self = [super init]) {
        _txHash = hash;
        _index = index;
    }
    return self;
}

- (id) initWithTxID:(NSString*)txid index:(uint32_t)index {
    NSData* hash = LTCHashFromID(txid);
    return [self initWithHash:hash index:index];
}

- (NSString*) txID {
    return LTCIDFromHash(self.txHash);
}

- (void) setTxID:(NSString *)txID {
    self.txHash = LTCHashFromID(txID);
}

- (NSUInteger) hash {
    const NSUInteger* words = _txHash.bytes;
    return words[0] + self.index;
}

- (BOOL) isEqual:(LTCOutpoint*)object {
    return [self.txHash isEqual:object.txHash] && self.index == object.index;
}

- (id) copyWithZone:(NSZone *)zone {
    return [[LTCOutpoint alloc] initWithHash:_txHash index:_index];
}

@end
