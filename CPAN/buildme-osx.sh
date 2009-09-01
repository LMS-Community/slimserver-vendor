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

if [ -x $PERL_58 ]; then
    # build 32-bit version 
    FLAGS="-arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.3"
elif [ -x $PERL_510 ]; then
    # Build 64-bit version    
    FLAGS="-arch x86_64 -arch i386 -isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5"
fi

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

function build_all {
    build Audio::Scan
    build AutoXS::Header
    build Data::Dump
    build Class::C3::XS
    build Class::XSAccessor
    build Class::XSAccessor::Array
    build Compress::Raw::Zlib
    build DBI
    build DBD::mysql
    build Digest::SHA1
    build EV
    build Encode::Detect
    build GD
    build HTML::Parser
    build JSON::XS
    build Locale::Hebrew
    build Sub::Name
    build Template
    build Time::HiRes
    build XML::Parser
    build YAML::Syck
}

function build {
    case "$1" in
        AutoXS::Header)
            # AutoXS::Header support module
            build_module AutoXS-Header-1.02
            ;;
            
        Data::Dump)
            # Data::Dump support module (Encode::Detect dep)
            build_module Data-Dump-1.15
            ;;
        
        Class::C3::XS)
            if [ -x $PERL_58 ]; then
                build_module Class-C3-XS-0.11
            fi
            ;;
        
        Class::XSAccessor)
            build_module Class-XSAccessor-1.03
            ;;
        
        Class::XSAccessor::Array)
            build_module Class-XSAccessor-Array-1.04
            ;;
        
        Compress::Raw::Zlib)
            build_module Compress-Raw-Zlib-2.017
            ;;
        
        DBI)
            build_module DBI-1.608
            ;;
        
        Digest::SHA1)
            build_module Digest-SHA1-2.11
            ;;
        
        EV)
            export PERL_MM_USE_DEFAULT=1
            build_module EV-3.6
            export PERL_MM_USE_DEFAULT=
            ;;
        
        Encode::Detect)
            build_module Encode-Detect-1.00
            ;;
        
        HTML::Parser)
            build_module HTML-Parser-3.60
            ;;
        
        JSON::XS)
            build_module JSON-XS-2.232
            ;;
        
        Locale::Hebrew)
            build_module Locale-Hebrew-1.04
            ;;
        
        Sub::Name)
            build_module Sub-Name-0.04
            ;;
        
        Time::HiRes)
            build_module Time-HiRes-1.86
            ;;
        
        YAML::Syck)
            build_module YAML-Syck-1.05
            ;;
        
        Audio::Scan)
            # Build libFLAC
            tar zxvf flac-1.2.1.tar.gz
            cd flac-1.2.1
            CFLAGS="$FLAGS" \
            LDFLAGS="$FLAGS" \
                ./configure --prefix=$BUILD \
                --disable-dependency-tracking --disable-shared \
                --disable-asm-optimizations --disable-xmms-plugin --disable-cpplibs --disable-ogg --disable-doxygen-docs
            make
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            make install
            cd ..
            rm -rf flac-1.2.1

            build_module Audio-Scan-0.31 "--with-flac-includes=$BUILD/include --with-flac-libs=$BUILD/lib --with-flac-static"
            ;;
        
        Template)
            # Template, custom build due to 2 Makefile.PL's
            tar zxvf Template-Toolkit-2.21.tar.gz
            cd Template-Toolkit-2.21
            cp -R ../hints .
            cp -R ../hints ./xs
            if [ -x $PERL_58 ]; then
                # Running Leopard
                $PERL_58 Makefile.PL INSTALL_BASE=$BASE_58 TT_ACCEPT=y TT_EXAMPLES=n TT_EXTRAS=n
                make # minor test failure, so don't test
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
            elif [ -x $PERL_510 ]; then
                # Running Snow Leopard
                $PERL_510 Makefile.PL INSTALL_BASE=$BASE_510 TT_ACCEPT=y TT_EXAMPLES=n TT_EXTRAS=n
                make # minor test failure, so don't test
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
            fi
            cd ..
            rm -rf Template-Toolkit-2.21
            ;;
        
        DBD::mysql)
            # Build libmysqlclient
            tar jxvf mysql-5.1.37.tar.bz2
            cd mysql-5.1.37
            CC=gcc CXX=gcc \
            CFLAGS="-O3 -fno-omit-frame-pointer $FLAGS" \
            CXXFLAGS="-O3 -fno-omit-frame-pointer -felide-constructors -fno-exceptions -fno-rtti $FLAGS" \
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
            ;;
        
        XML::Parser)
            # XML::Parser custom, built against system expat
            tar zxvf XML-Parser-2.36.tar.gz
            cd XML-Parser-2.36
            cp -R ../hints .
            cp -R ../hints ./Expat # needed for second Makefile.PL
            if [ -x $PERL_58 ]; then
                # Running Leopard
                $PERL_58 Makefile.PL INSTALL_BASE=$BASE_58 EXPATLIBPATH=/usr/lib EXPATINCPATH=/usr/include
                make # minor test failure, so don't test
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
            elif [ -x $PERL_510 ]; then
                # Running Snow Leopard
                $PERL_510 Makefile.PL INSTALL_BASE=$BASE_510 EXPATLIBPATH=/usr/lib EXPATINCPATH=/usr/include
                make # minor test failure, so don't test
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
            fi
            cd ..
            rm -rf XML-Parser-2.36
            ;;
        
        GD)
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
            tar zxvf GD-2.41.tar.gz
            cd GD-2.41
            patch -p0 < ../GD-Makefile.patch # patch to build statically
            cp -R ../hints .
            if [ -x $PERL_58 ]; then
                # Running Leopard
                PATH="$BUILD/bin:$PATH" \
                    $PERL_58 Makefile.PL INSTALL_BASE=$BASE_58
            elif [ -x $PERL_510 ]; then
                # Running Snow Leopard
                PATH="$BUILD/bin:$PATH" \
                    $PERL_510 Makefile.PL INSTALL_BASE=$BASE_510
            fi

            make test
            if [ $? != 0 ]; then
                echo "make test failed, aborting"
                exit $?
            fi
            make install
            cd ..
            rm -rf GD-2.41
            rm -rf gd-2.0.35
            rm -rf fontconfig-2.6.0
            rm -rf freetype-2.3.7
            rm -rf libpng-1.2.39
            rm -rf jpeg-6b
            ;;
    esac
}

# Set PERL5LIB so correct support modules are used
if [ -x $PERL_58 ]; then
    export PERL5LIB=$BASE_58/lib/perl5
else
    export PERL5LIB=$BASE_510/lib/perl5
fi

# Build a single module if requested, or all
if [ $1 ]; then
    build $1
else
    build_all
fi

# Reset PERL5LIB
export PERL5LIB=

# strip -S on all bundle files
find $BUILD -name '*.bundle' -exec chmod u+w {} \;
find $BUILD -name '*.bundle' -exec strip -S {} \;

# clean out useless .bs/.packlist files, etc
find $BUILD -name '*.bs' -exec rm -f {} \;
find $BUILD -name '*.packlist' -exec rm -f {} \;

# create our directory structure
# XXX there is still some crap left in here by some modules such as DBI, GD
if [ -x $PERL_58 ]; then
    mkdir -p $BUILD/arch/5.8
    cp -R $BASE_58/lib/perl5/darwin-thread-multi-2level $BUILD/arch/5.8
elif [ -x $PERL_510 ]; then
    mkdir -p $BUILD/arch/5.10
    cp -R $BASE_510/lib/perl5/darwin-thread-multi-2level $BUILD/arch/5.10
fi

# could remove rest of build data, but let's leave it around in case
#rm -rf $BASE_58
#rm -rf $BASE_510
#rm -rf $BUILD/bin $BUILD/etc $BUILD/include $BUILD/lib $BUILD/man $BUILD/share $BUILD/var
