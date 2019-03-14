Building Perl binaries for Logitech Media Server
============================
(aka. SlimServer, SqueezeboxServer, SliMP3...)
--------

In most cases it should be good enough to just run `./buildme.sh` from this folder.

Once compilation is done, copy the folder in `build/arch/{Perl version}/{your architecture string}/` to the corresponding folder in the Logitech Media Server `CPAN` folder. Eg. from this CPAN folder:

```
cp -r build/arch/5.26/aarch64-linux-thread-multi /path/to/slimserver/CPAN/arch/5.26/
```

### Preparation of a Debian based system
On Debian, Ubuntu etc. make sure you have the following packages installed:
* nasm
* make, gcc
* rsync
* patch
* g++
* libc-bin
* zlib1g-dev
* libmodule-install-perl

### Preparation of a Red Hat based system
On Red Hat, CentOS, Fedora, etc. make sure you have the following packages installed:
* nasm
* make, gcc
* patch
* g++
* rsync
* zlib-devel
* perl-devel
* perl-core

### Preparation of a FreeBSD based system
On FreeBSD, FreeNAS, etc. make sure you have the following ports installed:
* devel/nasm
* shells/bash
* devel/gmake
* net/rsync
* lang/perl5.X (substitute your preferred version for X)

### Preparation of a Illumos base system
Builds are best done with custom compiled perl having gnu-binutils in path, e.g.
```PATH=/opt/gcc-7/bin:/usr/gnu/bin:$PATH```

**NOTE:** Builds run best when using a i386 compiled perl (perl arch: \*-64int)
as an x86_64 perl (perl arch: \*-64) will cause incompatibilities with
some LMS plugins which bring their own pre-compiled libs in their
arch paths, e.g. ShairTunes2W.

On OmniOS, etc. make sure you have the following packages installed:
* developer/gcc7
* developer/gnu-binutils
* developer/nasm


## Overall Perl notes:
You should build using perlbrew and the following command. GCC's stack protector must be disabled
so the binaries will not be dynamically linked to libssp.so which is not available on some distros.
NOTE: On 32-bit systems for 5.12 and higher, `--thread` should be used.

### Example command for 5.12.4 install on 32-bit system
```
perlbrew install --thread --64int perl-5.12.4 -A ccflags=-fno-stack-protector -A ldflags=-fno-stack-protector
```

### Example command for 5.12.4 install on 64-bit native system
```
perlbrew install --thread perl-5.12.4 -A ccflags=-fno-stack-protector -A ldflags=-fno-stack-protector
```
In addition, you should make sure that your Perl was compiled with the same family of compiler 
(gcc or clang) as you are attempting to use with buildme.sh. Compiler mismatches can cause 
signficant problems.

## Supported OS/Perl Combinations:
#### Linux (Perl 5.8-28, both threaded & non )
  -  i386/x86_64 Linux
  -  ARM Linux
  -  PowerPC Linux
  -  Sparc Linux (ReadyNAS)
#### Mac OSX
  -  On 10.5, builds Universal Binaries for i386/ppc Perl 5.8.8
  -  On 10.6, builds Universal Binaries for i386/x86_64 Perl 5.10.0
  -  On 10.7, builds for x86_64 Perl 5.12.3 (Lion does not support 32-bit CPUs)
  -  On 10.9, builds for x86_64 Perl 5.16
  -  On 10.10, builds for x86_64 Perl 5.18
  -  On 10.11, builds for x86_64 Perl 5.18
  -  On 10.12, builds for x86_64 Perl 5.18
  -  On 10.13, builds for x86_64 Perl 5.18
#### FreeBSD 7-11 (Perl 5.8-14, 5.20-28)
  -  i386/x86_64
#### Solaris/OmniOS/Openindiana/Illumos
