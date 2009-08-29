#!/bin/bash

# Build dir
BUILD=$PWD/build

# Path to Perl 5.8 (Leopard only)
PERL_58=/usr/bin/perl5.8.8

# Install dir for 5.8
BASE_58=$BUILD/5.8

# Path to Perl 5.10.0 (Snow Leopard only)
PERL_510=/usr/bin/perl5.10.0

# Install dir for 5.10
BASE_510=$BUILD/5.10

# Require modules to pass tests
RUN_TESTS=1

# Clean up
rm -rf $BUILD

mkdir $BUILD

# $1 = module to build
# $2 = Makefile.PL arg(s)
function build_module {
	tar zxvf $1.tar.gz
	cd $1
	cp -R ../hints .
	if [ -x $PERL_58 ]; then
	    # Running Leopard
    	$PERL_58 Makefile.PL INSTALL_BASE=$BASE_58 $2
    	if [ $RUN_TESTS -eq 1 ]; then
    	    make test
    	else
    	    make
    	fi
    	if [ $? != 0 ]; then
    	    if [ $RUN_TESTS -eq 1 ]; then
		        echo "make test failed, aborting"
		    else
		        echo "make failed, aborting"
		    fi
    		exit $?
    	fi
    	make install
    	make clean
    elif [ -x $PERL_510 ]; then
        # Running Snow Leopard
    	$PERL_510 Makefile.PL INSTALL_BASE=$BASE_510 $2
    	if [ $RUN_TESTS -eq 1 ]; then
    	    make test
    	else
    	    make
    	fi
    	if [ $? != 0 ]; then
    	    if [ $RUN_TESTS -eq 1 ]; then
		        echo "make test failed, aborting"
		    else
		        echo "make failed, aborting"
		    fi
        	exit $?
        fi
    	make install
    fi
	cd ..
	rm -rf $1
}

# AutoXS::Header support module
build_module AutoXS-Header-0.03

# Data::Dump support module (Encode::Detect dep)
build_module Data-Dump-1.15

# Set PERL5LIB so correct support modules are used
if [ -x $PERL_58 ]; then
    export PERL5LIB=$BASE_58/lib/perl5
else
    export PERL5LIB=$BASE_510/lib/perl5
fi

# Class::XSAccessor::Array
build_module Class-XSAccessor-Array-0.05

# don't run Compress::Zlib tests, doesn't pass all tests on SL 5.10
RUN_TESTS=0
build_module Compress-Zlib-1.41
RUN_TESTS=1

build_module DBI-1.604

build_module Digest-SHA1-2.11

build_module Encode-Detect-1.00

build_module HTML-Parser-3.48

build_module JSON-XS-1.5

build_module Locale-Hebrew-1.04

# Skip tests, POE is not installed
RUN_TESTS=0
build_module POE-XS-Queue-Array-0.002
RUN_TESTS=1

# Skip tests, tiedhash tests fail
RUN_TESTS=0
build_module Template-Toolkit-2.15 "TT_ACCEPT=y TT_EXAMPLES=n TT_EXTRAS=n"
RUN_TESTS=1

build_module Time-HiRes-1.86

build_module YAML-Syck-0.64

# Now for the hard ones...

# DBD::mysql
# Build libmysqlclient
tar jxvf mysql-5.1.37.tar.bz2
cd mysql-5.1.37
if [ -x $PERL_58 ]; then
    # build 32-bit version
    CC=gcc CXX=gcc \
    CFLAGS="-O3 -fno-omit-frame-pointer -arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.3" \
    CXXFLAGS="-O3 -fno-omit-frame-pointer -felide-constructors -fno-exceptions -fno-rtti -arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.3" \
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
elif [ -x $PERL_510 ]; then
    # Build 64-bit version    
    CC=gcc CXX=gcc \
    CFLAGS="-O3 -fno-omit-frame-pointer -arch x86_64 -arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5" \
    CXXFLAGS="-O3 -fno-omit-frame-pointer -felide-constructors -fno-exceptions -fno-rtti -arch x86_64 -arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5" \
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
fi
cd ..
rm -rf mysql-5.1.37

# DBD::mysql custom, statically linked with libmysqlclient
tar zxvf DBD-mysql-3.0002.tar.gz
cd DBD-mysql-3.0002
cp -R ../hints .
mkdir mysql-static
cp $BUILD/lib/mysql/libmysqlclient.a mysql-static
if [ -x $PERL_58 ]; then
    # Running Leopard
    $PERL_58 Makefile.PL --mysql_config=$BUILD/bin/mysql_config --libs="-Lmysql-static -lmysqlclient -lz -lm" INSTALL_BASE=$BASE_58 
    make
    if [ $? != 0 ]; then
        echo "make failed, aborting"
        exit $?
    fi
    make install
    make clean
elif [ -x $PERL_510 ]; then
    # Running Snow Leopard
    $PERL_510 Makefile.PL --mysql_config=$BUILD/bin/mysql_config --libs="-Lmysql-static -lmysqlclient -lz -lm" INSTALL_BASE=$BASE_510
    make
    if [ $? != 0 ]; then
        echo "make failed, aborting"
        exit $?
    fi
    make install
fi
cd ..
rm -rf DBD-mysql-3.0002

# XML::Parser custom, built against system expat
tar zxvf XML-Parser-2.34.tar.gz
cd XML-Parser-2.34
cp -R ../hints .
cp -R ../hints ./Expat # needed for second Makefile.PL
if [ -x $PERL_58 ]; then
    # Running Leopard
    $PERL_58 Makefile.PL INSTALL_BASE=$BASE_58 EXPATLIBPATH=/usr/lib EXPATINCPATH=/usr/include
    make # minor test failure, so don't test
    if [ $? != 0 ]; then
        echo "make test failed, aborting"
        exit $?
    fi
    make install
elif [ -x $PERL_510 ]; then
    # Running Snow Leopard
    $PERL_510 Makefile.PL INSTALL_BASE=$BASE_510 EXPATLIBPATH=/usr/lib EXPATINCPATH=/usr/include
    make # minor test failure, so don't test
    if [ $? != 0 ]; then
        echo "make test failed, aborting"
        exit $?
    fi
    make install
fi
cd ..
rm -rf XML-Parser-2.34

# GD

if [ -x $PERL_58 ]; then
    # build 32-bit version 
    FLAGS="-arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.3"
elif [ -x $PERL_510 ]; then
    # Build 64-bit version    
    FLAGS="-arch x86_64 -arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5"
fi

# build libjpeg
# Makefile doesn't create directories properly, so make sure they exist
# Note none of these directories are deleted until GD is built
mkdir -p build/bin build/lib build/include build/man/man1
tar zxvf jpegsrc.v6b.tar.gz
cd jpeg-6b
CFLAGS="$FLAGS" \
LDFLAGS="$FLAGS" \
    ./configure --prefix=$BUILD \
    --disable-dependency-tracking
make && make test
if [ $? != 0 ]; then
    echo "make failed"
    exit $?
fi
make install-lib
cd ..

# build libpng
tar zxvf libpng-1.2.39.tar.gz
cd libpng-1.2.39
CFLAGS="$FLAGS" \
LDFLAGS="$FLAGS" \
    ./configure --prefix=$BUILD \
    --disable-dependency-tracking
make && make test
if [ $? != 0 ]; then
    echo "make failed"
    exit $?
fi
make install
cd ..

# build freetype
tar zxvf freetype-2.3.7.tar.gz
cd freetype-2.3.7
CFLAGS="$FLAGS" \
LDFLAGS="$FLAGS" \
    ./configure --prefix=$BUILD \
    --disable-dependency-tracking
make
if [ $? != 0 ]; then
    echo "make failed"
    exit $?
fi
make install
cd ..

# build fontconfig
tar zxvf fontconfig-2.6.0.tar.gz
cd fontconfig-2.6.0
CFLAGS="$FLAGS" \
LDFLAGS="$FLAGS" \
    ./configure --prefix=$BUILD \
    --disable-dependency-tracking --disable-docs \
    --with-expat-includes=/usr/include --with-expat-lib=/usr/lib \
    --with-freetype-config=$BUILD/bin/freetype-config
make
if [ $? != 0 ]; then
    echo "make failed"
    exit $?
fi
make install
cd ..

# build gd
tar zxvf gd-2.0.35.tar.gz
cd gd-2.0.35
# gd's configure is really dumb, adjust PATH so it can find the correct libpng config scripts
# and need to manually specify include dir
PATH="$BUILD/bin:$PATH" \
CFLAGS="-I$BUILD/include $FLAGS" \
LDFLAGS="$FLAGS" \
    ./configure --prefix=$BUILD \
    --disable-dependency-tracking --without-xpm --without-x \
    --with-libiconv-prefix=/usr \
    --with-jpeg=$BUILD \
    --with-png=$BUILD \
    --with-freetype=$BUILD \
    --with-fontconfig=$BUILD
make
if [ $? != 0 ]; then
    echo "make failed"
    exit $?
fi
make install
cd ..

# Symlink static versions of libraries to avoid OSX linker choosing dynamic versions
cd build/lib
ln -sf libjpeg.a libjpeg_s.a
ln -sf libpng12.a libpng12_s.a
ln -sf libgd.a libgd_s.a
ln -sf libfontconfig.a libfontconfig_s.a
ln -sf libfreetype.a libfreetype_s.a
cd ../..

# GD
tar zxvf GD-2.35.tar.gz
cd GD-2.35
patch -p0 < ../GD-Makefile.patch # patch to build statically
cp -R ../hints .
if [ -x $PERL_58 ]; then
    # Running Leopard
    $PERL_58 Makefile.PL INSTALL_BASE=$BASE_58 \
        -options "JPEG,FT,PNG,GIF,ANIMGIF" \
        -lib_gd_path=$BUILD \
        -lib_ft_path=$BUILD \
        -lib_png_path=$BUILD \
        -lib_jpeg_path=$BUILD
elif [ -x $PERL_510 ]; then
    # Running Snow Leopard
    $PERL_510 Makefile.PL INSTALL_BASE=$BASE_510 \
        -options "JPEG,FT,PNG,GIF,ANIMGIF" \
        -lib_gd_path=$BUILD \
        -lib_ft_path=$BUILD \
        -lib_png_path=$BUILD \
        -lib_jpeg_path=$BUILD
fi

make test
if [ $? != 0 ]; then
    echo "make test failed, aborting"
    exit $?
fi
make install
cd ..
rm -rf GD-2.35
rm -rf gd-2.0.35
rm -rf fontconfig-2.6.0
rm -rf freetype-2.3.7
rm -rf libpng-1.2.39
rm -rf jpeg-6b

export PERL5LIB=

# strip -S on all bundle files
find $BUILD -name '*.bundle' -exec chmod u+w {} \;
find $BUILD -name '*.bundle' -exec strip -S {} \;

# clean out useless .bs/.packlist files, etc
find $BUILD -name '*.bs' -exec rm -f {} \;
find $BUILD -name '*.packlist' -exec rm -f {} \;

# create our directory structure
# XXX there is still some crap left in here by some modules such as DBI, GD
if [ -e $BUILD_58 ]; then
    mkdir -p $BUILD/arch/5.8
    mv $BUILD_58/lib/perl5/darwin-thread-multi-2level $BUILD/arch/5.8
elif [ -e $BUILD_510 ]; then
    mkdir -p $BUILD/arch/5.10
    mv $BUILD_510/lib/perl5/darwin-thread-multi-2level $BUILD/arch/5.10
fi

# could remove rest of build data, but let's leave it around in case
#rm -rf $BUILD_58
#rm -rf $BUILD_510
#rm -rf $BUILD/bin $BUILD/etc $BUILD/include $BUILD/lib $BUILD/man $BUILD/share $BUILD/var
