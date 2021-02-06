#!/usr/bin/env bash
#
# $Id$
#
# This script builds all binary Perl modules required by Squeezebox Server.
#
# Supported OSes:
#
# Linux (Perl 5.8.8, 5.10.0, 5.12.4, 5.14.1, 5.16.3)
#   i386/x86_64 Linux
#   ARM Linux
#   PowerPC Linux
#   Sparc Linux (ReadyNAS)
# Mac OSX
#   Under 10.5, builds Universal Binaries for i386/ppc Perl 5.8.8
#   Under 10.6, builds Universal Binaries for i386/x86_64 Perl 5.10.0
#   Under 10.7, builds for x86_64 Perl 5.12.3 (Lion does not support 32-bit CPUs)
#   Under 10.9, builds for x86_64 Perl 5.16
#   Under 10.10, builds for x86_64 Perl 5.18
# FreeBSD 7.2 (Perl 5.8.9)
# FreeBSD 8.X,9.X (Perl 5.12.4)
# Solaris
#   builds are best done with custom compiled perl and gcc
#   using the following PATH=/opt/gcc-5.1.0/bin:/usr/gnu/bin:$PATH
#   plus a path to a version of yasm and nasm
#
#   Tested versions (to be extended)
#     OmniOSCE 151022 LTS (Perl 5.24.1)
#
# Perl 5.12.4/5.14.1 note:
#   You should build 5.12.4 using perlbrew and the following command. GCC's stack protector must be disabled
#   so the binaries will not be dynamically linked to libssp.so which is not available on some distros.
#   NOTE: On 32-bit systems for 5.12 and higher, -D use64bitint should be used. Debian Wheezy (the next release) will
#   use Perl 5.12.4 with use64bitint enabled, and hopefully other major distros will follow suit.
#
#     perlbrew install perl-5.12.4 -D usethreads -D use64bitint -A ccflags=-fno-stack-protector -A ldflags=-fno-stack-protector
#
#   For 64-bit native systems, use:
#
#     perlbrew install perl-5.12.4 -D usethreads -A ccflags=-fno-stack-protector -A ldflags=-fno-stack-protector
#

# Require modules to pass tests
RUN_TESTS=1
USE_HINTS=1
CLEAN=1
FLAGS="-fPIC"
# Default is to rename every x86 to i386
RENAME_x86=1
THREADNUM=2

function usage {
    cat <<EOF
$0 [args] [target]
-h            this help
-c            do not run make clean
-i <lmsbase>  install modules in lmsbase directory
-p <perlbin>  set custom perl binary
-r            do not rename all x86 archs to "i386"
-t            do not run tests
-j <threads>  multithreaded compile

target: make target - if not specified all will be built

EOF
}

while getopts j:hci:p:t opt; do
  case $opt in
  c)
      CLEAN=0
      ;;
  i)
      LMSBASEDIR=$OPTARG
      ;;
  p)
      CUSTOM_PERL=$OPTARG
      ;;
  r)
      RENAME_x86=0
      ;;
  t)
      RUN_TESTS=0
      ;;
  j)
      THREADNUM=$OPTARG
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

echo "RUN_TESTS:$RUN_TESTS CLEAN:$CLEAN USE_HINTS:$USE_HINTS RENAME_x86:$RENAME_x86 target ${1-all}"

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

# This script uses the following precedence for FreeBSD:
# 1. Environment values for CC/CXX/CPP (checks if $CC is already defined)
# 2. Values defined in /etc/make.conf, or
# 3. Stock build chain
if [ "$OS" = "FreeBSD" ]; then
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
fi

for i in $GCC $GXX rsync make ; do
    which $i > /dev/null
    if [ $? -ne 0 ] ; then
        echo "$i not found - please install it"
        exit 1
    fi
done

echo "Looks like your compiler is $GCC"
$GCC --version

# This method works for FreeBSD, with "normal" installs of GCC and clang.
CC_TYPE=`$GCC --version | head -1`

# Determine compiler type and version
CC_IS_CLANG=false
CC_IS_GCC=false
# Heavy wizardry begins here
# This uses bash globbing for the If statement
if [[ "$CC_TYPE" =~ "clang" ]]; then
    CLANG_MAJOR=`echo "#include <iostream>" | "$GXX" -xc++ -dM -E - | grep '#define __clang_major' | sed 's/.*__\ //g'`
    CLANG_MINOR=`echo "#include <iostream>" | "$GXX" -xc++ -dM -E - | grep '#define __clang_minor' | sed 's/.*__\ //g'`
    CLANG_PATCH=`echo "#include <iostream>" | "$GXX" -xc++ -dM -E - | grep '#define __clang_patchlevel' | sed 's/.*__\ //g'`
    CC_VERSION=`echo "$CLANG_MAJOR"."$CLANG_MINOR"."$CLANG_PATCH" | sed "s#\ *)\ *##g" | sed -e 's/\.\([0-9][0-9]\)/\1/g' -e 's/\.\([0-9]\)/0\1/g' -e 's/^[0-9]\{3,4\}$/&00/'`
    CC_IS_CLANG=true
elif [[ "$CC_TYPE" =~ "gcc" || "$CC_TYPE" =~ "GCC" ]]; then
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

which yasm > /dev/null
if [ $? -ne 0 ] ; then
    which nasm > /dev/null
    if [ $? -ne 0 ] ; then
        echo "please install either yasm or nasm."
        exit 1
    fi
fi

if [ "$OS" = "Linux" ]; then
	#for i in libgif libz libgd ; do
	for i in libz ; do
	    ldconfig -p | grep "${i}.so" > /dev/null
	    if [ $? -ne 0 ] ; then
	        echo "$i not found - please install it"
	        exit 1
	    fi
	done
	for hdr in "zlib.h"; do
	    hdr_found=$(find /usr/include -name "$hdr");
	    if [ ! "$hdr_found" ]; then
	        echo "$hdr not found - please install appropriate development package"
	        exit 1
	    fi
	done
fi

if [ "$OS" = "FreeBSD" ]; then
	#for i in libgif libz libgd ; do
	for i in libz ; do
	    ldconfig -r | grep "${i}.so" > /dev/null #On FreeBSD flag -r should be used, there is no -p
	    if [ $? -ne 0 ] ; then
	        echo "$i not found - please install it"
	        exit 1
	    fi
	done
	for hdr in "zlib.h"; do
	    hdr_found=$(find /usr/include/ -name "$hdr");
	    if [ ! "$hdr_found" ]; then
	        echo "$hdr not found - please install appropriate development package"
	        exit 1
	    fi
	done
fi

find /usr/lib/ -maxdepth 1 | grep libungif
if [ $? -eq 0 ] ; then
    echo "ON SOME PLATFORMS (Ubuntu/Debian at least) THE ABOVE LIBRARIES MAY NEED TO BE TEMPORARILY REMOVED TO ALLOW THE BUILD TO WORK"
fi

# figure out OSX version and customize SDK options
OSX_VER=
OSX_FLAGS=
OSX_ARCH=
if [ "$OS" = "Darwin" ]; then
    OSX_VER=`/usr/sbin/system_profiler SPSoftwareDataType`
    REGEX=' OS X.* (10\.[5-9])'
    REGEX2=' OS X.* (10\.1[0-9])'
    REGEX3=' macOS (10\.1[0-9])'

    if [[ $OSX_VER =~ $REGEX3 ]]; then
        OSX_VER=${BASH_REMATCH[1]}
    elif [[ $OSX_VER =~ $REGEX ]]; then
        OSX_VER=${BASH_REMATCH[1]}
    elif [[ $OSX_VER =~ $REGEX2 ]]; then
        OSX_VER=${BASH_REMATCH[1]}
    else
        echo "Unable to determine OSX version"
        exit 0
    fi

    if [ "$OSX_VER" = "10.5" ]; then
        # Leopard, build for i386/ppc with support back to 10.4
        OSX_ARCH="-arch i386 -arch ppc"
        OSX_FLAGS="-isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.4"
    elif [ "$OSX_VER" = "10.6" ]; then
        # Snow Leopard, build for x86_64/i386 with support back to 10.5
        OSX_ARCH="-arch x86_64 -arch i386"
        OSX_FLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5"
    elif [ "$OSX_VER" = "10.7" ]; then
        # Lion, build for x86_64 with support back to 10.6
        OSX_ARCH="-arch x86_64"
        OSX_FLAGS="-isysroot /Developer/SDKs/MacOSX10.6.sdk -mmacosx-version-min=10.6"
    elif [ "$OSX_VER" = "10.9" ]; then
        # Mavericks, build for x86_64 with support back to 10.9
        OSX_ARCH="-arch x86_64"
        OSX_FLAGS="-mmacosx-version-min=10.9"
    elif [ "$OSX_VER" = "10.10" ]; then
        # Yosemite, build for x86_64 with support back to 10.10
        OSX_ARCH="-arch x86_64"
        OSX_FLAGS="-mmacosx-version-min=10.10"
    else
        OSX_ARCH="-arch x86_64"
        OSX_FLAGS="-mmacosx-version-min=$OSX_VER"
    fi
fi

# Build dir
BUILD=$PWD/build
PERL_BASE=$BUILD/perl5x
PERL_ARCH=$BUILD/arch/perl5x

# Path to Perl 5.8.8
if [ -x "/usr/bin/perl5.8.8" ]; then
    PERL_58=/usr/bin/perl5.8.8
elif [ -x "/usr/local/bin/perl5.8.8" ]; then
    PERL_58=/usr/local/bin/perl5.8.8
elif [ -x "$HOME/perl5/perlbrew/perls/perl-5.8.9/bin/perl5.8.9" ]; then
    PERL_58=$HOME/perl5/perlbrew/perls/perl-5.8.9/bin/perl5.8.9
elif [ -x "/usr/local/bin/perl5.8.9" ]; then # FreeBSD 7.2
    PERL_58=/usr/local/bin/perl5.8.9
fi

if [ $PERL_58 ]; then
    PERL_BIN=$PERL_58
    PERL_MINOR_VER=8
fi

# Path to Perl 5.10.0
if [ -x "/usr/bin/perl5.10.0" ]; then
    PERL_510=/usr/bin/perl5.10.0
elif [ -x "/usr/local/bin/perl5.10.0" ]; then
    PERL_510=/usr/local/bin/perl5.10.0
elif [ -x "/usr/local/bin/perl5.10.1" ]; then # FreeBSD 8.2
    PERL_510=/usr/local/bin/perl5.10.1
fi

if [ $PERL_510 ]; then
    PERL_BIN=$PERL_510
    PERL_MINOR_VER=10
fi

# Path to Perl 5.12
if [ "$OSX_VER" = "10.9" ]; then
    echo "Ignoring Perl 5.12 - we want 5.16 on Mavericks"
elif [ -x "/usr/bin/perl5.12.4" ]; then
    PERL_512=/usr/bin/perl5.12.4
elif [ -x "/usr/local/bin/perl5.12.4" ]; then
    PERL_512=/usr/local/bin/perl5.12.4
elif [ -x "/usr/local/bin/perl5.12.4" ]; then # Also FreeBSD 8.2
    PERL_512=/usr/local/bin/perl5.12.4
elif [ -x "$HOME/perl5/perlbrew/perls/perl-5.12.4/bin/perl5.12.4" ]; then
    PERL_512=$HOME/perl5/perlbrew/perls/perl-5.12.4/bin/perl5.12.4
elif [ -x "/usr/bin/perl5.12" ]; then
    # OSX Lion uses this path
    PERL_512=/usr/bin/perl5.12
fi

if [ $PERL_512 ]; then
    PERL_BIN=$PERL_512
    PERL_MINOR_VER=12
fi

# Path to Perl 5.14.1
if [ -x "$HOME/perl5/perlbrew/perls/perl-5.14.1/bin/perl5.14.1" ]; then
    PERL_514=$HOME/perl5/perlbrew/perls/perl-5.14.1/bin/perl5.14.1
fi

if [ $PERL_514 ]; then
    PERL_BIN=$PERL_514
    PERL_MINOR_VER=14
fi

# Path to Perl 5.16
if [ "$OSX_VER" = "10.10" ]; then
    echo "Ignoring Perl 5.16 - we want 5.18 on Yosemite"
elif [ -x "/usr/bin/perl5.16" ]; then
    PERL_516=/usr/bin/perl5.16
elif [ -x "/usr/bin/perl5.16.3" ]; then
    PERL_516=/usr/bin/perl5.16.3
fi

if [ $PERL_516 ]; then
    PERL_BIN=$PERL_516
    PERL_MINOR_VER=16
fi

# Path to Perl 5.18
if [ -x "/usr/bin/perl5.18" ]; then
    PERL_518=/usr/bin/perl5.18
fi

# defined on the command line - no detection yet
if [ $PERL_518 ]; then
    PERL_BIN=$PERL_518
    PERL_MINOR_VER=18
fi

# defined on the command line - no detection yet
if [ $PERL_520 ]; then
    PERL_BIN=$PERL_520
    PERL_MINOR_VER=20
fi

# Path to Perl 5.22
if [ -x "/usr/bin/perl5.22.1" ]; then
    PERL_522=/usr/bin/perl5.22.1
fi

if [ $PERL_522 ]; then
    PERL_BIN=$PERL_522
    PERL_MINOR_VER=22
fi

# Path to Perl 5.24
if [ -x "/usr/bin/perl5.24.1" ]; then
    PERL_524=/usr/bin/perl5.24.1
fi

if [ $PERL_524 ]; then
    PERL_BIN=$PERL_524
    PERL_MINOR_VER=24
fi

# Path to Perl 5.26
if [ -x "/usr/bin/perl5.26.0" ]; then
    PERL_526=/usr/bin/perl5.26.0
fi

if [ $PERL_526 ]; then
    PERL_BIN=$PERL_526
    PERL_MINOR_VER=26
fi

# Path to Perl 5.32
if [ -x "/usr/bin/perl5.32.0" ]; then
    PERL_532=/opt/localperl/bin/perl5.32.0
fi

if [ $PERL_532 ]; then
    PERL_BIN=$PERL_532
    PERL_MINOR_VER=32
fi

# try to use default perl version
if [ "$PERL_BIN" = "" -o "$CUSTOM_PERL" != "" ]; then
    if [ "$CUSTOM_PERL" = "" ]; then
        PERL_BIN=`which perl`
        PERL_VERSION=`perl -MConfig -le '$Config{version} =~ /(\d+.\d+)\./; print $1'`
    else
        PERL_BIN=$CUSTOM_PERL
        PERL_VERSION=`$CUSTOM_PERL -MConfig -le '$Config{version} =~ /(\d+.\d+)\./; print $1'`
    fi
    if [[ "$PERL_VERSION" =~ "5." ]]; then
        PERL_MINOR_VER=`echo "$PERL_VERSION" | sed 's/.*\.//g'`
    else
        echo "Failed to find supported Perl version for '$PERL_BIN'"
        exit
    fi

fi

# We have found Perl, so get system arch, according to Perl
RAW_ARCH=`$PERL_BIN -MConfig -le 'print $Config{archname}'`
# Strip out extra -gnu on Linux for use within this build script
ARCH=`echo $RAW_ARCH | sed 's/gnu-//' | sed 's/armv.*?-/arm-/' `

# Default behavior is to rename all x86 architectures to i386
if [ $RENAME_x86 -eq 1 ]; then
   ARCH=`echo "$ARCH" | sed 's/^i[3456]86-/i386-/'`
fi


echo "Building for $OS / $ARCH"
echo "Building with Perl 5.$PERL_MINOR_VER at $PERL_BIN"
PERL_BASE=$BUILD/5.$PERL_MINOR_VER
PERL_ARCH=$BUILD/arch/5.$PERL_MINOR_VER

# FreeBSD's make sucks
if [ "$OS" = "FreeBSD" ]; then
    if [ ! -x /usr/local/bin/gmake ]; then
        echo "ERROR: Please install GNU make (gmake)"
        exit
    fi
    export MAKE="/usr/local/bin/gmake -j $THREADNUM"
elif [ "$OS" = "SunOS" ]; then
    if [ ! -x /usr/bin/gmake ]; then
        echo "ERROR: Please install GNU make (gmake)"
        exit
    fi
    export MAKE="/usr/bin/gmake -j $THREADNUM"
else
    # Support a newer make if available, needed on ReadyNAS
    if [ -x /usr/local/bin/make ]; then
        export MAKE="/usr/local/bin/make -j $THREADNUM"
    else
        export MAKE="/usr/bin/make -j $THREADNUM"
    fi
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
        # Always copy in our custom hints for OSX
        cp -R ../hints .
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

function build_module_with_build {
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
        # Always copy in our custom hints for OSX
        cp -R ../hints .
    fi
    if [ $PERL_BIN ]; then
        export PERL5LIB=$PERL_BASE/lib/perl5

        $PERL_BIN Build.PL INSTALL_BASE=$PERL_BASE $makefile_args
        if [ $local_run_tests -eq 1 ]; then
            $PERL_BIN Build test
        else
            $PERL_BIN Build
        fi
        if [ $? != 0 ]; then
            if [ $local_run_tests -eq 1 ]; then
                echo "make test failed, aborting"
            else
                echo "make failed, aborting"
            fi
            exit $?
        fi
        $PERL_BIN Build install

        if [ $local_clean -eq 1 ]; then
            $PERL_BIN Build clean
        fi
    fi

    cd ..
    rm -rf $module
}

function build_all {
    build Audio::Scan
    build Canary::Stability
    build Class::C3::XS
    build Class::XSAccessor
    build Compress::Raw::Zlib
    # DBD::SQLite builds DBI, so don't need it here as well.
    build DBI
    build Test::Needs
    build Try::Tiny
    build Encode::Locale
    build HTTP::Date
    build Time::Zone
    build Test::Fatal
    build IO::HTML
    build LWP::MediaTypes
    build URI::URL
#   build DBD::mysql
    build DBD::SQLite
    build Digest::SHA1
    build EV
    build Types::Serialiser
    build Encode::Detect
    build HTML::Parser
    build HTTP::Header
    # XXX - Image::Scale requires libjpeg-turbo - which requires nasm 2.07 or later (install from http://www.macports.org/)
    build Image::Scale
    build IO::AIO
    build IO::Interface
    build IO::Socket::SSL
    build JSON::XS
    build Linux::Inotify2
    build Mac::FSEvents
    build Media::Scan
    build MP3::Cut::Gapless
    build Sub::Name
    build Template
    build XML::Parser
    build YAML::LibYAML
    build HTTP::Headers
#    build Font::FreeType
#    build Locale::Hebrew
}

function build {
    case "$1" in
        Class::C3::XS)
            if [ $PERL_MINOR_VER -eq 8 ]; then
                tar_wrapper zxf Class-C3-XS-0.15.tar.gz
                cd Class-C3-XS-0.15
                patch -p0 < ../Class-C3-XS-no-ckWARN.patch
                cp -R ../hints .
                export PERL5LIB=$PERL_BASE/lib/perl5

                $PERL_BIN Makefile.PL INSTALL_BASE=$PERL_BASE $2
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
                rm -rf Class-C3-XS-0.15
            fi
            ;;

        Class::XSAccessor)
            if [ $PERL_MINOR_VER -ge 16 ]; then
                build_module Class-XSAccessor-1.19
            else
                if [[ "$CC_IS_CLANG" == true ]]; then
                    build_module Class-XSAccessor-1.19
                else
                    build_module Class-XSAccessor-1.05
                fi
            fi
            ;;

        Compress::Raw::Zlib)
            if [ $PERL_MINOR_VER -eq 8 -o $PERL_MINOR_VER -eq 10 ]; then
	            build_module Compress-Raw-Zlib-2.096
            fi
            ;;
			
		Test::Needs)
			build_module Test-Needs-0.002006
			;;
			
		Try::Tiny)
			build_module Try-Tiny-0.30
			;;
			
		Encode::Locale)
			build_module Encode-Locale-1.05
			;;
			
		HTTP::Date)
			build_module HTTP-Date-6.05
			;;
	
		Time::Zone)
			build_module TimeDate-2.33
			;;
			
		Test::Fatal)
			build_module Test-Fatal-0.016
			;;
			
		IO::HTML)
			build_module IO-HTML-1.004
			;;
			
		LWP::MediaTypes)
			build_module LWP-MediaTypes-6.04
			;;

        DBI)
            if [ $PERL_MINOR_VER -ge 18 ]; then
                build_module DBI-1.643
            elif [ $PERL_MINOR_VER -eq 8 ]; then
                build_module DBI-1.616 "" 0
            else
                build_module DBI-1.643
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
                    ICUFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -DU_USING_ICU_NAMESPACE=0 -DU_CHARSET_IS_UTF8=1" # faster code for native UTF-8 systems
                    ICUOS="MacOSX"
                elif [ "$OS" = 'Linux' ]; then
                    ICUFLAGS="$FLAGS -DU_USING_ICU_NAMESPACE=0"
                    ICUOS="Linux"
                elif [ "$OS" = 'SunOS' ]; then
                    ICUFLAGS="$FLAGS -D_XPG6 -DU_USING_ICU_NAMESPACE=0"
                    ICUOS="Solaris/GCC"
                elif [ "$OS" = 'FreeBSD' ]; then
                    ICUFLAGS="$FLAGS -DU_USING_ICU_NAMESPACE=0"
                    ICUOS="FreeBSD"
                    for i in ../../icu58_patches/freebsd/patch-*;
                        do patch -p0 < $i; done
                fi
                CFLAGS="$ICUFLAGS" CXXFLAGS="$ICUFLAGS" LDFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS" \
                    ./runConfigureICU $ICUOS --prefix=$BUILD --enable-static --with-data-packaging=archive
                $MAKE
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
            cp icudt58*.dat $BUILD/share/icu/58.2

            # Custom build for ICU support
            tar_wrapper zxf DBD-SQLite-1.66.tar.gz
            cd DBD-SQLite-1.66
            if [[ "$GCC_LIBCPP" == true ]] ; then
            # Need this because GLIBCXX uses -lstdc++, but LIBCPP uses -lc++
                patch -p0 < ../DBD-SQLite-ICU-libcpp.patch
            else
                patch -p0 < ../DBD-SQLite-ICU.patch
            fi
            if [ "$OS" = 'SunOS' ]; then
                patch -p0 < ../DBD-SQLite-XOPEN.patch
            fi
            cp -R ../hints .

            if [ $PERL_MINOR_VER -eq 8 ]; then
                # Running 5.8
                export PERL5LIB=$PERL_BASE/lib/perl5

                $PERL_BIN Makefile.PL INSTALL_BASE=$PERL_BASE $2

                if [ "$OS" = 'Darwin' ]; then
                    # OSX does not seem to properly find -lstdc++, so we need to hack the Makefile to add it
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
                rm -rf DBD-SQLite-1.66
            else
                cd ..
                build_module DBD-SQLite-1.66
            fi

            ;;

        Digest::SHA1)
            build_module Digest-SHA1-2.13
            ;;
			
		Canary::Stability)
			build_module Canary-Stability-2013
			;;
			
		Types::Serialiser)
			build_module Types-Serialiser-1.0
			;;

        EV)
            build_module common-sense-3.75

            # custom build to apply pthread patch
            export PERL_MM_USE_DEFAULT=1

            tar_wrapper zxf EV-4.33.tar.gz
            cd EV-4.33
            cp -R ../hints .
            cd ..

            build_module EV-4.33

            export PERL_MM_USE_DEFAULT=
            ;;

        Encode::Detect)
            build_module Data-Dump-1.23
            build_module ExtUtils-CBuilder-0.280234
            build_module Module-Build-0.4231 "" 0
            build_module Encode-Detect-1.01
            ;;

        HTML::Parser)
            build_module HTML-Tagset-3.20
			build_module HTTP-Message-6.26
            build_module HTML-Parser-3.75
            ;;

        Image::Scale)
            build_libjpeg
            build_libpng
            build_giflib

            build_module Test-NoWarnings-1.04 "" 0
            build_module Image-Scale-0.14 "--with-jpeg-includes="$BUILD/include" --with-jpeg-static \
                    --with-png-includes="$BUILD/include" --with-png-static \
                    --with-gif-includes="$BUILD/include" --with-gif-static"
            ;;

        IO::AIO)
            if [ "$OS" != "FreeBSD" ]; then
                build_module common-sense-3.75

                # Don't use the darwin hints file, it breaks if compiled on Snow Leopard with 10.5 (!?)
                build_module IO-AIO-4.75 "" 0 $CLEAN 0
            fi
            ;;

        IO::Interface)
            # The IO::Interface tests erroneously require that lo0 be 127.0.0.1. This can be tough in jails.
            if [[ "$OS" == "FreeBSD" && `sysctl -n security.jail.jailed` == 1 ]]; then
                build_module_with_build IO-Interface-1.09 "" 0
            else
                build_module_with_build IO-Interface-1.09
            fi
            ;;
			
		URI::URL)
			build_module URI-5.05
			;;
			
		HTTP::Header)
			build_module HTTP-Message-6.26
			;;

        IO::Socket::SSL)
            build_module Test-NoWarnings-1.04 "" 0
            build_module Net-IDN-Encode-2.500
	    
	    export PERL_MM_USE_DEFAULT=1

            tar_wrapper zxf Net-SSLeay-1.90.tar.gz
            cd Net-SSLeay-1.90
            #patch -p0 < ../NetSSLeay-SunOS-NoPrompt.patch
            cd ..

            build_module Net-SSLeay-1.90

            tar_wrapper zxf IO-Socket-SSL-2.069.tar.gz
            cd IO-Socket-SSL-2.069
            #patch -p0 < ../IOSocketSSL-NoPrompt-SunOS.patch
            cd ..

            build_module IO-Socket-SSL-2.069
	    
	    export PERL_MM_USE_DEFAULT=
	    ;;

        JSON::XS)
            build_module common-sense-3.75
	    export PERL_MM_USE_DEFAULT=1
            if [ $PERL_MINOR_VER -ge 18 ]; then
                build_module JSON-XS-4.02
            else
                build_module JSON-XS-2.3
            fi
	    export PERL_MM_USE_DEFAULT=
            ;;

        Linux::Inotify2)
            if [ "$OS" = "Linux" ]; then
                build_module common-sense-3.75
                build_module Linux-Inotify2-2.2
            fi
            ;;

        Locale::Hebrew)
            build_module Locale-Hebrew-1.05
            ;;

        Mac::FSEvents)
            if [ "$OS" = 'Darwin' ]; then
                build_module Mac-FSEvents-0.14 "" 0
            fi
            ;;

        Sub::Name)
            build_module Sub-Name-0.26
            ;;

        YAML::LibYAML)
            # Needed because LibYAML 0.35 used . in @INC (not permitted in Perl 5.26)
            # Needed for Debian's Perl 5.24 as well, for the same reason
            if [ $PERL_MINOR_VER -ge 24 ]; then
                build_module YAML-LibYAML-0.82
            elif [ $PERL_MINOR_VER -ge 16 ]; then
                build_module YAML-LibYAML-0.35 "" 0
            else
                build_module YAML-LibYAML-0.35
            fi
            ;;

        Audio::Scan)
            build_module Sub-Uplevel-0.2800 "" 0
            build_module Tree-DAG_Node-1.31 "" 0
            build_module Test-Warn-0.36 "" 0
            build_module Audio-Scan-1.02
            ;;

        MP3::Cut::Gapless)
            build_module Audio-Cuefile-Parser-0.02
            build_module MP3-Cut-Gapless-0.03
            ;;

        Template)
            # Template, custom build due to 2 Makefile.PL's
            tar_wrapper zxf Template-Toolkit-3.009.tar.gz
            cd Template-Toolkit-3.009
            cp -R ../hints .
            cp -R ../hints ./xs
            cd ..

            # minor test failure, so don't test
            build_module Template-Toolkit-3.009 "TT_ACCEPT=y TT_EXAMPLES=n TT_EXTRAS=n" 0

            ;;

        DBD::mysql)
            # Build libmysqlclient
            tar_wrapper zxf mysql-5.6.50.tar.gz
            cd mysql-5.6.50
            . ../update-config.sh
            CC=gcc CXX=gcc \
            CFLAGS="-O3 -fno-omit-frame-pointer $FLAGS $OSX_ARCH $OSX_FLAGS" \
            CXXFLAGS="-O3 -fno-omit-frame-pointer -felide-constructors -fno-exceptions -fno-rtti $FLAGS $OSX_ARCH $OSX_FLAGS" \
                ./configure --prefix=$BUILD \
                --disable-dependency-tracking \
                --enable-thread-safe-client \
                --without-server --disable-shared --without-docs --without-man
            make
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            make install
            cd ..
            rm -rf mysql-5.6.50

            # DBD::mysql custom, statically linked with libmysqlclient
            tar_wrapper zxf DBD-mysql-4.050.tar.gz
            cd DBD-mysql-4.050
            cp -R ../hints .
            mkdir mysql-static
            cp $BUILD/lib/mysql/libmysqlclient.a mysql-static
            cd ..

            build_module DBD-mysql-4.050 "--mysql_config=$BUILD/bin/mysql_config --libs=\"-Lmysql-static -lmysqlclient -lz -lm\""

            ;;

        XML::Parser)
            # build expat
            tar_wrapper zxf expat-2.2.10.tar.gz
            cd expat-2.2.10/conftools
            . ../../update-config.sh
            cd ..
            CFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS" \
            LDFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS" \
                ./configure --prefix=$BUILD \
                --disable-dependency-tracking
            $MAKE
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            $MAKE install
            cd ..

            # Symlink static versions of libraries to avoid OSX linker choosing dynamic versions
            cd build/lib
            ln -sf libexpat.a libexpat_s.a
            cd ../..

            # XML::Parser custom, built against expat
            tar_wrapper zxf XML-Parser-2.46.tar.gz
            cd XML-Parser-2.46
            cp -R ../hints .
            cp -R ../hints ./Expat # needed for second Makefile.PL
            patch -p0 < ../XML-Parser-Expat-Makefile.patch

            cd ..

            build_module XML-Parser-2.46 "EXPATLIBPATH=$BUILD/lib EXPATINCPATH=$BUILD/include"

            rm -rf expat-2.2.10
            ;;

        Font::FreeType)
            # build freetype
            tar_wrapper zxf freetype-2.10.4.tar.gz
            cd freetype-2.10.4
            . ../update-config.sh

            # Disable features we don't need for CODE2000
            cp -f ../freetype-ftoption.h objs/ftoption.h

            # Disable modules we don't need for CODE2000
            cp -f ../freetype-modules.cfg modules.cfg

            # libfreetype.a size (i386/x86_64 universal binary):
            #   1634288 (default)
            #    461984 (with custom ftoption.h/modules.cfg)
            CFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS" \
            LDFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS" \
                ./configure --prefix=$BUILD
            $MAKE # needed for FreeBSD to use gmake
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            $MAKE install
            cd ..

            # Symlink static version of library to avoid OSX linker choosing dynamic versions
            cd build/lib
            ln -sf libfreetype.a libfreetype_s.a
            cd ../..

            tar_wrapper zxf Font-FreeType-0.16.tar.gz
            cd Font-FreeType-0.16

            # Build statically
            patch -p0 < ../Font-FreeType-Makefile.patch

            # Disable some functions so we can compile out more freetype modules
            patch -p0 < ../Font-FreeType-lean.patch

            cp -R ../hints .
            cd ..

            build_module Font-FreeType-0.16

            rm -rf freetype-2.10.4
            ;;

        Media::Scan)
            build_ffmpeg
            build_libexif
            build_libjpeg
            build_libpng
            build_giflib
            build_bdb

            # build libmediascan
            # XXX library does not link correctly on Darwin with libjpeg due to missing x86_64
            # in libjpeg.dylib, Perl still links OK because it uses libjpeg.a
            tar_wrapper zxf libmediascan-devel.tar.gz

            cd libmediascan-devel

            . ../update-config.sh
			
			autoreconf -f -i
			
            CFLAGS="-I$BUILD/include $FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
            LDFLAGS="-L$BUILD/lib $FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
            OBJCFLAGS="-L$BUILD/lib $FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
                ./configure --prefix=$BUILD --disable-shared --disable-dependency-tracking
            $MAKE
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            $MAKE install
            cd ..

            # build Media::Scan
            cd libmediascan-devel/bindings/perl
            # LMS's hints file is OK and also has custom frameworks added

            MSOPTS="--with-static \
                --with-ffmpeg-includes=$BUILD/include \
                --with-lms-includes=$BUILD/include \
                --with-exif-includes=$BUILD/include \
                --with-jpeg-includes=$BUILD/include \
                --with-png-includes=$BUILD/include \
                --with-gif-includes=$BUILD/include \
                --with-bdb-includes=$BUILD/include"

            if [ $PERL_BIN ]; then
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
            rm -rf libmediascan-devel
            ;;
    esac
}

function build_libexif {
    if [ -f $BUILD/include/libexif/exif-data.h ]; then
        return
    fi

    # build libexif
    tar_wrapper xzf libexif-0.6.22.tar.gz
    cd libexif-0.6.22
    . ../update-config.sh

    CFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
    LDFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
        ./configure --prefix=$BUILD \
        --disable-dependency-tracking
    $MAKE
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install
    cd ..

    rm -rf libexif-0.6.22
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
    # skip on 10.9 until we've been able to build nasm from macports
    if [ "$OS" = "Darwin" -a "$OSX_VER" != "10.5" ]; then
        # Build i386/x86_64 versions of turbo
        tar_wrapper zxf $TURBO_VER.tar.gz
        cd $TURBO_VER

        # Disable features we don't need
        patch -p0 < ../libjpeg-turbo-jmorecfg.h.patch

        # Build 64-bit fork
        CFLAGS="-O3 $OSX_FLAGS" \
        CXXFLAGS="-O3 $OSX_FLAGS" \
        LDFLAGS="$OSX_FLAGS" \
            ./configure --prefix=$BUILD --host x86_64-apple-darwin NASM=/usr/local/bin/nasm \
            --disable-dependency-tracking
        $MAKE
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi
        cp -f .libs/libjpeg.a libjpeg-x86_64.a

        # Build 32-bit fork
        if [ $CLEAN -eq 1 ]; then
            $MAKE clean
        fi
        CFLAGS="-O3 -m32 $OSX_FLAGS" \
        CXXFLAGS="-O3 -m32 $OSX_FLAGS" \
        LDFLAGS="-m32 $OSX_FLAGS" \
            ./configure --prefix=$BUILD NASM=/usr/local/bin/nasm \
            --disable-dependency-tracking
        $MAKE
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi
        cp -f .libs/libjpeg.a libjpeg-i386.a

        # Combine the forks
        lipo -create libjpeg-x86_64.a libjpeg-i386.a -output libjpeg.a

        # Install and replace libjpeg.a with universal version
        $MAKE install
        cp -f libjpeg.a $BUILD/lib/libjpeg.a
        cd ..

    elif [ "$OS" = "Darwin" -a "$OSX_VER" = "10.5" ]; then
        # combine i386 turbo with ppc libjpeg

        # build i386 turbo
        tar_wrapper zxf $TURBO_VER.tar.gz
        cd $TURBO_VER

        CFLAGS="-O3 -m32 $OSX_FLAGS" \
        CXXFLAGS="-O3 -m32 $OSX_FLAGS" \
        LDFLAGS="-m32 $OSX_FLAGS" \
            ./configure --prefix=$BUILD NASM=/usr/local/bin/nasm \
            --disable-dependency-tracking
        $MAKE
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi
        $MAKE install
        cp -f .libs/libjpeg.a ../libjpeg-i386.a
        cd ..

        # build ppc libjpeg 6b
        tar_wrapper zxf jpegsrc.v9d.tar.gz
        cd jpeg-9d

        # Disable features we don't need
        cp -f ../libjpeg62-jmorecfg.h jmorecfg.h

        CFLAGS="-arch ppc -O3 $OSX_FLAGS" \
        LDFLAGS="-arch ppc -O3 $OSX_FLAGS" \
            ./configure --prefix=$BUILD \
            --disable-dependency-tracking
        $MAKE
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi
        cp -f libjpeg.a ../libjpeg-ppc.a
        cd ..

        # Combine the forks
        lipo -create libjpeg-i386.a libjpeg-ppc.a -output libjpeg.a

        # Replace libjpeg library
        mv -fv libjpeg.a $BUILD/lib/libjpeg.a
        rm -fv libjpeg-i386.a libjpeg-ppc.a

    elif [[ "$ARCH" =~ ^(i[3456]86-linux|x86_64-linux|i86pc-solaris).*$ || "$OS" == "FreeBSD" ]]; then
        # build libjpeg-turbo
        tar_wrapper zxf $TURBO_VER.tar.gz
        cd $TURBO_VER

        CFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS" CXXFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS" LDFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS" \
            ./configure --prefix=$BUILD --disable-dependency-tracking
        $MAKE
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi

        $MAKE install
        cd ..

    # build libjpeg v8 on other platforms
    else
        tar_wrapper zxf jpegsrc.v9d.tar.gz
        cd jpeg-9d
        . ../update-config.sh

        CFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
        LDFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
            ./configure --prefix=$BUILD \
            --disable-dependency-tracking
        $MAKE
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi
        $MAKE install
        cd ..
    fi

    rm -rf jpeg-9d
    rm -rf $TURBO_VER
}

function build_libpng {
    if [ -f $BUILD/include/png.h ]; then
        return
    fi

    # build libpng
    LIBPNG_VER="libpng-1.6.37"
    tar_wrapper zxf $LIBPNG_VER.tar.gz
    cd $LIBPNG_VER

    # Disable features we don't need
    cp -f ../libpng-pngusr.dfa pngusr.dfa
    . ../update-config.sh

    CFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
    LDFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
        ./configure --prefix=$BUILD \
        --disable-dependency-tracking
    $MAKE && $MAKE check
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install
    cd ..

    rm -rf $LIBPNG_VER
}

function build_giflib {
    if [ -f $BUILD/include/gif_lib.h ]; then
        return
    fi

    # build giflib
    tar_wrapper zxf giflib-5.2.1.tar.gz
    cd giflib-5.2.1
    . ../update-config.sh
	
	old="PREFIX = /usr/local"
	new="PREFIX = ${BUILD}"
	sed -i "" "s#$old#$new#g" Makefile
    CFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
    LDFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
        ./configure --prefix=$BUILD \
        --disable-dependency-tracking
    $MAKE
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install
    cd ..

    rm -rf giflib-5.2.1
}

function build_ffmpeg {
    echo "build ffmpeg"
    if [ -f $BUILD/include/libavformat/avformat.h ]; then
        echo "found avformat.h - returning"
        return
    fi

    # build ffmpeg, enabling only the things libmediascan uses
    tar_wrapper xzf FFmpeg-n4.3.1.tar.gz
    cd FFmpeg-n4.3.1
    . ../update-config.sh

    echo "Configuring FFmpeg..."

    # x86: Disable all but the lowend MMX ASM
    # ARM: Disable all
    # PPC: Disable AltiVec
    FFOPTS="--prefix=$BUILD --disable-ffmpeg --disable-ffplay --disable-ffprobe \
        --disable-avdevice --enable-pic \
        --disable-amd3dnow --disable-amd3dnowext  \
        --disable-armv5te --disable-armv6 --disable-armv6t2 --disable-mmi --disable-neon \
        --disable-altivec \
        --enable-zlib --disable-bzlib \
        --disable-everything --enable-swscale \
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
        --enable-protocol=file --cc=$GCC"

    # ASM doesn't work right on x86_64
    # XXX test --arch options on Linux
    if [[ "$ARCH" = "x86_64-linux-thread-multi" || "$ARCH" =~ "amd64-freebsd" || "$ARCH" = "i86pc-solaris-thread-multi-64int" ]]; then
        FFOPTS="$FFOPTS --disable-mmx"
    fi
    # FreeBSD amd64 needs arch option
    if [[ "$ARCH" =~ "amd64-freebsd" ]]; then
        FFOPTS="$FFOPTS --arch=x86"
        # FFMPEG has known issues with GCC 4.2. See: https://trac.ffmpeg.org/ticket/3970
        if [[ "$CC_IS_GCC" == true && "$CC_VERSION" -ge 40200 && "$CC_VERSION" -lt 40300 ]]; then
            FFOPTS="$FFOPTS --disable-asm"
        fi
    fi

    if [ "$OS" = "Darwin" ]; then
        SAVED_FLAGS=$FLAGS

        # Build 64-bit fork (10.6/10.7)
        if [ "$OSX_VER" != "10.5" ]; then
            FLAGS="-arch x86_64 -O3 -fPIC $OSX_FLAGS"
            CFLAGS="$FLAGS" \
            LDFLAGS="$FLAGS" \
                ./configure $FFOPTS --arch=x86_64

            $MAKE
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi

            cp -f libavcodec/libavcodec.a libavcodec-x86_64.a
            cp -f libavformat/libavformat.a libavformat-x86_64.a
            cp -f libavutil/libavutil.a libavutil-x86_64.a
            cp -f libswscale/libswscale.a libswscale-x86_64.a
        fi

        # Build 32-bit fork (all OSX versions)
        $MAKE clean
        FLAGS="-arch i386 -O3 $OSX_FLAGS"
        CFLAGS="$FLAGS" \
        LDFLAGS="$FLAGS" \
            ./configure $FFOPTS --arch=x86_32

        $MAKE
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi

        cp -f libavcodec/libavcodec.a libavcodec-i386.a
        cp -f libavformat/libavformat.a libavformat-i386.a
        cp -f libavutil/libavutil.a libavutil-i386.a
        cp -f libswscale/libswscale.a libswscale-i386.a

        # Build PPC fork (10.5)
        if [ "$OSX_VER" = "10.5" ]; then
            $MAKE clean
            FLAGS="-arch ppc -O3 $OSX_FLAGS"
            CFLAGS="$FLAGS" \
            LDFLAGS="$FLAGS" \
                ./configure $FFOPTS --arch=ppc --disable-altivec

            $MAKE
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi

            cp -f libavcodec/libavcodec.a libavcodec-ppc.a
            cp -f libavformat/libavformat.a libavformat-ppc.a
            cp -f libavutil/libavutil.a libavutil-ppc.a
            cp -f libswscale/libswscale.a libswscale-ppc.a
        fi

        # Combine the forks
        if [ "$OSX_VER" = "10.5" ]; then
            lipo -create libavcodec-i386.a libavcodec-ppc.a -output libavcodec.a
            lipo -create libavformat-i386.a libavformat-ppc.a -output libavformat.a
            lipo -create libavutil-i386.a libavutil-ppc.a -output libavutil.a
            lipo -create libswscale-i386.a libswscale-ppc.a -output libswscale.a
        else
            lipo -create libavcodec-x86_64.a libavcodec-i386.a -output libavcodec.a
            lipo -create libavformat-x86_64.a libavformat-i386.a -output libavformat.a
            lipo -create libavutil-x86_64.a libavutil-i386.a -output libavutil.a
            lipo -create libswscale-x86_64.a libswscale-i386.a -output libswscale.a
        fi

        # Install and replace libs with universal versions
        $MAKE install
        cp -f libavcodec.a $BUILD/lib/libavcodec.a
        cp -f libavformat.a $BUILD/lib/libavformat.a
        cp -f libavutil.a $BUILD/lib/libavutil.a
        cp -f libswscale.a $BUILD/lib/libswscale.a

        FLAGS=$SAVED_FLAGS
        cd ..
    else
        CFLAGS="$FLAGS -O3" \
        LDFLAGS="$FLAGS -O3" \
            ./configure $FFOPTS

        $MAKE
        if [ $? != 0 ]; then
            echo "make failed"
            exit $?
        fi
        $MAKE install
        cd ..
    fi

    rm -rf FFmpeg-n4.3.1
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
    tar_wrapper zxf db-5.3.28.tar.gz
    cd db-5.3.28/dist
    . ../../update-config.sh
    cd ../build_unix

    if [ "$OS" = "Darwin" -o "$OS" = "FreeBSD" ]; then
       pushd ..
       patch -p0 < ../db51-src_dbinc_atomic.patch
       popd
    fi
    CFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
    LDFLAGS="$FLAGS $OSX_ARCH $OSX_FLAGS -O3" \
        ../dist/configure --prefix=$BUILD $MUTEX \
        --with-cryptography=no -disable-hash --disable-queue --disable-replication --disable-statistics --disable-verify \
        --disable-dependency-tracking --disable-shared
    $MAKE
    if [ $? != 0 ]; then
        echo "make failed"
        exit $?
    fi
    $MAKE install
    cd ../..

    rm -rf db-5.3.28
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
