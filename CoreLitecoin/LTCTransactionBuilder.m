#import "LTCTransactionBuilder.h"
#import "LTCTransaction.h"
#import "LTCTransactionOutput.h"
#import "LTCTransactionInput.h"
#import "LTCAddress.h"
#import "LTCScript.h"
#import "LTCKey.h"
#import "LTCData.h"

NSString* const LTCTransactionBuilderErrorDomain = @"com.oleganza.CoreLitecoin.TransactionBuilder";

@interface LTCTransactionBuilderResult ()
@property(nonatomic, readwrite) LTCTransaction* transaction;
@property(nonatomic, readwrite) NSIndexSet* unsignedInputsIndexes;
@property(nonatomic, readwrite) LTCAmount fee;
@property(nonatomic, readwrite) LTCAmount inputsAmount;
@property(nonatomic, readwrite) LTCAmount outputsAmount;
@end

@implementation LTCTransactionBuilder

- (id) init {
    if (self = [super init]) {
        _feeRate = LTCTransactionDefaultFeeRate;
        _minimumChange = -1; // so it picks feeRate at runtime.
        _dustChange = -1; // so it picks minimumChange at runtime.
        _shouldSign = YES;
        _shouldShuffle = YES;
    }
    return self;
}

- (LTCTransactionBuilderResult*) buildTransaction:(NSError**)errorOut {
    if (!self.changeScript) {
        if (errorOut) *errorOut = [NSError errorWithDomain:LTCTransactionBuilderErrorDomain code:LTCTransactionBuilderInsufficientFunds userInfo:nil];
        return nil;
    }

    NSEnumerator* unspentsEnumerator = self.unspentOutputsEnumerator;

    if (!unspentsEnumerator) {
        if (errorOut) *errorOut = [NSError errorWithDomain:LTCTransactionBuilderErrorDomain code:LTCTransactionBuilderUnspentOutputsMissing userInfo:nil];
        return nil;
    }

    LTCTransactionBuilderResult* result = [[LTCTransactionBuilderResult alloc] init];
    result.transaction = [[LTCTransaction alloc] init];

    // If no outputs given, try to spend all available unspents.
    if (self.outputs.count == 0) {
        result.inputsAmount = 0;

        for (LTCTransactionOutput* utxo in unspentsEnumerator) {
            result.inputsAmount += utxo.value;

            LTCTransactionInput* txin = [self makeTransactionInputWithUnspentOutput:utxo];
            [result.transaction addInput:txin];
        }

        if (result.transaction.inputs.count == 0) {
            if (errorOut) *errorOut = [NSError errorWithDomain:LTCTransactionBuilderErrorDomain code:LTCTransactionBuilderUnspentOutputsMissing userInfo:nil];
            return nil;
        }

        // Prepare a destination output.
        // Value will be determined after computing the fee.
        LTCTransactionOutput* changeOutput = [[LTCTransactionOutput alloc] initWithValue:LTC_MAX_MONEY script:self.changeScript];
        [result.transaction addOutput:changeOutput];

        result.fee = [self computeFeeForTransaction:result.transaction];
        result.outputsAmount = result.inputsAmount - result.fee;

        // Check if inputs cover the fees
        if (result.outputsAmount < 0) {
            if (errorOut) *errorOut = [NSError errorWithDomain:LTCTransactionBuilderErrorDomain code:LTCTransactionBuilderInsufficientFunds userInfo:nil];
            return nil;
        }

        // Set the output value as needed
        changeOutput.value = result.outputsAmount;

        result.unsignedInputsIndexes = [self attemptToSignTransaction:result.transaction error:errorOut];
        if (!result.unsignedInputsIndexes) {
            return nil;
        }

        return result;

    } // if no outputs

    // We are having one or more outputs (e.g. normal payment)
    // Need to find appropriate unspents and compose a transaction.

    // Prepare all outputs

    result.outputsAmount = 0; // will contain change value after all inputs are finalized

    for (LTCTransactionOutput* txout in self.outputs) {
        result.outputsAmount += txout.value;
        [result.transaction addOutput:txout];
    }

    // We'll determine final change value depending on inputs.
    // Setting default to MAX_MONEY will protect against a bug when we fail to update the amount and
    // spend unexpected amount on mining fees.
    LTCTransactionOutput* changeOutput = [[LTCTransactionOutput alloc] initWithValue:LTC_MAX_MONEY script:self.changeScript];
    [result.transaction addOutput:changeOutput];

    // We have specific outputs with specific amounts, so we need to select the best amount of coins.

    result.inputsAmount = 0;

    for (LTCTransactionOutput* utxo in unspentsEnumerator) {
        result.inputsAmount += utxo.value;

        LTCTransactionInput* txin = [self makeTransactionInputWithUnspentOutput:utxo];
        [result.transaction addInput:txin];

        // Before computing the fee, quick check if we have enough inputs to cover the outputs.
        // If not, go and add one more utxo before wasting time computing fees.
        if (result.inputsAmount < result.outputsAmount) {
            // Try adding more unspent outputs on the next cycle.
            continue;
        }

        LTCAmount fee = [self computeFeeForTransaction:result.transaction];

        LTCAmount change = result.inputsAmount - result.outputsAmount - fee;

        if (change >= self.minimumChange) {
            // We have a big enough change, set missing values and return.
            changeOutput.value = change;
            result.outputsAmount += change;
            result.fee = fee;

            result.unsignedInputsIndexes = [self attemptToSignTransaction:result.transaction error:errorOut];
            if (!result.unsignedInputsIndexes) {
                return nil;
            }
            return result;
        } else if (change > self.dustChange && change < self.minimumChange) {
            // We have a shitty change: not small enough to forgo, not big enough to be useful.
            // Try adding more utxos on the next cycle (or fail if no more utxos are available).
        } else if (change >= 0 && change <= self.dustChange) {
            // This also includes the case when change is exactly zero satoshis.
            // Remove the change output, keep existing outputsAmount, set fee and try to sign.

            NSMutableArray* txoutputs = [result.transaction.outputs mutableCopy];
            [txoutputs removeObjectIdenticalTo:changeOutput];
            result.transaction.outputs = txoutputs;
            result.fee = fee;
            result.unsignedInputsIndexes = [self attemptToSignTransaction:result.transaction error:errorOut];
            if (!result.unsignedInputsIndexes)
            {
                return nil;
            }
            return result;
        } else {
            // Change is negative, we need more funds for this transaction.
            // Try adding more utxos on the next cycle.
        }
    }

    // If we haven't finished within the loop, then we don't have enough unspent outputs and should fail.

    LTCTransactionBuilderError errorCode = LTCTransactionBuilderInsufficientFunds;
    if (result.transaction.inputs.count == 0) {
        errorCode = LTCTransactionBuilderUnspentOutputsMissing;
    }
    if (errorOut) *errorOut = [NSError errorWithDomain:LTCTransactionBuilderErrorDomain code:errorCode userInfo:nil];
    return nil;
}




// Helpers



- (LTCTransactionInput*) makeTransactionInputWithUnspentOutput:(LTCTransactionOutput*)utxo {
    LTCTransactionInput* txin = [[LTCTransactionInput alloc] init];

    if (!utxo.transactionHash || utxo.index == LTCTransactionOutputIndexUnknown) {
        [[NSException exceptionWithName:@"Incorrect unspent transaction output" reason:@"Unspent output must have valid -transactionHash and -index properties" userInfo:nil] raise];
    }

    txin.previousHash = utxo.transactionHash;
    txin.previousIndex = utxo.index;
    txin.signatureScript = utxo.script; // put the output script here so the signer knows which key to use.
    txin.transactionOutput = utxo;

    return txin;
}


- (LTCAmount) computeFeeForTransaction:(LTCTransaction*)tx {
    // Compute fees for this tx by composing a tx with properly sized dummy signatures.
    LTCTransaction* simtx = [tx copy];
    uint32_t i = 0;
    for (LTCTransactionInput* txin in simtx.inputs) {
        NSAssert(!!txin.transactionOutput, @"must have transactionOutput");
        LTCScript* txoutScript = txin.transactionOutput.script;

        if (![self attemptToSignTransactionInput:txin tx:simtx inputIndex:i error:NULL]) {
            // TODO: if cannot match the simulated signature, use data source to provide one. (If signing API available, then use it.)
            txin.signatureScript = [txoutScript simulatedSignatureScriptWithOptions:LTCScriptSimulationMultisigP2SH];
        }

        if (!txin.signatureScript) txin.signatureScript = txoutScript;

        i++;
    }
    return [simtx estimatedFeeWithRate:self.feeRate];
}


// Tries to sign a transaction and returns index set of unsigned inputs.
- (NSIndexSet*) attemptToSignTransaction:(LTCTransaction*)tx error:(NSError**)errorOut {
    // By default, all inputs are marked to be signed.
    NSMutableIndexSet* unsignedIndexes = [NSMutableIndexSet indexSet];
    for (NSUInteger i = 0; i < tx.inputs.count; i++) {
        [unsignedIndexes addIndex:i];
    }

    // Check if we can possibly sign anything. Otherwise return early.
    if (!_shouldSign || tx.inputs.count == 0 || !self.dataSource) {
        return unsignedIndexes;
    }

    if (_shouldShuffle && _shouldSign) {
        // Shuffle both the inputs and outputs.
        NSData* seed = nil;

        if ([self.dataSource respondsToSelector:@selector(shuffleSeedForTransactionBuilder:)]) {
            seed = [self.dataSource shuffleSeedForTransactionBuilder:self];
        }

        if (!seed && [self.dataSource respondsToSelector:@selector(transactionBuilder:keyForUnspentOutput:)]) {
            // find the first key
            for (LTCTransactionInput* txin in tx.inputs) {
                LTCKey* k = [self.dataSource transactionBuilder:self keyForUnspentOutput:txin.transactionOutput];
                seed = k.privateKey;
                if (seed) break;
            }
        }

        // If finally have something as a seed, shuffle
        if (seed) {
            tx.inputs = [self shuffleInputs:tx.inputs withSeed:seed];
            tx.outputs = [self shuffleOutputs:tx.outputs withSeed:seed];
        }
    }

    // Try to sign each input.
    for (uint32_t i = 0; i < tx.inputs.count; i++) {
        // We support two kinds of scripts: p2pkh (modern style) and p2pk (old style)
        // For each of these we support compressed and uncompressed pubkeys.
        LTCTransactionInput* txin = tx.inputs[i];

        if ([self attemptToSignTransactionInput:txin tx:tx inputIndex:i error:errorOut]) {
            [unsignedIndexes removeIndex:i];
        }
    } // each input

    return unsignedIndexes;
}

- (NSArray*) shuffleInputs:(NSArray*)txins withSeed:(NSData*)seed {
    return [txins sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(LTCTransactionInput* a, LTCTransactionInput* b) {
        NSData* d1 = LTCHash256Concat(a.data, seed);
        NSData* d2 = LTCHash256Concat(b.data, seed);
        return [d1.description compare:d2.description];
    }];
}

- (NSArray*) shuffleOutputs:(NSArray*)txouts withSeed:(NSData*)seed {
    return [txouts sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(LTCTransactionOutput* a, LTCTransactionOutput* b) {
        NSData* d1 = LTCHash256Concat(a.data, seed);
        NSData* d2 = LTCHash256Concat(b.data, seed);
        return [d1.description compare:d2.description];
    }];
}

- (BOOL) attemptToSignTransactionInput:(LTCTransactionInput*)txin tx:(LTCTransaction*)tx inputIndex:(uint32_t)i error:(NSError**)errorOut {
    if (!_shouldSign) return NO;

    // We stored output script here earlier.
    LTCScript* outputScript = txin.signatureScript;
    LTCKey* key = nil;

    if ([self.dataSource respondsToSelector:@selector(transactionBuilder:keyForUnspentOutput:)]) {
        key = [self.dataSource transactionBuilder:self keyForUnspentOutput:txin.transactionOutput];
    }

    if (key) {
        NSData* cpk = key.compressedPublicKey;
        NSData* ucpk = key.uncompressedPublicKey;

        LTCSignatureHashType hashtype = LTC_SIGHASH_ALL;

        NSData* sighash = [tx signatureHashForScript:[outputScript copy] inputIndex:i hashType:hashtype error:errorOut];
        if (!sighash) {
            return NO;
        }

        // Most common case: P2PKH with compressed pubkey (because of BIP32)
        LTCScript* p2cpkhScript = [[LTCScript alloc] initWithAddress:[LTCPublicKeyAddress addressWithData:LTCHash160(cpk)]];
        if ([outputScript.data isEqual:p2cpkhScript.data]) {
            txin.signatureScript = [[[LTCScript new] appendData:[key signatureForHash:sighash hashType:hashtype]] appendData:cpk];
            return YES;
        }

        // Less common case: P2PKH with uncompressed pubkey (when not using BIP32)
        LTCScript* p2ucpkhScript = [[LTCScript alloc] initWithAddress:[LTCPublicKeyAddress addressWithData:LTCHash160(ucpk)]];
        if ([outputScript.data isEqual:p2ucpkhScript.data]) {
            txin.signatureScript = [[[LTCScript new] appendData:[key signatureForHash:sighash hashType:hashtype]] appendData:ucpk];
            return YES;
        }

        LTCScript* p2cpkScript = [[[LTCScript new] appendData:cpk] appendOpcode:LTC_OP_CHECKSIG];
        LTCScript* p2ucpkScript = [[[LTCScript new] appendData:ucpk] appendOpcode:LTC_OP_CHECKSIG];

        if ([outputScript.data isEqual:p2cpkScript] ||
            [outputScript.data isEqual:p2ucpkScript]) {
            txin.signatureScript = [[LTCScript new] appendData:[key signatureForHash:sighash hashType:hashtype]];
            return YES;
        } else {
            // Not supported script type.
            // Try custom signature.
        }
    } // if key

    // Ask to sign the transaction input to sign this if that's some kind of special input or script.
    if ([self.dataSource respondsToSelector:@selector(transactionBuilder:signatureScriptForTransaction:script:inputIndex:)]) {
        LTCScript* sigScript = [self.dataSource transactionBuilder:self signatureScriptForTransaction:tx script:outputScript inputIndex:i];
        if (sigScript) {
            txin.signatureScript = sigScript;
            return YES;
        }
    }

    return NO;
}




// Properties



- (LTCScript*) changeScript {
    if (_changeScript) return _changeScript;

    if (!self.changeAddress) return nil;

    return [[LTCScript alloc] initWithAddress:self.changeAddress.publicAddress];
}

- (NSEnumerator*) unspentOutputsEnumerator {
    if (_unspentOutputsEnumerator) return _unspentOutputsEnumerator;

    if (self.dataSource) {
        return [self.dataSource unspentOutputsForTransactionBuilder:self];
    }

    return nil;
}

- (LTCAmount) minimumChange {
    if (_minimumChange < 0) return self.feeRate;
    return _minimumChange;
}

- (LTCAmount) dustChange {
    if (_dustChange < 0) return self.minimumChange;
    return _dustChange;
}

@end


@implementation LTCTransactionBuilderResult
@end
