// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCPaymentMethod.h"
#import "LTCProtocolBuffers.h"
#import "LTCAssetID.h"
#import "LTCAssetType.h"

//message PaymentMethod {
//    optional bytes             merchant_data = 1;
//    repeated PaymentMethodItem items         = 2;
//}
typedef NS_ENUM(NSInteger, LTCPaymentMethodKey) {
    LTCPaymentMethodKeyMerchantData = 1,
    LTCPaymentMethodKeyItem         = 2,
};


@interface LTCPaymentMethod ()
@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation LTCPaymentMethod

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSMutableArray* items = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case LTCPaymentMethodKeyMerchantData:
                    if (d) _merchantData = d;
                    break;

                case LTCPaymentMethodKeyItem: {
                    if (d) {
                        LTCPaymentMethodItem* item = [[LTCPaymentMethodItem alloc] initWithData:d];
                        [items addObject:item];
                    }
                    break;
                }
                default: break;
            }
        }

        _items = items;
        _data = data;
    }
    return self;
}

- (void) setMerchantData:(NSData * __nullable)merchantData {
    _merchantData = merchantData;
    _data = nil;
}

- (void) setItems:(NSArray * __nullable)items {
    _items = items;
    _data = nil;
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_merchantData) {
            [LTCProtocolBuffers writeData:_merchantData withKey:LTCPaymentMethodKeyMerchantData toData:dst];
        }
        for (LTCPaymentMethodItem* item in _items) {
            [LTCProtocolBuffers writeData:item.data withKey:LTCPaymentMethodKeyItem toData:dst];
        }
        _data = dst;
    }
    return _data;
}

@end




//message PaymentMethodItem {
//    optional string             type                = 1 [default = "default"];
//    optional bytes              item_identifier     = 2;
//    repeated PaymentMethodAsset payment_item_assets = 3;
//}
typedef NS_ENUM(NSInteger, LTCPaymentMethodItemKey) {
    LTCPaymentMethodItemKeyItemType          = 1, // default = "default"
    LTCPaymentMethodItemKeyItemIdentifier    = 2,
    LTCPaymentMethodItemKeyAssets            = 3,
};


@interface LTCPaymentMethodItem ()

@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation LTCPaymentMethodItem

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSMutableArray* assets = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case LTCPaymentMethodItemKeyItemType:
                    if (d) _itemType = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case LTCPaymentMethodItemKeyItemIdentifier:
                    if (d) _itemIdentifier = d;
                    break;
                case LTCPaymentMethodItemKeyAssets: {
                    if (d) {
                        LTCPaymentMethodAsset* asset = [[LTCPaymentMethodAsset alloc] initWithData:d];
                        [assets addObject:asset];
                    }
                    break;
                }
                default: break;
            }
        }

        _assets = assets;
        _data = data;
    }
    return self;
}

- (void) setItemType:(NSString * __nonnull)itemType {
    _itemType = itemType;
    _data = nil;
}

- (void) setItemIdentifier:(NSData * __nullable)itemIdentifier {
    _itemIdentifier = itemIdentifier;
    _data = nil;
}

- (void) setAssets:(NSArray * __nullable)assets {
    _assets = assets;
    _data = nil;
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_itemType) {
            [LTCProtocolBuffers writeString:_itemType withKey:LTCPaymentMethodItemKeyItemType toData:dst];
        }
        if (_itemIdentifier) {
            [LTCProtocolBuffers writeData:_itemIdentifier withKey:LTCPaymentMethodItemKeyItemIdentifier toData:dst];
        }
        for (LTCPaymentMethodItem* item in _assets) {
            [LTCProtocolBuffers writeData:item.data withKey:LTCPaymentMethodItemKeyAssets toData:dst];
        }
        _data = dst;
    }
    return _data;
}

@end






//message PaymentMethodAsset {
//    optional string            asset_id = 1 [default = "default"];
//    optional uint64            amount = 2;
//}
typedef NS_ENUM(NSInteger, LTCPaymentMethodAssetKey) {
    LTCPaymentMethodAssetKeyAssetID = 1,
    LTCPaymentMethodAssetKeyAmount  = 2,
};


@interface LTCPaymentMethodAsset ()

@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation LTCPaymentMethodAsset

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSString* assetIDString = nil;

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case LTCPaymentMethodAssetKeyAssetID:
                    if (d) assetIDString = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case LTCPaymentMethodAssetKeyAmount: {
                    _amount = integer;
                    break;
                }
                default: break;
            }
        }
        if (!assetIDString || [assetIDString isEqual:@"default"]) {
            _assetType = LTCAssetTypeBitcoin;
            _assetID = nil;
        } else {
            _assetID = [LTCAssetID assetIDWithString:assetIDString];
            if (_assetID) {
                _assetType = LTCAssetTypeOpenAssets;
            }
        }
        _data = data;
    }
    return self;
}

- (void) setAssetType:(NSString * __nullable)assetType {
    _assetType = assetType;
    _data = nil;
}

- (void) setAssetID:(LTCAssetID * __nullable)assetID {
    _assetID = assetID;
    _data = nil;
}

- (void) setAmount:(LTCAmount)amount {
    _amount = amount;
    _data = nil;
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if ([_assetType isEqual:LTCAssetTypeBitcoin]) {
            [LTCProtocolBuffers writeString:@"default" withKey:LTCPaymentMethodAssetKeyAssetID toData:dst];
        } else if ([_assetType isEqual:LTCAssetTypeOpenAssets] && _assetID) {
            [LTCProtocolBuffers writeString:_assetID.string withKey:LTCPaymentMethodAssetKeyAssetID toData:dst];
        }

        [LTCProtocolBuffers writeInt:(uint64_t)_amount withKey:LTCPaymentMethodAssetKeyAmount toData:dst];
        _data = dst;
    }
    return _data;
}

@end




//message PaymentMethodRejection {
//    optional string memo = 1;
//    repeated PaymentMethodRejectedAsset rejected_assets = 2;
//}
typedef NS_ENUM(NSInteger, LTCPaymentMethodRejectionKey) {
    LTCPaymentMethodRejectionKeyMemo   = 1,
    LTCPaymentMethodRejectionKeyCode   = 2,
    LTCPaymentMethodRejectionKeyAssets = 3,
};


@interface LTCPaymentMethodRejection ()

@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation LTCPaymentMethodRejection

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSMutableArray* rejectedAssets = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case LTCPaymentMethodRejectionKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case LTCPaymentMethodRejectionKeyCode:
                    _code = integer;
                    break;
                case LTCPaymentMethodRejectionKeyAssets: {
                    if (d) {
                        LTCPaymentMethodRejectedAsset* rejasset = [[LTCPaymentMethodRejectedAsset alloc] initWithData:d];
                        [rejectedAssets addObject:rejasset];
                    }
                    break;
                }
                default: break;
            }
        }

        _rejectedAssets = rejectedAssets;
        _data = data;
    }
    return self;
}

- (void) setMemo:(NSString * __nullable)memo {
    _memo = [memo copy];
    _data = nil;
}

- (void) setCode:(uint64_t)code {
    _code = code;
    _data = nil;
}

- (void) setRejectedAssets:(NSArray * __nullable)rejectedAssets {
    _rejectedAssets = rejectedAssets;
    _data = nil;
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_memo) {
            [LTCProtocolBuffers writeString:_memo withKey:LTCPaymentMethodRejectionKeyMemo toData:dst];
        }

        [LTCProtocolBuffers writeInt:_code withKey:LTCPaymentMethodRejectionKeyCode toData:dst];

        for (LTCPaymentMethodRejectedAsset* rejectedAsset in _rejectedAssets) {
            [LTCProtocolBuffers writeData:rejectedAsset.data withKey:LTCPaymentMethodRejectionKeyAssets toData:dst];
        }

        _data = dst;
    }
    return _data;
}

@end


//message PaymentMethodRejectedAsset {
//    required string asset_id = 1;
//    optional uint64 code     = 2;
//    optional string reason   = 3;
//}
typedef NS_ENUM(NSInteger, LTCPaymentMethodRejectedAssetKey) {
    LTCPaymentMethodRejectedAssetKeyAssetID = 1,
    LTCPaymentMethodRejectedAssetKeyCode    = 2,
    LTCPaymentMethodRejectedAssetKeyReason  = 3,
};


@interface LTCPaymentMethodRejectedAsset ()

@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation LTCPaymentMethodRejectedAsset

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSString* assetIDString = nil;

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case LTCPaymentMethodRejectedAssetKeyAssetID:
                    if (d) assetIDString = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case LTCPaymentMethodRejectionKeyCode:
                    _code = integer;
                    break;
                case LTCPaymentMethodRejectedAssetKeyReason: {
                    if (d) _reason = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                }
                default: break;
            }
        }
        if (!assetIDString || [assetIDString isEqual:@"default"]) {
            _assetType = LTCAssetTypeBitcoin;
            _assetID = nil;
        } else {
            _assetID = [LTCAssetID assetIDWithString:assetIDString];
            if (_assetID) {
                _assetType = LTCAssetTypeOpenAssets;
            }
        }
        _data = data;
    }
    return self;
}

- (void) setAssetType:(NSString * __nonnull)assetType {
    _assetType = assetType;
    _data = nil;
}

- (void) setAssetID:(LTCAssetID * __nullable)assetID {
    _assetID = assetID;
    _data = nil;
}

- (void) setCode:(uint64_t)code {
    _code = code;
    _data = nil;
}

- (void) setReason:(NSString * __nullable)reason {
    _reason = reason;
    _data = nil;
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if ([_assetType isEqual:LTCAssetTypeBitcoin]) {
            [LTCProtocolBuffers writeString:@"default" withKey:LTCPaymentMethodRejectedAssetKeyAssetID toData:dst];
        } else if ([_assetType isEqual:LTCAssetTypeOpenAssets] && _assetID) {
            [LTCProtocolBuffers writeString:_assetID.string withKey:LTCPaymentMethodRejectedAssetKeyAssetID toData:dst];
        }

        [LTCProtocolBuffers writeInt:_code withKey:LTCPaymentMethodRejectedAssetKeyCode toData:dst];

        if (_reason) {
            [LTCProtocolBuffers writeString:_reason withKey:LTCPaymentMethodRejectedAssetKeyReason toData:dst];
        }

        _data = dst;
    }
    return _data;
}

@end
