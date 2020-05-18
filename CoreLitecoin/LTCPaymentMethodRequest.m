// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCPaymentRequest.h"
#import "LTCPaymentMethodRequest.h"
#import "LTCPaymentMethodDetails.h"
#import "LTCProtocolBuffers.h"

NSInteger const LTCPaymentMethodRequestVersion1 = 1;

//message PaymentMethodRequest {
//    optional uint32 payment_details_version = 1 [default = 1];
//    optional string pki_type = 2 [default = "none"];
//    optional bytes  pki_data = 3;
//    required bytes  serialized_payment_method_details = 4;
//    optional bytes  signature = 5;
//}
typedef NS_ENUM(NSInteger, LTCPMRKey) {
    LTCPMRKeyVersion        = 1,
    LTCPMRKeyPkiType        = 2,
    LTCPMRKeyPkiData        = 3,
    LTCPMRKeyPaymentDetails = 4,
    LTCPMRKeySignature      = 5
};

@interface LTCPaymentMethodRequest ()
// If you make these publicly writable, make sure to set _data to nil and _isValidated to NO.
@property(nonatomic, readwrite) NSInteger version;
@property(nonatomic, readwrite) NSString* pkiType;
@property(nonatomic, readwrite) NSData* pkiData;
@property(nonatomic, readwrite) LTCPaymentMethodDetails* details;
@property(nonatomic, readwrite) NSData* signature;
@property(nonatomic, readwrite) NSArray* certificates;
@property(nonatomic, readwrite) NSData* data;

@property(nonatomic) BOOL isValidated;
@property(nonatomic, readwrite) BOOL isValid;
@property(nonatomic, readwrite) NSString* signerName;
@property(nonatomic, readwrite) LTCPaymentRequestStatus status;
@end





@implementation LTCPaymentMethodRequest

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    // Note: we are not assigning default values here because we need to
    // reconstruct exact data (without the signature) for signature verification.

    if (self = [super init]) {
        
        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t i = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&i data:&d fromData:data]) {
                case LTCPMRKeyVersion:
                    if (i) _version = (uint32_t)i;
                    break;
                case LTCPMRKeyPkiType:
                    if (d) _pkiType = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case LTCPMRKeyPkiData:
                    if (d) _pkiData = d;
                    break;
                case LTCPMRKeyPaymentDetails:
                    if (d) _details = [[LTCPaymentMethodDetails alloc] initWithData:d];
                    break;
                case LTCPMRKeySignature:
                    if (d) _signature = d;
                    break;
                default: break;
            }
        }

        // Payment details are required.
        if (!_details) return nil;
    }
    return self;
}

- (NSData*) data {
    if (!_data) {
        _data = [self dataWithSignature:_signature];
    }
    return _data;
}

- (NSData*) dataForSigning {
    return [self dataWithSignature:[NSData data]];
}

- (NSData*) dataWithSignature:(NSData*)signature {
    NSMutableData* data = [NSMutableData data];

    // Note: we should reconstruct the data exactly as it was on the input.
    if (_version > 0) {
        [LTCProtocolBuffers writeInt:_version withKey:LTCPMRKeyVersion toData:data];
    }
    if (_pkiType) {
        [LTCProtocolBuffers writeString:_pkiType withKey:LTCPMRKeyPkiType toData:data];
    }
    if (_pkiData) {
        [LTCProtocolBuffers writeData:_pkiData withKey:LTCPMRKeyPkiData toData:data];
    }

    [LTCProtocolBuffers writeData:self.details.data withKey:LTCPMRKeyPaymentDetails toData:data];

    if (signature) {
        [LTCProtocolBuffers writeData:signature withKey:LTCPMRKeySignature toData:data];
    }
    return data;
}

- (NSInteger) version
{
    return (_version > 0) ? _version : LTCPaymentMethodRequestVersion1;
}

- (NSString*) pkiType
{
    return _pkiType ?: LTCPaymentRequestPKITypeNone;
}

- (NSArray*) certificates {
    if (!_certificates) {
        _certificates = LTCParseCertificatesFromPaymentRequestPKIData(self.pkiData);
    }
    return _certificates;
}

- (BOOL) isValid {
    if (!_isValidated) [self validatePaymentRequest];
    return _isValid;
}

- (NSString*) signerName {
    if (!_isValidated) [self validatePaymentRequest];
    return _signerName;
}

- (LTCPaymentRequestStatus) status {
    if (!_isValidated) [self validatePaymentRequest];
    return _status;
}

- (void) validatePaymentRequest {
    _isValidated = YES;
    _isValid = NO;

    // Make sure we do not accidentally send funds to a payment request that we do not support.
    if (self.version != LTCPaymentMethodRequestVersion1) {
        _status = LTCPaymentRequestStatusNotCompatible;
        return;
    }

    if (self.details.expirationDate && [self.currentDate ?: [NSDate date] timeIntervalSinceDate:self.details.expirationDate] > 0.0) {
        _status = LTCPaymentRequestStatusExpired;
        _isValid = NO;
        return;
    }

    __typeof(_status) status = _status;
    __typeof(_signerName) signer = _signerName;
    _isValid = LTCPaymentRequestVerifySignature(self.pkiType,
                                                [self dataForSigning],
                                                self.certificates,
                                                _signature,
                                                &status,
                                                &signer);
    _status = status;
    _signerName = signer;
    if (!_isValid) {
        return;
    }
}

@end







