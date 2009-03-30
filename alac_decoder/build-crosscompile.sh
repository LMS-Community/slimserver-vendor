#!/bin/sh
LOG=$PWD/config.log
CHANGENO=` svn info .  | grep -i Revision | awk -F": " '{print $2}'`
OUTPUT=$PWD/alac-$TARGET-$CHANGENO

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

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

## Build
echo "Configuring..."
export CC=$CROSSBIN/$TARGET-gcc
make clean
make -f Makefile.crosstool >> $LOG

## display the log, just so that parabuild can parse it
cat $LOG

## Tar the whole package up
tar -zcvf $OUTPUT.tgz alac
rm -rf alac
