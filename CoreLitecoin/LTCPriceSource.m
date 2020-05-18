// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCPriceSource.h"
#import "LTCErrors.h"



@implementation LTCPriceSourceResult
@end

@implementation LTCPriceSource

+ (NSMutableDictionary*) mutableSources {
    static dispatch_once_t onceToken;
    static NSMutableDictionary* sources;
    dispatch_once(&onceToken, ^{
        sources = [NSMutableDictionary dictionary];
    });
    return sources;
}

+ (NSDictionary*) sources {
    return [self mutableSources];
}

// Returns a registered price source. See `+registerPriceSource:forName:`.
+ (LTCPriceSource*) priceSourceWithName:(NSString*)name {
    if (!name) return nil;
    return [self mutableSources][name];
}

// Registers a price source with a given name.
+ (void) registerPriceSource:(LTCPriceSource*)priceSource {
    if (!priceSource) return;
    [self mutableSources][priceSource.name] = priceSource;
}

// Name of the source (e.g. "Paymium" or "Coindesk").
- (NSString*) name {
    [NSException raise:@"LTCPriceSource method not implemented" format:@"You must override -name method."];
    return nil;
}

// Supported currency codes ("USD", "EUR", "CNY" etc).
- (NSArray*) currencyCodes {
    [NSException raise:@"LTCPriceSource method not implemented" format:@"You must override -currencyCodes method."];
    return nil;
}

// Returns a NSURLRequest to fetch the avg price.
- (NSURLRequest*) requestForCurrency:(NSString*)currencyCode {
    [NSException raise:@"LTCPriceSource method not implemented" format:@"You must override either -loadPriceForCurrency:error: or -requestForCurrency:"];
    return nil;
}

// Returns price decoded from the parsedData (JSON by default).
- (LTCPriceSourceResult*) resultFromParsedData:(id)parsedData currencyCode:(NSString*)currencyCode error:(NSError**)errorOut {
    [NSException raise:@"LTCPriceSource method not implemented" format:@"You must override -resultFromParsedData:currencyCode:error: method."];
    return nil;
}

// Loads average price per LTC.
// Override this method to fetch the average price.
// Alternatively override the helper methods above to avoid dealing with networking and JSON parsing.
- (void) loadPriceForCurrency:(NSString*)currencyCode
            completionHandler:(void(^)(LTCPriceSourceResult* result, NSError* error))completionBlock {
    [self loadPriceForCurrency:currencyCode
             completionHandler:completionBlock
                         queue:dispatch_get_main_queue()];
}

- (void) loadPriceForCurrency:(NSString*)currencyCode
            completionHandler:(void(^)(LTCPriceSourceResult* result, NSError* error))completionBlock
                        queue:(dispatch_queue_t)queue {

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSError* error = nil;
        LTCPriceSourceResult* result = [self loadPriceForCurrency:currencyCode error:&error];

        if (!result) {
            dispatch_async(queue, ^{
                completionBlock(nil, error);
            });
            return;
        }

        dispatch_async(queue, ^{
            completionBlock(result, nil);
        });
    });
}

// Synchronous API used internally by asynchronous API.
- (LTCPriceSourceResult*) loadPriceForCurrency:(NSString*)currencyCode error:(NSError**)errorOut {
    NSParameterAssert(currencyCode);

    if (![self.currencyCodes containsObject:currencyCode]) {
        NSError* error = [NSError errorWithDomain:LTCErrorDomain
                                             code:LTCErrorUnsupportedCurrencyCode
                                         userInfo:@{}];
        if (errorOut) *errorOut = error;
        return nil;
    }

    NSURLRequest* request = [self requestForCurrency:currencyCode];

    NSError* error = nil;
    NSURLResponse* response = nil;
    NSData* data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];

    if (!data || !response) {
        if (errorOut) *errorOut = error;
        return nil;
    }

    // Check for HTTP status code.
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
        if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
            error = [NSError errorWithDomain:LTCErrorDomain
                                        code:httpResponse.statusCode
                                    userInfo:@{}];
            if (errorOut) *errorOut = error;
            return nil;
        }
    }

    id parsedData = [self parseData:data error:&error];

    if (!parsedData) {
        if (errorOut) *errorOut = error;
        return nil;
    }

    LTCPriceSourceResult* result = [self resultFromParsedData:parsedData currencyCode:currencyCode error:&error];

    if (!result) {
        if (errorOut) *errorOut = error;
        return nil;
    }

    return result;
}


// Returns a NSURLRequest to fetch the avg price.
// By default parses data as JSON and returns NSDictionary or NSArray whichever is encoded in JSON.
- (id) parseData:(NSData*)data error:(NSError**)errorOut {
    if (!data) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:errorOut];
}

@end


@implementation LTCPriceSourceCoindesk

+ (void) load {
    [self registerPriceSource:[[self alloc] init]];
}

- (NSString*) name { return @"Coindesk"; }

// Full list is here: http://api.coindesk.com/v1/bpi/supported-currencies.json
- (NSArray*) currencyCodes { return @[@"AED", @"AFN", @"ALL", @"AMD", @"ANG", @"AOA", @"ARS", @"AUD", @"AWG", @"AZN", @"BAM", @"BBD", @"BDT", @"BGN", @"BHD", @"BIF", @"BMD", @"BND", @"BOB", @"BRL", @"BSD", @"LTC", @"BTN", @"BWP", @"BYR", @"BZD", @"CAD", @"CDF", @"CHF", @"CLF", @"CLP", @"CNY", @"COP", @"CRC", @"CUP", @"CVE", @"CZK", @"DJF", @"DKK", @"DOP", @"DZD", @"EEK", @"EGP", @"ERN", @"ETB", @"EUR", @"FJD", @"FKP", @"GBP", @"GEL", @"GHS", @"GIP", @"GMD", @"GNF", @"GTQ", @"GYD", @"HKD", @"HNL", @"HRK", @"HTG", @"HUF", @"IDR", @"ILS", @"INR", @"IQD", @"IRR", @"ISK", @"JEP", @"JMD", @"JOD", @"JPY", @"KES", @"KGS", @"KHR", @"KMF", @"KPW", @"KRW", @"KWD", @"KYD", @"KZT", @"LAK", @"LBP", @"LKR", @"LRD", @"LSL", @"LTL", @"LVL", @"LYD", @"MAD", @"MDL", @"MGA", @"MKD", @"MMK", @"MNT", @"MOP", @"MRO", @"MTL", @"MUR", @"MVR", @"MWK", @"MXN", @"MYR", @"MZN", @"NAD", @"NGN", @"NIO", @"NOK", @"NPR", @"NZD", @"OMR", @"PAB", @"PEN", @"PGK", @"PHP", @"PKR", @"PLN", @"PYG", @"QAR", @"RON", @"RSD", @"RUB", @"RWF", @"SAR", @"SBD", @"SCR", @"SDG", @"SEK", @"SGD", @"SHP", @"SLL", @"SOS", @"SRD", @"STD", @"SVC", @"SYP", @"SZL", @"THB", @"TJS", @"TMT", @"TND", @"TOP", @"TRY", @"TTD", @"TWD", @"TZS", @"UAH", @"UGX", @"USD", @"UYU", @"UZS", @"VEF", @"VND", @"VUV", @"WST", @"XAF", @"XAG", @"XAU", @"XBT", @"XCD", @"XDR", @"XOF", @"XPF", @"YER", @"ZAR", @"ZMK", @"ZMW", @"ZWL"]; }

// Returns a NSURLRequest to fetch the avg price.
- (NSURLRequest*) requestForCurrency:(NSString*)currencyCode {
    return [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://api.coindesk.com/v1/bpi/currentprice/%@.json", currencyCode]]];
}

- (LTCPriceSourceResult*) resultFromParsedData:(id)parsedData currencyCode:(NSString*)currencyCode error:(NSError**)errorOut {
    // {"time":{"updatedISO":"2015-01-07T10:59:00+00:00",...},"bpi":{"EUR":{"code":"EUR","rate":"241.4845","description":"Euro","rate_float":241.4845}}}
    LTCPriceSourceResult* result = [[LTCPriceSourceResult alloc] init];
    // Coindesk provides exact decimal numbers, but separates thousands by comma which we need to strip to make NSDecimalNumber parse it.
    NSString* rateString = [parsedData[@"bpi"][currencyCode][@"rate"] stringByReplacingOccurrencesOfString:@"," withString:@""];
    result.averageRate = [NSDecimalNumber decimalNumberWithString:rateString];
    result.currencyCode = currencyCode;
    result.nativeCurrencyCode = @"USD";
    result.date = [NSDate date];
    // TODO: parse ISO8601 date here.
    return result;
}

@end

// Winklevoss Bitcoin Index. USD only.
@implementation LTCPriceSourceWinkdex

+ (void) load {
    [self registerPriceSource:[[self alloc] init]];
}

- (NSString*) name { return @"Winkdex"; }

- (NSArray*) currencyCodes { return @[@"USD"]; }

// Returns a NSURLRequest to fetch the avg price.
- (NSURLRequest*) requestForCurrency:(NSString*)currencyCode {
    return [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://winkdex.com/api/v0/price"]];
}

- (LTCPriceSourceResult*) resultFromParsedData:(id)parsedData currencyCode:(NSString*)currencyCode error:(NSError**)errorOut {
    // {"price": 63984, "timestamp": "2014-07-16T22:47:00Z"}
    LTCPriceSourceResult* result = [[LTCPriceSourceResult alloc] init];
    result.averageRate = [[NSDecimalNumber decimalNumberWithString:[parsedData[@"price"] stringValue]] decimalNumberByMultiplyingByPowerOf10:-2];
    result.currencyCode = @"USD";
    result.nativeCurrencyCode = @"USD";
    result.date = [NSDate date];
    // TODO: parse ISO8601 date here.
    return result;
}

@end

// Coinbase market price. USD only.
@implementation LTCPriceSourceCoinbase

+ (void) load {
    [self registerPriceSource:[[self alloc] init]];
}

- (NSString*) name { return @"Coinbase"; }

- (NSArray*) currencyCodes { return @[@"USD"]; }

// Returns a NSURLRequest to fetch the avg price.
- (NSURLRequest*) requestForCurrency:(NSString*)currencyCode {
    return [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://api.coinbase.com/v1/prices/spot_rate"]];
}

- (LTCPriceSourceResult*) resultFromParsedData:(id)parsedData currencyCode:(NSString*)currencyCode error:(NSError**)errorOut {
    // {"amount":"287.54","currency":"USD"}
    LTCPriceSourceResult* result = [[LTCPriceSourceResult alloc] init];
    result.averageRate = [NSDecimalNumber decimalNumberWithString:parsedData[@"amount"]];
    result.currencyCode = @"USD";
    result.nativeCurrencyCode = @"USD";
    result.date = [NSDate date];
    return result;
}

@end

// Paymium market price. EUR only.
@implementation LTCPriceSourcePaymium

+ (void) load {
    [self registerPriceSource:[[self alloc] init]];
}

- (NSString*) name { return @"Paymium"; }

- (NSArray*) currencyCodes { return @[@"EUR"]; }

// Returns a NSURLRequest to fetch the avg price.
- (NSURLRequest*) requestForCurrency:(NSString*)currencyCode {
    return [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://paymium.com/api/v1/data/eur/ticker"]];
}

- (LTCPriceSourceResult*) resultFromParsedData:(id)parsedData currencyCode:(NSString*)currencyCode error:(NSError**)errorOut {
    // {"high":250.0,"low":229.0,"volume":167.60924709,"bid":242.0,"ask":246.0,"midpoint":244.0,"vwap":236.52937755,"at":1420623750,"price":242.0,"variation":5.6769,"currency":"EUR"}
    LTCPriceSourceResult* result = [[LTCPriceSourceResult alloc] init];
    result.averageRate = [NSDecimalNumber decimalNumberWithString:[parsedData[@"price"] stringValue]];
    result.currencyCode = @"EUR";
    result.nativeCurrencyCode = @"EUR";
    result.date = [NSDate dateWithTimeIntervalSince1970:[parsedData[@"at"] doubleValue]];
    return result;
}

@end


