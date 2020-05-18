CoreLitecoin
===========

CoreLitecoin implements Bitcoin protocol in Objective-C and provides many additional APIs to make great apps.

CoreLitecoin deliberately implements as much as possible directly in Objective-C with limited dependency on OpenSSL. This gives everyone an opportunity to learn Bitcoin on a clean codebase and enables all Mac and iOS developers to extend and improve Bitcoin protocol.

Do not confuse this with "Bitcoin Core" (previously known as BitcoinQT or "Satoshi client") — the CoreLitecoin is stylized after Apple frameworks (like CoreAnimation and CoreFoundation), and was named this way in 2013, while Bitcoin-QT was renamed into Bitcoin Core in 2014.


Projects using CoreLitecoin
--------------------------

- [Chain-iOS SDK](https://github.com/chain-engineering/chain-ios) (written by Oleg Andreev)
- [Mycelium iOS Wallet](https://itunes.apple.com/us/app/mycelium-bitcoin-wallet/id943912290) (written by Oleg Andreev)
- [bitWallet](https://itunes.apple.com/us/app/bitwallet-bitcoin-wallet/id777634714)
- [Yallet](https://www.yallet.com)
- [BitStore](http://bitstoreapp.com)
- [ArcBit](http://arcbit.io)

Features
--------

See also [Release Notes](ReleaseNotes.md).

- Encoding/decoding addresses: P2PK, P2PKH, P2SH, WIF format ([BTCAddress](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCAddress.h)).
- Transaction building blocks: inputs, outputs, scripts ([BTCTransaction](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCTransaction.h), [BTCScript](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCScript.h)).
- EC keys and signatures ([BTCKey](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCKey.h)).
- High-level convenient and safe transaction builder ([BTCTransactionBuilder](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCTransactionBuilder.h)).
- Parsing and composing bitcoin URLs and payment requests ([BTCBitcoinURL](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCBitcoinURL.h)).
- QR Code generator and scanner in a unified API (iOS only for now; [BTCQRCode](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCQRCode.h)).
- BIP32, BIP44 hierarchical deterministic wallets ([BTCKeychain](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCKeychain.h)).
- BIP39 implementation ([BTCMnemonic](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCMnemonic.h)).
- BIP70 implementation ([BTCPaymentProtocol](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCPaymentProtocol.h)).
- [Automatic Encrypted Wallet Backup](https://github.com/oleganza/bitcoin-papers/blob/master/AutomaticEncryptedWalletBackups.md) scheme ([BTCEncryptedBackup](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCEncryptedBackup.h)).

Currency tools
--------------

- Bitcoin currency formatter with support for BTC, mBTC, bits ([BTCNumberFormatter](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCNumberFormatter.h)).
- Currency converter (not linked to any exchange) with support for various methods to calculate exchange rate ([BTCCurrencyConverter](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCCurrencyConverter.h)).
- Various price sources and abstract interface for adding new ones ([BTCPriceSource](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCPriceSource.h) with support for Winkdex, Coindesk, Coinbase, Paymium).

Advanced features
-----------------

- Deterministic [RFC6979](https://tools.ietf.org/html/rfc6979#section-3.2)-compliant ECDSA signatures.
- Script evaluation machine to actually validate individual transactions ([BTCScriptMachine](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCScriptMachine.h)).
- Blind signatures implementation ([BTCBlindSignature](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCBlindSignature.h)).
- Math on elliptic curves: big numbers, curve points, conversion between keys, numbers and points ([BTCBigNumber](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCBigNumber.h), [BTCCurvePoint](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCCurvePoint.h)).
- Various cryptographic primitives like hash functions and AES encryption (see [BTCData.h](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCData.h)).


On the roadmap
--------------

See [all todo items](https://github.com/oleganza/CoreLitecoin/issues).

- Complete support for blocks and block headers.
- SPV mode and P2P communication with other nodes.
- Full blockchain verification procedure and storage.
- Importing BitcoinQT, Electrum and Blockchain.info wallets.
- Support for [libsecp256k1](https://github.com/bitcoin/secp256k1) in addition to OpenSSL.
- Eventual support for libconsensus as it gets more mature and feature-complete.

The goal is to implement everything useful related to Bitcoin and organize it nicely in a single powerful library. Pull requests are welcome.


Starting points
---------------

To encode/decode addresses see [BTCAddress](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCAddress.h).

To perform cryptographic operations, use [BTCKey](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCKey.h), [BTCBigNumber](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCBigNumber.h) and [BTCCurvePoint](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCCurvePoint). [BTCKeychain](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCKeychain.h) implements BIP32 (hierarchical deterministic wallet).

To fetch unspent coins and broadcast transactions use one of the 3rd party APIs: [BTCBlockchainInfo](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCBlockchainInfo.h) (blockchain.info) or [Chain-iOS](https://github.com/chain-engineering/chain-ios) (recommended).

For full wallet workflow see [BTCTransaction+Tests.m](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCTransaction+Tests.m) (fetch unspent outputs, compose a transaction, sign inputs, verify and broadcast).

For multisignature scripts usage see [BTCScript+Tests.m](https://github.com/oleganza/CoreLitecoin/blob/master/CoreLitecoin/BTCScript+Tests.m): compose and unlock multisig output.

All other files with `+Tests` in their name are worth checking out as they contain useful sample code.


Using CoreLitecoin CocoaPod (recommended)
----------------------------------------

Add this to your Podfile:

    pod 'CoreLitecoin', :podspec => 'https://raw.github.com/oleganza/CoreLitecoin/master/CoreLitecoin.podspec'

Run in Terminal:

    $ pod install

Include headers:

	#import <CoreLitecoin/CoreLitecoin.h>

If you'd like to use categories, include different header:

	#import <CoreLitecoin/CoreLitecoin+Categories.h>


Using CoreLitecoin.framework
---------------------------

Clone this repository and build all libraries:

	$ ./update_openssl.sh
	$ ./build_libraries.sh

Copy iOS or OS X framework located in binaries/iOS or binaries/OSX to your project.

Include headers:

	#import <CoreLitecoin/CoreLitecoin.h>
	
There are also raw universal libraries (.a) with headers located in binaries/include, if you happen to need them for some reason. Frameworks and binary libraries have OpenSSL built-in. If you have different version of OpenSSL in your project, consider using CocoaPods or raw sources of CoreLitecoin.


Swift
-----

We love Swift and design the code to be compatible with Swift. That means using modern enums, favoring initializers over factory methods, avoiding obscure C features etc. You are welcome to try using CoreLitecoin from Swift, please file bugs if you have problems.

Swift is awesome to write crypto in it (due to explicit optionals, generics and first-class structs) and we would love to rewrite the entire CoreLitecoin and even relevant portions of OpenSSL in it. Unfortunately, for a year or two it's just out of the question due to instability. And then, using Swift-only features on the API level would mean that Objective-C code wouldn't be able to use CoreLitecoin. Given that, in the medium term we will focus solely on Objective-C implementation compatible with Swift. When everyone jumps exclusively on Swift, we'll make a complete rewrite.


Contribute
----------

Feel free to open issues, drop us pull requests or contact us to discuss how to do things.

Follow existing code style and use 4 spaces instead of tabs. Methods have opening braces on a new line. There's no line width limit.

Email: [oleganza@gmail.com](mailto:oleganza@gmail.com)

Twitter: [@oleganza](http://twitter.com/oleganza)

To publish on CocoaPods:

    $ pod trunk push --verbose --use-libraries


License
-------

Released under [WTFPL](http://www.wtfpl.net) (except for OpenSSL). Have a nice day.

