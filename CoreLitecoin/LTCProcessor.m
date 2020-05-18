// CoreBitcoin by Oleg Andreev <oleganza@gmail.com>, WTFPL.

#import "LTCProcessor.h"
#import "LTCNetwork.h"
#import "LTCBlock.h"
#import "LTCBlockHeader.h"
#import "LTCTransaction.h"
#import "LTCTransactionInput.h"
#import "LTCTransactionOutput.h"

NSString* const LTCProcessorErrorDomain = @"LTCProcessorErrorDomain";

@implementation LTCProcessor

- (id) init {
    if (self = [super init]) {
        self.network = [LTCNetwork mainnet];
    }
    return self;
}


// Macros to prepare NSError object and check with delegate if the error should cause failure or not.

#define REJECT_BLOCK_WITH_ERROR(ERROR_CODE, MESSAGE, ...) { \
    NSError* error = [NSError errorWithDomain:LTCProcessorErrorDomain code:(ERROR_CODE) \
                                     userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:MESSAGE, __VA_ARGS__] }]; \
    if ([self shouldRejectBlock:block withError:error]) { \
        [self notifyDidRejectBlock:block withError:error]; \
        *errorOut = error; \
        return NO; \
    } \
}

#define REJECT_BLOCK_WITH_DOS(ERROR_CODE, DOS_LEVEL, MESSAGE, ...) { \
    NSError* error = [NSError errorWithDomain:LTCProcessorErrorDomain code:ERROR_CODE \
                                     userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:MESSAGE, __VA_ARGS__], @"DoS": @(DOS_LEVEL) }]; \
    if ([self shouldRejectBlock:block withError:error]) { \
        [self notifyDidRejectBlock:block withError:error]; \
        *errorOut = error; \
        return NO; \
    } \
}


// Attempts to process the block. Returns YES on success, NO and error on failure.
- (BOOL) processBlock:(LTCBlock*)block error:(NSError**)errorOut {
    if (!self.dataSource) {
        @throw [NSException exceptionWithName:@"Cannot process block" reason:@"-[LTCProcessor dataSource] is nil." userInfo:nil];
    }
    
    // 1. Check for duplicate blocks
    
    NSData* hash = block.blockHash;
    
    if ([self.dataSource blockExistsWithHash:hash]) {
        REJECT_BLOCK_WITH_ERROR(LTCProcessorErrorDuplicateBlock, NSLocalizedString(@"Already have block %@", @""), hash);
    }
    
    if ([self.dataSource orphanBlockExistsWithHash:hash]) {
        REJECT_BLOCK_WITH_ERROR(LTCProcessorErrorDuplicateOrphanBlock, NSLocalizedString(@"Already have orphan block %@", @""), hash);
    }
    
    
    
    return YES;
}


// Attempts to add transaction to "memory pool" of unconfirmed transactions.
- (BOOL) processTransaction:(LTCTransaction*)transaction error:(NSError**)errorOut {
    
    // TODO: ...
    
    return NO;
}



#pragma mark - Helpers


- (BOOL) shouldRejectBlock:(LTCBlock*)block withError:(NSError*)error {
    return (![self.delegate respondsToSelector:@selector(processor:shouldRejectBlock:withError:)] ||
            [self.delegate processor:self shouldRejectBlock:block withError:error]);
}

- (void) notifyDidRejectBlock:(LTCBlock*)block withError:(NSError*)error {
    if ([self.delegate respondsToSelector:@selector(processor:didRejectBlock:withError:)]) {
        [self.delegate processor:self didRejectBlock:block withError:error];
    }
}


@end
