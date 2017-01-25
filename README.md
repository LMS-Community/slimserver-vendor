#Build LogitechMediaServer CPAN Modules


##Debian 9 (perl-5.24, arm)

```bash
dpkg -i logitechmediaserver_7.9.0~1484464959_arm.deb

apt-get install libgd-dev rsync yasm libmodule-install-perl

cd slimserver-vendor/CPAN
MAKEFLAGS=-j4 ./buildme.sh

cp -r build/5.24/lib/perl5/* /usr/share/squeezeboxserver/CPAN/arch/5.24
```
