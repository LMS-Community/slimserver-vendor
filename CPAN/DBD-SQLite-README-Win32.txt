To build DBD::SQLite for Win32 with ICU support, do the following:

Get ICU:

In order to build DBD::SQLite for Windows without any additional requirement, you'll have to compile using VS 2010.
As I wasn't able to build ICU myself, I downloaded the latest existing Win32 build built using that VS 2010 version:

http://site.icu-project.org/download/57#TOC-ICU4C-Download
http://download.icu-project.org/files/icu4c/57.1/icu4c-57_1-Win32-msvc10.zip

Extract the archive and put bin, include and lib folders into CPAN/build.

Make sure you have Cygwin installed, including the DBI module for Perl, patch, and binutils.


Build DBD::SQLite:

Extract the DBD-SQLite-1.58.tar.gz file
cd DBD-SQLite-1.58
patch -p0 < ../DBD-SQLite-ICU-win32.patch

Start the command shell by running "cmd"

perl Makefile.PL && nmake
Copy 3 DLL files to blib/arch/auto: icudt57.dll, icuin57.dll, and icuuc57.dll
nmake test

On success copy above DLLs and SQLite.dll from the build directory to LMS,
create CPAN/arch/5.14/MSWin32-x86-multi-thread/DBD in LMS code and add SQLite.pm
