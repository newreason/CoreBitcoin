#!/bin/sh

# Cleanup to start with a blank slate

rm -rf build
mkdir -p build

xcodebuild clean

# Update all headers to produce up-to-date combined headers.

./update_headers.rb

# Build iOS static libraries for simulator and for devices

xcodebuild -project CoreLitecoin.xcodeproj -target CoreLitecoinIOSlib -configuration Release -sdk iphonesimulator
mv build/libCoreLitecoinIOS.a build/libCoreLitecoinIOS-simulator.a

xcodebuild -project CoreLitecoin.xcodeproj -target CoreLitecoinIOSlib -configuration Release -sdk iphoneos
mv build/libCoreLitecoinIOS.a build/libCoreLitecoinIOS-device.a

# Merge simulator and device libs into one

lipo build/libCoreLitecoinIOS-device.a build/libCoreLitecoinIOS-simulator.a -create -output build/libCoreLitecoinIOS.a
rm build/libCoreLitecoinIOS-simulator.a
rm build/libCoreLitecoinIOS-device.a

# Build the iOS frameworks for simulator and for devices

rm -f build/CoreLitecoinIOS*.framework

xcodebuild -project CoreLitecoin.xcodeproj -target CoreLitecoinIOS -configuration Release -sdk iphonesimulator
mv build/CoreLitecoinIOS.framework build/CoreLitecoinIOS-simulator.framework

xcodebuild -project CoreLitecoin.xcodeproj -target CoreLitecoinIOS -configuration Release -sdk iphoneos

# Merge the libraries inside the frameworks

mv build/CoreLitecoinIOS-simulator.framework/CoreLitecoinIOS build/CoreLitecoinIOS.framework/CoreLitecoinIOS-simulator
mv build/CoreLitecoinIOS.framework/CoreLitecoinIOS build/CoreLitecoinIOS.framework/CoreLitecoinIOS-device

lipo build/CoreLitecoinIOS.framework/CoreLitecoinIOS-simulator build/CoreLitecoinIOS.framework/CoreLitecoinIOS-device \
		-create -output build/CoreLitecoinIOS.framework/CoreLitecoinIOS
		
# Update openssl includes to match framework header search path

./postprocess_openssl_includes_in_framework.rb build/CoreLitecoinIOS.framework

# Delete the intermediate files
		
rm build/CoreLitecoinIOS.framework/CoreLitecoinIOS-device
rm build/CoreLitecoinIOS.framework/CoreLitecoinIOS-simulator
rm -rf build/CoreLitecoinIOS-simulator.framework

# Build for OS X

xcodebuild -project CoreLitecoin.xcodeproj -target CoreLitecoinOSXlib -configuration Release
xcodebuild -project CoreLitecoin.xcodeproj -target CoreLitecoinOSX    -configuration Release

# Update openssl includes to match framework header search path

./postprocess_openssl_includes_in_framework.rb build/CoreLitecoinOSX.framework

# Clean up

rm -rf build/CoreLitecoin.build


# At this point all the libraries and frameworks are built and placed in the ./build 
# directory with names ending with -IOS and -OSX indicating their architectures. The 
# rest of the script renames them to have the same name without these suffixes. 

# If you build your project in a way that you would rather have the names differ, you 
# can uncomment the next line and stop the build process here.

#exit


# Moving the result to a separate location

BINARIES_TARGETDIR="binaries"

rm -rf ${BINARIES_TARGETDIR}

mkdir ${BINARIES_TARGETDIR}
mkdir ${BINARIES_TARGETDIR}/OSX
mkdir ${BINARIES_TARGETDIR}/iOS

# Move and rename the frameworks
mv build/CoreLitecoinOSX.framework ${BINARIES_TARGETDIR}/OSX/CoreLitecoin.framework
mv ${BINARIES_TARGETDIR}/OSX/CoreLitecoin.framework/CoreLitecoinOSX ${BINARIES_TARGETDIR}/OSX/CoreLitecoin.framework/CoreLitecoin

mv build/CoreLitecoinIOS.framework ${BINARIES_TARGETDIR}/iOS/CoreLitecoin.framework
mv ${BINARIES_TARGETDIR}/iOS/CoreLitecoin.framework/CoreLitecoinIOS ${BINARIES_TARGETDIR}/iOS/CoreLitecoin.framework/CoreLitecoin

# Move and rename the static libraries
mv build/libCoreLitecoinIOS.a ${BINARIES_TARGETDIR}/iOS/libCoreLitecoin.a
mv build/libCoreLitecoinOSX.a ${BINARIES_TARGETDIR}/OSX/libCoreLitecoin.a

# Move the headers
mv build/include ${BINARIES_TARGETDIR}/include

# Clean up
rm -rf build

# Remove +Tests.h headers from libraries and frameworks.
find ${BINARIES_TARGETDIR} -name '*+Tests.h' -print0 | xargs -0 rm


