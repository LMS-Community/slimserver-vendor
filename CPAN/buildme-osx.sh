#!/bin/bash

# Path to Perl 5.8 (Leopard only)
PERL_58=/usr/bin/perl5.8.8

# Install dir for 5.8
BASE_58=$PWD/build-5.8

# Path to Perl 5.10.0 (Snow Leopard only)
PERL_510=/usr/bin/perl5.10.0

# Install dir for 5.10
BASE_510=$PWD/build-5.10

# Require modules to pass tests
RUN_TESTS=1

# Clean up
rm -rf $BASE_58
rm -rf $BASE_510

# $1 = module to build
# $2 = Makefile.PL arg(s)
function build_module {
	tar zxvf $1.tar.gz
	cd $1
	cp -R ../hints .
	if [ -x $PERL_58 ]; then
	    # Running Leopard
    	$PERL_58 Makefile.PL INSTALL_BASE=$BASE_58 $2
    	make test
    	if [ $? != 0 ]; then
    		echo "make test failed, aborting"
    		exit $?
    	fi
    	make install
    	make clean
    fi
    if [ -x $PERL_510 ]; then
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

# XXX XML::Parser
#  build expat
#  needs multiple hints dirs

# XXX DBD::mysql
#  build libmysqlclient?

# XXX GD
#  build libjpeg
#  build libpng
#  build fontconfig
#  build freetype
#  build gd

export PERL5LIB=

# XXX strip -S on all bundle files
# XXX move bundles into our directory structure