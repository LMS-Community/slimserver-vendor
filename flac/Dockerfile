# Cross compilation environment
# docker build -t flacbuilder .
# docker build --platform linux/i386 -t flacbuilder-i386 .
# docker build --platform linux/arm -t flacbuilder-armhf .
# docker build --platform linux/arm64 -t flacbuilder-aarch64 .
# docker run --rm -v "${PWD}/..":/workdir -w /workdir/flac -it flacbuilder{-platform}
FROM debian:stretch

RUN apt-get update
RUN apt-get install -y curl git build-essential wget file
RUN mkdir /workdir

WORKDIR /workdir
CMD ["./buildme-linux.sh"]
