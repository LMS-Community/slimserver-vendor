To build DBD::SQLite for Win32 with ICU support, do the following:

Build ICU:

http://source.icu-project.org/repos/icu/icu/trunk/readme.html#HowToBuildCygwin

Install cygwin packages if needed: binutils, GNU make

(In a cmd.exe prompt with Cygwin in PATH):
tar zxvf icu4c-4_6-src.tgz
cd icu\source
Run: bash ./runConfigureICU Cygwin/MSVC --prefix=C:/dev/CPAN/build --with-data-packaging=archive
make
make check
make install

Build DBD::SQLite:

patch -p0 < ../DBD-SQLite-ICU.pach
Edit the DBD::SQLite Makefile.PL file:
  Add '-LC:/dev/build/lib' to @CC_LIBS
  Add '-IC:/dev/build/include' to @CC_INC
  Change MYEXTLIB to:
    '../build/lib/icuuc.lib',
    '../build/lib/icudt.lib',
    '../build/lib/icuin.lib',
perl Makefile.PL && nmake
Copy 3 DLL files to blib/arch/auto: icudt46.dll, icuin46.dll, and icuuc46.dll
nmake test

