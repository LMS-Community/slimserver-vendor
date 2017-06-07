#!/bin/sh

OGG=1.1.3
FLAC=1.2.1
LOG=$PWD/config.log
CHANGENO=`git show -s --format=%h`
ARCH="osx"
OUTPUT=$PWD/flac-build-$ARCH-$CHANGENO

# Mac Universal Binary support
#CFLAGS="-isysroot /Developer/SDKs/MacOSX10.4u.sdk -arch i386 -arch ppc -mmacosx-version-min=10.3"
#LDFLAGS="-arch i386 -arch ppc"
CFLAGS="-arch x86_64"
LDFLAGS="-arch x86_64"

# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

## Build Ogg first
echo "Untarring libogg-$OGG.tar.gz..."
tar -zxf libogg-$OGG.tar.gz
cd libogg-$OGG
echo "Configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --disable-shared --disable-dependency-tracking >> $LOG
echo "Running make..."
make >> $LOG
cd ..

## Build
echo "Untarring..."
tar zxvf flac-$FLAC.tar.gz >> $LOG
cd flac-$FLAC >> $LOG
patch -p0 < ../sc.patch >> $LOG
patch -p0 < ../triode-ignore-wav-length.patch >> $LOG
patch -p0 < ../steven-allow-bad-ssnd-chunk-size.patch >> $LOG
echo "Configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-doxygen-docs --disable-shared --disable-xmms-plugin --disable-dependency-tracking --disable-asm-optimizations --disable-cpplibs --prefix $OUTPUT >> $LOG
echo "Running make"
make >> $LOG
echo "Running make install"
make install >> $LOG
cd ..

## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf libogg-$OGG
