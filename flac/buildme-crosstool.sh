#!/bin/sh

OGG=1.1.3
FLAC=1.2.1
LOG=$PWD/config.log
CHANGENO=` svn info .  | grep -i Revision | awk -F": " '{print $2}'`
OUTPUT=$PWD/flac-build-$TARGET-$CHANGENO

export PATH=$CROSSBIN:"$PATH"
export CROSS="${CROSSBIN}/${TARGET}-"

# Check if $TARGET and $CROSSBIN were set
if [ "$TARGET" = "" ]; then
	echo "This tool is meant to be run through a cross compiler. Please set TARGET to the architecture you wish to build for."
	exit
fi

if [ "$CROSSBIN" = "" ]; then
	echo "This tool is meant to be run through a cross compiler. Please set CROSSBIN to the locatino of the cross compiler you are
 building with." 
	exit
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
./configure --host=$TARGET --disable-shared >> $LOG
echo "Running make..."
make >> $LOG
cd ..

## Build
echo "Untarring..."
tar zxvf flac-$FLAC.tar.gz >> $LOG
cd flac-$FLAC >> $LOG
patch -p0 < ../sc.patch >> $LOG
patch -p0 < ../triode-ignore-wav-length.patch >> $LOG
echo "Configuring..."
./configure --host=$TARGET --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-doxygen-docs --disable-shared --disable-xmms-plugin --disable-cpplibs --prefix $OUTPUT >> $LOG
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
