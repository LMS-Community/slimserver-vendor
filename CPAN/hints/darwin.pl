#!/usr/bin/perl

use Config;
use Cwd;

if ( $Config{myarchname} =~ /i386/ ) {
    # Read OS version
    my $ver = `sw_vers -productVersion`;
    my ($osx_ver) = $ver =~ /(1[12]\.[0-9])/;
    if ($osx_ver) {
        if (`arch` eq "arm64") {
            $arch = "-arch arm64 -mmacosx-version-min=11.0";
        }
        else {
            $arch = "-arch x86_64 -mmacosx-version-min=10.13";
        }
      #   $arch = "-arch arm64 -mmacosx-version-min=12.2";
    }
    else {
        die "Unsupported OSX version $ver\n";
    }

    print "Adding $arch\n";

    my $ccflags   = $Config{ccflags};
    my $ldflags   = $Config{ldflags};
    my $lddlflags = $Config{lddlflags};

    # Remove extra -arch flags from these
    $ccflags  =~ s/-arch\s+\w+//g;
    $ldflags  =~ s/-arch\s+\w+//g;
    $lddlflags =~ s/-arch\s+\w+//g;

    $self->{CCFLAGS} = "$arch -I/usr/include $ccflags";
    $self->{LDFLAGS} = "$arch -L/usr/lib $ldflags";
    $self->{LDDLFLAGS} = "$arch -L/usr/lib $lddlflags";
}
