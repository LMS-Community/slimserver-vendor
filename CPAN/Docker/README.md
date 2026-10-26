# Building Perl Binaries using Docker

Follow the below instructions to build binaries for your system x86_64 Linux.
Once the script is done building, you'll find the binaries in
`./build/arch/5.x/x86_64-linux-gnu-thread-multi/auto/`.
Copy them over into your LMS installation's `CPAN/arch` folder.

Don't forget to adjust platform and base image versions to cover your needs.

## Building for Fedora/Linux

```
cd CPAN
podman build --rm --platform=linux/amd64 -f "Docker/Dockerfile.fedora" -t slimservervendor:fedora .
podman run --rm --platform=linux/amd64 -v `pwd`:/cpan:Z localhost/slimservervendor:fedora ./buildme.sh
```

## Building for Debian

```
cd CPAN
docker build --rm --platform=linux/arm/v7 -f "Docker/Dockerfile.debian" -t slimservervendor:debian-arm .
docker run --rm --platform=linux/arm/v7 -v `pwd`:/cpan slimservervendor:debian-arm ./buildme.sh

docker build --rm --platform=linux/arm64/v8 -f "Docker/Dockerfile.debian" -t slimservervendor:debian-arm64 .
docker run --rm --platform=linux/arm64/v8 -v `pwd`:/cpan slimservervendor:debian-arm64 ./buildme.sh
```

## Building for Raspberry Pi OS ARMv6

Use this to build binaries compatible with Raspberry Pi 1 / ARMv6. The
interactive flags are useful when building or inspecting one module manually.

```
cd CPAN
docker build --rm --platform=linux/arm/v6 -f "Docker/Dockerfile.raspbian" -t slimservervendor:raspbian-armv6 .
docker run --rm -it --platform=linux/arm/v6 -v `pwd`:/cpan -w /cpan slimservervendor:raspbian-armv6 /bin/bash
```

Inside the container, verify the target and then build the desired module:

```
perl -MConfig -e 'print "$Config{version} $Config{archname}\n"'
gcc -Q --help=target | egrep 'march=|mfpu=|mfloat-abi='
./buildme.sh -t Audio::Scan
```

For the Github workflow or ACT, use:

```
flavour: raspbian
tag: latest
platform: arm/v6
module: Audio::Scan
```
