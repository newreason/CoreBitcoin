// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.
// Implementation of blind signatures for Bitcoin transactions:
// http://oleganza.com/blind-ecdsa-draft-v2.pdf

#import "LTCBlindSignature.h"
#import "LTCData.h"
#import "LTCKey.h"
#import "LTCKeychain.h"
#import "LTCCurvePoint.h"
#import "LTCBigNumber.h"
#include <openssl/ec.h>
#include <openssl/ecdsa.h>
#include <openssl/evp.h>
#include <openssl/bn.h>


@implementation LTCBlindSignature {
    LTCKeychain* _clientKeychain;
    LTCKeychain* _custodianKeychain;
}

// High-level API
// This is BIP32-based API to keep track of just a single private key for multiple signatures.

// Alice as a client needs private client keychain and public custodian keychain (provided by Bob).
- (id) initWithClientKeychain:(LTCKeychain*)clientKeychain custodianKeychain:(LTCKeychain*)custodianKeychain {
    if (!clientKeychain || !custodianKeychain) return nil;
    
    // Sanity check: client keychain must be private and custodian keychain must be public.
    if (!clientKeychain.isPrivate) return nil;
    if (custodianKeychain.isPrivate) return nil;

    if (self = [super init]) {
        _clientKeychain = clientKeychain;
        _custodianKeychain = custodianKeychain;
    }
    return self;
}

// Bob as a custodian only needs his own private keychain.
- (id) initWithCustodianKeychain:(LTCKeychain*)custodianKeychain {
    if (!custodianKeychain) return nil;
    
    // Sanity check: custodian keychain must be private.
    if (!custodianKeychain.isPrivate) return nil;
    
    if (self = [super init]) {
        _custodianKeychain = custodianKeychain;
    }
    return self;
}

// Steps 4-6: Alice generates public key to use in a transaction.
- (LTCKey*) publicKeyAtIndex:(uint32_t)index {
    LTCBigNumber* a = [self privateNumberFromKeychain:_clientKeychain index:4*index + 0];
    LTCBigNumber* b = [self privateNumberFromKeychain:_clientKeychain index:4*index + 1];
    LTCBigNumber* c = [self privateNumberFromKeychain:_clientKeychain index:4*index + 2];
    LTCBigNumber* d = [self privateNumberFromKeychain:_clientKeychain index:4*index + 3];
    
    LTCCurvePoint* P = [self pointFromKeychain:_custodianKeychain index:2*index + 0];
    LTCCurvePoint* Q = [self pointFromKeychain:_custodianKeychain index:2*index + 1];
    
    NSArray* KT = [self alice_K_and_T_for_a:a b:b c:c d:d P:P Q:Q];
    
    LTCCurvePoint* K = KT.firstObject;
    LTCCurvePoint* T = KT.lastObject;
    
    NSAssert(K, @"sanity check");
    NSAssert(T, @"sanity check");
    
    LTCKey* key = [[LTCKey alloc] initWithCurvePoint:T];
    
    NSAssert(key, @"sanity check");
    
    [K clear];
    [a clear];
    [b clear];
    [c clear];
    [d clear];
    [P clear];
    [Q clear];
    
    return key;
}

// Steps 7-8: Alice blinds her message and sends it to Bob.
// Note: the index will be encoded in the blinded hash so you don't need to carry it to Bob separately.
- (NSData*) blindedHashForHash:(NSData*)hash index:(uint32_t)index {
    if (!hash) return nil;
    
    LTCBigNumber* a = [self privateNumberFromKeychain:_clientKeychain index:4*index + 0];
    LTCBigNumber* b = [self privateNumberFromKeychain:_clientKeychain index:4*index + 1];
    
    LTCBigNumber* h1 = [[LTCBigNumber alloc] initWithUnsignedBigEndian:hash];
    
    LTCBigNumber* h2 = [self aliceBlindedHashForHash:h1 a:a b:b];
    
    [a clear];
    [b clear];
    [h1 clear];
    
    index = OSSwapHostToBigInt32(index);
    
    NSMutableData* result = [NSMutableData dataWithBytes:&index length:4];
    [result appendData:h2.unsignedBigEndian];
    
    return result;
}

// Step 9-10: Bob computes a signature for Alice.
// Note: the index is encoded in the blinded hash and blind signature so we don't need to carry it back and forth.
- (NSData*) blindSignatureForBlindedHash:(NSData*)blindedHash {
    if (!blindedHash) return nil;
    if (blindedHash.length != (4 + 32)) return nil; // blinded hash must contain 32-bit index and 256-bit hash.
    
    uint32_t index = *((uint32_t*)blindedHash.bytes);
    index = OSSwapBigToHostInt32(index);
    
    LTCBigNumber* h2 = [[LTCBigNumber alloc] initWithUnsignedBigEndian:[blindedHash subdataWithRange:NSMakeRange(4, blindedHash.length - 4)]];
    
    //    From
    //      P = p^-1·G = (w + x)·G (where x is a factor in ND(W, 2·i + 0))
    //    follows:
    //      p = (w + x)^-1 mod n
    //
    //    From
    //      Q = q·p^-1·G = (w + y)·G (where y is a factor in ND(W, 2·i + 1))
    //    follows:
    //      q = (w + y)·(w + x)^-1 mod n = (w + y)·p mod n

    LTCBigNumber* order = [LTCCurvePoint curveOrder];
    
    LTCBigNumber* w = [[LTCBigNumber alloc] initWithUnsignedBigEndian:_custodianKeychain.key.privateKey];
    
    LTCBigNumber* x = nil;
    LTCBigNumber* y = nil;
    
    [_custodianKeychain derivedKeychainAtIndex:2*index + 0 hardened:NO factor:&x];
    [_custodianKeychain derivedKeychainAtIndex:2*index + 1 hardened:NO factor:&y];
    
    LTCBigNumber* p = [[[w mutableCopy] add:x mod:order] inverseMod:order];
    LTCBigNumber* q = [[[w mutableCopy] add:y mod:order] multiply:p mod:order];
    
    LTCBigNumber* s1 = [self bobBlindedSignatureForHash:h2 p:p q:q];
    
    [w clear];
    [x clear];
    [y clear];
    [p clear];
    [q clear];
    [h2 clear];
    
    // Return signature with index in the front.
    index = OSSwapHostToBigInt32(index);
    
    NSMutableData* result = [NSMutableData dataWithBytes:&index length:4];
    [result appendData:s1.unsignedBigEndian];
    
    return result;
}

// Step 11: Alice receives signature from Bob and generates final DER-encoded signature to use in transaction.
// Note: Do not forget to add SIGHASH byte in the end when placing in a Bitcoin transaction.
- (NSData*) unblindedSignatureForBlindSignature:(NSData*)blindSignature {
    return [self unblindedSignatureForBlindSignature:blindSignature verifyHash:nil];
}

- (NSData*) unblindedSignatureForBlindSignature:(NSData*)blindSignature verifyHash:(NSData*)hashToVerify {
    if (!blindSignature) return nil;
    if (blindSignature.length < 5) return nil;
    
    uint32_t index = *((uint32_t*)blindSignature.bytes);
    index = OSSwapBigToHostInt32(index);

    LTCBigNumber* s1 = [[LTCBigNumber alloc] initWithUnsignedBigEndian:[blindSignature subdataWithRange:NSMakeRange(4, blindSignature.length - 4)]];

    LTCBigNumber* a = [self privateNumberFromKeychain:_clientKeychain index:4*index + 0];
    LTCBigNumber* b = [self privateNumberFromKeychain:_clientKeychain index:4*index + 1];
    LTCBigNumber* c = [self privateNumberFromKeychain:_clientKeychain index:4*index + 2];
    LTCBigNumber* d = [self privateNumberFromKeychain:_clientKeychain index:4*index + 3];

    LTCCurvePoint* P = [self pointFromKeychain:_custodianKeychain index:2*index + 0];
    LTCCurvePoint* Q = [self pointFromKeychain:_custodianKeychain index:2*index + 1];
    
    NSArray* KT = [self alice_K_and_T_for_a:a b:b c:c d:d P:P Q:Q];
    
    LTCCurvePoint* K = KT.firstObject;
    LTCCurvePoint* T = KT.lastObject;
    
    NSAssert(K, @"sanity check");
    NSAssert(T, @"sanity check");

    LTCBigNumber* s2 = [self aliceUnblindedSignatureForSignature:s1 c:c d:d];
    
    NSAssert(s2, @"sanity check");

    NSData* sig = [self aliceCompleteSignatureForKx:K.x unblindedSignature:s2];

    NSAssert(sig, @"sanity check");
    
    [K clear];
    [T clear];
    [s2 clear];
    [s1 clear];
    [a clear];
    [b clear];
    [c clear];
    [d clear];
    
    // Verify signature
    if (hashToVerify) {
        LTCKey* pubkey = [self publicKeyAtIndex:index];
    
        if (![pubkey isValidSignature:sig hash:hashToVerify]) {
            sig = nil;
        }
        
        [pubkey clear];
    }
    
    return sig;
}


- (LTCBigNumber*) privateNumberFromKeychain:(LTCKeychain*)keychain index:(uint32_t)index {
    LTCKeychain* derivedKC = [keychain derivedKeychainAtIndex:index hardened:YES];
    
    NSAssert(derivedKC, @"sanity check");
    
    LTCKey* key = derivedKC.key;
    
    NSAssert(key, @"sanity check");
    
    NSMutableData* privKeyData = key.privateKey;
    
    NSAssert(privKeyData, @"sanity check");
    
    LTCBigNumber* bn = [[LTCBigNumber alloc] initWithUnsignedBigEndian:privKeyData];
    
    LTCDataClear(privKeyData);
    [key clear];
    [derivedKC clear];
    
    return bn;
}

- (LTCCurvePoint*) pointFromKeychain:(LTCKeychain*)keychain index:(uint32_t)index {
    LTCKeychain* derivedKC = [keychain derivedKeychainAtIndex:index hardened:NO];
    
    NSAssert(derivedKC, @"sanity check");
    
    LTCKey* key = derivedKC.key;
    
    NSAssert(key, @"sanity check");
    
    LTCCurvePoint* point = [key curvePoint];
    
    NSAssert(point, @"sanity check");
    
    [key clear];
    [derivedKC clear];
    
    return point;
}


// Core Algorithm
// Exposed as a public API for testing purposes. Use less verbose high-level API above for real usage.

// Alice wants Bob to sign her transactions blindly.
// Bob will provide Alice with blinded public keys and blinded signatures for each transaction.

// 1. Alice chooses random numbers a, b, c, d within [1, n – 1].
// 2. Bob chooses random numbers p, q within [1, n – 1]
//    and sends two EC points to Alice:
//    P = (p^-1·G) and Q = (q·p^-1·G).
// 3. Alice computes K = (c·a)^-1·P and public key T = (a·Kx)^-1·(b·G + Q + d·c^-1·P).
//    Bob cannot know if his parameters were involved in K or T without the knowledge of a, b, c and d.
//    Thus, Alice can safely publish T (e.g. in a Bitcoin transaction that locks funds with T).
// 4. When time comes to sign a message (e.g. redeeming funds locked in a Bitcoin transaction),
//    Alice computes the hash h of her message.
// 5. Alice blinds the hash and sends h2 = a·h + b (mod n) to Bob.
// 6. Bob verifies the identity of Alice via separate communications channel.
// 7. Bob signs the blinded hash and returns the signature to Alice: s1 = p·h2 + q (mod n).
// 8. Alice unblinds the signature: s2 = c·s1 + d (mod n).
// 9. Now Alice has (Kx, s2) which is a valid ECDSA signature of hash h verifiable by public key T.
//    If she uses it in a Bitcoin transaction, she will be able to redeem her locked funds without Bob knowing which transaction he just helped to sign.

// Step 2: P and Q from Bob as blinded "public keys". Both P and C are LTCCurvePoint instances.
- (NSArray*) bob_P_and_Q_for_p:(LTCBigNumber*)p q:(LTCBigNumber*)q {
    if (!p || !q) return nil;
    
    LTCCurvePoint* P = nil;
    LTCCurvePoint* Q = nil;
    LTCBigNumber* invp = nil;
    
    invp = [[p mutableCopy] inverseMod:[LTCCurvePoint curveOrder]];
    
    P = [[LTCCurvePoint generator] multiply:invp];
    Q = [[P copy] multiply:q];
    
    NSAssert(P, @"P should be valid");
    NSAssert(Q, @"Q should be valid");
    
    [invp clear]; // clear sensitive data from temporary variable p^-1
    
    return @[P, Q];
}

// 3. Alice computes K = (c·a)^-1·P and public key T = (a·Kx)^-1·(b·G + Q + d·c^-1·P).
//    Bob cannot know if his parameters were involved in K or T without the knowledge of a, b, c and d.
- (NSArray*) alice_K_and_T_for_a:(LTCBigNumber*)a b:(LTCBigNumber*)b c:(LTCBigNumber*)c d:(LTCBigNumber*)d P:(LTCCurvePoint*)P Q:(LTCCurvePoint*)Q {
    if (!a || !b || !c || !d || !P || !Q) return nil;
    
    // K = (c·a)^-1·P
    // K = (c^-1)·(a^-1)·P
    
    // T = (a·Kx)^-1·(b·G + Q + d·(c^-1)·P).
    // T = (a^-1)·(Kx^-1)·(b·G + Q + d·(c^-1)·P).
    
    // Temporary vars
    LTCBigNumber* curveOrder = [LTCCurvePoint curveOrder];
    LTCBigNumber* invc = nil;
    LTCBigNumber* inva = nil;
    LTCBigNumber* Kx = nil;
    LTCBigNumber* invKx = nil;
    
    // Results
    LTCCurvePoint* K = nil;
    LTCCurvePoint* T = nil;
    
    inva = [[a mutableCopy] inverseMod:curveOrder];
    invc = [[c mutableCopy] inverseMod:curveOrder];
    
    K = [[[P copy] multiply:inva] multiply:invc];
    
    NSAssert(K, @"K should be valid");
    
    Kx = K.x;
    
    invKx = [[Kx mutableCopy] inverseMod:curveOrder];
    
    T = [[[[[[[P copy] multiply:invc] multiply:d] add:Q] addGeneratorMultipliedBy:b] multiply:invKx] multiply:inva];
    
    NSAssert(T, @"T should be valid");
    
    // Clear temporary variables.
    [invc clear];
    [inva clear];
    [Kx clear];
    [invKx clear];
    
    return @[K, T];
}

// Helper for steps 5, 7, 8.
- (LTCBigNumber*) linearTransformOfNumber:(LTCBigNumber*)number multiply:(LTCBigNumber*)a add:(LTCBigNumber*)b {
    if (!number || !a || !b) return nil;
    
    LTCBigNumber* curveOrder = [LTCCurvePoint curveOrder];
    LTCMutableBigNumber* result = [[[number mutableCopy] multiply:a mod:curveOrder] add:b mod:curveOrder];
    return result;
}

// 5. Alice blinds the hash and sends h2 = a·h + b (mod n) to Bob.
- (LTCBigNumber*) aliceBlindedHashForHash:(LTCBigNumber*)hash a:(LTCBigNumber*)a b:(LTCBigNumber*)b {
    return [self linearTransformOfNumber:hash multiply:a add:b];
}

// 7. Bob signs the blinded hash and returns the signature to Alice: s1 = p·h2 + q (mod n).
- (LTCBigNumber*) bobBlindedSignatureForHash:(LTCBigNumber*)hash p:(LTCBigNumber*)p q:(LTCBigNumber*)q {
    return [self linearTransformOfNumber:hash multiply:p add:q];
}

// 8. Alice unblinds the signature: s2 = c·s1 + d (mod n).
- (LTCBigNumber*) aliceUnblindedSignatureForSignature:(LTCBigNumber*)blindSignature c:(LTCBigNumber*)c d:(LTCBigNumber*)d {
    return [self linearTransformOfNumber:blindSignature multiply:c add:d];
}

// DER signature:
// 3045022100d21bdec190e170c6a59a91e002d3a4f26d64afecce704249484d2eb24721358d0220303f16b06e03f0719cadb001ea55f6f2d4f96807291802c2f26c09eb19ca087401
// Segments:
// 0x30 - prefix
// 0x45 - remaining length (69 = 1 + 1 + 33 + 1 + 1 + 32)
// 0x02 - prefix
// 0x21 - r length (33)
// 0x00d21bdec190e170c6a59a91e002d3a4f26d64afecce704249484d2eb24721358d // prefixed by 0x00 because 0xd2 is > 0x7F but the number is unsigned.
// 0x02 - prefix
// 0x20 - s length (32)
// 0x303f16b06e03f0719cadb001ea55f6f2d4f96807291802c2f26c09eb19ca0874 // not prefixed by 0x00 because 0x30 is below 0x7F, so "sign bit" is 0.
// 0x01 - hash type
- (NSData*) aliceCompleteSignatureForKx:(LTCBigNumber*)Kx unblindedSignature:(LTCBigNumber*)unblindedSignature {
    ECDSA_SIG sigValue;
    ECDSA_SIG *sig = &sigValue;
    
    BIGNUM r; BN_init(&r); BN_copy(&r, Kx.BIGNUM);
    BIGNUM s; BN_init(&s); BN_copy(&s, unblindedSignature.BIGNUM);
    
    sig->r = &r;
    sig->s = &s;
    
    // The remaining code is taken from LTCKey where we produce a canonical signature.
    
    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);
    
    EC_GROUP *group = EC_GROUP_new_by_curve_name(NID_secp256k1);
    BIGNUM *order = BN_CTX_get(ctx);
    BIGNUM *halforder = BN_CTX_get(ctx);
    EC_GROUP_get_order(group, order, ctx);
    BN_rshift1(halforder, order);
    if (BN_cmp(sig->s, halforder) > 0) {
        // enforce low S values, by negating the value (modulo the order) if above order/2.
        BN_sub(sig->s, order, sig->s);
    }
    BN_CTX_end(ctx);
    BN_CTX_free(ctx);
    EC_GROUP_free(group);
    
    unsigned int sigSize = 72; // typical size of a ECDSA signature (when both numbers are 33 bytes).
    
    NSMutableData* signature = [NSMutableData dataWithLength:sigSize + 16]; // Make sure it is big enough
    
    unsigned char *pos = (unsigned char *)signature.mutableBytes;
    sigSize = i2d_ECDSA_SIG(sig, &pos);

    // Do not free sig as its pointers belong to external parameters
    // ECDSA_SIG_free(sig);
    // Instead, clear individual bignums.
    BN_clear_free(&r);
    BN_clear_free(&s);
    
    // Shrink to fit actual size
    [signature setLength:sigSize];
    
    return signature;
}

@end
