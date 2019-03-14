#!/usr/bin/perl

use Config;
use Cwd;

if ( $Config{myarchname} =~ /i386/ ) {
    # Read OS version
    my $ver = `sw_vers -productVersion`;
    my ($macOS_ver) = $ver =~ /(10\.(?:[5679]|[1-9][0-9]))/;
    if ($macOS_ver eq '10.5' ) {
        if ( getcwd() =~ /FSEvents/ ) { # FSEvents is not available in 10.4
            $arch = "-arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5";
        }
        else {
            $arch = "-arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.4";
        }
    }
    elsif ( $macOS_ver eq '10.6' ) {
        $arch = "-arch x86_64 -arch i386 -isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5";
    }
    elsif ( $macOS_ver eq '10.7' ) {
        $arch = "-arch x86_64 -isysroot /Developer/SDKs/MacOSX10.6.sdk -mmacosx-version-min=10.6";
    }
    elsif ( $macOS_ver =~ /10\.\d+/) {
        # Certain frameworks are deprecated in 10.8, so it (and 10.7) cannot be uses as the version-min, due to errors beyond 10.10.
        $arch = "-arch x86_64 -mmacosx-version-min=10.9";
    }
    else {
        die "Unsupported macOS version $macOS_ver\n";
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
