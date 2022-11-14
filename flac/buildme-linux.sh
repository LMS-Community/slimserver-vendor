#!/bin/sh

OGG=1.3.5
FLAC=1.4.1
OGG_GIT=""
FLAC_GIT=""
LOG=$PWD/config.log
CHANGENO=$(git rev-parse --short HEAD)
ARCH=`arch`
OUTPUT=$PWD/flac-build-$ARCH-$CHANGENO
CORES=$(grep -c ^processor /proc/cpuinfo)

# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

# '-O2' reduces binary size with minimal performance loss.
export CFLAGS="-O2"
export CXXFLAGS="-O2"

## Build Ogg first
echo "Untarring libogg-$OGG.tar.gz..."
tar -Jxf libogg-${OGG}${OGG_GIT}.tar.xz
cd libogg-$OGG
. ../../CPAN/update-config.sh
echo "Configuring..."
./configure --disable-shared >> $LOG
echo "Running make..."
make -j $CORES >> $LOG
cd ..

## Build
echo "Untarring..."
tar Jxvf flac-${FLAC}${FLAC_GIT}.tar.xz >> $LOG
cd flac-$FLAC >> $LOG
. ../../CPAN/update-config.sh
patch -p1 < ../01-flac.patch >> $LOG
patch -p1 < ../02-flac-C-locale.patch >> $LOG
echo "Configuring..."
./configure --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-doxygen-docs --disable-shared --disable-xmms-plugin --disable-cpplibs --prefix $OUTPUT >> $LOG
echo "Running make"
make -j $CORES >> $LOG
echo "Running make install"
make install >> $LOG
cd ..

strip --strip-unneeded $OUTPUT/bin/*

## Tar the whole package up
cp $OUTPUT/bin/flac .
tar -zcf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf libogg-$OGG
