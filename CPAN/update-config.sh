#!/bin/sh
# Make sure configure can identify the build host: config.guess/config.sub in
# older tarballs predate e.g. aarch64. Prefer the tarball's own copies, then
# CPAN/config, and only then a download from gnu.org (unreliable, see #118).

# $1 = config.guess, $2 = config.sub: can they identify this host?
uc_works() {
    uc_triplet=`sh "$1" 2>/dev/null` && sh "$2" "$uc_triplet" >/dev/null 2>&1
}

if [ -f ./config.guess ] && ! uc_works ./config.guess ./config.sub; then
    # we're sourced from various depths, so look upwards for the CPAN dir
    uc_dir=`pwd`
    until [ -f "$uc_dir/update-config.sh" ] || [ -f "$uc_dir/CPAN/update-config.sh" ] || [ "$uc_dir" = / ]; do
        uc_dir=`dirname "$uc_dir"`
    done
    uc_src=$uc_dir/config
    [ -d "$uc_src" ] || uc_src=$uc_dir/CPAN/config

    if ! uc_works "$uc_src/config.guess" "$uc_src/config.sub"; then
        echo "config.guess/config.sub don't recognise this platform, downloading current versions"
        uc_tmp=${uc_tmp:-`mktemp -d`}
        uc_src=$uc_tmp
        for uc_f in config.guess config.sub; do
            [ -s "$uc_src/$uc_f" ] && continue
            uc_url="https://gitweb.git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=$uc_f;hb=HEAD"
            if command -v wget >/dev/null 2>&1; then
                wget -O "$uc_src/$uc_f" "$uc_url"
            else
                curl -fsSL -o "$uc_src/$uc_f" "$uc_url"
            fi || rm -f "$uc_src/$uc_f"
        done
        uc_works "$uc_src/config.guess" "$uc_src/config.sub" || {
            echo "ERROR: no working config.guess/config.sub for this platform"
            exit 1
        }
    fi
    cp -vf "$uc_src/config.guess" "$uc_src/config.sub" .
fi
