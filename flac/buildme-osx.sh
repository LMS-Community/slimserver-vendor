#!/bin/sh

OGG=1.3.3
FLAC=1.3.2
OGG_GIT="-bc82844df068429d209e909da47b1f730b53b689"
FLAC_GIT="-452a44777892086892feb8ed7f1156e9b897b5c3"
LOG=$PWD/config.log
CHANGENO=$(git rev-parse --short HEAD)
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
tar -zxf libogg-${OGG}${OGG_GIT}.tar.gz
cd libogg-$OGG
echo "Configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --disable-shared --disable-dependency-tracking >> $LOG
echo "Running make..."
make >> $LOG
cd ..

## Build
echo "Untarring..."
tar zxvf flac-${FLAC}${FLAC_GIT}.tar.gz >> $LOG
cd flac-$FLAC >> $LOG
patch -p1 < ../01-flac.patch >> $LOG
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
