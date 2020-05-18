// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCPaymentRequest.h"
#import "LTCProtocolBuffers.h"
#import "LTCErrors.h"
#import "LTCAssetType.h"
#import "LTCAssetID.h"
#import "LTCData.h"
#import "LTCNetwork.h"
#import "LTCScript.h"
#import "LTCTransaction.h"
#import "LTCTransactionOutput.h"
#import "LTCTransactionInput.h"
#import <Security/Security.h>

NSInteger const LTCPaymentRequestVersion1 = 1;
NSInteger const LTCPaymentRequestVersionOpenAssets1 = 0x4f41;

NSString* const LTCPaymentRequestPKITypeNone = @"none";
NSString* const LTCPaymentRequestPKITypeX509SHA1 = @"x509+sha1";
NSString* const LTCPaymentRequestPKITypeX509SHA256 = @"x509+sha256";

LTCAmount const LTCUnspecifiedPaymentAmount = -1;

typedef NS_ENUM(NSInteger, LTCOutputKey) {
    LTCOutputKeyAmount = 1,
    LTCOutputKeyScript = 2,
    LTCOutputKeyAssetID = 4001, // only for Open Assets PRs.
    LTCOutputKeyAssetAmount = 4002 // only for Open Assets PRs.
};

typedef NS_ENUM(NSInteger, LTCInputKey) {
    LTCInputKeyTxhash = 1,
    LTCInputKeyIndex = 2
};

typedef NS_ENUM(NSInteger, LTCRequestKey) {
    LTCRequestKeyVersion        = 1,
    LTCRequestKeyPkiType        = 2,
    LTCRequestKeyPkiData        = 3,
    LTCRequestKeyPaymentDetails = 4,
    LTCRequestKeySignature      = 5
};

typedef NS_ENUM(NSInteger, LTCDetailsKey) {
    LTCDetailsKeyNetwork      = 1,
    LTCDetailsKeyOutputs      = 2,
    LTCDetailsKeyTime         = 3,
    LTCDetailsKeyExpires      = 4,
    LTCDetailsKeyMemo         = 5,
    LTCDetailsKeyPaymentURL   = 6,
    LTCDetailsKeyMerchantData = 7,
    LTCDetailsKeyInputs       = 8
};

typedef NS_ENUM(NSInteger, LTCCertificatesKey) {
    LTCCertificatesKeyCertificate = 1
};

typedef NS_ENUM(NSInteger, LTCPaymentKey) {
    LTCPaymentKeyMerchantData = 1,
    LTCPaymentKeyTransactions = 2,
    LTCPaymentKeyRefundTo     = 3,
    LTCPaymentKeyMemo         = 4
};

typedef NS_ENUM(NSInteger, LTCPaymentAckKey) {
    LTCPaymentAckKeyPayment = 1,
    LTCPaymentAckKeyMemo    = 2
};


@interface LTCPaymentRequest ()
// If you make these publicly writable, make sure to set _data to nil and _isValidated to NO.
@property(nonatomic, readwrite) NSInteger version;
@property(nonatomic, readwrite) NSString* pkiType;
@property(nonatomic, readwrite) NSData* pkiData;
@property(nonatomic, readwrite) LTCPaymentDetails* details;
@property(nonatomic, readwrite) NSData* signature;
@property(nonatomic, readwrite) NSArray* certificates;
@property(nonatomic, readwrite) NSData* data;

@property(nonatomic) BOOL isValidated;
@property(nonatomic, readwrite) BOOL isValid;
@property(nonatomic, readwrite) NSString* signerName;
@property(nonatomic, readwrite) LTCPaymentRequestStatus status;
@end


@interface LTCPaymentDetails ()
@property(nonatomic, readwrite) LTCNetwork* network;
@property(nonatomic, readwrite) NSArray* /*[LTCTransactionOutput]*/ outputs;
@property(nonatomic, readwrite) NSArray* /*[LTCTransactionInput]*/ inputs;
@property(nonatomic, readwrite) NSDate* date;
@property(nonatomic, readwrite) NSDate* expirationDate;
@property(nonatomic, readwrite) NSString* memo;
@property(nonatomic, readwrite) NSURL* paymentURL;
@property(nonatomic, readwrite) NSData* merchantData;
@property(nonatomic, readwrite) NSData* data;
@end


@interface LTCPayment ()
@property(nonatomic, readwrite) NSData* merchantData;
@property(nonatomic, readwrite) NSArray* /*[LTCTransaction]*/ transactions;
@property(nonatomic, readwrite) NSArray* /*[LTCTransactionOutput]*/ refundOutputs;
@property(nonatomic, readwrite) NSString* memo;
@property(nonatomic, readwrite) NSData* data;
@end


@interface LTCPaymentACK ()
@property(nonatomic, readwrite) LTCPayment* payment;
@property(nonatomic, readwrite) NSString* memo;
@property(nonatomic, readwrite) NSData* data;
@end







@implementation LTCPaymentRequest

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        // Note: we are not assigning default values here because we need to
        // reconstruct exact data (without the signature) for signature verification.

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t i = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&i data:&d fromData:data]) {
                case LTCRequestKeyVersion:
                    if (i) _version = (uint32_t)i;
                    break;
                case LTCRequestKeyPkiType:
                    if (d) _pkiType = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case LTCRequestKeyPkiData:
                    if (d) _pkiData = d;
                    break;
                case LTCRequestKeyPaymentDetails:
                    if (d) _details = [[LTCPaymentDetails alloc] initWithData:d];
                    break;
                case LTCRequestKeySignature:
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
        [LTCProtocolBuffers writeInt:_version withKey:LTCRequestKeyVersion toData:data];
    }
    if (_pkiType) {
        [LTCProtocolBuffers writeString:_pkiType withKey:LTCRequestKeyPkiType toData:data];
    }
    if (_pkiData) {
        [LTCProtocolBuffers writeData:_pkiData withKey:LTCRequestKeyPkiData toData:data];
    }

    [LTCProtocolBuffers writeData:self.details.data withKey:LTCRequestKeyPaymentDetails toData:data];

    if (signature) {
        [LTCProtocolBuffers writeData:signature withKey:LTCRequestKeySignature toData:data];
    }
    return data;
}

- (NSInteger) version
{
    return (_version > 0) ? _version : LTCPaymentRequestVersion1;
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
    if (self.version != LTCPaymentRequestVersion1 &&
        self.version != LTCPaymentRequestVersionOpenAssets1) {
        _status = LTCPaymentRequestStatusNotCompatible;
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

    // Signatures are valid, but PR has expired.
    if (self.details.expirationDate && [self.currentDate ?: [NSDate date] timeIntervalSinceDate:self.details.expirationDate] > 0.0) {
        _status = LTCPaymentRequestStatusExpired;
        _isValid = NO;
        return;
    }
}

- (LTCPayment*) paymentWithTransaction:(LTCTransaction*)tx {
    NSParameterAssert(tx);
    return [self paymentWithTransactions:@[ tx ] memo:nil];
}

- (LTCPayment*) paymentWithTransactions:(NSArray*)txs memo:(NSString*)memo {
    if (!txs || txs.count == 0) return nil;
    LTCPayment* payment = [[LTCPayment alloc] init];
    payment.merchantData = self.details.merchantData;
    payment.transactions = txs;
    payment.memo = memo;
    return payment;
}

@end


NSArray* __nullable LTCParseCertificatesFromPaymentRequestPKIData(NSData* __nullable pkiData) {
    if (!pkiData) return nil;
    NSMutableArray* certs = [NSMutableArray array];
    NSInteger offset = 0;
    while (offset < pkiData.length) {
        NSData* d = nil;
        NSInteger key = [LTCProtocolBuffers fieldAtOffset:&offset int:NULL data:&d fromData:pkiData];
        if (key == LTCCertificatesKeyCertificate && d) {
            [certs addObject:d];
        }
    }
    return certs;
}


BOOL LTCPaymentRequestVerifySignature(NSString* __nullable pkiType,
                                      NSData* __nullable dataToVerify,
                                      NSArray* __nullable certificates,
                                      NSData* __nullable signature,
                                      LTCPaymentRequestStatus* __nullable statusOut,
                                      NSString* __autoreleasing __nullable *  __nullable signerOut) {

    if ([pkiType isEqual:LTCPaymentRequestPKITypeX509SHA1] ||
        [pkiType isEqual:LTCPaymentRequestPKITypeX509SHA256]) {

        if (!signature || !certificates || certificates.count == 0 || !dataToVerify) {
            if (statusOut) *statusOut = LTCPaymentRequestStatusInvalidSignature;
            return NO;
        }

        // 1. Verify chain of trust

        NSMutableArray *certs = [NSMutableArray array];
        NSArray *policies = @[CFBridgingRelease(SecPolicyCreateBasicX509())];
        SecTrustRef trust = NULL;
        SecTrustResultType trustResult = kSecTrustResultInvalid;

        for (NSData *certData in certificates) {
            SecCertificateRef cert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);
            if (cert) [certs addObject:CFBridgingRelease(cert)];
        }

        if (certs.count > 0) {
            if (signerOut) *signerOut = CFBridgingRelease(SecCertificateCopySubjectSummary((__bridge SecCertificateRef)certs[0]));
        }

        SecTrustCreateWithCertificates((__bridge CFArrayRef)certs, (__bridge CFArrayRef)policies, &trust);
        SecTrustEvaluate(trust, &trustResult); // verify certificate chain

        // kSecTrustResultUnspecified indicates the evaluation succeeded
        // and the certificate is implicitly trusted, but user intent was not
        // explicitly specified.
        if (trustResult != kSecTrustResultUnspecified && trustResult != kSecTrustResultProceed) {
            if (certs.count > 0) {
                if (statusOut) *statusOut = LTCPaymentRequestStatusUntrustedCertificate;
            } else {
                if (statusOut) *statusOut = LTCPaymentRequestStatusMissingCertificate;
            }
            return NO;
        }

        // 2. Verify signature

    #if TARGET_OS_IPHONE
        SecKeyRef pubKey = SecTrustCopyPublicKey(trust);
        SecPadding padding = kSecPaddingPKCS1;
        NSData* hash = nil;

        if ([pkiType isEqual:LTCPaymentRequestPKITypeX509SHA256]) {
            hash = LTCSHA256(dataToVerify);
            padding = kSecPaddingPKCS1SHA256;
        }
        else if ([pkiType isEqual:LTCPaymentRequestPKITypeX509SHA1]) {
            hash = LTCSHA1(dataToVerify);
            padding = kSecPaddingPKCS1SHA1;
        }

        OSStatus status = SecKeyRawVerify(pubKey, padding, hash.bytes, hash.length, signature.bytes, signature.length);

        CFRelease(pubKey);

        if (status != errSecSuccess) {
            if (statusOut) *statusOut = LTCPaymentRequestStatusInvalidSignature;
            return NO;
        }

        if (statusOut) *statusOut = LTCPaymentRequestStatusValid;
        return YES;

    #else
        // On OS X 10.10 we don't have kSecPaddingPKCS1SHA256 and SecKeyRawVerify.
        // So we have to verify the signature using Security Transforms API.

        //  Here's a draft of what needs to be done here.
        /*
         CFErrorRef* error = NULL;
         verifier = SecVerifyTransformCreate(publickey, signature, &error);
         if (!verifier) { CFShow(error); exit(-1); }
         if (!SecTransformSetAttribute(verifier, kSecTransformInputAttributeName, dataForSigning, &error) {
         CFShow(error);
         exit(-1);
         }
         // if it's sha256, then set SHA2 digest type and 32 bytes length.
         if (!SecTransformSetAttribute(verifier, kSecDigestTypeAttribute, kSecDigestSHA2, &error) {
         CFShow(error);
         exit(-1);
         }
         // Not sure if the length is in bytes or bits. Quinn The Eskimo says it's in bits:
         // https://devforums.apple.com/message/1119092#1119092
         if (!SecTransformSetAttribute(verifier, kSecDigestLengthAttribute, @(256), &error) {
         CFShow(error);
         exit(-1);
         }

         result = SecTransformExecute(verifier, &error);
         if (error) {
         CFShow(error);
         exit(-1);
         }
         if (result == kCFBooleanTrue) {
         // signature is valid
         if (statusOut) *statusOut = LTCPaymentRequestStatusValid;
         _isValid = YES;
         } else {
         // signature is invalid.
         if (statusOut) *statusOut = LTCPaymentRequestStatusInvalidSignature;
         _isValid = NO;
         return NO;
         }

         // -----------------------------------------------------------------------

         // From CryptoCompatibility sample code (QCCRSASHA1VerifyT.m):

         BOOL                success;
         SecTransformRef     transform;
         CFBooleanRef        result;
         CFErrorRef          errorCF;

         result = NULL;
         errorCF = NULL;

         // Set up the transform.

         transform = SecVerifyTransformCreate(self.publicKey, (__bridge CFDataRef) self.signatureData, &errorCF);
         success = (transform != NULL);

         // Note: kSecInputIsAttributeName defaults to kSecInputIsPlainText, which is what we want.

         if (success) {
         success = SecTransformSetAttribute(transform, kSecDigestTypeAttribute, kSecDigestSHA1, &errorCF) != false;
         }

         if (success) {
         success = SecTransformSetAttribute(transform, kSecTransformInputAttributeName, (__bridge CFDataRef) self.inputData, &errorCF) != false;
         }

         // Run it.

         if (success) {
         result = SecTransformExecute(transform, &errorCF);
         success = (result != NULL);
         }

         // Process the results.

         if (success) {
         assert(CFGetTypeID(result) == CFBooleanGetTypeID());
         self.verified = (CFBooleanGetValue(result) != false);
         } else {
         assert(errorCF != NULL);
         self.error = (__bridge NSError *) errorCF;
         }

         // Clean up.

         if (result != NULL) {
         CFRelease(result);
         }
         if (errorCF != NULL) {
         CFRelease(errorCF);
         }
         if (transform != NULL) {
         CFRelease(transform);
         }
         */

        if (statusOut) *statusOut = LTCPaymentRequestStatusUnknown;
        return NO;
    #endif

    } else {
        // Either "none" PKI type or some new and unsupported PKI.

        if (certificates.count > 0) {
            // Non-standard extension to include a signer's name without actually signing request.
            if (signerOut) *signerOut = [[NSString alloc] initWithData:certificates[0] encoding:NSUTF8StringEncoding];
        }

        if ([pkiType isEqual:LTCPaymentRequestPKITypeNone]) {
            if (statusOut) *statusOut = LTCPaymentRequestStatusUnsigned;
            return YES;
        } else {
            if (statusOut) *statusOut = LTCPaymentRequestStatusUnknown;
            return NO;
        }
    }
    return NO;
}



















@implementation LTCPaymentDetails

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSMutableArray* outputs = [NSMutableArray array];
        NSMutableArray* inputs = [NSMutableArray array];

        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case LTCDetailsKeyNetwork:
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
                case LTCDetailsKeyOutputs: {
                    NSInteger offset2 = 0;
                    LTCAmount amount = LTCUnspecifiedPaymentAmount;
                    NSData* scriptData = nil;
                    LTCAssetID* assetID = nil;
                    LTCAmount assetAmount = LTCUnspecifiedPaymentAmount;

                    uint64_t integer2 = 0;
                    NSData* d2 = nil;
                    while (offset2 < d.length) {
                        switch ([LTCProtocolBuffers fieldAtOffset:&offset2 int:&integer2 data:&d2 fromData:d]) {
                            case LTCOutputKeyAmount:
                                amount = integer2;
                                break;
                            case LTCOutputKeyScript:
                                scriptData = d2;
                                break;
                            case LTCOutputKeyAssetID:
                                if (d2.length != 20) {
                                    NSLog(@"CoreLitecoin ERROR: Received invalid asset id in Payment Request Details (must be 20 bytes long): %@", d2);
                                    return nil;
                                }
                                assetID = [LTCAssetID assetIDWithHash:d2];
                                break;
                            case LTCOutputKeyAssetAmount:
                                assetAmount = integer2;
                                break;
                            default:
                                break;
                        }
                    }
                    if (scriptData) {
                        LTCScript* script = [[LTCScript alloc] initWithData:scriptData];
                        if (!script) {
                            NSLog(@"CoreLitecoin ERROR: Received invalid script data in Payment Request Details: %@", scriptData);
                            return nil;
                        }
                        if (assetID) {
                            if (amount != LTCUnspecifiedPaymentAmount) {
                                NSLog(@"CoreLitecoin ERROR: Received invalid amount specification in Payment Request Details: amount must not be specified.");
                                return nil;
                            }
                        } else {
                            if (assetAmount != LTCUnspecifiedPaymentAmount) {
                                NSLog(@"CoreLitecoin ERROR: Received invalid amount specification in Payment Request Details: asset_amount must not specified without asset_id.");
                                return nil;
                            }
                        }
                        LTCTransactionOutput* txout = [[LTCTransactionOutput alloc] initWithValue:amount script:script];
                        NSMutableDictionary* userInfo = [NSMutableDictionary dictionary];

                        if (assetID) {
                            userInfo[@"assetID"] = assetID;
                        }
                        if (assetAmount != LTCUnspecifiedPaymentAmount) {
                            userInfo[@"assetAmount"] = @(assetAmount);
                        }
                        txout.userInfo = userInfo;
                        txout.index = (uint32_t)outputs.count;
                        [outputs addObject:txout];
                    }
                    break;
                }
                case LTCDetailsKeyInputs: {
                    NSInteger offset2 = 0;
                    uint64_t index = LTCUnspecifiedPaymentAmount;
                    NSData* txhash = nil;
                    // both amount and scriptData are optional, so we try to read any of them
                    while (offset2 < d.length) {
                        [LTCProtocolBuffers fieldAtOffset:&offset2 int:(uint64_t*)&index data:&txhash fromData:d];
                    }
                    if (txhash) {
                        if (txhash.length != 32) {
                            NSLog(@"CoreLitecoin ERROR: Received invalid txhash in Payment Request Input: %@", txhash);
                            return nil;
                        }
                        if (index > 0xffffffffLL) {
                            NSLog(@"CoreLitecoin ERROR: Received invalid prev index in Payment Request Input: %@", @(index));
                            return nil;
                        }
                        LTCTransactionInput* txin = [[LTCTransactionInput alloc] init];
                        txin.previousHash = txhash;
                        txin.previousIndex = (uint32_t)index;
                        [inputs addObject:txin];
                    }
                    break;
                }
                case LTCDetailsKeyTime:
                    if (integer) _date = [NSDate dateWithTimeIntervalSince1970:integer];
                    break;
                case LTCDetailsKeyExpires:
                    if (integer) _expirationDate = [NSDate dateWithTimeIntervalSince1970:integer];
                    break;
                case LTCDetailsKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                case LTCDetailsKeyPaymentURL:
                    if (d) _paymentURL = [NSURL URLWithString:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
                    break;
                case LTCDetailsKeyMerchantData:
                    if (d) _merchantData = d;
                    break;
                default: break;
            }
        }

        // PR must have at least one output
        if (outputs.count == 0) return nil;

        // PR requires a creation time.
        if (!_date) return nil;

        _outputs = outputs;
        _inputs = inputs;
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

        // Note: we should reconstruct the data exactly as it was on the input.

        if (_network) {
            [LTCProtocolBuffers writeString:_network.paymentProtocolName withKey:LTCDetailsKeyNetwork toData:dst];
        }

        for (LTCTransactionOutput* txout in _outputs) {
            NSMutableData* outputData = [NSMutableData data];

            if (txout.value != LTCUnspecifiedPaymentAmount) {
                [LTCProtocolBuffers writeInt:txout.value withKey:LTCOutputKeyAmount toData:outputData];
            }
            [LTCProtocolBuffers writeData:txout.script.data withKey:LTCOutputKeyScript toData:outputData];

            if (txout.userInfo[@"assetID"]) {
                LTCAssetID* aid = txout.userInfo[@"assetID"];
                [LTCProtocolBuffers writeData:aid.data withKey:LTCOutputKeyAssetID toData:outputData];
            }
            if (txout.userInfo[@"assetAmount"]) {
                LTCAmount assetAmount = [txout.userInfo[@"assetAmount"] longLongValue];
                [LTCProtocolBuffers writeInt:assetAmount withKey:LTCOutputKeyAssetAmount toData:outputData];
            }
            [LTCProtocolBuffers writeData:outputData withKey:LTCDetailsKeyOutputs toData:dst];
        }

        for (LTCTransactionInput* txin in _inputs) {
            NSMutableData* inputsData = [NSMutableData data];

            [LTCProtocolBuffers writeData:txin.previousHash withKey:LTCInputKeyTxhash toData:inputsData];
            [LTCProtocolBuffers writeInt:txin.previousIndex withKey:LTCInputKeyIndex toData:inputsData];
            [LTCProtocolBuffers writeData:inputsData withKey:LTCDetailsKeyInputs toData:dst];
        }

        if (_date) {
            [LTCProtocolBuffers writeInt:(uint64_t)[_date timeIntervalSince1970] withKey:LTCDetailsKeyTime toData:dst];
        }
        if (_expirationDate) {
            [LTCProtocolBuffers writeInt:(uint64_t)[_expirationDate timeIntervalSince1970] withKey:LTCDetailsKeyExpires toData:dst];
        }
        if (_memo) {
            [LTCProtocolBuffers writeString:_memo withKey:LTCDetailsKeyMemo toData:dst];
        }
        if (_paymentURL) {
            [LTCProtocolBuffers writeString:_paymentURL.absoluteString withKey:LTCDetailsKeyPaymentURL toData:dst];
        }
        if (_merchantData) {
            [LTCProtocolBuffers writeData:_merchantData withKey:LTCDetailsKeyMerchantData toData:dst];
        }
        _data = dst;
    }
    return _data;
}

@end




















@implementation LTCPayment

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {

        NSInteger offset = 0;
        NSMutableArray* txs = [NSMutableArray array];
        NSMutableArray* outputs = [NSMutableArray array];

        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;
            LTCTransaction* tx = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case LTCPaymentKeyMerchantData:
                    if (d) _merchantData = d;
                    break;
                case LTCPaymentKeyTransactions:
                    if (d) tx = [[LTCTransaction alloc] initWithData:d];
                    if (tx) [txs addObject:tx];
                    break;
                case LTCPaymentKeyRefundTo: {
                    NSInteger offset2 = 0;
                    LTCAmount amount = LTCUnspecifiedPaymentAmount;
                    NSData* scriptData = nil;
                    // both amount and scriptData are optional, so we try to read any of them
                    while (offset2 < d.length) {
                        [LTCProtocolBuffers fieldAtOffset:&offset2 int:(uint64_t*)&amount data:&scriptData fromData:d];
                    }
                    if (scriptData) {
                        LTCScript* script = [[LTCScript alloc] initWithData:scriptData];
                        if (!script) {
                            NSLog(@"CoreLitecoin ERROR: Received invalid script data in Payment Request Details: %@", scriptData);
                            return nil;
                        }
                        LTCTransactionOutput* txout = [[LTCTransactionOutput alloc] initWithValue:amount script:script];
                        [outputs addObject:txout];
                    }
                    break;
                }
                case LTCPaymentKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                default: break;
            }

        }

        _transactions = txs;
        _refundOutputs = outputs;
    }
    return self;
}

- (NSData*) data {

    if (!_data) {
        NSMutableData* dst = [NSMutableData data];

        if (_merchantData) {
            [LTCProtocolBuffers writeData:_merchantData withKey:LTCPaymentKeyMerchantData toData:dst];
        }

        for (LTCTransaction* tx in _transactions) {
            [LTCProtocolBuffers writeData:tx.data withKey:LTCPaymentKeyTransactions toData:dst];
        }

        for (LTCTransactionOutput* txout in _refundOutputs) {
            NSMutableData* outputData = [NSMutableData data];

            if (txout.value != LTCUnspecifiedPaymentAmount) {
                [LTCProtocolBuffers writeInt:txout.value withKey:LTCOutputKeyAmount toData:outputData];
            }
            [LTCProtocolBuffers writeData:txout.script.data withKey:LTCOutputKeyScript toData:outputData];
            [LTCProtocolBuffers writeData:outputData withKey:LTCPaymentKeyRefundTo toData:dst];
        }

        if (_memo) {
            [LTCProtocolBuffers writeString:_memo withKey:LTCPaymentKeyMemo toData:dst];
        }

        _data = dst;
    }
    return _data;
}

@end






















@implementation LTCPaymentACK

- (id) initWithData:(NSData*)data {
    if (!data) return nil;

    if (self = [super init]) {
        NSInteger offset = 0;
        while (offset < data.length) {
            uint64_t integer = 0;
            NSData* d = nil;

            switch ([LTCProtocolBuffers fieldAtOffset:&offset int:&integer data:&d fromData:data]) {
                case LTCPaymentAckKeyPayment:
                    if (d) _payment = [[LTCPayment alloc] initWithData:d];
                    break;
                case LTCPaymentAckKeyMemo:
                    if (d) _memo = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                    break;
                default: break;
            }
        }
        
        // payment object is required.
        if (! _payment) return nil;
    }
    return self;
}


- (NSData*) data {
    
    if (!_data) {
        NSMutableData* dst = [NSMutableData data];
        
        [LTCProtocolBuffers writeData:_payment.data withKey:LTCPaymentAckKeyPayment toData:dst];
        
        if (_memo) {
            [LTCProtocolBuffers writeString:_memo withKey:LTCPaymentAckKeyMemo toData:dst];
        }
        
        _data = dst;
    }
    return _data;
}


@end
