// Oleg Andreev <oleganza@gmail.com>

#import "LTCScriptMachine.h"
#import "LTCScript.h"
#import "LTCOpcode.h"
#import "LTCTransaction.h"
#import "LTCTransactionInput.h"
#import "LTCTransactionOutput.h"
#import "LTCKey.h"
#import "LTCBigNumber.h"
#import "LTCErrors.h"
#import "LTCUnitsAndLimits.h"
#import "LTCData.h"

@interface LTCScriptMachine ()

// Constants
@property(nonatomic) NSData* blobFalse;
@property(nonatomic) NSData* blobZero;
@property(nonatomic) NSData* blobTrue;
@property(nonatomic) LTCBigNumber* bigNumberZero;
@property(nonatomic) LTCBigNumber* bigNumberOne;
@property(nonatomic) LTCBigNumber* bigNumberFalse;
@property(nonatomic) LTCBigNumber* bigNumberTrue;
@end

// We try to match BitcoinQT code as close as possible to avoid subtle incompatibilities.
// The design might not look optimal to everyone, but I prefer to match the behaviour first, then document it well,
// then refactor it with even more documentation for every subtle decision.
// Think of an independent auditor who has to read several sources to check if they are compatible in every little
// decision they make. Proper documentation and cross-references will help this guy a lot.
@implementation LTCScriptMachine {
    
    // Stack contains NSData objects that are interpreted as numbers, bignums, booleans or raw data when needed.
    NSMutableArray* _stack;
    
    // Used in ALTSTACK ops.
    NSMutableArray* _altStack;
    
    // Holds an array of @YES and @NO values to keep track of if/else branches.
    NSMutableArray* _conditionStack;
    
    // Currently executed script.
    LTCScript* _script;
    
    // Current opcode.
    LTCOpcode _opcode;
    
    // Current payload for any "push data" operation.
    NSData* _pushdata;
    
    // Current opcode index in _script.
    NSUInteger _opIndex;
    
    // Index of last OP_CODESEPARATOR
    NSUInteger _lastCodeSeparatorIndex;
    
    // Keeps number of executed operations to check for limit.
    NSInteger _opCount;
}

- (id) init {
    if (self = [super init]) {
        // Constants used in script execution.
        _blobFalse = [NSData data];
        _blobZero = _blobFalse;
        uint8_t one = 1;
        _blobTrue = [NSData dataWithBytes:(void*)&one length:1];
        
        _bigNumberZero = [[LTCBigNumber alloc] initWithInt32:0];
        _bigNumberOne = [[LTCBigNumber alloc] initWithInt32:1];
        _bigNumberFalse = _bigNumberZero;
        _bigNumberTrue = _bigNumberOne;

        _inputIndex = 0xFFFFFFFF;
        _blockTimestamp = (uint32_t)[[NSDate date] timeIntervalSince1970];
        [self resetStack];
    }
    return self;
}

- (void) resetStack {
    _stack = [NSMutableArray array];
    _altStack = [NSMutableArray array];
    _conditionStack = [NSMutableArray array];
}

- (id) initWithTransaction:(LTCTransaction*)tx inputIndex:(uint32_t)inputIndex {
    if (!tx) return nil;
    // BitcoinQT would crash right before VerifyScript if the input index was out of bounds.
    // So even though it returns 1 from SignatureHash() function when checking for this condition,
    // it never actually happens. So we too will not check for it when calculating a hash.
    if (inputIndex >= tx.inputs.count) return nil;
    if (self = [self init]) {
        _transaction = tx;
        _inputIndex = inputIndex;
    }
    return self;
}

- (id) copyWithZone:(NSZone *)zone {
    LTCScriptMachine* sm = [[LTCScriptMachine alloc] init];
    sm.transaction = self.transaction;
    sm.inputIndex = self.inputIndex;
    sm.blockTimestamp = self.blockTimestamp;
    sm.verificationFlags = self.verificationFlags;
    sm->_stack = [_stack mutableCopy];
    return sm;
}

- (BOOL) shouldVerifyP2SH {
    return (_blockTimestamp >= LTC_BIP16_TIMESTAMP);
}

- (BOOL) verifyWithOutputScript:(LTCScript*)outputScript error:(NSError**)errorOut {
    // self.inputScript allows to override transaction so we can simply testing.
    LTCScript* inputScript = self.inputScript;
    
    if (!inputScript) {
        // Sanity check: transaction and its input should be consistent.
        if (!(self.transaction && self.inputIndex < self.transaction.inputs.count)) {
            [NSException raise:@"LTCScriptMachineException"  format:@"transaction and valid inputIndex are required for script verification."];
            return NO;
        }
        if (!outputScript) {
            [NSException raise:@"LTCScriptMachineException"  format:@"non-nil outputScript is required for script verification."];
            return NO;
        }

        LTCTransactionInput* txInput = self.transaction.inputs[self.inputIndex];
        inputScript = txInput.signatureScript;
    }
    
    // First step: run the input script which typically places signatures, pubkeys and other static data needed for outputScript.
    if (![self runScript:inputScript error:errorOut]) {
        // errorOut is set by runScript
        return NO;
    }
    
    // Make a copy of the stack if we have P2SH script.
    // We will run deserialized P2SH script on this stack if other verifications succeed.
    BOOL shouldVerifyP2SH = [self shouldVerifyP2SH] && outputScript.isPayToScriptHashScript;
    NSMutableArray* stackForP2SH = shouldVerifyP2SH ? [_stack mutableCopy] : nil;
    
    // Second step: run output script to see that the input satisfies all conditions laid in the output script.
    if (![self runScript:outputScript error:errorOut]) {
        // errorOut is set by runScript
        return NO;
    }
    
    // We need to have something on stack
    if (_stack.count == 0) {
        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Stack is empty after script execution.", @"")];
        return NO;
    }
    
    // The last value must be YES.
    if ([self boolAtIndex:-1] == NO) {
        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Last item on the stack is boolean NO.", @"")];
        return NO;
    }
    
    // Additional validation for spend-to-script-hash transactions:
    if (shouldVerifyP2SH) {
        // BitcoinQT: scriptSig must be literals-only
        if (![inputScript isDataOnly]) {
            if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Input script for P2SH spending must be literals-only.", @"")];
            return NO;
        }
        
        if (stackForP2SH.count == 0) {
            // stackForP2SH cannot be empty here, because if it was the
            // P2SH  HASH <> EQUAL  scriptPubKey would be evaluated with
            // an empty stack and the runScript: above would return NO.
            [NSException raise:@"LTCScriptMachineException"  format:@"internal inconsistency: stackForP2SH cannot be empty at this point."];
            return NO;
        }
        
        // Instantiate the script from the last data on the stack.
        LTCScript* providedScript = [[LTCScript alloc] initWithData:[stackForP2SH lastObject]];
        
        // Remove it from the stack.
        [stackForP2SH removeObjectAtIndex:stackForP2SH.count - 1];
        
        // Replace current stack with P2SH stack.
        [self resetStack];
        _stack = stackForP2SH;
        
        if (![self runScript:providedScript error:errorOut]) {
            return NO;
        }
        
        // We need to have something on stack
        if (_stack.count == 0) {
            if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Stack is empty after script execution.", @"")];
            return NO;
        }
        
        // The last value must be YES.
        if ([self boolAtIndex:-1] == NO) {
            if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Last item on the stack is boolean NO.", @"")];
            return NO;
        }
    }
    
    // If nothing failed, validation passed.
    return YES;
}


- (BOOL) runScript:(LTCScript*)script error:(NSError**)errorOut {
    if (!script) {
        [NSException raise:@"LTCScriptMachineException"  format:@"non-nil script is required for -runScript:error: method."];
        return NO;
    }
    
    if (script.data.length > LTC_MAX_SCRIPT_SIZE) {
        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Script binary is too long.", @"")];
        return NO;
    }
    
    // Altstack should be reset between script runs.
    _altStack = [NSMutableArray array];
    
    _script = script;
    _opIndex = 0;
    _opcode = 0;
    _pushdata = nil;
    _lastCodeSeparatorIndex = 0;
    _opCount = 0;
    
    __block BOOL opFailed = NO;
    [script enumerateOperations:^(NSUInteger opIndex, LTCOpcode opcode, NSData *pushdata, BOOL *stop) {
        
        _opIndex = opIndex;
        _opcode = opcode;
        _pushdata = pushdata;
        
        if (![self executeOpcodeError:errorOut])
        {
            opFailed = YES;
            *stop = YES;
        }
    }];
    
    if (opFailed) {
        // Error is already set by executeOpcode, return immediately.
        return NO;
    }
    
    if (_conditionStack.count > 0) {
        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Condition branches not balanced.", @"")];
        return NO;
    }
    
    return YES;
}


- (BOOL) executeOpcodeError:(NSError**)errorOut {
    NSUInteger opcodeIndex = _opIndex;
    LTCOpcode opcode = _opcode;
    NSData* pushdata = _pushdata;
    
    if (pushdata.length > LTC_MAX_SCRIPT_ELEMENT_SIZE) {
        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Pushdata chunk size is too big.", @"")];
        return NO;
    }
    
    if (opcode > LTC_OP_16 && !_pushdata && ++_opCount > LTC_MAX_OPS_PER_SCRIPT) {
        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Exceeded the allowed number of operations per script.", @"")];
        return NO;
    }
    
    // Disabled opcodes
    
    if (opcode == LTC_OP_CAT ||
        opcode == LTC_OP_SUBSTR ||
        opcode == LTC_OP_LEFT ||
        opcode == LTC_OP_RIGHT ||
        opcode == LTC_OP_INVERT ||
        opcode == LTC_OP_AND ||
        opcode == LTC_OP_OR ||
        opcode == LTC_OP_XOR ||
        opcode == LTC_OP_2MUL ||
        opcode == LTC_OP_2DIV ||
        opcode == LTC_OP_MUL ||
        opcode == LTC_OP_DIV ||
        opcode == LTC_OP_MOD ||
        opcode == LTC_OP_LSHIFT ||
        opcode == LTC_OP_RSHIFT) {
        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Attempt to execute a disabled opcode.", @"")];
        return NO;
    }
    
    BOOL shouldExecute = ([_conditionStack indexOfObject:@NO] == NSNotFound);
    
    if (shouldExecute && pushdata) {
        [_stack addObject:pushdata];
    } else if (shouldExecute || (LTC_OP_IF <= opcode && opcode <= LTC_OP_ENDIF)) {
    // this basically means that OP_VERIF and OP_VERNOTIF will always fail the script, even if not executed.
        switch (opcode) {
            //
            // Push value
            //
            case LTC_OP_1NEGATE:
            case LTC_OP_1:
            case LTC_OP_2:
            case LTC_OP_3:
            case LTC_OP_4:
            case LTC_OP_5:
            case LTC_OP_6:
            case LTC_OP_7:
            case LTC_OP_8:
            case LTC_OP_9:
            case LTC_OP_10:
            case LTC_OP_11:
            case LTC_OP_12:
            case LTC_OP_13:
            case LTC_OP_14:
            case LTC_OP_15:
            case LTC_OP_16: {
                // ( -- value)
                LTCBigNumber* bn = [[LTCBigNumber alloc] initWithInt64:(int)opcode - (int)(LTC_OP_1 - 1)];
                [_stack addObject:bn.signedLittleEndian];
            }
            break;
                
                
            //
            // Control
            //
            case LTC_OP_NOP:
            case LTC_OP_NOP1: case LTC_OP_NOP2: case LTC_OP_NOP3: case LTC_OP_NOP4: case LTC_OP_NOP5:
            case LTC_OP_NOP6: case LTC_OP_NOP7: case LTC_OP_NOP8: case LTC_OP_NOP9: case LTC_OP_NOP10:
            break;
            
            
            case LTC_OP_IF:
            case LTC_OP_NOTIF: {
                // <expression> if [statements] [else [statements]] endif
                BOOL value = NO;
                if (shouldExecute) {
                    if (_stack.count < 1) {
                        if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
                        return NO;
                    }
                    value = [self boolAtIndex:-1];
                    if (opcode == LTC_OP_NOTIF) {
                        value = !value;
                    }
                    [self popFromStack];
                }
                [_conditionStack addObject:@(value)];
            }
            break;
            
            case LTC_OP_ELSE: {
                if (_conditionStack.count == 0) {
                    if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Expected an OP_IF or OP_NOTIF branch before OP_ELSE.", @"")];
                    return NO;
                }
                
                // Invert last condition.
                BOOL f = [[_conditionStack lastObject] boolValue];
                [_conditionStack removeObjectAtIndex:_conditionStack.count - 1];
                [_conditionStack addObject:@(!f)];
            }
            break;
                
            case LTC_OP_ENDIF: {
                if (_conditionStack.count == 0) {
                    if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Expected an OP_IF or OP_NOTIF branch before OP_ENDIF.", @"")];
                    return NO;
                }
                [_conditionStack removeObjectAtIndex:_conditionStack.count - 1];
            }
            break;
            
            case LTC_OP_VERIFY: {
                // (true -- ) or
                // (false -- false) and return
                if (_stack.count < 1) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
                    return NO;
                }

                BOOL value = [self boolAtIndex:-1];
                if (value) {
                    [self popFromStack];
                } else {
                    if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"OP_VERIFY failed.", @"")];
                    return NO;
                }
            }
            break;
                
            case LTC_OP_RETURN: {
                if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"OP_RETURN executed.", @"")];
                return NO;
            }
            break;

                
            //
            // Stack ops
            //
            case LTC_OP_TOALTSTACK: {
                if (_stack.count < 1) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
                    return NO;
                }
                [_altStack addObject:[self dataAtIndex:-1]];
                [self popFromStack];
            }
            break;
                
            case LTC_OP_FROMALTSTACK: {
                if (_altStack.count < 1) {
                    if (errorOut) *errorOut = [self scriptError:[NSString stringWithFormat:NSLocalizedString(@"%@ requires one item on altstack", @""), LTCNameForOpcode(opcode)]];
                    return NO;
                }
                [_stack addObject:_altStack[_altStack.count - 1]];
                [_altStack removeObjectAtIndex:_altStack.count - 1];
            }
            break;
                
            case LTC_OP_2DROP: {
                // (x1 x2 -- )
                if (_stack.count < 2) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
                    return NO;
                }
                [self popFromStack];
                [self popFromStack];
            }
            break;
                
            case LTC_OP_2DUP: {
                // (x1 x2 -- x1 x2 x1 x2)
                if (_stack.count < 2) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
                    return NO;
                }
                NSData* data1 = [self dataAtIndex:-2];
                NSData* data2 = [self dataAtIndex:-1];
                [_stack addObject:data1];
                [_stack addObject:data2];
            }
            break;
                
            case LTC_OP_3DUP: {
                // (x1 x2 x3 -- x1 x2 x3 x1 x2 x3)
                if (_stack.count < 3) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:3];
                    return NO;
                }
                NSData* data1 = [self dataAtIndex:-3];
                NSData* data2 = [self dataAtIndex:-2];
                NSData* data3 = [self dataAtIndex:-1];
                [_stack addObject:data1];
                [_stack addObject:data2];
                [_stack addObject:data3];
            }
            break;
                
            case LTC_OP_2OVER: {
                // (x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2)
                if (_stack.count < 4) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:4];
                    return NO;
                }
                NSData* data1 = [self dataAtIndex:-4];
                NSData* data2 = [self dataAtIndex:-3];
                [_stack addObject:data1];
                [_stack addObject:data2];
            }
            break;
                
            case LTC_OP_2ROT: {
                // (x1 x2 x3 x4 x5 x6 -- x3 x4 x5 x6 x1 x2)
                if (_stack.count < 6) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:6];
                    return NO;
                }
                NSData* data1 = [self dataAtIndex:-6];
                NSData* data2 = [self dataAtIndex:-5];
                [_stack removeObjectsInRange:NSMakeRange(_stack.count-6, 2)];
                [_stack addObject:data1];
                [_stack addObject:data2];
            }
            break;
                
            case LTC_OP_2SWAP: {
                // (x1 x2 x3 x4 -- x3 x4 x1 x2)
                if (_stack.count < 4) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:4];
                    return NO;
                }
                
                [self swapDataAtIndex:-4 withIndex:-2]; // x1 <-> x3
                [self swapDataAtIndex:-3 withIndex:-1]; // x2 <-> x4
            }
            break;
                
            case LTC_OP_IFDUP: {
                // (x -- x x)
                // (0 -- 0)
                if (_stack.count < 1) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
                    return NO;
                }
                NSData* data = [self dataAtIndex:-1];
                if ([self boolAtIndex:-1]) {
                    [_stack addObject:data];
                }
            }
            break;
                
            case LTC_OP_DEPTH: {
                // -- stacksize
                LTCBigNumber* bn = [[LTCBigNumber alloc] initWithInt64:_stack.count];
                [_stack addObject:bn.signedLittleEndian];
            }
            break;
                
            case LTC_OP_DROP: {
                // (x -- )
                if (_stack.count < 1) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
                    return NO;
                }
                [self popFromStack];
            }
            break;
                
            case LTC_OP_DUP: {
                // (x -- x x)
                if (_stack.count < 1) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
                    return NO;
                }
                NSData* data = [self dataAtIndex:-1];
                [_stack addObject:data];
            }
            break;
                
            case LTC_OP_NIP: {
                // (x1 x2 -- x2)
                if (_stack.count < 2) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
                    return NO;
                }
                [_stack removeObjectAtIndex:_stack.count - 2];
            }
            break;
                
            case LTC_OP_OVER: {
                // (x1 x2 -- x1 x2 x1)
                if (_stack.count < 2) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
                    return NO;
                }
                NSData* data = [self dataAtIndex:-2];
                [_stack addObject:data];
            }
            break;
                
            case LTC_OP_PICK:
            case LTC_OP_ROLL: {
                // pick: (xn ... x2 x1 x0 n -- xn ... x2 x1 x0 xn)
                // roll: (xn ... x2 x1 x0 n --    ... x2 x1 x0 xn)
                if (_stack.count < 2) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
                    return NO;
                }
                
                // Top item is a number of items to roll over.
                // Take it and pop it from the stack.
                LTCBigNumber* bn = [self bigNumberAtIndex:-1];
                
                if (!bn) {
                    if (errorOut) *errorOut = [self scriptErrorInvalidBignum];
                    return NO;
                }
                
                int32_t n = [bn int32value];
                [self popFromStack];
                
                if (n < 0 || n >= _stack.count) {
                    if (errorOut) *errorOut = [self scriptError:[NSString stringWithFormat:NSLocalizedString(@"Invalid number of items for %@: %d.", @""), LTCNameForOpcode(opcode), n]];
                    return NO;
                }
                NSData* data = [self dataAtIndex: -n - 1];
                if (opcode == LTC_OP_ROLL) {
                    [self removeAtIndex: -n - 1];
                }
                [_stack addObject:data];
            }
            break;
                
            case LTC_OP_ROT: {
                // (x1 x2 x3 -- x2 x3 x1)
                //  x2 x1 x3  after first swap
                //  x2 x3 x1  after second swap
                if (_stack.count < 3) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:3];
                    return NO;
                }
                [self swapDataAtIndex:-3 withIndex:-2];
                [self swapDataAtIndex:-2 withIndex:-1];
            }
            break;
                
            case LTC_OP_SWAP: {
                // (x1 x2 -- x2 x1)
                if (_stack.count < 2) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
                    return NO;
                }
                [self swapDataAtIndex:-2 withIndex:-1];
            }
            break;
                
            case LTC_OP_TUCK: {
                // (x1 x2 -- x2 x1 x2)
                if (_stack.count < 2) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
                    return NO;
                }
                NSData* data = [self dataAtIndex:-1];
                [_stack insertObject:data atIndex:_stack.count - 2];
            }
            break;
                
                
            case LTC_OP_SIZE: {
                // (in -- in size)
                if (_stack.count < 1) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
                    return NO;
                }
                LTCBigNumber* bn = [[LTCBigNumber alloc] initWithUInt64:[self dataAtIndex:-1].length];
                [_stack addObject:bn.signedLittleEndian];
            }
            break;


            //
            // Bitwise logic
            //
            case LTC_OP_EQUAL:
            case LTC_OP_EQUALVERIFY: {
                //case OP_NOTEQUAL: // use OP_NUMNOTEQUAL
                // (x1 x2 - bool)
                if (_stack.count < 2) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
                    return NO;
                }
                NSData* x1 = [self dataAtIndex:-2];
                NSData* x2 = [self dataAtIndex:-1];
                BOOL equal = [x1 isEqual:x2];
                
                // OP_NOTEQUAL is disabled because it would be too easy to say
                // something like n != 1 and have some wiseguy pass in 1 with extra
                // zero bytes after it (numerically, 0x01 == 0x0001 == 0x000001)
                //if (opcode == OP_NOTEQUAL)
                //    equal = !equal;
                
                [self popFromStack];
                [self popFromStack];
                
                [_stack addObject:equal ? _blobTrue : _blobFalse];
                
                if (opcode == LTC_OP_EQUALVERIFY) {
                    if (equal) {
                        [self popFromStack];
                    } else {
                        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"OP_EQUALVERIFY failed.", @"")];
                        return NO;
                    }
                }
            }
            break;
                
            //
            // Numeric
            //
            case LTC_OP_1ADD:
            case LTC_OP_1SUB:
            case LTC_OP_NEGATE:
            case LTC_OP_ABS:
            case LTC_OP_NOT:
            case LTC_OP_0NOTEQUAL: {
                // (in -- out)
                if (_stack.count < 1) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
                    return NO;
                }
                
                LTCMutableBigNumber* bn = [self bigNumberAtIndex:-1];
                
                if (!bn) {
                    if (errorOut) *errorOut = [self scriptErrorInvalidBignum];
                    return NO;
                }
                
                switch (opcode) {
                    case LTC_OP_1ADD:       [bn add:_bigNumberOne]; break;
                    case LTC_OP_1SUB:       [bn subtract:_bigNumberOne]; break;
                    case LTC_OP_NEGATE:     [bn multiply:[LTCBigNumber negativeOne]]; break;
                    case LTC_OP_ABS:        if ([bn less:_bigNumberZero]) [bn multiply:[LTCBigNumber negativeOne]]; break;
                    case LTC_OP_NOT:        bn.uint32value = (uint32_t)[bn isEqual:_bigNumberZero]; break;
                    case LTC_OP_0NOTEQUAL:  bn.uint32value = (uint32_t)(![bn isEqual:_bigNumberZero]); break;
                    default:            NSAssert(0, @"Invalid opcode"); break;
                }
                [self popFromStack];
                [_stack addObject:bn.signedLittleEndian];
            }
            break;

            case LTC_OP_ADD:
            case LTC_OP_SUB:
            case LTC_OP_BOOLAND:
            case LTC_OP_BOOLOR:
            case LTC_OP_NUMEQUAL:
            case LTC_OP_NUMEQUALVERIFY:
            case LTC_OP_NUMNOTEQUAL:
            case LTC_OP_LESSTHAN:
            case LTC_OP_GREATERTHAN:
            case LTC_OP_LESSTHANOREQUAL:
            case LTC_OP_GREATERTHANOREQUAL:
            case LTC_OP_MIN:
            case LTC_OP_MAX: {
                // (x1 x2 -- out)
                if (_stack.count < 2) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
                    return NO;
                }
                
                // bn1 is nil when stack is ( <00000080 00>, <> )

                LTCMutableBigNumber* bn1 = [self bigNumberAtIndex:-2];
                LTCMutableBigNumber* bn2 = [self bigNumberAtIndex:-1];
                
                if (!bn1 || !bn2) {
                    if (errorOut) *errorOut = [self scriptErrorInvalidBignum];
                    return NO;
                }
                
                LTCMutableBigNumber* bn = nil;
                
                switch (opcode) {
                    case LTC_OP_ADD:
                        bn = [bn1 add:bn2];
                        break;
                        
                    case LTC_OP_SUB:
                        bn = [bn1 subtract:bn2];
                        break;
                        
                    case LTC_OP_BOOLAND:             bn = [[LTCMutableBigNumber alloc] initWithInt32:![bn1 isEqual:_bigNumberZero] && ![bn2 isEqual:_bigNumberZero]]; break;
                    case LTC_OP_BOOLOR:              bn = [[LTCMutableBigNumber alloc] initWithInt32:![bn1 isEqual:_bigNumberZero] || ![bn2 isEqual:_bigNumberZero]]; break;
                    case LTC_OP_NUMEQUAL:            bn = [[LTCMutableBigNumber alloc] initWithInt32: [bn1 isEqual:bn2]]; break;
                    case LTC_OP_NUMEQUALVERIFY:      bn = [[LTCMutableBigNumber alloc] initWithInt32: [bn1 isEqual:bn2]]; break;
                    case LTC_OP_NUMNOTEQUAL:         bn = [[LTCMutableBigNumber alloc] initWithInt32:![bn1 isEqual:bn2]]; break;
                    case LTC_OP_LESSTHAN:            bn = [[LTCMutableBigNumber alloc] initWithInt32:[bn1 less:bn2]]; break;
                    case LTC_OP_GREATERTHAN:         bn = [[LTCMutableBigNumber alloc] initWithInt32:[bn1 greater:bn2]]; break;
                    case LTC_OP_LESSTHANOREQUAL:     bn = [[LTCMutableBigNumber alloc] initWithInt32:[bn1 lessOrEqual:bn2]]; break;
                    case LTC_OP_GREATERTHANOREQUAL:  bn = [[LTCMutableBigNumber alloc] initWithInt32:[bn1 greaterOrEqual:bn2]]; break;
                    case LTC_OP_MIN:                 bn = [[bn1 min:bn2] mutableCopy]; break;
                    case LTC_OP_MAX:                 bn = [[bn1 max:bn2] mutableCopy]; break;
                    default:                     NSAssert(0, @"Invalid opcode"); break;
                }
                
                [self popFromStack];
                [self popFromStack];
                [_stack addObject:bn.signedLittleEndian];
                
                if (opcode == LTC_OP_NUMEQUALVERIFY) {
                    if ([self boolAtIndex:-1]) {
                        [self popFromStack];
                    } else {
                        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"OP_NUMEQUALVERIFY failed.", @"")];
                        return NO;
                    }
                }
            }
            break;
                
            case LTC_OP_WITHIN: {
                // (x min max -- out)
                if (_stack.count < 3) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:3];
                    return NO;
                }
                
                LTCMutableBigNumber* bn1 = [self bigNumberAtIndex:-3];
                LTCMutableBigNumber* bn2 = [self bigNumberAtIndex:-2];
                LTCMutableBigNumber* bn3 = [self bigNumberAtIndex:-1];
                
                if (!bn1 || !bn2 || !bn3) {
                    if (errorOut) *errorOut = [self scriptErrorInvalidBignum];
                    return NO;
                }
                
                BOOL value = ([bn2 lessOrEqual:bn1] && [bn1 less:bn3]);
                
                [self popFromStack];
                [self popFromStack];
                [self popFromStack];
                
                [_stack addObject:(value ? _bigNumberTrue : _bigNumberFalse).signedLittleEndian];
            }
            break;
            
                
            //
            // Crypto
            //
            case LTC_OP_RIPEMD160:
            case LTC_OP_SHA1:
            case LTC_OP_SHA256:
            case LTC_OP_HASH160:
            case LTC_OP_HASH256: {
                // (in -- hash)
                if (_stack.count < 1) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
                    return NO;
                }
                
                NSData* data = [self dataAtIndex:-1];
                NSData* hash = nil;
                
                if (opcode == LTC_OP_RIPEMD160) {
                    hash = LTCRIPEMD160(data);
                } else if (opcode == LTC_OP_SHA1) {
                    hash = LTCSHA1(data);
                } else if (opcode == LTC_OP_SHA256) {
                    hash = LTCSHA256(data);
                } else if (opcode == LTC_OP_HASH160) {
                    hash = LTCHash160(data);
                } else if (opcode == LTC_OP_HASH256) {
                    hash = LTCHash256(data);
                }
                [self popFromStack];
                [_stack addObject:hash];
            }
            break;
            
            
            case LTC_OP_CODESEPARATOR: {
                // Code separator is almost never used and no one knows why it could be useful. Maybe it's Satoshi's design mistake.
                // It affects how OP_CHECKSIG and OP_CHECKMULTISIG compute the hash of transaction for verifying the signature.
                // That hash should be computed after the most recent OP_CODESEPARATOR before current OP_CHECKSIG (or OP_CHECKMULTISIG).
                // Notice how we remember the index of OP_CODESEPARATOR itself, not the position after it.
                // Bitcoind will extract subscript *including* this codeseparator. But all codeseparators will be stripped out eventually
                // when we compute a hash of transaction. Just to keep ourselves close to bitcoind for extra asfety, we'll do the same here.
                _lastCodeSeparatorIndex = opcodeIndex;
            }
            break;

            
            case LTC_OP_CHECKSIG:
            case LTC_OP_CHECKSIGVERIFY: {
                // (sig pubkey -- bool)
                if (_stack.count < 2) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
                    return NO;
                }
                
                NSData* signature = [self dataAtIndex:-2];
                NSData* pubkeyData = [self dataAtIndex:-1];
                
                // Subset of script starting at the most recent OP_CODESEPARATOR (inclusive)
                LTCScript* subscript = [_script subScriptFromIndex:_lastCodeSeparatorIndex];

                // Drop the signature, since there's no way for a signature to sign itself.
                // Normally we neither have signatures in the output scripts, nor checksig ops in the input scripts.
                // In early days of Bitcoin (before July 2010) input and output scripts were concatenated and executed as one,
                // so this cleanup could make sense. But the concatenation was done with OP_CODESEPARATOR in the middle,
                // so dropping sigs still didn't make much sense - output script was still hashed separately from the input script (that contains signatures).
                // There could have been some use case if one could put a signature
                // right in the output script. E.g. to provably time-lock the funds.
                // But the second tx must contain a valid hash to its parent while
                // the parent must contain a signed hash of its child. This creates an unsolvable cycle.
                // See https://bitcointalk.org/index.php?topic=278992.0 for more info.
                [subscript deleteOccurrencesOfData:signature];

                NSError* sigerror = nil;
                BOOL failed = NO;
                if (_verificationFlags & LTCScriptVerificationStrictEncoding) {
                    if (![LTCKey isCanonicalPublicKey:pubkeyData error:&sigerror]) {
                        failed = YES;
                    }
                    if (!failed && ![LTCKey isCanonicalSignatureWithHashType:signature
                                                                 verifyLowerS:!!(_verificationFlags & LTCScriptVerificationEvenS)
                                                                       error:&sigerror]) {
                        failed = YES;
                    }
                }
                
                BOOL success = !failed && [self checkSignature:signature publicKey:pubkeyData subscript:subscript error:&sigerror];
                
                [self popFromStack];
                [self popFromStack];
                
                [_stack addObject:success ? _blobTrue : _blobFalse];
                
                if (opcode == LTC_OP_CHECKSIGVERIFY) {
                    if (success) {
                        [self popFromStack];
                    } else {
                        if (sigerror && errorOut) *errorOut = [self scriptError:[NSString stringWithFormat:NSLocalizedString(@"Signature check failed. %@", @""),
                                                                                 [sigerror localizedDescription]] underlyingError:sigerror];
                        return NO;
                    }
                }
            }
            break;
            
            
            case LTC_OP_CHECKMULTISIG:
            case LTC_OP_CHECKMULTISIGVERIFY: {
                // ([sig ...] num_of_signatures [pubkey ...] num_of_pubkeys -- bool)
                
                int i = 1;
                if (_stack.count < i) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:i];
                    return NO;
                }
                
                LTCBigNumber* bn = [self bigNumberAtIndex:-i];
                
                if (!bn) {
                    if (errorOut) *errorOut = [self scriptErrorInvalidBignum];
                    return NO;
                }

                int32_t keysCount = bn.int32value;
                if (keysCount < 0 || keysCount > LTC_MAX_KEYS_FOR_CHECKMULTISIG) {
                    if (errorOut) *errorOut = [self scriptError:[NSString stringWithFormat:NSLocalizedString(@"Invalid number of keys for %@: %d.", @""), LTCNameForOpcode(opcode), keysCount]];
                    return NO;
                }
                
                _opCount += keysCount;
                
                if (_opCount > LTC_MAX_OPS_PER_SCRIPT) {
                    if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Exceeded allowed number of operations per script.", @"")];
                    return NO;
                }
                
                // An index of the first key
                int ikey = ++i;
                
                i += keysCount;
                
                if (_stack.count < i) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:i];
                    return NO;
                }
                
                // Read the required number of signatures.
                LTCBigNumber* bn2 = [self bigNumberAtIndex:-i];
                
                if (!bn2) {
                    if (errorOut) *errorOut = [self scriptErrorInvalidBignum];
                    return NO;
                }

                int sigsCount = bn2.int32value;
                if (sigsCount < 0 || sigsCount > keysCount) {
                    if (errorOut) *errorOut = [self scriptError:[NSString stringWithFormat:NSLocalizedString(@"Invalid number of signatures for %@: %d.", @""), LTCNameForOpcode(opcode), keysCount]];
                    return NO;
                }
                
                // The index of the first signature
                int isig = ++i;
                
                i += sigsCount;
                
                if (_stack.count < i) {
                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:i];
                    return NO;
                }
                
                // Subset of script starting at the most recent OP_CODESEPARATOR (inclusive)
                LTCScript* subscript = [_script subScriptFromIndex:_lastCodeSeparatorIndex];
                
                // Drop the signatures, since there's no way for a signature to sign itself.
                // Essentially this is noop because signatures are never present in scripts.
                // See also a comment to a similar code in OP_CHECKSIG.
                for (int k = 0; k < sigsCount; k++) {
                    NSData* sig = [self dataAtIndex: - isig - k];
                    [subscript deleteOccurrencesOfData:sig];
                }
                
                BOOL success = YES;
                NSError* firstsigerror = nil;

                // Signatures must come in the same order as their keys.
                while (success && sigsCount > 0) {
                    NSData* signature = [self dataAtIndex:-isig];
                    NSData* pubkeyData = [self dataAtIndex:-ikey];
                    
                    BOOL validMatch = YES;
                    NSError* sigerror = nil;
                    if (_verificationFlags & LTCScriptVerificationStrictEncoding) {
                        if (![LTCKey isCanonicalPublicKey:pubkeyData error:&sigerror]) {
                            validMatch = NO;
                        }
                        if (validMatch && ![LTCKey isCanonicalSignatureWithHashType:signature
                                                                        verifyLowerS:!!(_verificationFlags & LTCScriptVerificationEvenS)
                                                                              error:&sigerror]) {
                            validMatch = NO;
                        }
                    }
                    if (validMatch) {
                        validMatch = [self checkSignature:signature publicKey:pubkeyData subscript:subscript error:&sigerror];
                    }
                    
                    if (validMatch) {
                        isig++;
                        sigsCount--;
                    } else {
                        if (!firstsigerror) firstsigerror = sigerror;
                    }
                    ikey++;
                    keysCount--;
                    
                    // If there are more signatures left than keys left,
                    // then too many signatures have failed
                    if (sigsCount > keysCount) {
                        success = NO;
                    }
                }
                
                // Remove all signatures, counts and pubkeys from stack.
                // Note: 'i' points past the signatures. Due to postfix decrement (i--) this loop will pop one extra item from the stack.
                // We can't change this code to use prefix decrement (--i) until every node does the same.
                // This means that to redeem multisig script you have to prepend a dummy OP_0 item before all signatures so it can be popped here.
                while (i-- > 0) {
                    [self popFromStack];
                }
                
                [_stack addObject:success ? _blobTrue : _blobFalse];
                
                if (opcode == LTC_OP_CHECKMULTISIGVERIFY) {
                    if (success) {
                        [self popFromStack];
                    } else {
                        if (firstsigerror && errorOut) *errorOut =
                            [self scriptError:[NSString stringWithFormat:NSLocalizedString(@"Multisignature check failed. %@", @""),
                                               [firstsigerror localizedDescription]] underlyingError:firstsigerror];
                        return NO;
                    }
                }
            }
            break;

                
            default:
                if (errorOut) *errorOut = [self scriptError:[NSString stringWithFormat:NSLocalizedString(@"Unknown opcode %d (%@).", @""), opcode, LTCNameForOpcode(opcode)]];
                return NO;
        }
    }
    
    if (_stack.count + _altStack.count > 1000) {
        return NO;
    }
    
    return YES;
}


- (BOOL) checkSignature:(NSData*)signature publicKey:(NSData*)pubkeyData subscript:(LTCScript*)subscript error:(NSError**)errorOut {
    LTCKey* pubkey = [[LTCKey alloc] initWithPublicKey:pubkeyData];
    
    if (!pubkey) {
        if (errorOut) *errorOut = [self scriptError:[NSString stringWithFormat:NSLocalizedString(@"Public key is not valid: %@.", @""),
                                                     LTCHexFromData(pubkeyData)]];
        return NO;
    }
    
    // Hash type is one byte tacked on to the end of the signature. So the signature shouldn't be empty.
    if (signature.length == 0) {
        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Signature is empty.", @"")];
        return NO;
    }
    
    // Extract hash type from the last byte of the signature.
    LTCSignatureHashType hashType = ((unsigned char*)signature.bytes)[signature.length - 1];
    
    // Strip that last byte to have a pure signature.
    signature = [signature subdataWithRange:NSMakeRange(0, signature.length - 1)];
    
    NSData* sighash = [_transaction signatureHashForScript:subscript inputIndex:_inputIndex hashType:hashType error:errorOut];
    
    //NSLog(@"LTCScriptMachine: Hash for input %d [%d]: %@", _inputIndex, hashType, LTCHexFromData(sighash));
    
    if (!sighash) {
        // errorOut is set already.
        return NO;
    }
    
    if (![pubkey isValidSignature:signature hash:sighash]) {
        if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Signature is not valid.", @"")];
        return NO;
    }
    
    return YES;
}

- (NSArray*) stack {
    return [_stack copy] ?: @[];
}

- (NSArray*) altstack {
    return [_altStack copy] ?: @[];
}




#pragma mark - Error Helpers




- (NSError*) scriptError:(NSString*)localizedString {
    return [NSError errorWithDomain:LTCErrorDomain
                               code:LTCErrorScriptError
                           userInfo:@{NSLocalizedDescriptionKey: localizedString}];
}

- (NSError*) scriptError:(NSString*)localizedString underlyingError:(NSError*)underlyingError {
    if (!underlyingError) return [self scriptError:localizedString];
    
    return [NSError errorWithDomain:LTCErrorDomain
                               code:LTCErrorScriptError
                           userInfo:@{NSLocalizedDescriptionKey: localizedString,
                                      NSUnderlyingErrorKey: underlyingError}];
}

- (NSError*) scriptErrorOpcodeRequiresItemsOnStack:(NSUInteger)items {
    if (items == 1) {
        return [NSError errorWithDomain:LTCErrorDomain
                                   code:LTCErrorScriptError
                               userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"%@ requires %d item on stack.", @""), LTCNameForOpcode(_opcode), items]}];
    }
    return [NSError errorWithDomain:LTCErrorDomain code:LTCErrorScriptError userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"%@ requires %d items on stack.", @""), LTCNameForOpcode(_opcode), items]}];
}

- (NSError*) scriptErrorInvalidBignum {
    return [NSError errorWithDomain:LTCErrorDomain
                               code:LTCErrorScriptError
                           userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Invalid bignum data.", @"")}];
}



#pragma mark - Stack Utilities

// 0 is the first item in stack, 1 is the second.
// -1 is the last item, -2 is the pre-last item.
#define LTCNormalizeIndex(list, i) (i < 0 ? (list.count + i) : i)

- (NSData*) dataAtIndex:(NSInteger)index {
    return _stack[LTCNormalizeIndex(_stack, index)];
}

- (void) swapDataAtIndex:(NSInteger)index1 withIndex:(NSInteger)index2 {
    [_stack exchangeObjectAtIndex:LTCNormalizeIndex(_stack, index1)
                withObjectAtIndex:LTCNormalizeIndex(_stack, index2)];
}

// Returns bignum from pushdata or nil.
- (LTCMutableBigNumber*) bigNumberAtIndex:(NSInteger)index {
    NSData* data = [self dataAtIndex:index];
    if (!data) return nil;
    
    // BitcoinQT throws "CastToBigNum() : overflow" and then catches it inside EvalScript to return false.
    // This is catched in unit test for invalid scripts: @[@"2147483648 0 ADD", @"NOP", @"arithmetic operands must be in range @[-2^31...2^31] "]
    if (data.length > 4) {
        return nil;
    }

    // Get rid of extra leading zeros like BitcoinQT does:
    // CBigNum(CBigNum(vch).getvch());
    // FIXME: It's a cargo cult here. I haven't checked myself when do these extra zeros appear and whether they really go away. [Oleg]
    LTCMutableBigNumber* bn = [[LTCMutableBigNumber alloc] initWithSignedLittleEndian:[[LTCBigNumber alloc] initWithSignedLittleEndian:data].signedLittleEndian];
    return bn;
}

- (BOOL) boolAtIndex:(NSInteger)index {
    NSData* data = [self dataAtIndex:index];
    if (!data) return NO;
    
    NSUInteger len = data.length;
    if (len == 0) return NO;
    
    const unsigned char* bytes = data.bytes;
    for (NSUInteger i = 0; i < len; i++) {
        if (bytes[i] != 0) {
            // Can be negative zero, also counts as NO
            if (i == (len - 1) && bytes[i] == 0x80) {
                return NO;
            }
            return YES;
        }
    }
    return NO;
}

// -1 means last item
- (void) removeAtIndex:(NSInteger)index {
    [_stack removeObjectAtIndex:LTCNormalizeIndex(_stack, index)];
}

// -1 means last item
- (void) popFromStack {
    [_stack removeObjectAtIndex:LTCNormalizeIndex(_stack, -1)];
}

@end
