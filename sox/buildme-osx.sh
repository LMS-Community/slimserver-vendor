#!/bin/sh

SOX=14.4.3
FLAC=1.3.2
OGG=1.3.3
OGG_GIT="-bc82844df068429d209e909da47b1f730b53b689"
FLAC_GIT="-452a44777892086892feb8ed7f1156e9b897b5c3"
SOX_GIT="-0be259eaa9ce3f3fa587a3ef0cf2c0b9c73167a2"
VORBIS=1.3.6
MAD=0.15.1b
MAD_SUB="-8"
WAVPACK=5.1.0
LOG=$PWD/config.log
CHANGENO=$(git rev-parse --short HEAD)
ARCH="osx"
OUTPUT=$PWD/sox-build-$ARCH-$CHANGENO

# Mac Universal Binary support
#CFLAGS="-isysroot /Developer/SDKs/MacOSX10.4u.sdk -arch i386 -arch ppc -mmacosx-version-min=10.3"
#LDFLAGS="-arch i386 -arch ppc"
CFLAGS="-mmacosx-version-min=10.6 -arch x86_64"
LDFLAGS="-mmacosx-version-min=10.6 -arch x86_64"

# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf sox-$SOX
rm -rf libogg-$OGG
rm -rf libvorbis-$VORBIS
rm -rf libmad-$MAD
rm -rf wavpack-$WAVPACK

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

## Build Ogg first
echo "Untarring libogg-$OGG.tar.gz..."
tar -zxf libogg-${OGG}${OGG_GIT}.tar.gz 
cd libogg-$OGG
echo "Configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --disable-shared --disable-dependency-tracking >> $LOG
echo "Running make..."
make >> $LOG
cd ..

## Build Vorbis
echo "Untarring libvorbis-$VORBIS.tar.gz..."
tar -zxf libvorbis-$VORBIS.tar.gz
cd libvorbis-$VORBIS
echo "Configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs --disable-shared --disable-dependency-tracking >> $LOG
echo "Running make"
make >> $LOG
cd ..

## Build FLAC
# Mac: Disabled ASM code
echo "Untarring flac-$FLAC.tar.gz..."
tar zxf flac-${FLAC}${FLAC_GIT}.tar.gz >> $LOG
cd flac-$FLAC
echo "Configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-shared --disable-xmms-plugin --disable-dependency-tracking --disable-cpplibs >> $LOG
echo "Running make"
make >> $LOG
cd ..

## Build LibMAD
echo "Untarring libmad-$MAD.tar.gz..."
tar -zxf libmad-${MAD}${MAD_SUB}.tar.gz
cd libmad-$MAD
echo "configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --disable-shared --disable-dependency-tracking --enable-fpm=64bit >> $LOG
echo "Running make"
make >> $LOG
cd ..

## Build Wavpack
echo "Untarring wavpack-$WAVPACK.tar.bz2..."
tar -jxf wavpack-$WAVPACK.tar.bz2
cd wavpack-$WAVPACK
echo "Configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --disable-shared --disable-dependency-tracking --with-iconv=no --disable-apps >> $LOG
echo "Running make"
make >> $LOG
# sox looks for wavpack/wavpack.h so we need to make a symlink
cd include
ln -s . wavpack
cd ../..

## finally, build SOX against FLAC
echo "Untarring sox-$SOX.tar.gz..."
tar -zxf sox-${SOX}${SOX_GIT}.tar.gz >> $LOG
cd sox-$SOX >> $LOG
patch -p1 < ../02-restore-short-options.patch
patch -p1 < ../03-version.patch
echo "Configuring..."
CPF="-I$PWD/../libogg-$OGG/include -I$PWD/../libvorbis-$VORBIS/include -I$PWD/../wavpack-$WAVPACK/include -I$PWD/../flac-$FLAC/include -I$PWD/../libmad-$MAD"
LDF="-L$PWD/../libogg-$OGG/src/.libs -L$PWD/../libvorbis-$VORBIS/lib/.libs -L$PWD/../wavpack-$WAVPACK/src/.libs -L$PWD/../libmad-$MAD/.libs -L$PWD/../flac-$FLAC/src/libFLAC/.libs"
./configure CFLAGS="$CFLAGS $CPF" LDFLAGS="$CFLAGS $LDF" --without-ao --without-pulseaudio --disable-openmp --with-flac --with-oggvorbis --with-mp3 --with-wavpack --without-id3tag --without-lame --without-png --without-ladspa --disable-shared --without-oss --without-alsa --disable-symlinks --without-coreaudio --disable-dependency-tracking --prefix $OUTPUT >> $LOG
echo "Running make"
make  >> $LOG
echo "Running make install"
make install >> $LOG
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
