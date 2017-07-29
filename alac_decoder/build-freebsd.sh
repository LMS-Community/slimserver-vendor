#!/bin/sh
MAKEFILE=$1
DEST=$2

gmake -f $MAKEFILE
cp alac $DEST
