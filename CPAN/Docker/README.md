# Building Perl Binaries using Docker

Follow the below instructions to build binaries for your system x86_64 Linux.
Once the script is done building, you'll find the binaries in
`./build/arch/5.x/x86_64-linux-gnu-thread-multi/auto/`.
Copy them over into your LMS installation's `CPAN/arch` folder.

Don't forget to adjust platform and base image versions to cover your needs.

## Building for Fedora/Linux

```
cd CPAN
docker build --rm -f "Docker/Dockerfile.fedora" -t slimservervendor:fedora .
docker run --rm -it --platform=linux/amd64 -v `pwd`:/cpan slimservervendor:fedora
cd cpan
./buildme.sh
```

## Building for Debian

```
cd CPAN
docker build --rm -f "Docker/Dockerfile.debian" -t slimservervendor:debian .
docker run --rm -it --platform=linux/amd64 -v `pwd`:/cpan slimservervendor:debian
cd cpan
./buildme.sh
```