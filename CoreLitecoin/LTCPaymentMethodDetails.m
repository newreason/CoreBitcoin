// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCPaymentMethodDetails.h"
#import "LTCPaymentProtocol.h"
#import "LTCProtocolBuffers.h"
#import "LTCNetwork.h"
#import "LTCAssetType.h"
#import "LTCAssetID.h"

//message PaymentMethodDetails {
//    optional string        network            = 1 [default = "main"];
//    required string        payment_method_url = 2;
//    repeated PaymentItem   items              = 3;
//    required uint64        time               = 4;
//    optional uint64        expires            = 5;
//    optional string        memo               = 6;
//    optional bytes         merchant_data      = 7;
//}
typedef NS_ENUM(NSInteger, LTCPMDetailsKey) {
    LTCPMDetailsKeyNetwork            = 1,
    LTCPMDetailsKeyPaymentMethodURL   = 2,
    LTCPMDetailsKeyItems              = 3,
    LTCPMDetailsKeyTime               = 4,
    LTCPMDetailsKeyExpires            = 5,
    LTCPMDetailsKeyMemo               = 6,
    LTCPMDetailsKeyMerchantData       = 7,
};

@interface LTCPaymentMethodDetails ()
@property(nonatomic, readwrite) LTCNetwork* network;
@property(nonatomic, readwrite) NSArray* /* [LTCPaymentMethodRequestItem] */ items;
@property(nonatomic, readwrite) NSURL* paymentMethodURL;
@property(nonatomic, readwrite) NSDate* date;
@property(nonatomic, readwrite) NSDate* expirationDate;
@property(nonatomic, readwrite) NSString* memo;
@property(nonatomic, readwrite) NSData* merchantData;
@property(nonatomic, readwrite) NSData* data;
@end

@implementation LTCPaymentMethodDetails

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSMutableArray* items = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case LTCPMDetailsKeyNetwork:
                    if (d) {
                        NSString* networkName = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                        if ([networkName isEqual:@"main"]) {
                            _network = [LTCNetwork mainnet];
                        } else if ([networkName isEqual:@"test"]) {
                            _network = [LTCNetwork testnet];
                        } else {
                            _network = [[LTCNetwork alloc] initWithName:networkName];
                        }
                    }
                    break;
                case LTCPMDetailsKeyPaymentMethodURL:
                    if (d) _paymentMethodURL = [NSURL URLWithString:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
                    break;
                case LTCPMDetailsKeyItems: {
                    if (d) {
                        LTCPaymentMethodDetailsItem* item = [[LTCPaymentMethodDetailsItem alloc] initWithData:d];
                        [items addObject:item];
                    }
                    break;
                }
                case LTCPMDetailsKeyTime:
                    if (integer) _date = [NSDate dateWithTimeIntervalSince1970:integer];
                    break;
                case LTCPMDetailsKeyExpires:
                    if (integer) _expirationDate = [NSDate dateWithTimeIntervalSince1970:integer];
                    break;
                case LTCPMDetailsKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case LTCPMDetailsKeyMerchantData:
                    if (d) _merchantData = d;
                    break;
                default: break;
            }
        }

        // PMR must have at least one item
        if (items.count == 0) return nil;

        // PMR requires a creation time.
        if (!_date) return nil;

        _items = items;
        _data = data;
    }
    return self;
}

- (LTCNetwork*) network {
    return _network ?: [LTCNetwork mainnet];
}

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_network) {
            [LTCProtocolBuffers writeString:_network.paymentProtocolName withKey:LTCPMDetailsKeyNetwork toData:dst];
        }
        if (_paymentMethodURL) {
            [LTCProtocolBuffers writeString:_paymentMethodURL.absoluteString withKey:LTCPMDetailsKeyPaymentMethodURL toData:dst];
        }
        for (LTCPaymentMethodDetailsItem* item in _items) {
            [LTCProtocolBuffers writeData:item.data withKey:LTCPMDetailsKeyItems toData:dst];
        }
        if (_date) {
            [LTCProtocolBuffers writeInt:(uint64_t)[_date timeIntervalSince1970] withKey:LTCPMDetailsKeyTime toData:dst];
        }
        if (_expirationDate) {
            [LTCProtocolBuffers writeInt:(uint64_t)[_expirationDate timeIntervalSince1970] withKey:LTCPMDetailsKeyExpires toData:dst];
        }
        if (_memo) {
            [LTCProtocolBuffers writeString:_memo withKey:LTCPMDetailsKeyMemo toData:dst];
        }
        if (_merchantData) {
            [LTCProtocolBuffers writeData:_merchantData withKey:LTCPMDetailsKeyMerchantData toData:dst];
        }
        _data = dst;
    }
    return _data;
}

@end





//message PaymentItem {
//    optional string type                   = 1 [default = "default"];
//    optional bool   optional               = 2 [default = false];
//    optional bytes  item_identifier        = 3;
//    optional uint64 amount                 = 4 [default = 0];
//    repeated AcceptedAsset accepted_assets = 5;
//    optional string memo                   = 6;
//}
typedef NS_ENUM(NSInteger, LTCPMItemKey) {
    LTCPMRItemKeyItemType           = 1,
    LTCPMRItemKeyItemOptional       = 2,
    LTCPMRItemKeyItemIdentifier     = 3,
    LTCPMRItemKeyAmount             = 4,
    LTCPMRItemKeyAcceptedAssets     = 5,
    LTCPMRItemKeyMemo               = 6,
};

@interface LTCPaymentMethodDetailsItem ()
@property(nonatomic, readwrite, nullable) NSString* itemType;
@property(nonatomic, readwrite) BOOL optional;
@property(nonatomic, readwrite, nullable) NSData* itemIdentifier;
@property(nonatomic, readwrite) LTCAmount amount;
@property(nonatomic, readwrite, nonnull) NSArray* /* [LTCPaymentMethodAcceptedAsset] */ acceptedAssets;
@property(nonatomic, readwrite, nullable) NSString* memo;
@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation LTCPaymentMethodDetailsItem

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSMutableArray* assets = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case LTCPMRItemKeyItemType:
                    if (d) _itemType = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case LTCPMRItemKeyItemOptional:
                    _optional = (integer != 0);
                    break;
                case LTCPMRItemKeyItemIdentifier:
                    if (d) _itemIdentifier = d;
                    break;

                case LTCPMRItemKeyAmount: {
                    _amount = integer;
                    break;
                }
                case LTCPMRItemKeyAcceptedAssets: {
                    if (d) {
                        LTCPaymentMethodAcceptedAsset* asset = [[LTCPaymentMethodAcceptedAsset alloc] initWithData:d];
                        [assets addObject:asset];
                    }
                    break;
                }
                case LTCPMRItemKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                default: break;
            }
        }
        _acceptedAssets = assets;
        _data = data;
    }
    return self;
}


- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_itemType) {
            [LTCProtocolBuffers writeString:_itemType withKey:LTCPMRItemKeyItemType toData:dst];
        }
        [LTCProtocolBuffers writeInt:_optional ? 1 : 0 withKey:LTCPMRItemKeyItemOptional toData:dst];
        if (_itemIdentifier) {
            [LTCProtocolBuffers writeData:_itemIdentifier withKey:LTCPMRItemKeyItemIdentifier toData:dst];
        }
        if (_amount > 0) {
             [LTCProtocolBuffers writeInt:(uint64_t)_amount withKey:LTCPMRItemKeyAmount toData:dst];
        }
        for (LTCPaymentMethodAcceptedAsset* asset in _acceptedAssets) {
            [LTCProtocolBuffers writeData:asset.data withKey:LTCPMRItemKeyAcceptedAssets toData:dst];
        }
        if (_memo) {
            [LTCProtocolBuffers writeString:_memo withKey:LTCPMRItemKeyMemo toData:dst];
        }
        _data = dst;
    }
    return _data;
}

@end





//message AcceptedAsset {
//    optional string asset_id = 1 [default = "default"];
//    optional string asset_group = 2;
//    optional double multiplier = 3 [default = 1.0];
//    optional uint64 min_amount = 4 [default = 0];
//    optional uint64 max_amount = 5;
//}
typedef NS_ENUM(NSInteger, LTCPMAcceptedAssetKey) {
    LTCPMRAcceptedAssetKeyAssetID    = 1,
    LTCPMRAcceptedAssetKeyAssetGroup = 2,
    LTCPMRAcceptedAssetKeyMultiplier = 3,
    LTCPMRAcceptedAssetKeyMinAmount  = 4,
    LTCPMRAcceptedAssetKeyMaxAmount  = 5,
};


@interface LTCPaymentMethodAcceptedAsset ()
@property(nonatomic, readwrite, nullable) NSString* assetType; // LTCAssetTypeBitcoin or LTCAssetTypeOpenAssets
@property(nonatomic, readwrite, nullable) LTCAssetID* assetID;
@property(nonatomic, readwrite, nullable) NSString* assetGroup;
@property(nonatomic, readwrite) double multiplier; // to use as a multiplier need to multiply by that amount and divide by 1e8.
@property(nonatomic, readwrite) LTCAmount minAmount;
@property(nonatomic, readwrite) LTCAmount maxAmount;
@property(nonatomic, readwrite, nonnull) NSData* data;
@end

@implementation LTCPaymentMethodAcceptedAsset


- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSString* assetIDString = nil;

        _multiplier = 1.0;

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            uint64_t fixed64 = 0;
            NSData* d = nil;
            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer fixed32:NULL fixed64:&fixed64 data:&d fromData:data]) {
                case LTCPMRAcceptedAssetKeyAssetID:
                    if (d) assetIDString = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;

                case LTCPMRAcceptedAssetKeyAssetGroup: {
                    if (d) _assetGroup = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                }
                case LTCPMRAcceptedAssetKeyMultiplier: {
                    _multiplier = (double)fixed64;
                    break;
                }
                case LTCPMRAcceptedAssetKeyMinAmount: {
                    _minAmount = integer;
                    break;
                }
                case LTCPMRAcceptedAssetKeyMaxAmount: {
                    _maxAmount = integer;
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

- (NSData*) data {
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if ([_assetType isEqual:LTCAssetTypeBitcoin]) {
            [LTCProtocolBuffers writeString:@"default" withKey:LTCPMRAcceptedAssetKeyAssetID toData:dst];
        } else if ([_assetType isEqual:LTCAssetTypeOpenAssets] && _assetID) {
            [LTCProtocolBuffers writeString:_assetID.string withKey:LTCPMRAcceptedAssetKeyAssetID toData:dst];
        }
        if (_assetGroup) {
            [LTCProtocolBuffers writeString:_assetGroup withKey:LTCPMRAcceptedAssetKeyAssetGroup toData:dst];
        }

        [LTCProtocolBuffers writeFixed64:(uint64_t)_multiplier withKey:LTCPMRAcceptedAssetKeyMultiplier toData:dst];
        [LTCProtocolBuffers writeInt:(uint64_t)_minAmount withKey:LTCPMRAcceptedAssetKeyMinAmount toData:dst];
        [LTCProtocolBuffers writeInt:(uint64_t)_maxAmount withKey:LTCPMRAcceptedAssetKeyMaxAmount toData:dst];
        _data = dst;
    }
    return _data;
}

@end

