#!/bin/sh

OGG=1.1.3
FLAC=1.2.1
LOG=$PWD/config.log
ARCH=`uname -m`
CHANGENO=`git rev-parse --short HEAD`
OUTPUT=$PWD/flac-build-$ARCH-$CHANGENO

if [ -f "/etc/make.conf" ]; then
    CC=`grep CC /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CC=##g'`
    CXX=`grep CXX /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CXX=##g'`
fi

if [ -z CC ]; then
    CC=cc
fi

if [ -z $CXX ]; then
    CXX=c++
fi


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
CC=$CC CXX=$CXX ./configure --disable-shared >> $LOG
echo "Running make..."
gmake >> $LOG
cd ..

## Build
echo "Untarring..."
tar zxvf flac-$FLAC.tar.gz >> $LOG
cd flac-$FLAC >> $LOG
patch -p0 < ../sc.patch >> $LOG
patch -p0 < ../triode-ignore-wav-length.patch >> $LOG
patch -p0 < ../steven-allow-bad-ssnd-chunk-size.patch >> $LOG
patch -p0 < ../flac_configure.in.patch >> $LOG
mv configure.in configure.ac
autoreconf -fi
./autogen.sh
CC=$CC CXX=$CXX \
./configure --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-doxygen-docs --disable-oggtest --disable-shared --disable-xmms-plugin --disable-cpplibs --prefix $OUTPUT >> $LOG
echo "Running make"
gmake >> $LOG
echo "Running make install"
gmake install >> $LOG
cd ..

## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf libogg-$OGG
