#!/bin/sh

FLAC=1.2.1
SOX=14.2.0
OGG=1.1.3
VORBIS=1.2.0
MAD=0.15.1b
WAVPACK=4.50.1
SAMPLERATE=0.1.4
LOG=$PWD/config.log
CHANGENO=` svn info .  | grep -i Revision | awk -F": " '{print $2}'`
OUTPUT=$PWD/sox-build-$TARGET-$CHANGENO

CPF="-I$PWD/libogg-$OGG/include -I$PWD/libvorbis-$VORBIS/include -I$PWD/wavpack-$WAVPACK/include -I$PWD/flac-$FLAC/include -I$PWD/libmad-$MAD -I$PWD/libsamplerate-$SAMPLERATE/src" 
LDF="-L$PWD/libogg-$OGG/src/.libs -L$PWD/libvorbis-$VORBIS/lib/.libs -L$PWD/wavpack-$WAVPACK/src/.libs -L$PWD/libmad-$MAD/.libs -L$PWD/flac-$FLAC/src/libFLAC/.libs -L$PWD/libsamplerate-$SAMPLERATE/src/.libs"

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
rm -rf sox-$SOX
rm -rf libogg-$OGG
rm -rf libvorbis-$VORBIS
rm -rf libmad-$MAD
rm -rf wavpack-$WAVPACK
rm -rf libsamplerate-$SAMPLERATE

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

## Build Vorbis
echo "Untarring libvorbis-$VORBIS.tar.gz..."
tar -zxf libvorbis-$VORBIS.tar.gz
cd libvorbis-$VORBIS
echo "Configuring..."
./configure --host=$TARGET CFLAGS="$CPF" LDFLAGS="$LDF" --disable-shared >> $LOG
echo "Running make"
make >> $LOG
cd ..

## Build FLAC
echo "Untarring flac-$FLAC.tar.gz..."
tar -zxf flac-$FLAC.tar.gz 
cd flac-$FLAC
echo "Configuring..."
./configure --host=$TARGET --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-shared --disable-xmms-plugin --disable-cpplibs >> $LOG
echo "Running make"
make >> $LOG
cd ..

## Build LibMAD
echo "Untarring libmad-$MAD.tar.gz..."
tar -zxf libmad-$MAD.tar.gz
cd libmad-$MAD
# Remove -fforce-mem line as it doesn't work with newer gcc
sed -i 's/-fforce-mem//' configure
echo "configuring..."
./configure --host=$TARGET --disable-shared >> $LOG
echo "Running make"
make >> $LOG
cd ..

## Build Wavpack
echo "Untarring wavpack-$WAVPACK.tar.bz2..."
tar -jxf wavpack-$WAVPACK.tar.bz2
cd wavpack-$WAVPACK
echo "Configuring..."
./configure --host=$TARGET --disable-shared >> $LOG
echo "Running make"
make >> $LOG
# sox looks for wavpack/wavpack.h so we need to make a symlink
cd include
ln -s . wavpack
cd ../..

## Build libsamplerate
echo "Untarring libsamplerate-$SAMPLERATE.tar.gz"
tar -zxf libsamplerate-$SAMPLERATE.tar.gz
cd libsamplerate-$SAMPLERATE
echo "Configuring..."
./configure --host=$TARGET --disable-shared >> $LOG
echo "Running make"
make >> $LOG
cd ..

## finally, build SOX against FLAC
echo "Untarring sox-$SOX.tar.gz..."
tar -zxf sox-$SOX.tar.gz >> $LOG
cd sox-$SOX >> $LOG
echo "Configuring..."
./configure --host=$TARGET CFLAGS="$CPF" LDFLAGS="$LDF" --with-flac --with-vorbis --with-ogg --with-mad --with-wavpack --with-samplerate --without-id3tag --without-lame --without-ffmpeg --without-png --without-ladspa --disable-shared --disable-oss --disable-alsa --disable-symlinks --disable-libao --disable-coreaudio --without-libltdl --prefix $OUTPUT >> $LOG
echo "Running make"
make  >> $LOG
echo "Running make install"
make install-strip >> $LOG
cd ..

## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf sox-$SOX
rm -rf libogg-$OGG
rm -rf libvorbis-$VORBIS
rm -rf libmad-$MAD
rm -rf wavpack-$WAVPACK
rm -rf libsamplerate-$SAMPLERATE
