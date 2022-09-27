#!/bin/sh

OGG=1.3.5
FLAC=1.4.1
OGG_GIT=""
FLAC_GIT=""
LOG=$PWD/config.log
CHANGENO=$(git rev-parse --short HEAD)
ARCH="osx"
OUTPUT=$PWD/flac-build-$ARCH-$CHANGENO

# Mac Universal Binary support
# CFLAGS="-O2 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -arch x86_64 -mmacosx-version-min=10.12"
CFLAGS="-O2 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -arch arm64 -mmacosx-version-min=11.0"
CXXFLAGS="${CFLAGS}"
# LDFLAGS="-Wl,-syslibroot,/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -arch x86_64 -mmacosx-version-min=10.12"
LDFLAGS="-Wl,-syslibroot,/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk -arch arm64 -mmacosx-version-min=11.0"

# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

## Build Ogg first
echo "Untarring libogg-$OGG.tar.xz..."
tar -jxf libogg-${OGG}${OGG_GIT}.tar.xz
cd libogg-$OGG
echo "Configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --disable-shared --disable-dependency-tracking >> $LOG
echo "Running make..."
make >> $LOG
cd ..

## Build
echo "Untarring..."
tar jxvf flac-${FLAC}${FLAC_GIT}.tar.xz >> $LOG
cd flac-$FLAC >> $LOG
patch -p1 < ../01-flac.patch >> $LOG
patch -p1 < ../02-flac-C-locale.patch >> $LOG
echo "Configuring..."
./configure CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" LDFLAGS="$LDFLAGS" --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-doxygen-docs --disable-shared --disable-xmms-plugin --disable-dependency-tracking --disable-asm-optimizations --disable-cpplibs --prefix $OUTPUT >> $LOG
echo "Running make"
make >> $LOG
echo "Running make install"
make install >> $LOG
cd ..

## Tar the whole package up
cp $OUTPUT/bin/flac .
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf libogg-$OGG
