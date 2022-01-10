Building for Fedora/Linux

```
cd CPAN
docker build --rm -f "Docker/Dockerfile.fedora" -t slimservervendor:fedora .
docker run --rm -it --platform=linux/amd64 -v `pwd`:/cpan slimservervendor:fedora
cd cpan
./buildme.sh
```