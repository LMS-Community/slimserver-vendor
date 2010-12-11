To build DBD::SQLite for Win32 with ICU support, do the following:

Download the ICU4C 32-bit binary zip file, such as icu4c-4_6-Win32-msvc10.zip
Unzip to C:\dev\icu
Edit the DBD::SQLite Makefile.PL file:
  Add '-LC:/dev/icu/lib -licuuc -licudt -licuin' to @CC_LIBS
  Add '-IC:/dev/icu/include' to @CC_INC
perl Makefile.PL && nmake
Copy 3 DLL files to blib/arch/auto: icudt46.dll, icuin46.dll, and icuuc46.dll
nmake test

