#!/bin/sh

SOX=14.4.3
OGG=1.3.3
FLAC=1.3.2
OGG_GIT="-bc82844df068429d209e909da47b1f730b53b689"
FLAC_GIT="-faafa4c82c31e5aed7bc7c0e87a379825372c6ac"
SOX_GIT="-0be259eaa9ce3f3fa587a3ef0cf2c0b9c73167a2"
VORBIS=1.3.6
OPUS=1.2.1
OPUSFILE=0.11
MAD=0.15.1b
MAD_SUB="-8"
WAVPACK=5.1.0
LOG=$PWD/config.log
CHANGENO=$(git rev-parse --short HEAD)
ARCH=`uname -m`
OUTPUT=$PWD/sox-build-$ARCH-$CHANGENO

if [ -z ${CC} ] && [ -f "/etc/make.conf" ]; then
    CC=`grep CC /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CC=##g'`
    CXX=`grep CXX /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CXX=##g'`
fi

if [ -z $CC ]; then
    CC=cc
fi

if [ -z $CXX ]; then
    CXX=c++
fi

echo "Looks like your compiler is $CC"
$CC --version

# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf sox-$SOX
rm -rf libogg-$OGG
rm -rf libvorbis-$VORBIS
rm -rf opus-$OPUS
rm -rf opusfile-$OPUSFILE
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
CC=$CC CXX=$CXX ./configure --disable-shared >> $LOG
echo "Running make..."
gmake -j $CORES >> $LOG
cd ..

## Build Vorbis
echo "Untarring libvorbis-$VORBIS.tar.gz..."
tar -zxf libvorbis-$VORBIS.tar.gz
cd libvorbis-$VORBIS
echo "Configuring..."
CC=$CC CXX=$CXX ./configure --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs --disable-shared >> $LOG
echo "Running make"
gmake -j $CORES >> $LOG
cd ..

## Build Opus
echo "Untarring opus-$OPUS.tar.gz..."
tar -zxf opus-$OPUS.tar.gz
cd opus-$OPUS
echo "Configuring..."
./configure --disable-extra-programs --enable-shared=no >> $LOG
echo "Running make"
gmake -j $CORES >> $LOG
cd ..

## Build Opusfile
echo "Untarring opusfile-$OPUSFILE.tar.gz..."
tar -zxf opusfile-$OPUSFILE.tar.gz
cd opusfile-$OPUSFILE
echo "Configuring..."
CPF="-I$PWD/../libogg-$OGG/include -I$PWD/../opus-$OPUS/include"
LDF="-L$PWD/../libogg-$OGG/src/.libs -L$PWD/../opus-$OPUS/.libs"
./configure DEPS_CFLAGS="$CPF" DEPS_LIBS="$LDF" --enable-shared=no --disable-examples --disable-doc >> $LOG
echo "Running make"
gmake -j $CORES >> $LOG
cd ..

## Build FLAC
echo "Untarring flac-$FLAC.tar.gz..."
tar zxf flac-${FLAC}${FLAC_GIT}.tar.gz >> $LOG
cd flac-$FLAC
patch -p1 < ../01-flac.patch >> $LOG
echo "Configuring..."
CC=$CC CXX=$CXX ./configure --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-shared --disable-xmms-plugin --disable-cpplibs >> $LOG
echo "Running make"
gmake -j $CORES >> $LOG
cd ..

## Build LibMAD
echo "Untarring libmad-$MAD.tar.gz..."
tar -zxf libmad-$MAD${MAD_SUB}.tar.gz
cd libmad-$MAD
echo "configuring..."
CC=$CC CXX=$CXX ./configure --disable-shared >> $LOG
echo "Running make"
gmake -j $CORES >> $LOG
cd ..

## Build Wavpack
echo "Untarring wavpack-$WAVPACK.tar.bz2..."
tar -jxf wavpack-$WAVPACK.tar.bz2
cd wavpack-$WAVPACK
echo "Configuring..."
CC=$CC CXX=$CXX ./configure --disable-shared --with-iconv=no --disable-apps >> $LOG
echo "Running make"
gmake -j $CORES >> $LOG
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
CC=$CC CXX=$CXX \
CPF="-I$PWD/../libogg-$OGG/include -I$PWD/../libvorbis-$VORBIS/include -I$PWD/../opus-$OPUS/include -I$PWD/../wavpack-$WAVPACK/include -I$PWD/../flac-$FLAC/include -I$PWD/../libmad-$MAD"
LDF="-L$PWD/../libogg-$OGG/src/.libs -L$PWD/../libvorbis-$VORBIS/lib/.libs -L$PWD/../opus-$OPUS/.libs -L$PWD/../wavpack-$WAVPACK/src/.libs -L$PWD/../libmad-$MAD/.libs -L$PWD/../flac-$FLAC/src/libFLAC/.libs"
./configure CFLAGS="$CPF" LDFLAGS="$LDF" OPUS_CFLAGS="-I$PWD/../opusfile-$OPUSFILE/include" OPUS_LIBS="-L$PWD/../opusfile-$OPUSFILE/.libs -lopusfile -lopus" --without-ao --without-pulseaudio --disable-openmp --with-flac --with-oggvorbis --with-opus --with-mp3 --with-wavpack --without-id3tag --without-lame --without-png --without-ladspa --disable-shared --without-oss --without-alsa --disable-symlinks --without-coreaudio --prefix $OUTPUT >> $LOG
echo "Running make"
gmake -j $CORES >> $LOG
echo "Running make install"
make install >> $LOG
cd ..

## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf sox-$SOX
rm -rf opus-$OPUS
rm -rf opusfile-$OPUSFILE
rm -rf libogg-$OGG
rm -rf libvorbis-$VORBIS
rm -rf libmad-$MAD
rm -rf wavpack-$WAVPACK
