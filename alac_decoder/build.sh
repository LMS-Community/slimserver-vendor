#!/bin/sh
MAKEFILE=$1
DEST=$2

make -f $MAKEFILE
cp alac $DEST
