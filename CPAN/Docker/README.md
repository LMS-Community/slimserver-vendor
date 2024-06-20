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
