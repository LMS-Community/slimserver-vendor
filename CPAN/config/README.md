# `config.guess` and `config.sub`

This folder contains updated versions of the `config.guess` and `config.sub` files.
Some of the older tarballs we have come with outdated version which eg. wouldn't
support ARM platforms etc.

If a check failed, the `CPAN/update-config.sh` script would try these updated copies
first, worst case try to download the latest versions from gitweb.git.savannah.gnu.org.
That said: this host seems to be rather unreliable. That's why we keep updated copies
here. Only fall back to downloading if even our local copies fail.