// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCHashID.h"
#import "LTCData.h"

NSData* LTCHashFromID(NSString* identifier) {
    return LTCReversedData(LTCDataFromHex(identifier));
}

NSString* LTCIDFromHash(NSData* hash) {
    return LTCHexFromData(LTCReversedData(hash));
}
