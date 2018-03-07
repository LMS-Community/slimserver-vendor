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
* libgd-dev
* libmodule-install-perl

### Preparation of a FreeBSD based system
On FreeBSD, FreeNAS, etc. make sure you have the following packages/ports installed:
* devel/nasm
* shells/bash
* devel/gmake
* net/rsync
* lang/perl5 (or perl5.22 or perl5.26)

In addition, you should make sure that your Perl was compiled with the same family of compiler 
(gcc or clang) as you are attempting to use with buildme.sh. Compiler mismatches can cause 
signficant problems.
