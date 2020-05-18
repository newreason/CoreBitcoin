// Oleg Andreev <oleganza@gmail.com>

#import "LTCOpcode.h"

NSDictionary* LTCOpcodeForNameDictionary() {
    static NSDictionary* dict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dict = @{
                 @"OP_0":                   @(LTC_OP_0),
                 @"OP_FALSE":               @(LTC_OP_FALSE),
                 @"OP_PUSHDATA1":           @(LTC_OP_PUSHDATA1),
                 @"OP_PUSHDATA2":           @(LTC_OP_PUSHDATA2),
                 @"OP_PUSHDATA4":           @(LTC_OP_PUSHDATA4),
                 @"OP_1NEGATE":             @(LTC_OP_1NEGATE),
                 @"OP_RESERVED":            @(LTC_OP_RESERVED),
                 @"OP_1":                   @(LTC_OP_1),
                 @"OP_TRUE":                @(LTC_OP_TRUE),
                 @"OP_2":                   @(LTC_OP_2),
                 @"OP_3":                   @(LTC_OP_3),
                 @"OP_4":                   @(LTC_OP_4),
                 @"OP_5":                   @(LTC_OP_5),
                 @"OP_6":                   @(LTC_OP_6),
                 @"OP_7":                   @(LTC_OP_7),
                 @"OP_8":                   @(LTC_OP_8),
                 @"OP_9":                   @(LTC_OP_9),
                 @"OP_10":                  @(LTC_OP_10),
                 @"OP_11":                  @(LTC_OP_11),
                 @"OP_12":                  @(LTC_OP_12),
                 @"OP_13":                  @(LTC_OP_13),
                 @"OP_14":                  @(LTC_OP_14),
                 @"OP_15":                  @(LTC_OP_15),
                 @"OP_16":                  @(LTC_OP_16),
                 @"OP_NOP":                 @(LTC_OP_NOP),
                 @"OP_VER":                 @(LTC_OP_VER),
                 @"OP_IF":                  @(LTC_OP_IF),
                 @"OP_NOTIF":               @(LTC_OP_NOTIF),
                 @"OP_VERIF":               @(LTC_OP_VERIF),
                 @"OP_VERNOTIF":            @(LTC_OP_VERNOTIF),
                 @"OP_ELSE":                @(LTC_OP_ELSE),
                 @"OP_ENDIF":               @(LTC_OP_ENDIF),
                 @"OP_VERIFY":              @(LTC_OP_VERIFY),
                 @"OP_RETURN":              @(LTC_OP_RETURN),
                 @"OP_TOALTSTACK":          @(LTC_OP_TOALTSTACK),
                 @"OP_FROMALTSTACK":        @(LTC_OP_FROMALTSTACK),
                 @"OP_2DROP":               @(LTC_OP_2DROP),
                 @"OP_2DUP":                @(LTC_OP_2DUP),
                 @"OP_3DUP":                @(LTC_OP_3DUP),
                 @"OP_2OVER":               @(LTC_OP_2OVER),
                 @"OP_2ROT":                @(LTC_OP_2ROT),
                 @"OP_2SWAP":               @(LTC_OP_2SWAP),
                 @"OP_IFDUP":               @(LTC_OP_IFDUP),
                 @"OP_DEPTH":               @(LTC_OP_DEPTH),
                 @"OP_DROP":                @(LTC_OP_DROP),
                 @"OP_DUP":                 @(LTC_OP_DUP),
                 @"OP_NIP":                 @(LTC_OP_NIP),
                 @"OP_OVER":                @(LTC_OP_OVER),
                 @"OP_PICK":                @(LTC_OP_PICK),
                 @"OP_ROLL":                @(LTC_OP_ROLL),
                 @"OP_ROT":                 @(LTC_OP_ROT),
                 @"OP_SWAP":                @(LTC_OP_SWAP),
                 @"OP_TUCK":                @(LTC_OP_TUCK),
                 @"OP_CAT":                 @(LTC_OP_CAT),
                 @"OP_SUBSTR":              @(LTC_OP_SUBSTR),
                 @"OP_LEFT":                @(LTC_OP_LEFT),
                 @"OP_RIGHT":               @(LTC_OP_RIGHT),
                 @"OP_SIZE":                @(LTC_OP_SIZE),
                 @"OP_INVERT":              @(LTC_OP_INVERT),
                 @"OP_AND":                 @(LTC_OP_AND),
                 @"OP_OR":                  @(LTC_OP_OR),
                 @"OP_XOR":                 @(LTC_OP_XOR),
                 @"OP_EQUAL":               @(LTC_OP_EQUAL),
                 @"OP_EQUALVERIFY":         @(LTC_OP_EQUALVERIFY),
                 @"OP_RESERVED1":           @(LTC_OP_RESERVED1),
                 @"OP_RESERVED2":           @(LTC_OP_RESERVED2),
                 @"OP_1ADD":                @(LTC_OP_1ADD),
                 @"OP_1SUB":                @(LTC_OP_1SUB),
                 @"OP_2MUL":                @(LTC_OP_2MUL),
                 @"OP_2DIV":                @(LTC_OP_2DIV),
                 @"OP_NEGATE":              @(LTC_OP_NEGATE),
                 @"OP_ABS":                 @(LTC_OP_ABS),
                 @"OP_NOT":                 @(LTC_OP_NOT),
                 @"OP_0NOTEQUAL":           @(LTC_OP_0NOTEQUAL),
                 @"OP_ADD":                 @(LTC_OP_ADD),
                 @"OP_SUB":                 @(LTC_OP_SUB),
                 @"OP_MUL":                 @(LTC_OP_MUL),
                 @"OP_DIV":                 @(LTC_OP_DIV),
                 @"OP_MOD":                 @(LTC_OP_MOD),
                 @"OP_LSHIFT":              @(LTC_OP_LSHIFT),
                 @"OP_RSHIFT":              @(LTC_OP_RSHIFT),
                 @"OP_BOOLAND":             @(LTC_OP_BOOLAND),
                 @"OP_BOOLOR":              @(LTC_OP_BOOLOR),
                 @"OP_NUMEQUAL":            @(LTC_OP_NUMEQUAL),
                 @"OP_NUMEQUALVERIFY":      @(LTC_OP_NUMEQUALVERIFY),
                 @"OP_NUMNOTEQUAL":         @(LTC_OP_NUMNOTEQUAL),
                 @"OP_LESSTHAN":            @(LTC_OP_LESSTHAN),
                 @"OP_GREATERTHAN":         @(LTC_OP_GREATERTHAN),
                 @"OP_LESSTHANOREQUAL":     @(LTC_OP_LESSTHANOREQUAL),
                 @"OP_GREATERTHANOREQUAL":  @(LTC_OP_GREATERTHANOREQUAL),
                 @"OP_MIN":                 @(LTC_OP_MIN),
                 @"OP_MAX":                 @(LTC_OP_MAX),
                 @"OP_WITHIN":              @(LTC_OP_WITHIN),
                 @"OP_RIPEMD160":           @(LTC_OP_RIPEMD160),
                 @"OP_SHA1":                @(LTC_OP_SHA1),
                 @"OP_SHA256":              @(LTC_OP_SHA256),
                 @"OP_HASH160":             @(LTC_OP_HASH160),
                 @"OP_HASH256":             @(LTC_OP_HASH256),
                 @"OP_CODESEPARATOR":       @(LTC_OP_CODESEPARATOR),
                 @"OP_CHECKSIG":            @(LTC_OP_CHECKSIG),
                 @"OP_CHECKSIGVERIFY":      @(LTC_OP_CHECKSIGVERIFY),
                 @"OP_CHECKMULTISIG":       @(LTC_OP_CHECKMULTISIG),
                 @"OP_CHECKMULTISIGVERIFY": @(LTC_OP_CHECKMULTISIGVERIFY),
                 @"OP_NOP1":                @(LTC_OP_NOP1),
                 @"OP_NOP2":                @(LTC_OP_NOP2),
                 @"OP_NOP3":                @(LTC_OP_NOP3),
                 @"OP_NOP4":                @(LTC_OP_NOP4),
                 @"OP_NOP5":                @(LTC_OP_NOP5),
                 @"OP_NOP6":                @(LTC_OP_NOP6),
                 @"OP_NOP7":                @(LTC_OP_NOP7),
                 @"OP_NOP8":                @(LTC_OP_NOP8),
                 @"OP_NOP9":                @(LTC_OP_NOP9),
                 @"OP_NOP10":               @(LTC_OP_NOP10),
                 @"OP_INVALIDOPCODE":       @(LTC_OP_INVALIDOPCODE),
                 };
    });
    return dict;
}

NSString* LTCNameForOpcode(LTCOpcode opcode) {
    NSDictionary* dict = LTCOpcodeForNameDictionary();
    for (NSString* name in dict) {
        if ([dict[name] unsignedCharValue] == opcode) return name;
    }
    return @"OP_UNKNOWN";
}

LTCOpcode LTCOpcodeForName(NSString* opcodeName) {
    NSNumber* number = opcodeName ? LTCOpcodeForNameDictionary()[opcodeName] : nil;
    if (!number) return LTC_OP_INVALIDOPCODE;
    return [number unsignedCharValue];
}

// Returns OP_1NEGATE, OP_0 .. OP_16 for ints from -1 to 16.
// Returns OP_INVALIDOPCODE for other ints.
LTCOpcode LTCOpcodeForSmallInteger(NSInteger smallInteger) {
    if (smallInteger == 0) return LTC_OP_0;
    if (smallInteger == -1) return LTC_OP_1NEGATE;
    if (smallInteger >= 1 && smallInteger <= 16) return (LTC_OP_1 + (smallInteger - 1));
    return LTC_OP_INVALIDOPCODE;
}

// Converts opcode OP_<N> or OP_1NEGATE to an integer value.
// If incorrect opcode is given, NSIntegerMax is returned.
NSInteger LTCSmallIntegerFromOpcode(LTCOpcode opcode) {
    if (opcode == LTC_OP_0) return 0;
    if (opcode == LTC_OP_1NEGATE) return -1;
    if (opcode >= LTC_OP_1 && opcode <= LTC_OP_16) return (int)opcode - (int)(LTC_OP_1 - 1);
    return NSIntegerMax;
}

