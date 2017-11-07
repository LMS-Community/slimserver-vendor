#!/bin/sh
if [ "`uname -m`" = "aarch64" -a "`uname`" = "Linux"  ]; then
    [ -f /tmp/config.guess.$$ ] || wget -O /tmp/config.guess.$$ 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
    [ -f /tmp/config.sub.$$ ] || wget -O /tmp/config.sub.$$ 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'
    cp -vf /tmp/config.guess.$$ ./config.guess
    cp -vf /tmp/config.sub.$$ ./config.sub
fi
