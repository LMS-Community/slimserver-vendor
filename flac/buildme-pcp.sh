#!/bin/sh

#pCP package Dependancies
tce-load -i git compiletc automake gettext-dev

OGG=1.3.3
FLAC=1.3.2
OGG_GIT="-bc82844df068429d209e909da47b1f730b53b689"
FLAC_GIT="-452a44777892086892feb8ed7f1156e9b897b5c3"
LOG=$PWD/config.log
CHANGENO=$(git rev-parse --short HEAD)
ARCH=`arch`
ARCH="pCP"
OUTPUT=$PWD/flac-build-$ARCH-$CHANGENO
CORES=$(grep -c ^processor /proc/cpuinfo)

# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

export CFLAGS="-O2 -pipe -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard"
export CXXFLAGS="-O2 -pipe -fno-exceptions -fno-rtti -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp"

## Build Ogg first
echo "Cloning ligogg....."
[ -d libogg-$OGG ] || git clone --depth 1 https://github.com/xiph/ogg.git libogg-$OGG >> $LOG
cd libogg-$OGG
[ -x configure ] || ./autogen.sh >> $LOG
#. ../../CPAN/update-config.sh
echo "Configuring..."
./configure --disable-shared >> $LOG
echo "Running make..."
make -j $CORES >> $LOG
cd ..

## Build
echo "Cloning FLAC....."
[ -d flac-$FLAC ] || git clone --depth 1 https://github.com/xiph/flac.git flac-$FLAC >> $LOG
cd flac-$FLAC >> $LOG
patch -p1 < ../01-flac.patch
[ -x configure ] || ./autogen.sh >> $LOG
#. ../../CPAN/update-config.sh
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
