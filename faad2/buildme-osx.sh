#!/bin/sh

FAAD=2.7
LOG=$PWD/config.log
CHANGENO=` svn info .  | grep -i Revision | awk -F": " '{print $2}'`

# Build Intel half first
echo "Building Intel binary..."
ARCH=i386

# Mac Universal Binary support
CFLAGS="-isysroot /Developer/SDKs/MacOSX10.4u.sdk -arch $ARCH -mmacosx-version-min=10.3"
LDFLAGS="-arch $ARCH"

# Clean up
rm -rf faad2-$FAAD faad-i386 faad-ppc

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

## Build
echo "Untarring..."
tar zxvf faad2-$FAAD.tar.gz >> $LOG
cd faad2-$FAAD >> $LOG
patch -p1 < ../sbs.patch >> $LOG
echo "Configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --without-xmms --without-drm --without-mpeg4ip --disable-shared --disable-dependency-tracking >> $LOG
echo "Running make"
make >> $LOG
cd ..

# Copy faad binary out
cp faad2-$FAAD/frontend/faad faad-$ARCH

rm -rf faad2-$FAAD

# Build PPC half
echo "Building PPC binary..."
ARCH=ppc

# Mac Universal Binary support
CFLAGS="-isysroot /Developer/SDKs/MacOSX10.4u.sdk -arch $ARCH -mmacosx-version-min=10.3"
LDFLAGS="-arch $ARCH"

## Build
echo "Untarring..."
tar zxvf faad2-$FAAD.tar.gz >> $LOG
cd faad2-$FAAD >> $LOG
patch -p1 < ../sbs.patch >> $LOG
echo "Configuring..."
./configure CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" --without-xmms --without-drm --without-mpeg4ip --disable-shared --disable-dependency-tracking >> $LOG
echo "Running make"
make >> $LOG
cd ..

# Copy faad binary out
cp faad2-$FAAD/frontend/faad faad-$ARCH

rm -rf faad2-$FAAD

# Combine them
lipo -create faad-i386 faad-ppc -output faad
rm -f faad-i386 faad-ppc
strip faad
