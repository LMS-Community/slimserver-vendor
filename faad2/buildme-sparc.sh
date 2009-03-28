#!/bin/sh
TARGET="sparc-unknown-linux-gnu"
FAAD=2.7
LOG=$PWD/config.log
CHANGENO=` svn info .  | grep -i Revision | awk -F": " '{print $2}'`
OUTPUT=$PWD/faad2-build-$TARGET-$CHANGENO

export CROSSBIN="/opt/crosstool/gcc-3.3.6-glibc-2.3.2/sparc-unknown-linux-gnu/bin"
export PATH=$CROSSBIN:"$PATH"
export CROSS="${CROSSBIN}/${TARGET}-"


# Clean up
rm -rf $OUTPUT
rm -rf faad2-$FAAD

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

## Build
echo "Untarring..."
tar zxvf faad2-$FAAD.tar.gz >> $LOG
cd faad2-$FAAD >> $LOG
patch -p0 < ../sc.patch >> $LOG
patch -p0 < ../bpa-stdin.patch >> $LOG
echo "Configuring..."
./configure --host=sparc-unknown-linux-gnu --without-xmms --without-drm --without-mpeg4ip --disable-shared --prefix $OUTPUT >> $LOG
# Fix libfaad Makefile to not use -iquote
sed -i 's/-iquote/-I/' libfaad/Makefile
echo "Running make"
make frontend >> $LOG
echo "Running make install"
make install >> $LOG
cd ..

## display the log, just so that parabuild can parse it
cat $LOG

## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf faad2-$FAAD
