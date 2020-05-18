#import "LTCBitcoinURL.h"
#import "LTCAddress.h"
#import "LTCAssetAddress.h"
#import "LTCAssetID.h"
#import "LTCNumberFormatter.h"

NSString* const LTCBitcoinURLSchemeBitcoin = @"bitcoin";
NSString* const LTCBitcoinURLSchemeOpenAssets = @"openassets";

@interface LTCBitcoinURL ()
@property NSMutableDictionary* mutableQueryParameters;
@property NSString* scheme;
@end

@implementation LTCBitcoinURL

@synthesize amount = _amount;
@synthesize label = _label;
@synthesize assetID = _assetID;
@synthesize message = _message;
@synthesize paymentRequestURL = _paymentRequestURL;
@synthesize queryParameters = _queryParameters;

+ (NSURL*) URLWithAddress:(LTCAddress*)address amount:(LTCAmount)amount label:(NSString*)label {
    LTCBitcoinURL* btcurl = [[self alloc] init];
    btcurl.scheme = @"bitcoin";
    btcurl.address = address;
    btcurl.amount = amount;
    btcurl.label = label;
    return btcurl.URL;
}

- (id) init {
    if (self = [super init]) {
        self.mutableQueryParameters = [NSMutableDictionary dictionary];
    }
    return self;
}

- (id) initWithURL:(NSURL*)url {
    if (!url) return nil;

    NSURLComponents* comps = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];

    if (!comps) {
        return nil;
    }

    NSString* scheme = [comps.scheme lowercaseString];

    // We only support bitcoin: and openassets: schemes.
    if (![scheme isEqual:LTCBitcoinURLSchemeBitcoin] &&
        ![scheme isEqual:LTCBitcoinURLSchemeOpenAssets]) {
        return nil;
    }

    // We allow empty address, but if it's not empty, it must be a valid address.
    LTCAddress* address = nil;
    if (comps.path.length > 0) {
        address = [LTCAddress addressWithString:comps.path];
        if (!address) {
            return nil;
        }
    }

    if (self = [self init]) {
        self.address = address;
        for (NSURLQueryItem* item in comps.queryItems) {
            [self.mutableQueryParameters setObject:item.value forKey:item.name];
        }
    }

    self.scheme = scheme;

    return self;
}

- (BOOL) isValid {
    return [self isValidBitcoinURL] || [self isValidOpenAssetsURL];
}

- (BOOL) isBitcoinAddress {
    return [self.address isKindOfClass:[LTCPublicKeyAddress class]] ||
           [self.address isKindOfClass:[LTCScriptHashAddress class]];
}

- (BOOL) isValidBitcoinURL {
    if ([self.scheme isEqualToString:LTCBitcoinURLSchemeBitcoin]) {
        return [self isBitcoinAddress] || (!self.address && self.paymentRequestURL);
    }
    return NO;
}

- (BOOL) isValidOpenAssetsURL {
    if ([self.scheme isEqualToString:LTCBitcoinURLSchemeBitcoin] ||
        [self.scheme isEqualToString:LTCBitcoinURLSchemeOpenAssets]) {

        // We should either have an asset address with asset ID, or no address and payment request URL.
        return ([self.address isKindOfClass:[LTCAssetAddress class]] && self.assetID) || (!self.address && !self.assetID && self.paymentRequestURL);
    }
    return NO;
}

- (NSURL*) URL {
    NSMutableString* string = [NSMutableString stringWithFormat:@"%@:%@", self.scheme, self.address ? self.address.string : @""];
    NSMutableArray* queryItems = [NSMutableArray array];

    if(self.queryParameters) {
        NSArray* keys = self.queryParameters.allKeys;
        for (NSString* key in keys) {
            NSString* encodedKey = CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)key, NULL, CFSTR("&="),
                                                                                             kCFStringEncodingUTF8));
            NSString* encodedValue = CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)[self.queryParameters objectForKey:key], NULL, CFSTR("&="),
                                                                                               kCFStringEncodingUTF8));
            [queryItems addObject:[NSString stringWithFormat:@"%@=%@",encodedKey,encodedValue]];
             
        }
    }

    if (queryItems.count > 0) {
        [string appendString:@"?"];
        [string appendString:[queryItems componentsJoinedByString:@"&"]];
    }

    return [NSURL URLWithString:string];
}

- (id)objectForKeyedSubscript:(id <NSCopying>)key {
    return self.mutableQueryParameters[key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key {
    self.mutableQueryParameters[key] = obj;
}

- (NSDictionary*) queryParameters {
    return self.mutableQueryParameters;
}

- (void) setQueryParameters:(NSDictionary *)queryParameters {
    self.mutableQueryParameters = [NSMutableDictionary dictionaryWithDictionary:queryParameters ?: @{}];
    //Reset cached standard query parameters
    _amount = 0;
    _paymentRequestURL = nil;
    _message = nil;
    _label = nil;
    _assetID = nil;
}




#pragma mark - Standard query parameters


- (void) setAddress:(LTCAddress *)address {
    // Make sure to reformat amount according to the address.
    LTCAmount amount = self.amount;
    _address = address;
    self.amount = amount;
}

- (LTCAmount) amount {
    if(_amount == 0){
        NSString* amountString = self.mutableQueryParameters[@"amount"];
        if (amountString) _amount = [LTCBitcoinURL parseAmount:amountString address:self.address];
    }
    return _amount;
}

- (void) setAmount:(LTCAmount)amount {
    _amount = amount;
    if (amount > 0) {
        NSString* amountString = [LTCBitcoinURL formatAmount:amount address:self.address];
        self.mutableQueryParameters[@"amount"] = amountString;
    } else {
        [self.mutableQueryParameters removeObjectForKey:@"amount"];
    }
}

- (LTCAssetID*) assetID {
    return [LTCAssetID assetIDWithString:self.mutableQueryParameters[@"asset"]];
}

- (void) setAssetID:(LTCAssetID *)assetID {
    if (assetID) {
        self.mutableQueryParameters[@"asset"] = assetID.string;
    } else {
        [self.mutableQueryParameters removeObjectForKey:@"asset"];
    }
}

- (NSURL*) paymentRequestURL {
    if (!_paymentRequestURL) {
        NSString* r = self.mutableQueryParameters[@"r"];
        if (r) _paymentRequestURL = [NSURL URLWithString:r];
    }
    return _paymentRequestURL;
}

- (void) setPaymentRequestURL:(NSURL *)paymentRequestURL {
    _paymentRequestURL = paymentRequestURL;
    if(paymentRequestURL != nil) {
        self.mutableQueryParameters[@"r"] = paymentRequestURL.absoluteString;
    } else {
        [self.mutableQueryParameters removeObjectForKey:@"r"];
    }
}

- (NSString*) label {
    if(!_label) {
        _label = self.mutableQueryParameters[@"label"];
    }
    return _label;
}

- (void) setLabel:(NSString *)label {
    _label = label;
    if(label != nil) {
        self.mutableQueryParameters[@"label"] = label;
    } else {
        [self.mutableQueryParameters removeObjectForKey:@"label"];
    }
}

- (NSString*) message {
    if(!_message) {
        _message = self.mutableQueryParameters[@"message"];
    }
    return _message;
}

- (void) setMessage:(NSString *)message {
    _message = message;
    if(message != nil) {
        self.mutableQueryParameters[@"message"] = message;
    } else {
        [self.mutableQueryParameters removeObjectForKey:@"message"];
    }
}

#pragma mark - Helpers

+ (NSString*) formatAmount:(LTCAmount)amount address:(LTCAddress*)address {
    // Open Assets urls should have amount formatted as integer
    if (address && [address isKindOfClass:[LTCAssetAddress class]]) {
        return @(amount).stringValue;
    }
    return [NSString stringWithFormat:@"%d.%08d", (int)(amount / LTCCoin), (int)(amount % LTCCoin)];
}

+ (LTCAmount) parseAmount:(NSString*)string address:(LTCAddress*)address {

    // Open Assets urls should have amount formatted as integer
    if (address && [address isKindOfClass:[LTCAssetAddress class]]) {
        return [string longLongValue];
    }

    NSLocale* locale = [[NSLocale localeWithLocaleIdentifier:@"en_US"] copy]; // uses period (".") as a decimal point.
    NSAssert([[locale objectForKey:NSLocaleDecimalSeparator] isEqual:@"."], @"must be point as a decimal separator");
    NSDecimalNumber* dn = [NSDecimalNumber decimalNumberWithString:string locale:locale];
    // Fixes crash on URL like "bitcoin:1shaYanre36PBhspFL9zG7nt6tfDhxQ4u?amount=#" (https://twitter.com/sbetamc/status/581974120440700929)
    if ([dn isEqual:[NSDecimalNumber notANumber]]) {
        return 0;
    }
    if (LTCAmountFromDecimalNumber(dn) > 21000000) { // prevent overflow when multiplying by 8.
        return 0;
    }
    dn = [dn decimalNumberByMultiplyingByPowerOf10:8];
    return LTCAmountFromDecimalNumber(dn);
}

@end
