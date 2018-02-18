Building Perl binaries for Logitech Media Server
============================
(aka. SlimServer, SqueezeboxServer, SliMP3...)
--------

In most cases it should be good enough to just run `./buildme.sh` from this folder.

Once compilation is done, copy the folder in `build/arch/{Perl version}/{your architecture string}/auto/` to the corresponding folder in the Logitech Media Server `CPAN` folder. Eg. from this CPAN folder:

```
cp -r build/arch/5.26/aarch64-linux-thread-multi/aarch64-linux-gnu-thread-multi /path/to/slimserver/CPAN/arch/5.26/
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

In addition you should make sure you do have `/usr/include/xlocale.h` available on your system. If you don't, then simply symlink locale.h:
```
sudo ln -s /usr/include/locale.h /usr/include/xlocale.h
```
