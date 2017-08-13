#!/bin/sh

FLAC=1.2.1
SOX=14.3.1
OGG=1.1.4
VORBIS=1.2.3
MAD=0.15.1b
WAVPACK=4.60.1
LOG=$PWD/config.log
CHANGENO=`git rev-parse --short HEAD`
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
rm -rf libmad-$MAD
rm -rf wavpack-$WAVPACK

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

## Build Vorbis
echo "Untarring libvorbis-$VORBIS.tar.gz..."
tar -zxf libvorbis-$VORBIS.tar.gz
cd libvorbis-$VORBIS
patch -p0 < ../patch/libvorbis_configure.ac.patch
patch -p0 < ../patch/libvorbis_autogen.sh.patch
autoreconf -fi
sh autogen.sh
echo "Configuring..."
CC=$CC CXX=$CXX ./configure --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs --disable-shared >> $LOG
echo "Running make"
gmake >> $LOG
cd ..

## Build FLAC
echo "Untarring flac-$FLAC.tar.gz..."
tar -zxf flac-$FLAC.tar.gz 
cd flac-$FLAC
patch -p0 < ../patch/flac_configure.in.patch
autoreconf -fi
sh autogen.sh
echo "Configuring..."
CC=$CC CXX=$CXX ./configure --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-shared --disable-xmms-plugin --disable-cpplibs >> $LOG
echo "Running make"
gmake >> $LOG
cd ..

## Build LibMAD
echo "Untarring libmad-$MAD.tar.gz..."
tar -zxf libmad-$MAD.tar.gz
cd libmad-$MAD
# Remove -fforce-mem line as it doesn't work with newer gcc
patch -p0 < ../patch/libmad_configure.ac.patch
autoreconf -fi
sh autogen.sh 
echo "configuring..."
CC=$CC CXX=$CXX ./configure --disable-shared >> $LOG
echo "Running make"
gmake >> $LOG
cd ..

## Build Wavpack
echo "Untarring wavpack-$WAVPACK.tar.bz2..."
tar -jxf wavpack-$WAVPACK.tar.bz2
cd wavpack-$WAVPACK
echo "Configuring..."
CC=$CC CXX=$CXX ./configure --disable-shared >> $LOG
echo "Running make"
gmake >> $LOG
# sox looks for wavpack/wavpack.h so we need to make a symlink
cd include
ln -s . wavpack
cd ../..

## finally, build SOX against FLAC
echo "Untarring sox-$SOX.tar.gz..."
tar -zxf sox-$SOX.tar.gz >> $LOG
cd sox-$SOX >> $LOG
echo "Configuring..."
CC=$CC CXX=$CXX \
CPF="-I$PWD/../libogg-$OGG/include -I$PWD/../libvorbis-$VORBIS/include -I$PWD/../wavpack-$WAVPACK/include -I$PWD/../flac-$FLAC/include -I$PWD/../libmad-$MAD" 
LDF="-L$PWD/../libogg-$OGG/src/.libs -L$PWD/../libvorbis-$VORBIS/lib/.libs -L$PWD/../wavpack-$WAVPACK/src/.libs -L$PWD/../libmad-$MAD/.libs -L$PWD/../flac-$FLAC/src/libFLAC/.libs"
./configure CFLAGS="$CPF" LDFLAGS="$LDF" --with-pulseaudio=no --with-flac --with-oggvorbis --with-mp3 --with-wavpack --without-id3tag --without-lame --without-ffmpeg --without-png --without-ladspa --disable-shared --without-oss --without-alsa --disable-symlinks --without-coreaudio --prefix $OUTPUT >> $LOG
echo "Running make"
gmake  >> $LOG
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
