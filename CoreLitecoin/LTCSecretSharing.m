// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCErrors.h"
#import "LTCData.h"
#import "LTCBigNumber.h"
#import "LTCSecretSharing.h"

@interface LTCSecretSharing ()
@property(nonatomic, readwrite) LTCSecretSharingVersion version;
@property(nonatomic, readwrite) LTCBigNumber* order;
@property(nonatomic, readwrite) NSInteger bitlength;
@end

@implementation LTCSecretSharing

// Returns a configuration for compact 128-bit secrets with up to 16 shares.
- (id __nonnull) initWithVersion:(LTCSecretSharingVersion)version {
    if (self = [super init]) {
        self.version = version;
        if (version == LTCSecretSharingVersionCompact96) {
            // 0xffffffffffffffffffffffef
            self.bitlength = 96;
            self.order = [[LTCBigNumber alloc] initWithString:@"ffffffffffffffffffffffef" base:16];
        } else if (version == LTCSecretSharingVersionCompact104) {
            // 0xffffffffffffffffffffffffef
            self.bitlength = 104;
            self.order = [[LTCBigNumber alloc] initWithString:@"ffffffffffffffffffffffffef" base:16];
        } else if (version == LTCSecretSharingVersionCompact128) {
            // 0xffffffffffffffffffffffffffffff61
            self.bitlength = 128;
            self.order = [[LTCBigNumber alloc] initWithString:@"ffffffffffffffffffffffffffffff61" base:16];
        } else {
            [NSException raise:@"LTCSecretSharing supports only LTCSecretSharingVersionCompact{96,104,128} versions" format:@""];
        }
    }
    return self;
}

- (NSArray* __nullable) splitSecret:(NSData* __nonnull)secret threshold:(NSInteger)m shares:(NSInteger)n error:(NSError**)errorOut {

    if (secret.length*8 != self.bitlength) {
        if (errorOut) *errorOut = [NSError errorWithDomain:LTCErrorDomain code:LTCErrorIncompatibleSecret userInfo:@{NSLocalizedDescriptionKey: @"Secret length does not match bitlength of LTCSecretSharing."}];
        return nil;
    }
    LTCBigNumber* prime = self.order;
    LTCBigNumber* secretNumber = [[LTCBigNumber alloc] initWithUnsignedBigEndian:secret];

    if ([secretNumber greaterOrEqual:prime]) {
        if (errorOut) *errorOut = [NSError errorWithDomain:LTCErrorDomain code:LTCErrorIncompatibleSecret userInfo:@{NSLocalizedDescriptionKey: @"Secret as bigint must be less than prime order of LTCSecretSharing."}];
        return nil;
    }

    if (!(n >= 1 && n <= 16)) {
        if (errorOut) *errorOut = [NSError errorWithDomain:LTCErrorDomain code:LTCErrorIncompatibleSecret userInfo:@{NSLocalizedDescriptionKey: @"Number of shares (N) must be between 1 and 16."}];
        return nil;
    }

    if (!(m >= 1 && m <= n)) {
        if (errorOut) *errorOut = [NSError errorWithDomain:LTCErrorDomain code:LTCErrorIncompatibleSecret userInfo:@{NSLocalizedDescriptionKey: @"Threshold (M) must be between 1 and N (number of shares)."}];
        return nil;
    }

    NSMutableArray* shares = [NSMutableArray array];
    NSMutableArray* coefficients = [NSMutableArray array];
    [coefficients addObject:secretNumber];
    for (NSInteger i = 0; i < (m-1); i++) {
        // Generate unpredictable yet deterministic coefficients for each secret and M.
        NSMutableData* seed = [secret mutableCopy];
        unsigned char mbyte = m;
        unsigned char ibyte = i;
        [seed appendBytes:&mbyte length:1];
        [seed appendBytes:&ibyte length:1];
        NSData* coefdata = [self prng:seed];
        LTCBigNumber* coef = [[LTCBigNumber alloc] initWithUnsignedBigEndian:coefdata];
        [coefficients addObject:coef];
    }
    for (NSInteger i = 0; i < n; i++) {
        LTCMutableBigNumber* x = [[LTCMutableBigNumber alloc] initWithInt64:i+1];
        NSInteger exp = 1;
        LTCMutableBigNumber* y = [coefficients[0] mutableCopy];
        // while exp < m
        //   y = (y + (coef[exp] * ((x**exp) % prime) % prime)) % prime
        //   exp += 1
        // end
        while (exp < m) {
            LTCMutableBigNumber* coef = [coefficients[exp] mutableCopy];
            LTCMutableBigNumber* xexp = [x mutableCopy];
            [xexp exp:[[LTCBigNumber alloc] initWithInt64:exp] mod:prime];
            [coef multiply:xexp mod:prime];
            [y add:coef mod:prime];
            exp += 1;
        }
        NSData* share = [self encodeShareM:m X:i+1 Y:y];
        [shares addObject:share];
    }
    return shares;
}

- (NSData* __nullable) joinShares:(NSArray* __nonnull)shares error:(NSError**)errorOut {

    LTCBigNumber* prime = self.order;

    shares = [[NSSet setWithArray:shares] allObjects]; // uniq
    NSMutableArray* points = [NSMutableArray array];
    for (id sh in shares) {
        id p = [self decodeShare:sh];
        if (p) { [points addObject:p]; }
    }
    if (points.count == 0) {
        if (errorOut) *errorOut = [NSError errorWithDomain:LTCErrorDomain code:LTCErrorInsufficientShares userInfo:@{NSLocalizedDescriptionKey: @"No shares provided."}];
        return nil;
    }

    NSMutableSet* ms = [NSMutableSet set];
    for (id p in points) {
        [ms addObject:p[0]];
    }
    if (ms.count > 1) {
        if (errorOut) *errorOut = [NSError errorWithDomain:LTCErrorDomain code:LTCErrorMalformedShare userInfo:@{NSLocalizedDescriptionKey: @"All shares must have the same threshold (M) value."}];
        return nil;
    }
    NSMutableSet* xs = [NSMutableSet set];
    for (id p in points) {
        [xs addObject:p[1]];
    }
    if (xs.count != points.count) {
        if (errorOut) *errorOut = [NSError errorWithDomain:LTCErrorDomain code:LTCErrorMalformedShare userInfo:@{NSLocalizedDescriptionKey: @"All shares must have unique indexes (X) values."}];
        return nil;
    }
    NSInteger m = [[ms anyObject] integerValue];
    if (points.count < m) {
        if (errorOut) *errorOut = [NSError errorWithDomain:LTCErrorDomain code:LTCErrorInsufficientShares userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Not enough shares to restore the secret (need %@)", @(m)]}];
        return nil;
    }
    LTCMutableBigNumber* y = [LTCMutableBigNumber zero];
    for (NSInteger formula = 0; formula < m; formula++) {
        // Multiply the numerator across the top and denominators across the bottom to do Lagrange's interpolation
        LTCMutableBigNumber* numerator = [LTCMutableBigNumber one];
        LTCMutableBigNumber* denominator = [LTCMutableBigNumber one];
        for (NSInteger count = 0; count < m; count++) {
            if (formula != count) { // skip element with i == j
                LTCMutableBigNumber* startposition = [[[LTCBigNumber alloc] initWithInt64:[points[formula][1] longLongValue]] mutableCopy];
                LTCBigNumber* negnextposition = [[LTCBigNumber alloc] initWithInt64:-[points[count][1] longLongValue]];
                [numerator multiply:negnextposition mod:prime];
                [startposition add:negnextposition];
                [denominator multiply:startposition mod:prime];
            }
        }
        LTCMutableBigNumber* value = [points[formula][2] mutableCopy];
        [value multiply:numerator];
        [value multiply:[denominator inverseMod:prime] mod:prime];
        [y add:prime];
        [y add:value mod:prime];
    }
    return [y.unsignedBigEndian subdataWithRange:NSMakeRange(32-self.bitlength/8, self.bitlength/8)];
}

- (NSData*) prng:(NSData*)seed {
    /*
     def prng(seed)
         x = Order
         s = nil
         pad = "".b
         while x >= Order
             s = Digest::SHA2.digest(Digest::SHA2.digest(seed + pad))[0,16]
             x = int_from_be(s)
             pad = pad + "\x00".b
         end
         s
     end
     */
    LTCBigNumber* x = self.order;
    NSData* s = nil;
    NSMutableData* pad = [NSMutableData data];
    while ([x greaterOrEqual:self.order]) {
        NSMutableData* input = [seed mutableCopy];
        [input appendData:pad];
        s = [LTCHash256(input) subdataWithRange:NSMakeRange(0, self.bitlength/8)];
        x = [[LTCBigNumber alloc] initWithUnsignedBigEndian:s];
        unsigned char zero = 0;
        [pad appendBytes:&zero length:1];
    }
    return s;
}

// Returns mmmmxxxx yyyyyyyy yyyyyyyy ... (N bytes of y)
- (NSData*) encodeShareM:(NSInteger)m X:(NSInteger)x Y:(LTCBigNumber*)y {
    m = [self toNibble:m];
    x = [self toNibble:x];
    unsigned char prefix = (m << 4) + x;
    NSMutableData* data = [[NSMutableData alloc] initWithBytes:&prefix length:1];
    [data appendData:[y.unsignedBigEndian subdataWithRange:NSMakeRange(32-self.bitlength/8, self.bitlength/8)]];
    return data;
}

// Returns [m, x, y] where m, x - NSNumber, y - LTCBigNumber
- (NSArray*) decodeShare:(NSData*)share {
    if (share.length != (self.bitlength/8+1)) return nil;
    unsigned char byte = ((unsigned char*)share.bytes)[0];
    NSInteger m = [self fromNibble:byte >> 4];
    NSInteger x = [self fromNibble:byte & 0x0f];
    LTCBigNumber* y = [[LTCBigNumber alloc]initWithUnsignedBigEndian:[share subdataWithRange:NSMakeRange(1, self.bitlength/8)]];
    return @[@(m), @(x), y];
}

// Encodes values in range 1..16 to one nibble where all values are encoded as-is,
// except for 16 which becomes 0. This is to make strings look friendly for common cases when M,N < 16
- (NSInteger) toNibble:(NSInteger)x {
    return x == 16 ? 0 : x;
}

- (NSInteger) fromNibble:(NSInteger)x {
    return x == 0 ? 16 : x;
}

@end
