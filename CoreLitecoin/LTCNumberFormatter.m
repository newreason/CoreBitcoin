#import "LTCNumberFormatter.h"

#define NarrowNbsp @"\xE2\x80\xAF"
//#define PunctSpace @" "
//#define ThinSpace  @" "

NSString* const LTCNumberFormatterBitcoinCode    = @"XBT";

NSString* const LTCNumberFormatterSymbolLTC      = @"Ƀ" @"";
NSString* const LTCNumberFormatterSymbolMilliLTC = @"mɃ";
NSString* const LTCNumberFormatterSymbolBit      = @"ƀ";
NSString* const LTCNumberFormatterSymbolSatoshi  = @"ṡ";

LTCAmount LTCAmountFromDecimalNumber(NSNumber* num) {
    if ([num isKindOfClass:[NSDecimalNumber class]]) {
        NSDecimalNumber* dnum = (id)num;
        // Starting iOS 8.0.2, the longLongValue method returns 0 for some non rounded values.
        // Rounding the number looks like a work around.
        NSDecimalNumberHandler *roundingBehavior = [NSDecimalNumberHandler decimalNumberHandlerWithRoundingMode:NSRoundPlain
                                                                                                          scale:0
                                                                                               raiseOnExactness:NO
                                                                                                raiseOnOverflow:YES
                                                                                               raiseOnUnderflow:NO
                                                                                            raiseOnDivideByZero:YES];
        num = [dnum decimalNumberByRoundingAccordingToBehavior:roundingBehavior];
    }
    LTCAmount sat = [num longLongValue];
    return sat;
}

@implementation LTCNumberFormatter {
    NSDecimalNumber* _myMultiplier; // because standard multiplier when below 1e-6 leads to a rounding no matter what the settings.
}

- (id) initWithBitcoinUnit:(LTCNumberFormatterUnit)unit {
    return [self initWithBitcoinUnit:unit symbolStyle:LTCNumberFormatterSymbolStyleNone];
}

- (id) initWithBitcoinUnit:(LTCNumberFormatterUnit)unit symbolStyle:(LTCNumberFormatterSymbolStyle)symbolStyle {
    if (self = [super init]) {
        _bitcoinUnit = unit;
        _symbolStyle = symbolStyle;

        [self updateFormatterProperties];
    }
    return self;
}

- (void) setBitcoinUnit:(LTCNumberFormatterUnit)bitcoinUnit {
    if (_bitcoinUnit == bitcoinUnit) return;
    _bitcoinUnit = bitcoinUnit;
    [self updateFormatterProperties];
}

- (void) setSymbolStyle:(LTCNumberFormatterSymbolStyle)suffixStyle {
    if (_symbolStyle == suffixStyle) return;
    _symbolStyle = suffixStyle;
    [self updateFormatterProperties];
}

- (void) updateFormatterProperties {
    // Reset formats so they are recomputed after we change properties.
    self.positiveFormat = nil;
    self.negativeFormat = nil;

    self.lenient = YES;
    self.generatesDecimalNumbers = YES;
    self.numberStyle = NSNumberFormatterCurrencyStyle;
    self.currencyCode = @"XBT";
    self.groupingSize = 3;

    self.currencySymbol = [self bitcoinUnitSymbol] ?: @"";

    self.internationalCurrencySymbol = self.currencySymbol;

    // On iOS 8 we have to set these *after* setting the currency symbol.
    switch (_bitcoinUnit) {
        case LTCNumberFormatterUnitSatoshi:
            _myMultiplier = [NSDecimalNumber decimalNumberWithMantissa:1 exponent:0 isNegative:NO];
            self.minimumFractionDigits = 0;
            self.maximumFractionDigits = 0;
            break;
        case LTCNumberFormatterUnitBit:
            _myMultiplier = [NSDecimalNumber decimalNumberWithMantissa:1 exponent:-2 isNegative:NO];
            self.minimumFractionDigits = 0;
            self.maximumFractionDigits = 2;
            break;
        case LTCNumberFormatterUnitMilliLTC:
            _myMultiplier = [NSDecimalNumber decimalNumberWithMantissa:1 exponent:-5 isNegative:NO];
            self.minimumFractionDigits = 2;
            self.maximumFractionDigits = 5;
            break;
        case LTCNumberFormatterUnitLTC:
            _myMultiplier = [NSDecimalNumber decimalNumberWithMantissa:1 exponent:-8 isNegative:NO];
            self.minimumFractionDigits = 2;
            self.maximumFractionDigits = 8;
            break;
        default:
            [[NSException exceptionWithName:@"LTCNumberFormatter: not supported bitcoin unit" reason:@"" userInfo:nil] raise];
    }

    switch (_symbolStyle) {
        case LTCNumberFormatterSymbolStyleNone:
            self.minimumFractionDigits = 0;
            self.positivePrefix = @"";
            self.positiveSuffix = @"";
            self.negativePrefix = @"–";
            self.negativeSuffix = @"";
            break;
        case LTCNumberFormatterSymbolStyleCode:
        case LTCNumberFormatterSymbolStyleLowercase:
            self.positivePrefix = @"";
            self.positiveSuffix = [NSString stringWithFormat:@" %@", self.currencySymbol]; // nobreaking space here.
            self.negativePrefix = @"-";
            self.negativeSuffix = self.positiveSuffix;
            break;

        case LTCNumberFormatterSymbolStyleSymbol:
            // Leave positioning of the currency symbol to locale (in English it'll be prefix, in French it'll be suffix).
            break;
    }
    self.maximum = @(LTC_MAX_MONEY);

    // Fixup prefix symbol with a no-breaking space. When it's postfix, Foundation puts nobr space already.
    self.positiveFormat = [self.positiveFormat stringByReplacingOccurrencesOfString:@"¤" withString:@"¤" NarrowNbsp "#"];

    // Fixup negative format to have the same format as positive format and a minus sign in front of the first digit.
    self.negativeFormat = [self.positiveFormat stringByReplacingCharactersInRange:[self.positiveFormat rangeOfString:@"#"] withString:@"–#"];
}

- (NSString *) standaloneSymbol {
    NSString* sym = [self bitcoinUnitSymbol];
    if (!sym) {
        sym = [self bitcoinUnitSymbolForUnit:_bitcoinUnit];
    }
    return sym;
}

- (NSString*) bitcoinUnitSymbol {
    return [self bitcoinUnitSymbolForStyle:_symbolStyle unit:_bitcoinUnit];
}

- (NSString*) unitCode {
    return [self bitcoinUnitCodeForUnit:_bitcoinUnit];
}

- (NSString*) bitcoinUnitCodeForUnit:(LTCNumberFormatterUnit)unit {
    switch (unit) {
        case LTCNumberFormatterUnitSatoshi:
            return NSLocalizedStringFromTable(@"SAT", @"CoreLitecoin", @"");
        case LTCNumberFormatterUnitBit:
            return NSLocalizedStringFromTable(@"Bits", @"CoreLitecoin", @"");
        case LTCNumberFormatterUnitMilliLTC:
            return NSLocalizedStringFromTable(@"mLTC", @"CoreLitecoin", @"");
        case LTCNumberFormatterUnitLTC:
            return NSLocalizedStringFromTable(@"LTC", @"CoreLitecoin", @"");
        default:
            [[NSException exceptionWithName:@"LTCNumberFormatter: not supported bitcoin unit" reason:@"" userInfo:nil] raise];
    }
}

- (NSString*) bitcoinUnitSymbolForUnit:(LTCNumberFormatterUnit)unit {
    switch (unit) {
        case LTCNumberFormatterUnitSatoshi:
            return LTCNumberFormatterSymbolSatoshi;
        case LTCNumberFormatterUnitBit:
            return LTCNumberFormatterSymbolBit;
        case LTCNumberFormatterUnitMilliLTC:
            return LTCNumberFormatterSymbolMilliLTC;
        case LTCNumberFormatterUnitLTC:
            return LTCNumberFormatterSymbolLTC;
        default:
            [[NSException exceptionWithName:@"LTCNumberFormatter: not supported bitcoin unit" reason:@"" userInfo:nil] raise];
    }
}

- (NSString*) bitcoinUnitSymbolForStyle:(LTCNumberFormatterSymbolStyle)symbolStyle unit:(LTCNumberFormatterUnit)bitcoinUnit {
    switch (symbolStyle) {
        case LTCNumberFormatterSymbolStyleNone:
            return nil;
        case LTCNumberFormatterSymbolStyleCode:
            return [self bitcoinUnitCodeForUnit:bitcoinUnit];
        case LTCNumberFormatterSymbolStyleLowercase:
            return [[self bitcoinUnitCodeForUnit:bitcoinUnit] lowercaseString];
        case LTCNumberFormatterSymbolStyleSymbol:
            return [self bitcoinUnitSymbolForUnit:bitcoinUnit];
        default:
            [[NSException exceptionWithName:@"LTCNumberFormatter: not supported symbol style" reason:@"" userInfo:nil] raise];
    }
    return nil;
}

- (NSString *) placeholderText {
    //NSString* groupSeparator = self.currencyGroupingSeparator ?: @"";
    NSString* decimalPoint = self.currencyDecimalSeparator ?: @".";
    switch (_bitcoinUnit) {
        case LTCNumberFormatterUnitSatoshi:
            return @"0";
        case LTCNumberFormatterUnitBit:
            return [NSString stringWithFormat:@"0%@00", decimalPoint];
        case LTCNumberFormatterUnitMilliLTC:
            return [NSString stringWithFormat:@"0%@00000", decimalPoint];
        case LTCNumberFormatterUnitLTC:
            return [NSString stringWithFormat:@"0%@00000000", decimalPoint];
        default:
            [[NSException exceptionWithName:@"LTCNumberFormatter: not supported bitcoin unit" reason:@"" userInfo:nil] raise];
            return nil;
    }
}

- (NSString*) stringFromNumber:(NSNumber *)number {
    if (![number isKindOfClass:[NSDecimalNumber class]]) {
        number = [NSDecimalNumber decimalNumberWithDecimal:number.decimalValue];
    }
    return [super stringFromNumber:[(NSDecimalNumber*)number decimalNumberByMultiplyingBy:_myMultiplier]];
}

- (NSNumber*) numberFromString:(NSString *)string {
    // self.generatesDecimalNumbers guarantees NSDecimalNumber here.
    NSDecimalNumber* number = (NSDecimalNumber*)[super numberFromString:string];
    return [number decimalNumberByDividingBy:_myMultiplier];
}

- (NSString *) stringFromAmount:(LTCAmount)amount {
    return [self stringFromNumber:@(amount)];
}

- (LTCAmount) amountFromString:(NSString *)string {
    return LTCAmountFromDecimalNumber([self numberFromString:string]);
}

- (id) copyWithZone:(NSZone *)zone {
    return [[LTCNumberFormatter alloc] initWithBitcoinUnit:self.bitcoinUnit symbolStyle:self.symbolStyle];
}


@end
