#!/usr/bin/env bash
#
# $Id$
#
# Filename: buildme.sh
# Description:
# 	This script builds all binary Perl modules required by Squeezebox Server.
#       It first parses the input values for any custom parameters. Then it checks
#       to ensure all necessary prerequites are present on the the system. It then
#	makes the targets specified (or all).
#	See the README.md for supported OSes and build notes/preparations.
#
# Arguments:
#    lmsbase    Optional string containing the path to the desired installation
#               directory. The default location is within the build/arch directory,
#               but this parameter may be used to place the Perl modules directly
#               within an existing Logitech Media Server installation folder.
#
#    jobs       Optional integer to be passed through to make. The default is
#               one, for safety. Increasing this value can speed builds.
#
#    perlbin    Optional string containing the location to a custom Perl binary.
#               This overrides default behavior of searching the PATH for Perl.
#
# Parameter:
#    target	Optional string containing desired Perl module, (e.g., Media::Scan)
#		The default behavior is to build all necessary modules based on
#		the OS and Perl version.
#
################################################################################
# Initial values prior to argument parsing
# Require modules to pass tests
RUN_TESTS=1
USE_HINTS=1
CLEAN=1
NUM_MAKE_JOBS=1

function usage {
    cat <<EOF
$0 [args] [target]
-h            this help
-c            do not run make clean
-i <lmsbase>  install modules in lmsbase directory
-j <jobs>     set number of processes for make (default: 1)
-p <perlbin > set custom perl binary (other than one in PATH)
-t            do not run tests

target: make target - if not specified all will be built

EOF
}

while getopts hci:j:p:t opt; do
  case $opt in
  c)
      CLEAN=0
      ;;
  i)
      LMSBASEDIR=$OPTARG
      ;;
  j)
      NUM_MAKE_JOBS=$OPTARG
      ;;
  p)
      CUSTOM_PERL=$OPTARG
      ;;
  t)
      RUN_TESTS=0
      ;;
  h)
      usage
      exit
      ;;
  *)
      echo "invalid argument"
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

echo "RUN_TESTS:$RUN_TESTS CLEAN:$CLEAN USE_HINTS:$USE_HINTS target ${1-all}"

OS=`uname`
MACHINE=`uname -m`

if [ "$OS" != "Linux" -a "$OS" != "Darwin" -a "$OS" != "FreeBSD" -a "$OS" != "SunOS" ]; then
    echo "Unsupported platform: $OS, please submit a patch or provide us with access to a development system."
    exit
fi

# Set default values prior to potential overwrite
# Check to see if CC and CXX are already defined
if [[ ! -z "$CC" ]]; then
   GCC="$CC"
else
   # Take a guess
   GCC=gcc
fi
if [[ ! -z "$CXX" ]]; then
   GXX="$CXX"
else
   GXX=g++
fi

# Set default values prior to potential overwrite
CFLAGS_COMMON="-w -fPIC"
CXXFLAGS_COMMON="-w -fPIC"
LDFLAGS_COMMON="-w -fPIC"

# Support a newer make if available, needed on ReadyNAS
if [ -x /usr/local/bin/make ]; then
    MAKE_BIN=/usr/local/bin/make
else
    MAKE_BIN=/usr/bin/make
fi

# Try to use the version of Perl in PATH, or the CLI supplied
if [ "$PERL_BIN" = "" -o "$CUSTOM_PERL" != "" ]; then
    if [ "$CUSTOM_PERL" = "" ]; then
        PERL_BIN=`which perl`
        PERL_VERSION=`perl -MConfig -le '$Config{version} =~ /(\d+.\d+)\./; print $1'`
    else
        PERL_BIN=$CUSTOM_PERL
        PERL_VERSION=`$CUSTOM_PERL -MConfig -le '$Config{version} =~ /(\d+.\d+)\./; print $1'`
    fi
    if [[ "$PERL_VERSION" =~ ^5\.[0-9]+$ ]]; then
        PERL_MINOR_VER=`echo "$PERL_VERSION" | sed 's/.*\.//g'`
    else
        echo "Failed to find supported Perl version for '$PERL_BIN'"
        exit
    fi
fi

# We have found Perl, so get system arch, according to Perl
RAW_ARCH=`$PERL_BIN -MConfig -le 'print $Config{archname}'`
# Strip out extra -gnu on Linux for use within this build script
ARCH=`echo $RAW_ARCH | sed 's/gnu-//' | sed 's/^i[3456]86-/i386-/' | sed 's/armv.*?-/arm-/' `

echo "Building for $OS / $ARCH"
echo "Building with Perl 5.$PERL_MINOR_VER at $PERL_BIN"

# Build dirs
BUILD=$PWD/build
PERL_BASE=$BUILD/5.$PERL_MINOR_VER
PERL_ARCH=$BUILD/arch/5.$PERL_MINOR_VER

# Perform necessary customizations per OS.
case "$OS" in
    FreeBSD)
       # This script uses the following precedence for FreeBSD:
       # 1. Environment values for CC/CXX/CPP (checks if $CC is already defined)
       # 2. Values defined in /etc/make.conf, or
       # 3. Stock build chain
        BSD_MAJOR_VER=`uname -r | sed 's/\..*//g'`
        BSD_MINOR_VER=`uname -r | sed 's/.*\.//g'`
        if [ -f "/etc/make.conf" ]; then
            MAKE_CC=`grep ^CC= /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CC=##g'`
            MAKE_CXX=`grep ^CXX= /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CXX=##g'`
            MAKE_CPP=`grep ^CPP= /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CPP=##g'`
        fi
        if [[ ! -z "$CC" ]]; then
            GCC="$CC"
        elif [[ ! -z "$MAKE_CC" ]]; then
            GCC="$MAKE_CC"
        elif [ $BSD_MAJOR_VER -ge 10 ]; then
            # FreeBSD started using clang as the default compiler starting with 10.
            GCC=cc
        else
            GCC=gcc
        fi
        if [[ ! -z "$CXX" ]]; then
            GXX="$CXX"
        elif [[ ! -z "$MAKE_CXX" ]]; then
            GXX="$MAKE_CXX"
        elif [ $BSD_MAJOR_VER -ge 10 ]; then
            # FreeBSD started using clang++ as the default compiler starting with 10.
            GXX=c++
        else
            GXX=g++
        fi
        if [[ ! -z "$CPP" ]]; then
            GPP="$CPP"
        elif [[ ! -z "$MAKE_CPP" ]]; then
            GPP="$MAKE_CPP"
        else
            GPP=cpp
        fi
        # Ensure the environment makes use of the desired/specified compilers and
        # pre-processor
        export CC=$GCC
        export CXX=$GXX
        export CPP=$GPP

        if [ ! -x /usr/local/bin/gmake ]; then
            echo "ERROR: Please install GNU make (gmake)"
            exit
        fi
        MAKE_BIN=/usr/local/bin/gmake

	for i in libz ; do
            #On FreeBSD flag -r should be used, there is no -p
            if ! ldconfig -r | grep -q "${i}.so" ; then
                echo "$i not found - please install it"
	        exit 1
	    fi
	done
	for hdr in "zlib.h"; do
	    if [ -z "$(find /usr/include/ -name ${hdr} -print)" ]; then
	        echo "$hdr not found - please install appropriate development package"
	        exit 1
	    fi
	done
    ;;
    SunOS)
        if [ ! -x /usr/bin/gmake ]; then
            echo "ERROR: Please install GNU make (gmake)"
            exit
        fi
        MAKE_BIN=/usr/bin/gmake
        # On Solaris, both i386 and x64 version of Perl exist.
        # If it is i386, and Perl uses 64 bit integers, then an additional flag is needed.
        if [[ "$ARCH" =~ ^.*-64int$ ]]; then
            CFLAGS_COMMON="-m32 $CFLAGS_COMMON"
            CXXFLAGS_COMMON="-m32 $CXXFLAGS_COMMON"
            LDFLAGS_COMMON="-m32 $LDFLAGS_COMMON"
        elif [[ "$ARCH" =~ ^.*-64$ ]]; then
            CFLAGS_COMMON="-m64 $CFLAGS_COMMON"
            CXXFLAGS_COMMON="-m64 $CXXFLAGS_COMMON"
            LDFLAGS_COMMON="-m64 $LDFLAGS_COMMON"
        fi
    ;;
    Linux)
        for i in libz ; do
            if ! ldconfig -p | grep -q "${i}.so" ; then
                echo "$i not found - please install it"
	        exit 1
	    fi
	done
	for hdr in "zlib.h"; do
	    if [ -z "$(find /usr/include/ -name ${hdr} -print)" ]; then
	        echo "$hdr not found - please install appropriate development package"
	        exit 1
	    fi
	done
    ;;
    Darwin)
        # figure out macOS version and customize SDK options (do not care about patch ver)
        MACOS_VER_STR=`/usr/bin/sw_vers -productVersion |  sed "s#\ *)\ *##g" | sed 's/\.[0-9]*$//g'`

        # This transforms the OS ver into a 4 digit number with leading zeros for the
        # Darwin version, e.g., 10.6 --> 1006, 10.12 --> 1012.
        MACOS_VER=`echo "$MACOS_VER_STR" | sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3\}$/&00/'`

        if [ "$MACOS_VER" -eq 1005 ]; then
            # Leopard, build for i386/ppc with support back to 10.4
            MACOS_ARCH="-arch i386 -arch ppc"
            MACOS_FLAGS="-isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.4"
        elif [ "$MACOS_VER" -eq 1006 ]; then
            # Snow Leopard, build for x86_64/i386 with support back to 10.5
            MACOS_ARCH="-arch x86_64 -arch i386"
            MACOS_FLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5"
        elif [ "$MACOS_VER" -eq 1007 ]; then
            # Lion, build for x86_64 with support back to 10.6
            MACOS_ARCH="-arch x86_64"
            MACOS_FLAGS="-isysroot /Developer/SDKs/MacOSX10.6.sdk -mmacosx-version-min=10.6"
        elif [ "$MACOS_VER" -ge 1009 ]; then
            MACOS_ARCH="-arch x86_64"
            MACOS_FLAGS="-mmacosx-version-min=10.9"
        else
            echo "Unsupported Mac OS version."
            exit 1
        fi
        CFLAGS_COMMON="$CFLAGS_COMMON $MACOS_ARCH $MACOS_FLAGS"
        CXXFLAGS_COMMON="$CXXFLAGS_COMMON $MACOS_ARCH $MACOS_FLAGS"
        LDFLAGS_COMMON="$LDFLAGS_COMMON $MACOS_ARCH $MACOS_FLAGS"
    ;;
esac

# Export the OS specific values
export MAKE=$MAKE_BIN
export CFLAGS_COMMON=$CFLAGS_COMMON
export CXXFLAGS_COMMON=$CXXFLAGS_COMMON
export LDFLAGS_COMMON=$LDFLAGS_COMMON

# Check for other pre-requisites
for i in $GCC $GXX $MAKE nasm rsync ; do
    if ! [ -x "$(command -v $i)" ] ; then
        echo "$i not found - please install it"
        exit 1
    fi
done

if [ -n "$(find /usr/lib/ -maxdepth 1 -name '*libungif*' -print)" ] ; then
    echo "ON SOME PLATFORMS (Ubuntu/Debian at least) THE ABOVE LIBRARIES MAY NEED TO BE TEMPORARILY REMOVED TO ALLOW THE BUILD TO WORK"
fi

echo "Looks like your compiler is $GCC"
$GCC --version

# This method works for FreeBSD, with "normal" installs of GCC and clang.
CC_TYPE=`$GCC --version | head -1`

# Determine compiler type and version
CC_IS_CLANG=false
CC_IS_GCC=false
# Heavy wizardry begins here
# This uses bash globbing for the If statement
if [[ "$CC_TYPE" =~ ^.*clang.*$ ]]; then
    CLANG_MAJOR=`echo "#include <iostream>" | "$GXX" -xc++ -dM -E - | grep '#define __clang_major' | sed 's/.*__\ //g'`
    CLANG_MINOR=`echo "#include <iostream>" | "$GXX" -xc++ -dM -E - | grep '#define __clang_minor' | sed 's/.*__\ //g'`
    CLANG_PATCH=`echo "#include <iostream>" | "$GXX" -xc++ -dM -E - | grep '#define __clang_patchlevel' | sed 's/.*__\ //g'`
    CC_VERSION=`echo "$CLANG_MAJOR"."$CLANG_MINOR"."$CLANG_PATCH" | sed "s#\ *)\ *##g" | sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3,4\}$/&00/'`
    CC_IS_CLANG=true
elif [[ "$CC_TYPE" =~ ^.*gcc.*$ || "$CC_TYPE" =~ ^.*GCC.*$ ]]; then
    CC_IS_GCC=true
    CC_VERSION=`$GCC -dumpfullversion -dumpversion | sed "s#\ *)\ *##g" | sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3,4\}$/&00/'`
else
    echo "********************************************** ERROR ***************************************"
    echo "*"
    echo "*    You're not using GCC or clang. Somebody's playing a prank on me."
    echo "*    Cowardly choosing to abandon build."
    echo "*"
    echo "********************************************************************************************"
    exit 1
fi

if [[ "$CC_IS_GCC" == true && "$CC_VERSION" -lt 40200 ]]; then
    echo "********************************************** ERROR ****************************************"
    echo "*"
    echo "*    It looks like you're using GCC earlier than 4.2,"
    echo "*    Cowardly choosing to abandon build."
    echo "*    This is because modern ICU requires -std=c99"
    echo "*"
    echo "********************************************************************************************"
    exit 1
fi

if [[ "$CC_IS_CLANG" == true && "$CC_VERSION" -lt 30000 ]]; then
    echo "********************************************** ERROR ****************************************"
    echo "*"
    echo "*    It looks like you're using clang earlier than 3.0,"
    echo "*    Cowardly choosing to abandon build."
    echo "*    This is because modern ICU requires -std=c99"
    echo "*"
    echo "********************************************************************************************"
    exit 1
fi

if [[ ! -z `echo "#include <iostream>" | "$GXX" -xc++ -dM -E - | grep LIBCPP_VERSION` ]]; then
    GCC_LIBCPP=true
elif [[ ! -z `echo "#include <iostream>" | "$GXX" -xc++ -dM -E - | grep __GLIBCXX__` ]]; then
    GCC_LIBCPP=false
else
    echo "********************************************** NOTICE **************************************"
    echo "*"
    echo "*    Doesn't seem you're using libc++ or lc++ as your c++ library."
    echo "*    I will assume you're using the GCC stack, and that DBD needs -lstdc++."
    echo "*"
    echo "********************************************************************************************"
    GCC_LIBCPP=false
fi

#  Clean up
if [ $CLEAN -eq 1 ]; then
    rm -rf $BUILD/arch
fi

mkdir -p $PERL_ARCH

# $1 = args
# $2 = file
function tar_wrapper {
    echo "tar $1 $2"
    tar $1 "$2"
    echo "tar done"
}

# $1 = module to build
# $2 = Makefile.PL arg(s)
# $3 = run tests if 1 - default to $RUN_TESTS
# $4 = make clean if 1 - default to $CLEAN
# $5 = use hints if 1 - default to $USE_HINTS
function build_module {
    module=$1
    makefile_args=$2
    local_run_tests=${3-$RUN_TESTS}
    local_clean=${4-$CLEAN}
    local_use_hints=${5-$USE_HINTS}

    echo "build_module run tests:$local_run_tests clean:$local_clean hints $local_use_hints $module $makefile_args"

    if [ ! -d $module ]; then

        if [ ! -f "${module}.tar.gz" ]; then
            echo "ERROR: cannot find source code archive ${module}.tar.gz"
            echo "Please download all source files from http://github.com/Logitech/slimserver-vendor"
            exit
        fi

        tar_wrapper zxf "${module}.tar.gz"
    fi

    cd "${module}"

    if [ $local_use_hints -eq 1 ]; then
        # Always copy in our custom hints for macOS
        cp -Rv ../hints .
    fi
    if [ $PERL_BIN ]; then
        export PERL5LIB=$PERL_BASE/lib/perl5

        $PERL_BIN Makefile.PL INSTALL_BASE=$PERL_BASE $makefile_args
        if [ $local_run_tests -eq 1 ]; then
            $MAKE test
        else
            $MAKE
        fi
        if [ $? != 0 ]; then
            if [ $local_run_tests -eq 1 ]; then
                echo "make test failed, aborting"
            else
                echo "make failed, aborting"
            fi
            exit $?
        fi
        $MAKE install

        if [ $local_clean -eq 1 ]; then
            $MAKE clean
        fi
    fi

    cd ..
    rm -rf $module
}

function build_all {
    build Audio::Scan
    build Class::C3::XS
    build Class::XSAccessor
    build Compress::Raw::Zlib
    # DBD::SQLite builds DBI, so don't need it here as well.
#   build DBI
#   build DBD::mysql
    build DBD::SQLite
    build Digest::SHA1
    build EV
    build Encode::Detect
    build HTML::Parser
    # XXX - Image::Scale requires libjpeg-turbo - which requires nasm 2.07 or later (install from http://www.macports.org/)
    build Image::Scale
    build IO::AIO
    build IO::Interface
#   build IO::Socket::SSL
    build JSON::XS
    build Linux::Inotify2
    build Mac::FSEvents
    build Media::Scan
    build MP3::Cut::Gapless
    build Sub::Name
    build Template
    build XML::Parser
    build YAML::LibYAML
#    build Font::FreeType
#    build Locale::Hebrew
}

function build {
    case "$1" in
        Class::C3::XS)
            if [ $PERL_MINOR_VER -eq 8 ]; then
                tar_wrapper zxf Class-C3-XS-0.11.tar.gz
                cd Class-C3-XS-0.11
                patch -p0 < ../Class-C3-XS-no-ckWARN.patch
                cp -Rv ../hints .
                export PERL5LIB=$PERL_BASE/lib/perl5

                $PERL_BIN Makefile.PL INSTALL_BASE=$PERL_BASE $PERL_CONFIG_CUSTOM $2
                if [ $RUN_TESTS -eq 1 ]; then
                    $MAKE test
                else
                    $MAKE
                fi
                if [ $? != 0 ]; then
                    if [ $RUN_TESTS -eq 1 ]; then
                        echo "make test failed, aborting"
                    else
                        echo "make failed, aborting"
                    fi
                    exit $?
                fi
                $MAKE install
                if [ $CLEAN -eq 1 ]; then
                    $MAKE clean
                fi
                cd ..
                rm -rf Class-C3-XS-0.11
            fi
            ;;

        Class::XSAccessor)
            if [ $PERL_MINOR_VER -ge 16 ]; then
                build_module Class-XSAccessor-1.18
            else
                if [[ "$CC_IS_CLANG" == true ]]; then
                    build_module Class-XSAccessor-1.18
                else
                    build_module Class-XSAccessor-1.05
                fi
            fi
            ;;

        Compress::Raw::Zlib)
            if [ $PERL_MINOR_VER -le 10 ]; then
	            build_module Compress-Raw-Zlib-2.033
            fi
            ;;

        DBI)
            if [ $PERL_MINOR_VER -ge 18 ]; then
                build_module DBI-1.628
            else
                # Old Perl is missing some test methods used by DBI and DBD::SQLite
                if [ $PERL_MINOR_VER -eq 8 ] ; then
                    build_module Test-Simple-1.302141
                fi
                build_module DBI-1.616
            fi
            ;;

        DBD::SQLite)
            # Build DBI before DBD::SQLite so that DBD::SQLite is built
            # against _our_ DBI, not one already present on the system.
            build DBI

            # build ICU, but only if it doesn't exist in the build dir,
            # because it takes so damn long on slow platforms
            if [ ! -f build/lib/libicudata_s.a ]; then
                tar_wrapper zxf icu4c-58_2-src.tgz
                cd icu/source
                # Need to patch ICU to adapt to removal of xlocale.h on some platforms.
                patch -p0 < ../../icu58_patches/digitlst.cpp.patch
                . ../../update-config.sh
                if [ "$OS" = 'Darwin' ]; then
                    ICUFLAGS="-DU_USING_ICU_NAMESPACE=0 -DU_CHARSET_IS_UTF8=1" # faster code for native UTF-8 systems
                    ICUOS="MacOSX"
                elif [ "$OS" = 'Linux' ]; then
                    ICUFLAGS="-DU_USING_ICU_NAMESPACE=0"
                    ICUOS="Linux"
                elif [ "$OS" = 'SunOS' ]; then
                    ICUFLAGS="-D_XPG6 -DU_USING_ICU_NAMESPACE=0 -DU_CHARSET_IS_UTF8=1"
                    ICUOS="Solaris/GCC"
                elif [ "$OS" = 'FreeBSD' ]; then
                    ICUFLAGS="-DU_USING_ICU_NAMESPACE=0"
                    ICUOS="FreeBSD"
                    for i in ../../icu58_patches/freebsd/patch-*;
                        do patch -p0 < $i; done
                fi
                CFLAGS="$CFLAGS_COMMON $ICUFLAGS" CXXFLAGS="$CXXFLAGS_COMMON $ICUFLAGS" LDFLAGS="$LDFLAGS_COMMON" \
                    ./runConfigureICU $ICUOS --prefix=$BUILD --enable-static --with-data-packaging=archive
                $MAKE -j $NUM_MAKE_JOBS
                if [ $? != 0 ]; then
                    echo "make failed"
                    exit $?
                fi
                $MAKE install

                cd ../..
                rm -rf icu

                # Symlink static versions of libraries
                cd build/lib
                ln -sf libicudata.a libicudata_s.a
                ln -sf libicui18n.a libicui18n_s.a
                ln -sf libicuuc.a libicuuc_s.a
                cd ../..
            fi

            # Point to data directory for test suite
            export ICU_DATA=$BUILD/share/icu/58.2

            # Replace huge data file with smaller one containing only our collations
            rm -f $BUILD/share/icu/58.2/icudt58*.dat
            cp -v icudt58*.dat $BUILD/share/icu/58.2

            # Custom build for ICU support
            tar_wrapper zxf DBD-SQLite-1.58.tar.gz
            cd DBD-SQLite-1.58
            if [[ "$GCC_LIBCPP" == true ]] ; then
            # Need this because GLIBCXX uses -lstdc++, but LIBCPP uses -lc++
                patch -p0 < ../DBD-SQLite-ICU-libcpp.patch
            else
                patch -p0 < ../DBD-SQLite-ICU.patch
            fi
            if [ "$OS" = 'SunOS' ]; then
                patch -p0 < ../DBD-SQLite-XOPEN.patch
            fi
            cp -Rv ../hints .

            if [ $PERL_MINOR_VER -eq 8 ]; then
                # Running 5.8
                export PERL5LIB=$PERL_BASE/lib/perl5

                $PERL_BIN Makefile.PL INSTALL_BASE=$PERL_BASE $PERL_CONFIG_CUSTOM $2

                if [ "$OS" = 'Darwin' ]; then
                    # macOS does not seem to properly find -lstdc++, so we need to hack the Makefile to add it
                    $PERL_BIN -p -i -e "s{^LDLOADLIBS =.+}{LDLOADLIBS = -L$PWD/../build/lib -licudata_s -licui18n_s -licuuc_s -lstdc++}" Makefile
                fi

                $MAKE test
                if [ $? != 0 ]; then
                    echo "make test failed, aborting"
                    exit $?
                fi
                $MAKE install
                if [ $CLEAN -eq 1 ]; then
                    $MAKE clean
                fi

                cd ..
                rm -rf DBD-SQLite-1.58
            else
                cd ..
                build_module DBD-SQLite-1.58
            fi

            ;;

        Digest::SHA1)
            build_module Digest-SHA1-2.13
            ;;

        EV)
            build_module common-sense-2.0

            # custom build to apply pthread patch
            export PERL_MM_USE_DEFAULT=1

            tar_wrapper zxf EV-4.03.tar.gz
            cd EV-4.03
            patch -p0 < ../EV-llvm-workaround.patch # patch to avoid LLVM bug 9891
            if [ "$OS" = "Darwin" ]; then
                if [ $PERL_58 ]; then
                    patch -p0 < ../EV-fixes.patch # patch to disable pthreads and one call to SvREADONLY
                fi
            fi
            cp -Rv ../hints .
            cd ..

            build_module EV-4.03

            export PERL_MM_USE_DEFAULT=
            ;;

        Encode::Detect)
            if [[ "$OS" == "FreeBSD" && `sysctl -n security.jail.jailed` == 1 && $PERL_MINOR_VER -le 10 ]]; then
                # Tests fail in jails with old Perl
                build_module Data-Dump-1.19 "" 0
            else
                build_module Data-Dump-1.19
            fi
            build_module ExtUtils-CBuilder-0.260301
            build_module Module-Build-0.35 "" 0
            build_module Encode-Detect-1.00
            ;;

        HTML::Parser)
            build_module HTML-Tagset-3.20
            build_module HTML-Parser-3.68
            ;;

        Image::Scale)
            build_libjpeg
            build_libpng
            build_giflib

            build_module Test-NoWarnings-1.02 "" 0
            build_module Image-Scale-0.14 "--with-jpeg-includes="$BUILD/include" --with-jpeg-static \
                    --with-png-includes="$BUILD/include" --with-png-static \
                    --with-gif-includes="$BUILD/include" --with-gif-static"
            ;;

        IO::AIO)
            if [ "$OS" != "FreeBSD" ]; then
                build_module common-sense-2.0

                # Don't use the darwin hints file, it breaks if compiled on Snow Leopard with 10.5 (!?)
                build_module IO-AIO-3.71 "" 0 $CLEAN 0
            fi
            ;;

        IO::Interface)
            # The IO::Interface tests erroneously require that lo0 be 127.0.0.1. This can be tough in jails.
            if [[ "$OS" == "FreeBSD" && `sysctl -n security.jail.jailed` == 1 ]]; then
                build_module IO-Interface-1.06 "" 0
            else
                build_module IO-Interface-1.06
            fi
            ;;

        IO::Socket::SSL)
            build_module Test-NoWarnings-1.02 "" 0
            build_module Net-IDN-Encode-2.400

            tar_wrapper zxf Net-SSLeay-1.85.tar.gz
            cd Net-SSLeay-1.85
            patch -p0 < ../NetSSLeay-SunOS-NoPrompt.patch
            patch -p0 < ../NetSSLeay-OpenSSL.patch
            cd ..

            build_module Net-SSLeay-1.85

            tar_wrapper zxf IO-Socket-SSL-2.060.tar.gz
            cd IO-Socket-SSL-2.060
            patch -p0 < ../IOSocketSSL-NoPrompt-SunOS.patch
            cd ..

            build_module IO-Socket-SSL-2.060
	    ;;

        JSON::XS)
            build_module common-sense-2.0

            if [ $PERL_MINOR_VER -ge 18 ]; then
                build_module JSON-XS-2.34
            else
                build_module JSON-XS-2.3
            fi
            ;;

        Linux::Inotify2)
            if [ "$OS" = "Linux" ]; then
                build_module common-sense-2.0
                build_module Linux-Inotify2-1.21
            fi
            ;;

        Locale::Hebrew)
            build_module Locale-Hebrew-1.04
            ;;

        Mac::FSEvents)
            if [ "$OS" = 'Darwin' ]; then
                build_module Mac-FSEvents-0.04 "" 0
            fi
            ;;

        Sub::Name)
            build_module Sub-Name-0.05
            ;;

        YAML::LibYAML)
            # Needed because LibYAML 0.35 used . in @INC (not permitted in Perl 5.26)
            # Needed for Debian's Perl 5.24 as well, for the same reason
            if [ $PERL_MINOR_VER -ge 24 ]; then
                build_module YAML-LibYAML-0.65
            elif [ $PERL_MINOR_VER -ge 16 ]; then
                build_module YAML-LibYAML-0.35 "" 0
            else
                build_module YAML-LibYAML-0.35
            fi
            ;;

        Audio::Scan)
            build_module Sub-Uplevel-0.22 "" 0
            build_module Tree-DAG_Node-1.06 "" 0
            build_module Test-Warn-0.23 "" 0
            build_module Audio-Scan-1.02
            ;;

        MP3::Cut::Gapless)
            build_module Audio-Cuefile-Parser-0.02
            build_module MP3-Cut-Gapless-0.03
            ;;

        Template)
            # Template, custom build due to 2 Makefile.PL's
            tar_wrapper zxf Template-Toolkit-2.21.tar.gz
            cd Template-Toolkit-2.21
            cp -Rv ../hints .
            cp -Rv ../hints ./xs
            cd ..

            # minor test failure, so don't test
            build_module Template-Toolkit-2.21 "TT_ACCEPT=y TT_EXAMPLES=n TT_EXTRAS=n" 0

            ;;

        DBD::mysql)
            # Build libmysqlclient
            tar_wrapper jxf mysql-5.1.37.tar.bz2
            cd mysql-5.1.37
            . ../update-config.sh
            CFLAGS="-O3 -fno-omit-frame-pointer $CFLAGS_COMMON" \
            CXXFLAGS="-O3 -fno-omit-frame-pointer -felide-constructors -fno-exceptions -fno-rtti $CXXFLAGS_COMMON" \
                ./configure --prefix=$BUILD \
                --disable-dependency-tracking \
                --enable-thread-safe-client \
                --without-server --disable-shared --without-docs --without-man
            $MAKE
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            $MAKE install
            cd ..
            rm -rf mysql-5.1.37

            # DBD::mysql custom, statically linked with libmysqlclient
            tar_wrapper zxf DBD-mysql-3.0002.tar.gz
            cd DBD-mysql-3.0002
            cp -Rv ../hints .
            mkdir mysql-static
            cp $BUILD/lib/mysql/libmysqlclient.a mysql-static
            cd ..

            build_module DBD-mysql-3.0002 "--mysql_config=$BUILD/bin/mysql_config --libs=\"-Lmysql-static -lmysqlclient -lz -lm\""

            ;;

        XML::Parser)
            # build expat
            tar_wrapper zxf expat-2.0.1.tar.gz
            cd expat-2.0.1/conftools
            . ../../update-config.sh
            cd ..
            CFLAGS="$CFLAGS_COMMON" \
            LDFLAGS="$LDFLAGS_COMMON" \
                ./configure --prefix=$BUILD \
                --disable-dependency-tracking
            $MAKE
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            $MAKE install
            cd ..

            # Symlink static versions of libraries to avoid macOS linker choosing dynamic versions
            cd build/lib
            ln -sf libexpat.a libexpat_s.a
            cd ../..

            # XML::Parser custom, built against expat
            tar_wrapper zxf XML-Parser-2.41.tar.gz
            cd XML-Parser-2.41
            cp -Rv ../hints .
            cp -Rv ../hints ./Expat # needed for second Makefile.PL
            patch -p0 < ../XML-Parser-Expat-Makefile.patch

            cd ..

            build_module XML-Parser-2.41 "EXPATLIBPATH=$BUILD/lib EXPATINCPATH=$BUILD/include"

            rm -rf expat-2.0.1
            ;;

        Font::FreeType)
            # build freetype
            tar_wrapper zxf freetype-2.4.2.tar.gz
            cd freetype-2.4.2
            . ../update-config.sh

            # Disable features we don't need for CODE2000
            cp -fv ../freetype-ftoption.h objs/ftoption.h

            # Disable modules we don't need for CODE2000
            cp -fv ../freetype-modules.cfg modules.cfg

            # libfreetype.a size (i386/x86_64 universal binary):
            #   1634288 (default)
            #    461984 (with custom ftoption.h/modules.cfg)
            CFLAGS="$CFLAGS_COMMON" \
            LDFLAGS="$LDFLAGS_COMMON" \
                ./configure --prefix=$BUILD
            $MAKE # needed for FreeBSD to use gmake
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            $MAKE install
            cd ..

            # Symlink static version of library to avoid macOS linker choosing dynamic versions
            cd build/lib
            ln -sf libfreetype.a libfreetype_s.a
            cd ../..

            tar_wrapper zxf Font-FreeType-0.03.tar.gz
            cd Font-FreeType-0.03

            # Build statically
            patch -p0 < ../Font-FreeType-Makefile.patch

            # Disable some functions so we can compile out more freetype modules
            patch -p0 < ../Font-FreeType-lean.patch

            cp -Rv ../hints .
            cd ..

            build_module Font-FreeType-0.03

            rm -rf freetype-2.4.2
            ;;

        Media::Scan)
            build_ffmpeg
            build_libexif
            build_libjpeg
            build_libpng
            build_giflib
            build_bdb

            # build libmediascan
            # Early macOS versions did not link library correctly libjpeg due to
            # missing x86_64 in libjpeg.dylib, Perl linked OK because it used libjpeg.a
            # Correct linking confirmed with macOS 10.10 and up.
            tar_wrapper zxf libmediascan-0.4.tar.gz
            cd libmediascan-0.4
            . ../update-config.sh

            CFLAGS="-I$BUILD/include $CFLAGS_COMMON -O3" \
            LDFLAGS="-L$BUILD/lib $LDFLAGS_COMMON -O3" \
            OBJCFLAGS="-L$BUILD/lib $CFLAGS_COMMON -O3" \
                ./configure -q --prefix=$BUILD --with-bdb=$BUILD --disable-shared --disable-dependency-tracking
            $MAKE
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            $MAKE install
            cd ..

            # build Media::Scan
            build_module Sub-Uplevel-0.22 "" 0
            build_module Tree-DAG_Node-1.06 "" 0
            build_module Test-Warn-0.23 "" 0
            cd libmediascan-0.4/bindings/perl
            # LMS's hints file is OK and also has custom frameworks added

            MSOPTS="--with-static \
                --with-ffmpeg-includes=$BUILD/include \
                --with-lms-includes=$BUILD/include \
                --with-exif-includes=$BUILD/include \
                --with-jpeg-includes=$BUILD/include \
                --with-png-includes=$BUILD/include \
                --with-gif-includes=$BUILD/include \
                --with-bdb-includes=$BUILD/include"

            # FreeBSD and macOS don't have GNU gettext in the base. This only prevents exif logging.
            if [[ "$OS" == "FreeBSD" || "$OS" == "Darwin" ]]; then
                MSOPTS="$MSOPTS --omit-intl"
            fi

            if [ $PERL_BIN ]; then
                export PERL5LIB=$PERL_BASE/lib/perl5
                $PERL_BIN Makefile.PL $MSOPTS INSTALL_BASE=$PERL_BASE
                $MAKE
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                # XXX hack until regular test works
                $PERL_BIN -Iblib/lib -Iblib/arch t/01use.t
                if [ $? != 0 ]; then
                    echo "make test failed, aborting"
                    exit $?
                fi
                $MAKE install
                if [ $CLEAN -eq 1 ]; then
                    $MAKE clean
                fi
            fi

            cd ../../..
            rm -rf libmediascan-0.4
            ;;
    esac
}

function build_libexif {
    if [ -f $BUILD/include/libexif/exif-data.h ]; then
        return
    fi

    # build libexif
    tar_wrapper jxf libexif-0.6.20.tar.bz2
    cd libexif-0.6.20
    . ../update-config.sh

    CFLAGS="$CFLAGS_COMMON -O3" \
    LDFLAGS="$LDFLAGS_COMMON -O3" \
        ./configure -q --prefix=$BUILD \
        --disable-dependency-tracking
    $MAKE -j $NUM_MAKE_JOBS
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install
    cd ..

    rm -rf libexif-0.6.20
}

function build_libjpeg {
    if [ -f $BUILD/include/jpeglib.h ]; then
        return
    fi
    # There is a known issue with the way automake passes things to libtool,
    # so the warnings about an "unknown NASM token" can be disregarded. See
    # for more info: https://sourceforge.net/p/libjpeg-turbo/mailman/message/34381375/

    # build libjpeg-turbo on x86 platforms
    TURBO_VER="libjpeg-turbo-1.5.3"
    if [ "$OS" = "Darwin" ]; then
    tar_wrapper zxf $TURBO_VER.tar.gz
        if [ "$MACOS_VER" -ge 1006 ]; then
            # Build x86_64 versions of turbo - 64 bit OS was introduced in 10.6
            cd $TURBO_VER

            # Disable features we don't need
            patch -p0 < ../libjpeg-turbo-jmorecfg.h.patch

            # Build 64-bit fork
            CFLAGS="-O3 $MACOS_FLAGS" \
            CXXFLAGS="-O3 $MACOS_FLAGS" \
            LDFLAGS="$MACOS_FLAGS" \
                ./configure -q --prefix=$BUILD --host x86_64-apple-darwin NASM=/usr/local/bin/nasm \
                --disable-dependency-tracking
            $MAKE -j $NUM_MAKE_JOBS
            if [ $? != 0 ]; then
                echo "64-bit macOS make failed"
                exit $?
            fi

            if [ "$MACOS_VER" -eq 1006 ]; then
                # Prep for fork merging - 10.6 requires universal i386/x64 binaries
                cp -fv .libs/libjpeg.a ../libjpeg-x86_64.a
            else
                $MAKE install
                cp -fv .libs/libjpeg.a ../libjpeg.a
            fi
            cd ..
        fi

        # We only need to build the 32-bit for for older macOS. All versions
        # since 10.7 are 64-bit only.
        if [ "$MACOS_VER" -lt 1007 ]; then
            cd $TURBO_VER

            # Disable features we don't need, ignore it if we've already patched
            patch -N -p0 < ../libjpeg-turbo-jmorecfg.h.patch

            if [ $CLEAN -eq 1 ]; then
                 $MAKE clean
            fi
            CFLAGS="-O3 -m32 $MACOS_FLAGS" \
            CXXFLAGS="-O3 -m32 $MACOS_FLAGS" \
            LDFLAGS="-m32 $MACOS_FLAGS" \
                ./configure -q --host i686-apple-darwin --prefix=$BUILD NASM=/usr/local/bin/nasm \
                --disable-dependency-tracking
            $MAKE -j $NUM_MAKE_JOBS
            if [ $? != 0 ]; then
                echo "32-bit macOS make failed"
                exit $?
            fi
            $MAKE install
            cp -fv .libs/libjpeg.a ../libjpeg-i386.a
            cd ..
        fi

        # We only need to build the ppc binaries for for macOS 10.5.
        if [ "$MACOS_VER" -eq 1005 ]; then
            # build ppc libjpeg 6b
            tar_wrapper zxf jpegsrc.v6b.tar.gz
            cd jpeg-6b

            # Disable features we don't need
            cp -fv ../libjpeg62-jmorecfg.h jmorecfg.h

            CFLAGS="-arch ppc -O3 $MACOS_FLAGS" \
            LDFLAGS="-arch ppc -O3 $MACOS_FLAGS" \
                ./configure -q --prefix=$BUILD \
                --disable-dependency-tracking
            $MAKE -j $NUM_MAKE_JOBS
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            cp -fv libjpeg.a ../libjpeg-ppc.a
            cd ..
        fi

        # Combine the forks (only needed for those platforms which require universal binaries)
        if [ "$MACOS_VER" -eq 1005 ]; then
            lipo -create libjpeg-i386.a libjpeg-ppc.a -output libjpeg.a
        elif [ "$MACOS_VER" -lt 1007 ] ; then
            lipo -create libjpeg-x86_64.a libjpeg-i386.a -output libjpeg.a
        fi

        # Install and replace libjpeg.a with the one we built
        mv -fv libjpeg.a $BUILD/lib/libjpeg.a
        rm -fv libjpeg-x86_64.a libjpeg-i386.a libjpeg-ppc.a

    elif [[ "$ARCH" =~ ^(i386-linux|x86_64-linux|i86pc-solaris).*$ || "$OS" == "FreeBSD" ]]; then
        # build libjpeg-turbo
        tar_wrapper zxf $TURBO_VER.tar.gz
        cd $TURBO_VER

        # Disable features we don't need
        patch -p0 < ../libjpeg-turbo-jmorecfg.h.patch

        CFLAGS="$CFLAGS_COMMON" CXXFLAGS="$CXXFLAGS_COMMON" LDFLAGS="$LDFLAGS_COMMON" \
            ./configure -q --prefix=$BUILD --disable-dependency-tracking
        $MAKE -j $NUM_MAKE_JOBS
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi

        $MAKE install
        cd ..

    # build libjpeg v8 on other platforms
    else
        tar_wrapper zxf jpegsrc.v8b.tar.gz
        cd jpeg-8b
        . ../update-config.sh
        # Disable features we don't need
        cp -fv ../libjpeg-jmorecfg.h jmorecfg.h

        CFLAGS="$CFLAGS_COMMON -O3" \
        LDFLAGS="$LDFLAGS_COMMON -O3" \
            ./configure -q --prefix=$BUILD \
            --disable-dependency-tracking
        $MAKE -j $NUM_MAKE_JOBS
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi
        $MAKE install
        cd ..
    fi

    rm -rf jpeg-8b
    rm -rf jpeg-6b
    rm -rf $TURBO_VER
}

function build_libpng {
    if [ -f $BUILD/include/png.h ]; then
        return
    fi

    # build libpng
    LIBPNG_PREFIX="libpng-1.6.36"
    tar_wrapper zxf $LIBPNG_PREFIX.tar.gz
    cd $LIBPNG_PREFIX

    # Disable features we don't need
    cp -fv ../libpng-pngusr.dfa pngusr.dfa
    . ../update-config.sh

    CFLAGS="$CFLAGS_COMMON -O3" \
    CPPFLAGS="$CFLAGS_COMMON -O3 -DFA_XTRA" \
    LDFLAGS="$LDFLAGS_COMMON -O3" \
        ./configure -q --prefix=$BUILD \
        --disable-dependency-tracking
    $MAKE -j $NUM_MAKE_JOBS && $MAKE check
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install
    cd ..

    rm -rf $LIBPNG_PREFIX
}

function build_giflib {
    if [ -f $BUILD/include/gif_lib.h ]; then
        # Determine the version of the last-built giflib
        GIF_MAJOR=`grep 'GIFLIB_MAJOR' $BUILD/include/gif_lib.h | sed 's/.*_MAJOR\ //g'`
        if [ ! -z $GIF_MAJOR ]; then
            GIF_MINOR=`grep 'GIFLIB_MINOR' $BUILD/include/gif_lib.h | sed 's/.*_MINOR\ //g'`
            GIF_RELEASE=`grep 'GIFLIB_RELEASE' $BUILD/include/gif_lib.h | sed 's/.*_RELEASE\ //g'`
            GIF_VERSION=`echo "$GIF_MAJOR"."$GIF_MINOR"."$GIF_RELEASE" | sed "s#\ *)\ *##g" | \
                        sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3,4\}$/&00/'`
            # Only skip the build if it's using the right version
            if [ $GIF_VERSION -ge 50104 ]; then
                return
            fi
        fi
    fi

    # build giflib
    GIFLIB_PREFIX="giflib-5.1.4"
    tar_wrapper zxf $GIFLIB_PREFIX.tar.gz
    cd $GIFLIB_PREFIX
    . ../update-config.sh
    CFLAGS="$CFLAGS_COMMON -O3" \
    LDFLAGS="$LDFLAGS_COMMON -O3" \
        ./configure -q --prefix=$BUILD \
        --disable-dependency-tracking
    $MAKE -j $NUM_MAKE_JOBS
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install
    cd ..

    rm -rf $GIFLIB_PREFIX
}

function build_ffmpeg {
    FFMPEG_PREFIX="ffmpeg-4.1.1"
    FFMPEG_VER_TO_BUILD=`echo ${FFMPEG_PREFIX##*-} | sed "s#\ *)\ *##g" | \
            sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3,4\}$/&00/'`
    echo "build ffmpeg"
    if [ -f $BUILD/include/libavformat/avformat.h ]; then
        # Determine the version of the last-built ffmpeg
        if [ -f $BUILD/share/ffmpeg/VERSION ]; then
            FFMPEG_VER_FOUND=`cat $BUILD/share/ffmpeg/VERSION`
            # Only skip the build if it's using the most recent version
            if [ $FFMPEG_VER_FOUND -ge $FFMPEG_VER_TO_BUILD ]; then
                return
            fi
        fi
    fi

    # build ffmpeg, enabling only the things libmediascan uses
    tar_wrapper jxf $FFMPEG_PREFIX.tar.bz2
    cd $FFMPEG_PREFIX
    . ../update-config.sh

    echo "Configuring FFmpeg..."

    # x86: Disable all but the lowend MMX ASM
    # ARM: Disable all
    # PPC: Disable AltiVec
    FFOPTS="--prefix=$BUILD --disable-ffmpeg --disable-ffplay --disable-ffprobe \
        --disable-avdevice --enable-pic \
        --disable-amd3dnow --disable-amd3dnowext --disable-sse --disable-ssse3 --disable-avx \
        --disable-armv5te --disable-armv6 --disable-armv6t2 --disable-mmi --disable-neon \
        --disable-altivec \
        --enable-zlib --disable-bzlib \
        --disable-everything --disable-iconv --enable-swscale \
        --enable-decoder=h264 --enable-decoder=mpeg1video --enable-decoder=mpeg2video \
        --enable-decoder=mpeg4 --enable-decoder=msmpeg4v1 --enable-decoder=msmpeg4v2 \
        --enable-decoder=msmpeg4v3 --enable-decoder=vp6f --enable-decoder=vp8 \
        --enable-decoder=wmv1 --enable-decoder=wmv2 --enable-decoder=wmv3 --enable-decoder=rawvideo \
        --enable-decoder=mjpeg --enable-decoder=mjpegb --enable-decoder=vc1 \
        --enable-decoder=aac --enable-decoder=ac3 --enable-decoder=dca --enable-decoder=mp3 \
        --enable-decoder=mp2 --enable-decoder=vorbis --enable-decoder=wmapro --enable-decoder=wmav1 --enable-decoder=flv \
        --enable-decoder=wmav2 --enable-decoder=wmavoice \
        --enable-decoder=pcm_dvd --enable-decoder=pcm_s16be --enable-decoder=pcm_s16le \
        --enable-decoder=pcm_s24be --enable-decoder=pcm_s24le \
        --enable-decoder=ass --enable-decoder=dvbsub --enable-decoder=dvdsub --enable-decoder=pgssub --enable-decoder=xsub \
        --enable-parser=aac --enable-parser=ac3 --enable-parser=dca --enable-parser=h264 --enable-parser=mjpeg \
        --enable-parser=mpeg4video --enable-parser=mpegaudio --enable-parser=mpegvideo --enable-parser=vc1 \
        --enable-demuxer=asf --enable-demuxer=avi --enable-demuxer=flv --enable-demuxer=h264 \
        --enable-demuxer=matroska --enable-demuxer=mov --enable-demuxer=mpegps --enable-demuxer=mpegts --enable-demuxer=mpegvideo \
        --enable-protocol=file --cc=$GCC --cxx=$GXX"

    if [ "$MACHINE" = "padre" ]; then
        FFOPTS="$FFOPTS --arch=sparc"
    fi

    # ASM doesn't work right on x86_64
    # XXX test --arch options on Linux
    if [[ "$ARCH" =~ ^(amd64-freebsd|x86_64-linux|i86pc-solaris).*$ ]]; then
        FFOPTS="$FFOPTS --disable-mmx"
    fi

    # FreeBSD amd64 needs arch option
    if [[ "$ARCH" =~ ^amd64-freebsd.*$ ]]; then
        FFOPTS="$FFOPTS --arch=x86"
        # FFMPEG has known issues with GCC 4.2. See: https://trac.ffmpeg.org/ticket/3970
        if [[ "$CC_IS_GCC" == true && "$CC_VERSION" -ge 40200 && "$CC_VERSION" -lt 40300 ]]; then
            FFOPTS="$FFOPTS --disable-asm"
        fi
    fi

    # SunOS and Illumos have problems compiling libmediascan with ASM. So disable it for ffmpeg.
    if [ "$OS" = "SunOS" ]; then
        FFOPTS="$FFOPTS --disable-asm"
    fi

    if [ "$OS" = "Darwin" ]; then
        # Build 64-bit fork
        if [ "$MACOS_VER" -ge 1006 ]; then
            # Build x86_64 versions of turbo - 64 bit OS was introduced in 10.6
            CFLAGS="-arch x86_64 -O3 -fPIC $MACOS_FLAGS" \
            LDFLAGS="-arch x86_64 -O3 -fPIC $MACOS_FLAGS" \
                ./configure $FFOPTS --arch=x86_64

            $MAKE -j $NUM_MAKE_JOBS
            if [ $? != 0 ]; then
                echo "64-bit ffmpeg make failed"
                exit $?
            fi

            if [ "$MACOS_VER" -eq 1006 ]; then
                # Prep for fork merging - 10.6 requires universal i386/x64 binaries
                cp -fv libavcodec/libavcodec.a libavcodec-x86_64.a
                cp -fv libavformat/libavformat.a libavformat-x86_64.a
                cp -fv libavutil/libavutil.a libavutil-x86_64.a
                cp -fv libswscale/libswscale.a libswscale-x86_64.a
            else
                cp -fv libavcodec/libavcodec.a libavcodec.a
                cp -fv libavformat/libavformat.a libavformat.a
                cp -fv libavutil/libavutil.a libavutil.a
                cp -fv libswscale/libswscale.a libswscale.a
            fi
        fi

        # Build 32-bit fork (all macOS versions less than 10.7)
        # All versions since 10.7 are 64-bit only
        if [ "$MACOS_VER" -lt 1007 ]; then
            $MAKE clean
            CFLAGS="-arch i386 -O3 $MACOS_FLAGS" \
            LDFLAGS="-arch i386 -O3 $MACOS_FLAGS" \
                ./configure -q $FFOPTS --arch=x86_32

            $MAKE -j $NUM_MAKE_JOBS
            if [ $? != 0 ]; then
                echo "32-bit ffmpeg make failed"
                exit $?
            fi

            cp -fv libavcodec/libavcodec.a libavcodec-i386.a
            cp -fv libavformat/libavformat.a libavformat-i386.a
            cp -fv libavutil/libavutil.a libavutil-i386.a
            cp -fv libswscale/libswscale.a libswscale-i386.a
        fi

        # We only need to build the ppc fork for macOS 10.5
        if [ "$MACOS_VER" -eq 1005 ]; then
            $MAKE clean
            CFLAGS="-arch ppc -O3 $MACOS_FLAGS" \
            LDFLAGS="-arch ppc -O3 $MACOS_FLAGS" \
                ./configure $FFOPTS --arch=ppc --disable-altivec

            $MAKE -j $NUM_MAKE_JOBS
            if [ $? != 0 ]; then
                echo "ppc ffmpeg make failed"
                exit $?
            fi

            cp -fv libavcodec/libavcodec.a libavcodec-ppc.a
            cp -fv libavformat/libavformat.a libavformat-ppc.a
            cp -fv libavutil/libavutil.a libavutil-ppc.a
            cp -fv libswscale/libswscale.a libswscale-ppc.a
        fi

        # Combine the forks (if necessary). macOS 10.7 and onwards do not need
        # universal binaries.
        if [ "$MACOS_VER" -eq 1005 ]; then
            lipo -create libavcodec-i386.a libavcodec-ppc.a -output libavcodec.a
            lipo -create libavformat-i386.a libavformat-ppc.a -output libavformat.a
            lipo -create libavutil-i386.a libavutil-ppc.a -output libavutil.a
            lipo -create libswscale-i386.a libswscale-ppc.a -output libswscale.a
        elif [ "$MACOS_VER" -lt 1007 ]; then
            lipo -create libavcodec-x86_64.a libavcodec-i386.a -output libavcodec.a
            lipo -create libavformat-x86_64.a libavformat-i386.a -output libavformat.a
            lipo -create libavutil-x86_64.a libavutil-i386.a -output libavutil.a
            lipo -create libswscale-x86_64.a libswscale-i386.a -output libswscale.a
        fi

        # Install and replace libs with versions we built
        $MAKE install
        cp -f libavcodec.a $BUILD/lib/libavcodec.a
        cp -f libavformat.a $BUILD/lib/libavformat.a
        cp -f libavutil.a $BUILD/lib/libavutil.a
        cp -f libswscale.a $BUILD/lib/libswscale.a

    else
        CFLAGS="$CFLAGS_COMMON -O3" \
        LDFLAGS="$LDFLAGS_COMMON -O3" \
            ./configure $FFOPTS

        $MAKE -j $NUM_MAKE_JOBS
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi
        $MAKE install
    fi
    # Starting with 4.1, we copy the release to ease last-built version detection
    echo $FFMPEG_VER_TO_BUILD > $BUILD/share/ffmpeg/VERSION

    cd ..
    rm -r $FFMPEG_PREFIX
}

function build_bdb {
    if [ -f $BUILD/include/db.h ]; then
        return
    fi

    # --enable-posixmutexes is needed to build on ReadyNAS Sparc.
    MUTEX=""
    if [ "$MACHINE" = "padre" ]; then
      MUTEX="--enable-posixmutexes"
    fi

    # build bdb
    DB_PREFIX="db-6.2.32"
    tar_wrapper zxf $DB_PREFIX.tar.gz
    cd $DB_PREFIX/dist
    . ../../update-config.sh
    cd ../build_unix

    CFLAGS="$CFLAGS_COMMON -O3" \
    LDFLAGS="$CFLAGS_COMMON -O3 " \
        ../dist/configure -q --prefix=$BUILD $MUTEX \
        --with-cryptography=no -disable-hash --disable-queue --disable-replication --disable-statistics --disable-verify \
        --disable-dependency-tracking --disable-shared
    $MAKE -j $NUM_MAKE_JOBS
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install
    cd ../..

    rm -rf $DB_PREFIX
}

# Build a single module if requested, or all
if [ $1 ]; then
    echo "building only $1"
    build $1
else
    build_all
fi

# Reset PERL5LIB
export PERL5LIB=

if [ "$OS" = 'Darwin' ]; then
    # strip -S on all bundle files
    find $BUILD -name '*.bundle' -exec chmod u+w {} \;
    find $BUILD -name '*.bundle' -exec strip -S {} \;
elif [ "$OS" = 'Linux' -o "$OS" = "FreeBSD" ]; then
    # strip all so files
    find $BUILD -name '*.so' -exec chmod u+w {} \;
    find $BUILD -name '*.so' -exec strip {} \;
fi

# clean out useless .bs/.packlist files, etc
find $BUILD -name '*.bs' -exec rm -f {} \;
find $BUILD -name '*.packlist' -exec rm -f {} \;

# create our directory structure
# rsync is used to avoid copying non-binary modules or other extra stuff
mkdir -p $PERL_ARCH/$ARCH
rsync -amv --include='*/' --include='*.so' --include='*.bundle' --include='autosplit.ix' --include='*.pm' --include='*.al' --exclude='*' $PERL_BASE/lib/perl5/$RAW_ARCH $PERL_ARCH/
rsync -amv --exclude=$RAW_ARCH --include='*/' --include='*.so' --include='*.bundle' --include='autosplit.ix' --include='*.pm' --include='*.al' --exclude='*' $PERL_BASE/lib/perl5/ $PERL_ARCH/$ARCH/

if [ $LMSBASEDIR ]; then
    if [ ! -d $LMSBASEDIR/CPAN/arch/5.$PERL_MINOR_VER/$ARCH ]; then
        mkdir -p $LMSBASEDIR/CPAN/arch/5.$PERL_MINOR_VER/$ARCH
    fi
    rsync -amv --include='*/' --include='*' $PERL_ARCH/$ARCH/ $LMSBASEDIR/CPAN/arch/5.$PERL_MINOR_VER/$ARCH/
fi

# could remove rest of build data, but let's leave it around in case
#rm -rf $PERL_BASE
#rm -rf $PERL_ARCH
#rm -rf $BUILD/bin $BUILD/etc $BUILD/include $BUILD/lib $BUILD/man $BUILD/share $BUILD/var
