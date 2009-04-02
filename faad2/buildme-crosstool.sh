#!/bin/sh
FAAD=2.7
LOG=$PWD/config.log
CHANGENO=` svn info .  | grep -i Revision | awk -F": " '{print $2}'`
OUTPUT=$PWD/faad2-build-$TARGET-$CHANGENO

export PATH=$CROSSBIN:"$PATH"
export CROSS="${CROSSBIN}/${TARGET}-"

# Check if $TARGET and $CROSSBIN were set
if [ "$TARGET" = "" ]; then
	echo "This tool is meant to be run through a cross compiler. Please set TARGET to the architecture you wish to build for."
	exit
fi

if [ "$CROSSBIN" = "" ]; then
	echo "This tool is meant to be run through a cross compiler. Please set CROSSBIN to the locatino of the cross compiler you are building with." 
	exit
fi

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
CFLAGS=-DFIXED_POINT ./configure --host=$TARGET --without-xmms --without-drm --without-mpeg4ip --disable-shared --prefix $OUTPUT >> $LOG
# Fix libfaad Makefile to not use -iquote
sed -i 's/-iquote/-I/' libfaad/Makefile
echo "Running make"
make frontend >> $LOG
echo "Running make install"
make install-strip >> $LOG
cd ..

## display the log, just so that parabuild can parse it
cat $LOG

## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf faad2-$FAAD
