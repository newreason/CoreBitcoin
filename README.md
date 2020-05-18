CoreLitecoin
===========

CoreLitecoin is a fork of CoreBitcoin with edited names, renamed some variables and edited address prefixes. It implements Litecoin protocol in Objective-C and provides many additional APIs to make great apps.

CoreLitecoin deliberately implements as much as possible directly in Objective-C with limited dependency on OpenSSL. This gives everyone an opportunity to learn Bitcoin on a clean codebase and enables all Mac and iOS developers to extend and improve Bitcoin protocol.

Using CoreLitecoin CocoaPod
----------------------------------------

Add this to your Podfile:

    pod 'CoreLitecoin', :podspec => 'https://raw.github.com/newreason/CoreLitecoin/master/CoreLitecoin.podspec'

Run in Terminal:

    $ pod install

Include headers:

	#import <CoreLitecoin/CoreLitecoin.h>

If you'd like to use categories, include different header:

	#import <CoreLitecoin/CoreLitecoin+Categories.h>


Using CoreLitecoin.framework (recommended)
---------------------------

Clone this repository and build all libraries:

	$ ./update_openssl.sh
	$ ./build_libraries.sh

Copy iOS or OS X framework located in binaries/iOS or binaries/OSX to your project.

Include headers:

	#import <CoreLitecoin/CoreLitecoin.h>
	
There are also raw universal libraries (.a) with headers located in binaries/include, if you happen to need them for some reason. Frameworks and binary libraries have OpenSSL built-in. If you have different version of OpenSSL in your project, consider using CocoaPods or raw sources of CoreLitecoin.
