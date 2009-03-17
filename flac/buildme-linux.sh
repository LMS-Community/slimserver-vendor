#!/bin/sh

FLAC=1.2.1
LOG=$PWD/config.log
CHANGENO=` svn info .  | grep -i Revision | awk -F": " '{print $2}'`
ARCH=`arch`
OUTPUT=$PWD/flac-build-$ARCH-$CHANGENO

# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

## Build
echo "Untarring..."
tar zxvf flac-$FLAC.tar.gz >> $LOG
cd flac-$FLAC >> $LOG
patch -p0 < ../sc.patch >> $LOG
patch -p0 < ../triode-ignore-wav-length.patch >> $LOG
echo "Configuring..."
./configure --disable-doxygen-docs --disable-shared --disable-xmms-plugin --disable-cpplibs --disable-ogg --disable-oggtest --prefix $OUTPUT >> $LOG
echo "Running make"
make >> $LOG
echo "Running make install"
make install >> $LOG
cd ..

## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
