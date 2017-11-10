#!/bin/sh


ARCH=`uname -m`
CHANGENO=`git rev-parse --short HEAD`
OUTPUT=$PWD/shineenc-build-$ARCH-$CHANGENO

# Clean up
echo "Clean up the last run..."
rm -rf $OUTPUT
gmake -f Makefile.freebsd clean

if [ -f "/etc/make.conf" ]; then
    CC=`grep CC /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CC=##g'`
    CXX=`grep CXX /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CXX=##g'`
fi

if [ -z $CC ]; then
    CC=cc
fi

if [ -z $CXX ]; then
    CXX=c++
fi

COMPY=`cc --version`
echo  "Looks like your compiler is $CC"
echo "... and it has the following properties:"
echo "$COMPY"
echo "Running gmake..."
gmake -f Makefile.freebsd --eval=CC=$CC --eval=CXX=$CXX default release cleanobj

mkdir -p $OUTPUT
cp *.la $OUTPUT/ 
cp *.so* $OUTPUT/
cp shineenc $OUTPUT/

gmake -f Makefile.freebsd clean

