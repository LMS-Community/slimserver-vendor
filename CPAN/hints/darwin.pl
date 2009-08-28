#!/usr/bin/perl

use Config;

if ( $Config{myarchname} =~ /i386/ ) {
    if ( $Config{version} =~ /^5\.10/ ) {
        # 5.10, build as 10.5+ with Snow Leopard 64-bit support
        $arch = "-arch x86_64 -arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5";
    }
    else {
        # 5.8.x, build for 10.3+ 32-bit universal
        $arch = "-arch i386 -arch ppc -isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.3";
    }
    
    print "Adding $arch\n";
    
    my $ccflags   = $Config{ccflags};
    my $ldflags   = $Config{ldflags};
    my $lddlflags = $Config{lddlflags};
    
    # Remove extra -arch flags from these
    $ccflags  =~ s/-arch\s+\w+//g;
    $ldflags  =~ s/-arch\s+\w+//g;
    $lddlflags =~ s/-arch\s+\w+//g;

    $self->{CCFLAGS} = "$arch $ccflags";
    $self->{LDFLAGS} = "$arch -L/usr/lib $ldflags";
    $self->{LDDLFLAGS} = "$arch $lddlflags";
}
