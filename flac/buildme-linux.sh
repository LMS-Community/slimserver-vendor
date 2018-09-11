#!/bin/sh

OGG=1.3.3
FLAC=1.3.2
OGG_GIT="-bc82844df068429d209e909da47b1f730b53b689"
FLAC_GIT="-faafa4c82c31e5aed7bc7c0e87a379825372c6ac"
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

## Build Ogg first
echo "Untarring libogg-$OGG.tar.gz..."
tar -zxf libogg-${OGG}${OGG_GIT}.tar.gz
cd libogg-$OGG
. ../../CPAN/update-config.sh
echo "Configuring..."
./configure --disable-shared >> $LOG
echo "Running make..."
make -j $CORES >> $LOG
cd ..

## Build
echo "Untarring..."
tar zxvf flac-${FLAC}${FLAC_GIT}.tar.gz >> $LOG
cd flac-$FLAC >> $LOG
. ../../CPAN/update-config.sh
patch -p1 < ../01-flac.patch >> $LOG
echo "Configuring..."
./configure --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-doxygen-docs --disable-shared --disable-xmms-plugin --disable-cpplibs --prefix $OUTPUT >> $LOG
echo "Running make"
make -j $CORES >> $LOG
echo "Running make install"
make install >> $LOG
cd ..

strip --strip-unneeded $OUTPUT/bin/*

## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf libogg-$OGG
