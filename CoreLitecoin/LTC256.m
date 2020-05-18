// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTC256.h"
#import "LTCData.h"

// 1. Structs are already defined in the .h file.

// 2. Constants

const LTC160 LTC160Zero = {0,0,0,0,0};
const LTC256 LTC256Zero = {0,0,0,0};
const LTC512 LTC512Zero = {0,0,0,0,0,0,0,0};

const LTC160 LTC160Max = {0xffffffff,0xffffffff,0xffffffff,0xffffffff,0xffffffff};
const LTC256 LTC256Max = {0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL};
const LTC512 LTC512Max = {0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL,
                          0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL,0xffffffffffffffffLL};

// Using ints assuming little-endian platform. 160-bit chunk actually begins with 82963d5e. Same thing about the rest.
// Digest::SHA512.hexdigest("CoreLitecoin/LTC160Null")[0,2*20].scan(/.{8}/).map{|x| "0x" + x.scan(/../).reverse.join}.join(",")
// 82963d5edd842f1e6bd2b6bc2e9a97a40a7d8652
const LTC160 LTC160Null = {0x5e3d9682,0x1e2f84dd,0xbcb6d26b,0xa4979a2e,0x52867d0a};

// Digest::SHA512.hexdigest("CoreLitecoin/LTC256Null")[0,2*32].scan(/.{16}/).map{|x| "0x" + x.scan(/../).reverse.join}.join(",")
// d1007a1fe826e95409e21595845f44c3b9411d5285b6b5982285aabfa5999a5e
const LTC256 LTC256Null = {0x54e926e81f7a00d1LL,0xc3445f849515e209LL,0x98b5b685521d41b9LL,0x5e9a99a5bfaa8522LL};

// Digest::SHA512.hexdigest("CoreLitecoin/LTC512Null")[0,2*64].scan(/.{16}/).map{|x| "0x" + x.scan(/../).reverse.join}.join(",")
// 62ce64dd92836e6e99d83eee3f623652f6049cf8c22272f295b262861738f0363e01b5d7a53c4a2e5a76d283f3e4a04d28ab54849c6e3e874ca31128bcb759e1
const LTC512 LTC512Null = {0x6e6e8392dd64ce62LL,0x5236623fee3ed899LL,0xf27222c2f89c04f6LL,0x36f038178662b295LL,0x2e4a3ca5d7b5013eLL,0x4da0e4f383d2765aLL,0x873e6e9c8454ab28LL,0xe159b7bc2811a34cLL};


// 3. Comparison

BOOL LTC160Equal(LTC160 chunk1, LTC160 chunk2) {
// Which one is faster: memcmp or word-by-word check? The latter does not need any loop or extra checks to compare bytes.
//    return memcmp(&chunk1, &chunk2, sizeof(chunk1)) == 0;
    return chunk1.words32[0] == chunk2.words32[0]
        && chunk1.words32[1] == chunk2.words32[1]
        && chunk1.words32[2] == chunk2.words32[2]
        && chunk1.words32[3] == chunk2.words32[3]
        && chunk1.words32[4] == chunk2.words32[4];
}

BOOL LTC256Equal(LTC256 chunk1, LTC256 chunk2) {
    return chunk1.words64[0] == chunk2.words64[0]
        && chunk1.words64[1] == chunk2.words64[1]
        && chunk1.words64[2] == chunk2.words64[2]
        && chunk1.words64[3] == chunk2.words64[3];
}

BOOL LTC512Equal(LTC512 chunk1, LTC512 chunk2) {
    return chunk1.words64[0] == chunk2.words64[0]
        && chunk1.words64[1] == chunk2.words64[1]
        && chunk1.words64[2] == chunk2.words64[2]
        && chunk1.words64[3] == chunk2.words64[3]
        && chunk1.words64[4] == chunk2.words64[4]
        && chunk1.words64[5] == chunk2.words64[5]
        && chunk1.words64[6] == chunk2.words64[6]
        && chunk1.words64[7] == chunk2.words64[7];
}

NSComparisonResult LTC160Compare(LTC160 chunk1, LTC160 chunk2) {
    int r = memcmp(&chunk1, &chunk2, sizeof(chunk1));
    
         if (r > 0) return NSOrderedDescending;
    else if (r < 0) return NSOrderedAscending;
    return NSOrderedSame;
}

NSComparisonResult LTC256Compare(LTC256 chunk1, LTC256 chunk2) {
    int r = memcmp(&chunk1, &chunk2, sizeof(chunk1));
    
         if (r > 0) return NSOrderedDescending;
    else if (r < 0) return NSOrderedAscending;
    return NSOrderedSame;
}

NSComparisonResult LTC512Compare(LTC512 chunk1, LTC512 chunk2) {
    int r = memcmp(&chunk1, &chunk2, sizeof(chunk1));
    
         if (r > 0) return NSOrderedDescending;
    else if (r < 0) return NSOrderedAscending;
    return NSOrderedSame;
}



// 4. Operations


// Inverse (b = ~a)
LTC160 LTC160Inverse(LTC160 chunk) {
    chunk.words32[0] = ~chunk.words32[0];
    chunk.words32[1] = ~chunk.words32[1];
    chunk.words32[2] = ~chunk.words32[2];
    chunk.words32[3] = ~chunk.words32[3];
    chunk.words32[4] = ~chunk.words32[4];
    return chunk;
}

LTC256 LTC256Inverse(LTC256 chunk) {
    chunk.words64[0] = ~chunk.words64[0];
    chunk.words64[1] = ~chunk.words64[1];
    chunk.words64[2] = ~chunk.words64[2];
    chunk.words64[3] = ~chunk.words64[3];
    return chunk;
}

LTC512 LTC512Inverse(LTC512 chunk) {
    chunk.words64[0] = ~chunk.words64[0];
    chunk.words64[1] = ~chunk.words64[1];
    chunk.words64[2] = ~chunk.words64[2];
    chunk.words64[3] = ~chunk.words64[3];
    chunk.words64[4] = ~chunk.words64[4];
    chunk.words64[5] = ~chunk.words64[5];
    chunk.words64[6] = ~chunk.words64[6];
    chunk.words64[7] = ~chunk.words64[7];
    return chunk;
}

// Swap byte order
LTC160 LTC160Swap(LTC160 chunk) {
    LTC160 chunk2;
    chunk2.words32[4] = OSSwapConstInt32(chunk.words32[0]);
    chunk2.words32[3] = OSSwapConstInt32(chunk.words32[1]);
    chunk2.words32[2] = OSSwapConstInt32(chunk.words32[2]);
    chunk2.words32[1] = OSSwapConstInt32(chunk.words32[3]);
    chunk2.words32[0] = OSSwapConstInt32(chunk.words32[4]);
    return chunk2;
}

LTC256 LTC256Swap(LTC256 chunk) {
    LTC256 chunk2;
    chunk2.words64[3] = OSSwapConstInt64(chunk.words64[0]);
    chunk2.words64[2] = OSSwapConstInt64(chunk.words64[1]);
    chunk2.words64[1] = OSSwapConstInt64(chunk.words64[2]);
    chunk2.words64[0] = OSSwapConstInt64(chunk.words64[3]);
    return chunk2;
}

LTC512 LTC512Swap(LTC512 chunk) {
    LTC512 chunk2;
    chunk2.words64[7] = OSSwapConstInt64(chunk.words64[0]);
    chunk2.words64[6] = OSSwapConstInt64(chunk.words64[1]);
    chunk2.words64[5] = OSSwapConstInt64(chunk.words64[2]);
    chunk2.words64[4] = OSSwapConstInt64(chunk.words64[3]);
    chunk2.words64[3] = OSSwapConstInt64(chunk.words64[4]);
    chunk2.words64[2] = OSSwapConstInt64(chunk.words64[5]);
    chunk2.words64[1] = OSSwapConstInt64(chunk.words64[6]);
    chunk2.words64[0] = OSSwapConstInt64(chunk.words64[7]);
    return chunk2;
}

// Bitwise AND operation (a & b)
LTC160 LTC160AND(LTC160 chunk1, LTC160 chunk2) {
    chunk1.words32[0] = chunk1.words32[0] & chunk2.words32[0];
    chunk1.words32[1] = chunk1.words32[1] & chunk2.words32[1];
    chunk1.words32[2] = chunk1.words32[2] & chunk2.words32[2];
    chunk1.words32[3] = chunk1.words32[3] & chunk2.words32[3];
    chunk1.words32[4] = chunk1.words32[4] & chunk2.words32[4];
    return chunk1;
}

LTC256 LTC256AND(LTC256 chunk1, LTC256 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] & chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] & chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] & chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] & chunk2.words64[3];
    return chunk1;
}

LTC512 LTC512AND(LTC512 chunk1, LTC512 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] & chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] & chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] & chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] & chunk2.words64[3];
    chunk1.words64[4] = chunk1.words64[4] & chunk2.words64[4];
    chunk1.words64[5] = chunk1.words64[5] & chunk2.words64[5];
    chunk1.words64[6] = chunk1.words64[6] & chunk2.words64[6];
    chunk1.words64[7] = chunk1.words64[7] & chunk2.words64[7];
    return chunk1;
}

// Bitwise OR operation (a | b)
LTC160 LTC160OR(LTC160 chunk1, LTC160 chunk2) {
    chunk1.words32[0] = chunk1.words32[0] | chunk2.words32[0];
    chunk1.words32[1] = chunk1.words32[1] | chunk2.words32[1];
    chunk1.words32[2] = chunk1.words32[2] | chunk2.words32[2];
    chunk1.words32[3] = chunk1.words32[3] | chunk2.words32[3];
    chunk1.words32[4] = chunk1.words32[4] | chunk2.words32[4];
    return chunk1;
}

LTC256 LTC256OR(LTC256 chunk1, LTC256 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] | chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] | chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] | chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] | chunk2.words64[3];
    return chunk1;
}

LTC512 LTC512OR(LTC512 chunk1, LTC512 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] | chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] | chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] | chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] | chunk2.words64[3];
    chunk1.words64[4] = chunk1.words64[4] | chunk2.words64[4];
    chunk1.words64[5] = chunk1.words64[5] | chunk2.words64[5];
    chunk1.words64[6] = chunk1.words64[6] | chunk2.words64[6];
    chunk1.words64[7] = chunk1.words64[7] | chunk2.words64[7];
    return chunk1;
}

// Bitwise exclusive-OR operation (a ^ b)
LTC160 LTC160XOR(LTC160 chunk1, LTC160 chunk2) {
    chunk1.words32[0] = chunk1.words32[0] ^ chunk2.words32[0];
    chunk1.words32[1] = chunk1.words32[1] ^ chunk2.words32[1];
    chunk1.words32[2] = chunk1.words32[2] ^ chunk2.words32[2];
    chunk1.words32[3] = chunk1.words32[3] ^ chunk2.words32[3];
    chunk1.words32[4] = chunk1.words32[4] ^ chunk2.words32[4];
    return chunk1;
}

LTC256 LTC256XOR(LTC256 chunk1, LTC256 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] ^ chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] ^ chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] ^ chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] ^ chunk2.words64[3];
    return chunk1;
}

LTC512 LTC512XOR(LTC512 chunk1, LTC512 chunk2) {
    chunk1.words64[0] = chunk1.words64[0] ^ chunk2.words64[0];
    chunk1.words64[1] = chunk1.words64[1] ^ chunk2.words64[1];
    chunk1.words64[2] = chunk1.words64[2] ^ chunk2.words64[2];
    chunk1.words64[3] = chunk1.words64[3] ^ chunk2.words64[3];
    chunk1.words64[4] = chunk1.words64[4] ^ chunk2.words64[4];
    chunk1.words64[5] = chunk1.words64[5] ^ chunk2.words64[5];
    chunk1.words64[6] = chunk1.words64[6] ^ chunk2.words64[6];
    chunk1.words64[7] = chunk1.words64[7] ^ chunk2.words64[7];
    return chunk1;
}

LTC512 LTC512Concat(LTC256 chunk1, LTC256 chunk2) {
    LTC512 result;
    *((LTC256*)(&result)) = chunk1;
    *((LTC256*)(((unsigned char*)&result) + sizeof(chunk2))) = chunk2;
    return result;
}


// 5. Conversion functions


// Conversion to NSData
NSData* NSDataFromLTC160(LTC160 chunk) {
    return [[NSData alloc] initWithBytes:&chunk length:sizeof(chunk)];
}

NSData* NSDataFromLTC256(LTC256 chunk) {
    return [[NSData alloc] initWithBytes:&chunk length:sizeof(chunk)];
}

NSData* NSDataFromLTC512(LTC512 chunk) {
    return [[NSData alloc] initWithBytes:&chunk length:sizeof(chunk)];
}

// Conversion from NSData.
// If NSData is not big enough, returns LTCHash{160,256,512}Null.
LTC160 LTC160FromNSData(NSData* data) {
    if (data.length < 160/8) return LTC160Null;
    LTC160 chunk = *((LTC160*)data.bytes);
    return chunk;
}

LTC256 LTC256FromNSData(NSData* data) {
    if (data.length < 256/8) return LTC256Null;
    LTC256 chunk = *((LTC256*)data.bytes);
    return chunk;
}

LTC512 LTC512FromNSData(NSData* data) {
    if (data.length < 512/8) return LTC512Null;
    LTC512 chunk = *((LTC512*)data.bytes);
    return chunk;
}


// Returns lowercase hex representation of the chunk

NSString* NSStringFromLTC160(LTC160 chunk) {
    const int length = 20;
    char dest[2*length + 1];
    const unsigned char *src = (unsigned char *)&chunk;
    for (int i = 0; i < length; ++i) {
        sprintf(dest + i*2, "%02x", (unsigned int)(src[i]));
    }
    return [[NSString alloc] initWithBytes:dest length:2*length encoding:NSASCIIStringEncoding];
}

NSString* NSStringFromLTC256(LTC256 chunk) {
    const int length = 32;
    char dest[2*length + 1];
    const unsigned char *src = (unsigned char *)&chunk;
    for (int i = 0; i < length; ++i) {
        sprintf(dest + i*2, "%02x", (unsigned int)(src[i]));
    }
    return [[NSString alloc] initWithBytes:dest length:2*length encoding:NSASCIIStringEncoding];
}

NSString* NSStringFromLTC512(LTC512 chunk) {
    const int length = 64;
    char dest[2*length + 1];
    const unsigned char *src = (unsigned char *)&chunk;
    for (int i = 0; i < length; ++i) {
        sprintf(dest + i*2, "%02x", (unsigned int)(src[i]));
    }
    return [[NSString alloc] initWithBytes:dest length:2*length encoding:NSASCIIStringEncoding];
}

// Conversion from hex NSString (lower- or uppercase).
// If string is invalid or data is too short, returns LTCHash{160,256,512}Null.
LTC160 LTC160FromNSString(NSString* string) {
    return LTC160FromNSData(LTCDataFromHex(string));
}

LTC256 LTC256FromNSString(NSString* string) {
    return LTC256FromNSData(LTCDataFromHex(string));
}

LTC512 LTC512FromNSString(NSString* string) {
    return LTC512FromNSData(LTCDataFromHex(string));
}



