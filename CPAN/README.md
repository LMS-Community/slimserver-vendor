Building Perl binaries for Logitech Media Server
============================

## Build using the Github Workflow `buildCPAN`

There's a Github Workflow `buildCPAN.yaml` to build on various platforms using a few parameters. It's easiest to run it directly on Github. Alas, Github Actions only support x86_64 for Linux so far, no ARM. But the same workflow file can be run locall using [ACT](https://nektosact.com/installation/index.html). Run on a Mac with Apple Silicon this allows you to build for the ARM platform, too.

After you've set up ACT following the instructions from above link you can set up a configuration file, like eg. [`CPAN/Docker/act.json`]:

```json
{
	"action": "workflow_dispatch",
	"inputs": {
		"flavour": "debian",
		"tag": "bullseye",
		"platform": "arm64",
		"module": "Audio::Scan"
	}
}
```

Where:
* `flavour`: currently `debian` or `fedora` are supported
* `tag`: the Docker tag if you wish to use a specific version of one of those distributions. See Docker Hub for available tags for [Debian](https://hub.docker.com/_/debian) or [Fedora](https://hub.docker.com/_/fedora). The workflow would fall back to `testing` or `latest`, respectively.
* `platform`: the target platform you want to build for. You'd have to use the Docker notification like `amd64`, `arm64`, or `arm/v7`.
* `module`: one of the Perl modules you'd like to build. Or empty if you want to build all dependencies.

Once that file is set up you can build from the root of this repository running:

```
act --job buildCPAN --eventpath CPAN/Docker/act.json
```

You'll then find the resulting binaries in `CPAN/build/arch` (see below).

## Building on your machine

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

In order to build on Debian unstable/sid where Perl 5.38 is deployed, but the prebuild CPAN modules do not work because glibc is not yet version 2.38, you could use the following shell script:

```
#!/bin/bash

PERL=5.38

sudo apt install git sed nasm make gcc rsync patch g++ libc-bin zlib1g-dev libgd-dev libmodule-install-perl
git clone -b public/8.4 https://github.com/LMS-Community/slimserver-vendor.git
cd slimserver-vendor/CPAN
sed -i -e 's+ldconfig+/sbin/ldconfig+' buildme.sh
./buildme.sh
(cd build/arch/$PERL/x86_64-linux-gnu-thread-multi/auto && tar cf - $(find . -name "*.so")) | sudo tar xvf - -C /usr/share/squeezeboxserver/CPAN/arch/$PERL/x86_64-linux-thread-multi/auto
sudo sed -i -e 's/1\.06/1\.09/' /usr/share/squeezeboxserver/CPAN/arch/$PERL/Audio/Scan.pm
```

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
