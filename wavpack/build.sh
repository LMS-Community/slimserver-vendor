#!/usr/local/bin/bash
#
# $Id $

OS=`uname`

# Build dir
BUILD=$PWD/build

FLAGS=""
# Mac-specific flags (must be built on Leopard)
if [ $OS = "Darwin" ]; then
#    FLAGS="-arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.3"
    FLAGS="-arch x86_64"
elif [ $OS = "FreeBSD" ]; then
    # needed to find iconv
    FLAGS="-I/usr/local/include -L/usr/local/lib"
fi

# FreeBSD's make sucks
if [ $OS = "FreeBSD" ]; then
    if [ !-x /usr/local/bin/gmake ]; then
        echo "ERROR: Please install GNU make (gmake)"
        exit
    fi
    export GNUMAKE=/usr/local/bin/gmake
    export MAKE=/usr/local/bin/gmake
else
    export MAKE=/usr/bin/make
fi

# Clean up
# XXX command-line flag to skip cleanup
rm -rf $BUILD

mkdir $BUILD

# Build wavpack
tar jxvf wavpack-4.50.1.tar.bz2
cd wavpack-4.50.1
CFLAGS="$FLAGS" \
LDFLAGS="$FLAGS" \
    ./configure --prefix=$BUILD \
    --disable-dependency-tracking \
    --disable-shared
make
if [ $? != 0 ]; then
    echo "make failed"
    exit $?
fi
make install
cd ..
rm -rf wavpack-4.50.1

cp $BUILD/bin/wvunpack .
rm -rf $BUILD

if [ $OS = 'Darwin' ]; then
    strip -S wvunpack
elif [ $OS = 'Linux' -o $OS = "FreeBSD" ]; then
    strip wvunpack
fi
