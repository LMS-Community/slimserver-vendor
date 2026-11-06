#!/bin/sh
# Make sure the config.guess/config.sub bundled with a tarball can identify the
# build host. Old copies don't know about newer platforms (e.g. aarch64), which
# makes configure fail with "invalid value of canonical build".
#
# Only if the bundled copies fail do we try to fetch current versions from
# gnu.org - and only replace them if the download actually succeeded. A failed
# wget leaves an empty file behind, and copying that over a working script is
# worse than leaving the old one in place.

if [ -f ./config.guess ] && [ -f ./config.sub ] \
    && build_triplet=`sh ./config.guess 2>/dev/null` \
    && sh ./config.sub "$build_triplet" >/dev/null 2>&1; then
    : # bundled config.guess/config.sub are fine, nothing to do
else
    echo "Bundled config.guess/config.sub don't recognise this platform, fetching current versions"
    for f in config.guess config.sub; do
        if [ ! -s /tmp/$f.$$ ]; then
            url="https://gitweb.git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=$f;hb=HEAD"
            if command -v wget >/dev/null 2>&1; then
                wget -O /tmp/$f.$$ "$url" || rm -f /tmp/$f.$$
            else
                curl -fsSL -o /tmp/$f.$$ "$url" || rm -f /tmp/$f.$$
            fi
        fi
        if [ -s /tmp/$f.$$ ]; then
            cp -vf /tmp/$f.$$ ./$f
        else
            echo "WARNING: could not download $f - keeping the bundled copy"
        fi
    done
fi
