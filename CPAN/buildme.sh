#!/bin/bash
#
# $Id$
#
# This script builds all binary Perl modules required by Squeezebox Server.
# 
# Supported OSes:
#
# Linux (Perl 5.8.8, 5.10.0, 5.12.1)
#   i386/x86_64 Linux
#   ARM Linux
#   PowerPC Linux
# Mac OSX 10.5, 10.6, (Perl 5.8.8 & 5.10.0)
#   Under 10.5, builds Universal Binaries for i386/ppc
#   Under 10.6, builds Universal Binaries for i386/x86_64
# FreeBSD 7.2 (Perl 5.8.9)

OS=`uname`

# get system arch, stripping out extra -gnu on Linux
ARCH=`/usr/bin/perl -MConfig -le 'print $Config{archname}' | sed 's/gnu-//' | sed 's/^i[3456]86-/i386-/' `

if [ $OS = "Linux" -o $OS = "Darwin" -o $OS = "FreeBSD" ]; then
    echo "Building for $OS / $ARCH"
else
    echo "Unsupported platform: $OS, please submit a patch or provide us with access to a development system."
    exit
fi

# Build dir
BUILD=$PWD/build

# Path to Perl 5.8.8
if [ -x "/usr/bin/perl5.8.8" ]; then
    PERL_58=/usr/bin/perl5.8.8
elif [ -x "/usr/local/bin/perl5.8.8" ]; then
    PERL_58=/usr/local/bin/perl5.8.8
elif [ -x "/usr/local/bin/perl5.8.9" ]; then # FreeBSD 7.2
    PERL_58=/usr/local/bin/perl5.8.9
fi

if [ $PERL_58 ]; then
    echo "Building with Perl 5.8.x at $PERL_58"
fi

# Install dir for 5.8
BASE_58=$BUILD/5.8

# Path to Perl 5.10.0
if [ -x "/usr/bin/perl5.10.0" ]; then
    PERL_510=/usr/bin/perl5.10.0
elif [ -x "/usr/local/bin/perl5.10.0" ]; then
    PERL_510=/usr/local/bin/perl5.10.0
fi

if [ $PERL_510 ]; then
    echo "Building with Perl 5.10 at $PERL_510"
fi

# Install dir for 5.10
BASE_510=$BUILD/5.10

# Path to Perl 5.12.1
if [ -x "/usr/bin/perl5.12.1" ]; then
    PERL_512=/usr/bin/perl5.12.1
elif [ -x "/usr/local/bin/perl5.12.1" ]; then
    PERL_512=/usr/local/bin/perl5.12.1
fi

if [ $PERL_512 ]; then
    echo "Building with Perl 5.12 at $PERL_512"
fi

# Install dir for 5.12
BASE_512=$BUILD/5.12

# Require modules to pass tests
RUN_TESTS=1

USE_HINTS=1

FLAGS="-fPIC"
# Mac-specific flags
if [ $OS = "Darwin" ]; then
    if [ $PERL_58 ]; then
        # build 32-bit version 
        FLAGS="-arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.3"
    elif [ $PERL_510 ]; then
        # Build 64-bit version    
        FLAGS="-arch x86_64 -arch i386 -isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5"
    fi
fi

# Enable fPIC on 64-bit Linux
if [ $ARCH = "x86_64-linux-thread-multi" ]; then
    FLAGS="-fPIC"
fi

# FreeBSD's make sucks
if [ $OS = "FreeBSD" ]; then
    if [ !-x /usr/local/bin/gmake ]; then
        echo "ERROR: Please install GNU make (gmake)"
        exit
    fi
    export GNUMAKE=/usr/local/bin/gmake
    export MAKE=/usr/local/bin/gmake
else
    export MAKE=/usr/bin/make
fi

# Clean up
# XXX command-line flag to skip cleanup
rm -rf $BUILD

mkdir $BUILD

# $1 = module to build
# $2 = Makefile.PL arg(s)
function build_module {
    tar zxvf $1.tar.gz
    cd $1
    if [ $USE_HINTS -eq 1 ]; then
        if [ ! -f hints/darwin.pl ]; then
            cp -R ../hints .
        fi
    fi
    if [ $PERL_58 ]; then
        # Running 5.8
        export PERL5LIB=$BASE_58/lib/perl5
        
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
    fi
    if [ $PERL_510 ]; then
        # Running 5.10
        export PERL5LIB=$BASE_510/lib/perl5
        
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
    if [ $PERL_512 ]; then
        # Running 5.12
        export PERL5LIB=$BASE_512/lib/perl5

        $PERL_512 Makefile.PL INSTALL_BASE=$BASE_512 $2
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
    build Class::C3::XS
    build Class::XSAccessor
    build Compress::Raw::Zlib
    build DBI
    build DBD::mysql
    build DBD::SQLite
    build Digest::SHA1
    build EV
    build Encode::Detect
    build Font::FreeType
    build HTML::Parser
    build Image::Scale
    build IO::AIO
    build JSON::XS
    build Linux::Inotify2
    build Locale::Hebrew
    build Mac::FSEvents
    build MP3::Cut::Gapless
    build Sub::Name
    build Template
    build XML::Parser
    build YAML::Syck
}

function build {
    case "$1" in
        Class::C3::XS)
            if [ $PERL_58 ]; then
                tar zxvf Class-C3-XS-0.11.tar.gz
                cd Class-C3-XS-0.11
                patch -p0 < ../Class-C3-XS-no-ckWARN.patch
                cp -R ../hints .
                export PERL5LIB=$BASE_58/lib/perl5

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
                cd ..
                rm -rf Class-C3-XS-0.11
            fi
            ;;
        
        Class::XSAccessor)
            build_module Class-XSAccessor-1.05
            ;;
        
        Compress::Raw::Zlib)
            build_module Compress-Raw-Zlib-2.017
            ;;
        
        DBI)
            build_module DBI-1.608
            ;;
        
        DBD::SQLite)
            RUN_TESTS=0
            build_module DBI-1.608
            RUN_TESTS=1
            build_module DBD-SQLite-1.30_06
            ;;
        
        Digest::SHA1)
            build_module Digest-SHA1-2.11
            ;;
        
        EV)
            build_module common-sense-2.0

            # custom build to apply pthread patch
            export PERL_MM_USE_DEFAULT=1
            
            tar zxvf EV-3.9.tar.gz
            cd EV-3.9
            if [ $OS = "Darwin" ]; then
                if [ $PERL_58 ]; then
                    patch -p0 < ../EV-fixes.patch # patch to disable pthreads and one call to SvREADONLY
                fi
            fi
            cp -R ../hints .
            if [ $PERL_58 ]; then
                # Running 5.8
                export PERL5LIB=$BASE_58/lib/perl5

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
            fi
            if [ $PERL_510 ]; then
                # Running 5.10
                export PERL5LIB=$BASE_510/lib/perl5

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
            if [ $PERL_512 ]; then
                # Running 5.12
                export PERL5LIB=$BASE_512/lib/perl5

                $PERL_512 Makefile.PL INSTALL_BASE=$BASE_512 $2
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
            rm -rf EV-3.9
            
            export PERL_MM_USE_DEFAULT=
            ;;
        
        Encode::Detect)
            build_module Data-Dump-1.15
            build_module ExtUtils-CBuilder-0.260301
            RUN_TESTS=0
            build_module Module-Build-0.35
            RUN_TESTS=1
            build_module Encode-Detect-1.00
            ;;
        
        HTML::Parser)
            build_module HTML-Tagset-3.20
            build_module HTML-Parser-3.60
            ;;

        Image::Scale)
            # build libjpeg-turbo on x86 platforms
            if [ $OS = "Darwin" -a $PERL_510 ]; then
                # Only build turbo for Snow Leopard, because it doesn't need a ppc version
                tar zxvf libjpeg-turbo-1.0.0.tar.gz
                cd libjpeg-turbo-1.0.0
                
                # Disable features we don't need
                cp -fv ../libjpeg-turbo-jmorecfg.h jmorecfg.h
                
                # Build 64-bit fork
                CFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5 -O3" \
                CXXFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5 -O3" \
                LDFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5" \
                    ./configure --prefix=$BUILD --host x86_64-apple-darwin NASM=/usr/local/bin/nasm \
                    --disable-dependency-tracking
                make
                if [ $? != 0 ]; then
                    echo "make failed"
                    exit $?
                fi
                cp .libs/libjpeg.a libjpeg-x86_64.a
                
                # Build 32-bit fork
                make clean
                CFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5 -O3 -m32" \
                CXXFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5 -O3 -m32" \
                LDFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5 -m32" \
                    ./configure --prefix=$BUILD NASM=/usr/local/bin/nasm \
                    --disable-dependency-tracking
                make
                if [ $? != 0 ]; then
                    echo "make failed"
                    exit $?
                fi
                cp .libs/libjpeg.a libjpeg-i386.a
                
                # Combine the forks
                lipo -create libjpeg-x86_64.a libjpeg-i386.a -output libjpeg.a
                
                # Install and replace libjpeg.a with universal version
                make install
                cp -f libjpeg.a $BUILD/lib/libjpeg.a
                cd ..       
                
            elif [ $ARCH = "i386-linux-thread-multi" -o $ARCH = "x86_64-linux-thread-multi" -o $OS = "FreeBSD" ]; then
                # build libjpeg-turbo
                tar zxvf libjpeg-turbo-1.0.0.tar.gz
                cd libjpeg-turbo-1.0.0
                
                # Disable features we don't need
                cp -fv ../libjpeg-turbo-jmorecfg.h jmorecfg.h
                
                CFLAGS="$FLAGS" CXXFLAGS="$FLAGS" LDFLAGS="$FLAGS" \
                    ./configure --prefix=$BUILD --disable-dependency-tracking
                make
                if [ $? != 0 ]; then
                    echo "make failed"
                    exit $?
                fi
                
                make install
                cd ..
                
            # build libjpeg v8 on other platforms
            else
                tar zxvf jpegsrc.v8b.tar.gz
                cd jpeg-8b
                
                # Disable features we don't need
                cp -fv ../libjpeg-jmorecfg.h jmorecfg.h
                
                CFLAGS="$FLAGS -O3" \
                LDFLAGS="$FLAGS -O3" \
                    ./configure --prefix=$BUILD \
                    --disable-dependency-tracking
                make
                if [ $? != 0 ]; then
                    echo "make failed"
                    exit $?
                fi
                make install
                cd ..
            fi
            
            # build libpng
            tar zxvf libpng-1.4.3.tar.gz
            cd libpng-1.4.3
            CFLAGS="$FLAGS -O3" \
            LDFLAGS="$FLAGS -O3" \
                ./configure --prefix=$BUILD \
                --disable-dependency-tracking
            make && make check
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            make install
            cd ..
            
            # build giflib
            tar zxvf giflib-4.1.6.tar.gz
            cd giflib-4.1.6
            CFLAGS="$FLAGS -O3" \
            LDFLAGS="$FLAGS -O3" \
                ./configure --prefix=$BUILD \
                --disable-dependency-tracking
            make
            if [ $? != 0 ]; then
                echo "make failed"
                exit $?
            fi
            make install
            cd ..
            
            # build Image::Scale
            RUN_TESTS=0
            build_module Test-NoWarnings-1.02
            RUN_TESTS=1
            
            tar zxvf Image-Scale-0.01.tar.gz
            cd Image-Scale-0.01
            if [ $PERL_58 ]; then
                # Running 5.8
                $PERL_58 Makefile.PL --with-jpeg-includes="$BUILD/include" --with-jpeg-static \
                    --with-png-includes="$BUILD/include" --with-png-static \
                    --with-gif-includes="$BUILD/include" --with-gif-static \
                    INSTALL_BASE=$BASE_58

                make
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make test
                make install
                make clean
            fi
            if [ $PERL_510 ]; then
                # Running 5.10
                # Replace hints file so we don't build ppc version
                cp -f ../hints/darwin.pl hints/darwin.pl
                $PERL_510 Makefile.PL --with-jpeg-includes="$BUILD/include" --with-jpeg-static \
                    --with-png-includes="$BUILD/include" --with-png-static \
                    --with-gif-includes="$BUILD/include" --with-gif-static \
                    INSTALL_BASE=$BASE_510

                make
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make test
                make install
                make clean
            fi
            if [ $PERL_512 ]; then
                # Running 5.12
                $PERL_512 Makefile.PL --with-jpeg-includes="$BUILD/include" --with-jpeg-static \
                    --with-png-includes="$BUILD/include" --with-png-static \
                    --with-gif-includes="$BUILD/include" --with-gif-static \
                    INSTALL_BASE=$BASE_512
            
                make
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make test
                make install
            fi
            cd ..
            
            rm -rf Image-Scale-0.01
            rm -rf giflib-4.1.6
            rm -rf libpng-1.4.3
            rm -rf jpeg-8b
            rm -rf libjpeg-turbo-1.0.0
            ;;
        
        IO::AIO)
            if [ $OS != "FreeBSD" ]; then
                build_module common-sense-2.0
            
                # Don't use the darwin hints file, it breaks if compiled on Snow Leopard with 10.5 (!?)
                USE_HINTS=0
                build_module IO-AIO-3.5
                USE_HINTS=1
            fi
            ;;
        
        JSON::XS)
            build_module common-sense-2.0
            build_module JSON-XS-2.3
            ;;
        
        Linux::Inotify2)
            if [ $OS = "Linux" ]; then
                build_module common-sense-2.0
                build_module Linux-Inotify2-1.21
            fi
            ;;
        
        Locale::Hebrew)
            build_module Locale-Hebrew-1.04
            ;;

        Mac::FSEvents)
            if [ $OS = 'Darwin' ]; then
                build_module Mac-FSEvents-0.04
            fi
            ;;
        
        Sub::Name)
            build_module Sub-Name-0.04
            ;;
        
        YAML::Syck)
            build_module YAML-Syck-1.05
            ;;
        
        Audio::Scan)
            build_module Audio-Scan-0.85
            ;;

        MP3::Cut::Gapless)
            build_module Audio-Cuefile-Parser-0.02
            build_module MP3-Cut-Gapless-0.02
            ;;  
        
        Template)
            # Template, custom build due to 2 Makefile.PL's
            tar zxvf Template-Toolkit-2.21.tar.gz
            cd Template-Toolkit-2.21
            cp -R ../hints .
            cp -R ../hints ./xs
            if [ $PERL_58 ]; then
                # Running 5.8
                $PERL_58 Makefile.PL INSTALL_BASE=$BASE_58 TT_ACCEPT=y TT_EXAMPLES=n TT_EXTRAS=n
                make # minor test failure, so don't test
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
                make clean
            fi
            if [ $PERL_510 ]; then
                # Running 5.10
                $PERL_510 Makefile.PL INSTALL_BASE=$BASE_510 TT_ACCEPT=y TT_EXAMPLES=n TT_EXTRAS=n
                make # minor test failure, so don't test
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
            fi
            if [ $PERL_512 ]; then
                # Running 5.12
                $PERL_512 Makefile.PL INSTALL_BASE=$BASE_512 TT_ACCEPT=y TT_EXAMPLES=n TT_EXTRAS=n
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
            if [ $PERL_58 ]; then
                # Running 5.8
                export PERL5LIB=$BASE_58/lib/perl5
                
                $PERL_58 Makefile.PL --mysql_config=$BUILD/bin/mysql_config --libs="-Lmysql-static -lmysqlclient -lz -lm" INSTALL_BASE=$BASE_58 
                make
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
                make clean
            fi
            if [ $PERL_510 ]; then
                # Running 5.10
                export PERL5LIB=$BASE_510/lib/perl5
                
                $PERL_510 Makefile.PL --mysql_config=$BUILD/bin/mysql_config --libs="-Lmysql-static -lmysqlclient -lz -lm" INSTALL_BASE=$BASE_510
                make
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
            fi
            if [ $PERL_512 ]; then
                # Running 5.12
                export PERL5LIB=$BASE_512/lib/perl5

                $PERL_512 Makefile.PL --mysql_config=$BUILD/bin/mysql_config --libs="-Lmysql-static -lmysqlclient -lz -lm" INSTALL_BASE=$BASE_512
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
            # build expat
            tar zxvf expat-2.0.1.tar.gz
            cd expat-2.0.1
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

            # Symlink static versions of libraries to avoid OSX linker choosing dynamic versions
            cd build/lib
            ln -sf libexpat.a libexpat_s.a
            cd ../..

            # XML::Parser custom, built against expat
            tar zxvf XML-Parser-2.36.tar.gz
            cd XML-Parser-2.36
            cp -R ../hints .
            cp -R ../hints ./Expat # needed for second Makefile.PL
            patch -p0 < ../XML-Parser-Expat-Makefile.patch
            if [ $PERL_58 ]; then
                # Running 5.8
                $PERL_58 Makefile.PL INSTALL_BASE=$BASE_58 EXPATLIBPATH=$BUILD/lib EXPATINCPATH=$BUILD/include
                make test
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
                make clean
            fi
            if [ $PERL_510 ]; then
                # Running 5.10
                $PERL_510 Makefile.PL INSTALL_BASE=$BASE_510 EXPATLIBPATH=$BUILD/lib EXPATINCPATH=$BUILD/include
                make test
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
            fi
            if [ $PERL_512 ]; then
                # Running 5.12
                $PERL_512 Makefile.PL INSTALL_BASE=$BASE_512 EXPATLIBPATH=$BUILD/lib EXPATINCPATH=$BUILD/include
                make test
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
            fi
            cd ..
            rm -rf XML-Parser-2.36
            rm -rf expat-2.0.1
            ;;
        
        Font::FreeType)
            # build freetype
            tar zxvf freetype-2.4.2.tar.gz
            cd freetype-2.4.2
            
            # Disable features we don't need for CODE2000
            cp -fv ../freetype-ftoption.h objs/ftoption.h
            
            # Disable modules we don't need for CODE2000
            cp -fv ../freetype-modules.cfg modules.cfg
            
            # libfreetype.a size (i386/x86_64 universal binary):
            #   1634288 (default)
            #    461984 (with custom ftoption.h/modules.cfg)
            
            CFLAGS="$FLAGS" \
            LDFLAGS="$FLAGS" \
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

            tar zxvf Font-FreeType-0.03.tar.gz
            cd Font-FreeType-0.03
            
            # Build statically
            patch -p0 < ../Font-FreeType-Makefile.patch
            
            # Disable some functions so we can compile out more freetype modules
            patch -p0 < ../Font-FreeType-lean.patch
            
            cp -R ../hints .
            if [ $PERL_58 ]; then
                # Running 5.8
                $PERL_58 Makefile.PL INSTALL_BASE=$BASE_58

                make # tests fail
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
                make clean
            fi
            if [ $PERL_510 ]; then
                # Running 5.10
                $PERL_510 Makefile.PL INSTALL_BASE=$BASE_510

                make 
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
                make clean
            fi
            if [ $PERL_512 ]; then
                # Running 5.12
                $PERL_512 Makefile.PL INSTALL_BASE=$BASE_512
                
                make
                if [ $? != 0 ]; then
                    echo "make failed, aborting"
                    exit $?
                fi
                make install
            fi

            cd ..
            rm -rf Font-FreeType-0.03
            rm -rf freetype-2.4.2
            ;;
    esac
}

# Build a single module if requested, or all
if [ $1 ]; then
    build $1
else
    build_all
fi

# Reset PERL5LIB
export PERL5LIB=

if [ $OS = 'Darwin' ]; then
    # strip -S on all bundle files
    find $BUILD -name '*.bundle' -exec chmod u+w {} \;
    find $BUILD -name '*.bundle' -exec strip -S {} \;
elif [ $OS = 'Linux' -o $OS = "FreeBSD" ]; then
    # strip all so files
    find $BUILD -name '*.so' -exec chmod u+w {} \;
    find $BUILD -name '*.so' -exec strip {} \;
fi

# clean out useless .bs/.packlist files, etc
find $BUILD -name '*.bs' -exec rm -f {} \;
find $BUILD -name '*.packlist' -exec rm -f {} \;

# create our directory structure
# XXX there is still some crap left in here by some modules such as DBI, GD
if [ $PERL_58 ]; then
    mkdir -p $BUILD/arch/5.8/$ARCH
    cp -R $BASE_58/lib/perl5/*/auto $BUILD/arch/5.8/$ARCH/
fi
if [ $PERL_510 ]; then
    mkdir -p $BUILD/arch/5.10/$ARCH
    cp -R $BASE_510/lib/perl5/*/auto $BUILD/arch/5.10/$ARCH/
fi
if [ $PERL_512 ]; then
    mkdir -p $BUILD/arch/5.12/$ARCH
    cp -R $BASE_512/lib/perl5/*/auto $BUILD/arch/5.12/$ARCH/
fi

# could remove rest of build data, but let's leave it around in case
#rm -rf $BASE_58
#rm -rf $BASE_510
#rm -rf $BASE_512
#rm -rf $BUILD/bin $BUILD/etc $BUILD/include $BUILD/lib $BUILD/man $BUILD/share $BUILD/var
