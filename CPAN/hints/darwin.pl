#!/usr/bin/perl

use Config;

if ( $Config{myarchname} =~ /i386/ ) {
    my $arch;
    
    # Match arch options with the running perl
    if ( my @archs = $Config{ccflags} =~ /-arch ([^ ]+)/g ) {
        $arch = join( '', map { "-arch $_ " } @archs );
        
        if ( -e 'MANIFEST.SKIP' ) {
            # XXX for development, use only one arch to speed up compiles
            $arch = '-arch x86_64 ';
        }
    }
    
    # Read OS version
    my $sys = `/usr/sbin/system_profiler SPSoftwareDataType`;
    my ($osx_ver) = $sys =~ /Mac OS X.*(10\.[^ ]+)/;
    if ( $osx_ver gt '10.5' ) {
        # Running 10.6+, build as 10.5+
        if ( -d '/Developer/SDKs/MacOSX10.5.sdk' ) {
            $arch .= "-isysroot /Developer/SDKs/MacOSX10.5.sdk -mmacosx-version-min=10.5";
        }
        else {
            # 10.5 SDK not installed, use 10.6 only
            $arch = "-arch x86_64 -arch i386 -isysroot /Developer/SDKs/MacOSX10.6.sdk -mmacosx-version-min=10.6";
        }
    }
    else {
        # 5.8.x, build for 10.3+
        $arch .= "-isysroot /Developer/SDKs/MacOSX10.4u.sdk -mmacosx-version-min=10.3";
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
