use ExtUtils::MakeMaker qw(prompt WriteMakefile);
use Config;
use strict;

require 5.6.0;

unless (@ARGV) {
warn <<END;
NOTICE: This module requires libgd 2.0.28 or higher.

        If you are using Math::Trig 1.01 or lower, it has a bug that
        causes a "prerequisite not found" warning to be issued.  You may
        safely ignore this warning.

        Type perl Makefile.PL -h for command-line option summary

END
}


# =====> PATHS: CHECK AND ADJUST <=====
my (@INC,@LIBPATH,@LIBS);
my $AUTOCONFIG = 0;      # global set by try_to_autoconfigure() below

my ($options,$lib_gd_path,$lib_ft_path,$lib_png_path,$lib_jpeg_path,$lib_xpm_path,$lib_zlib_path);

try_to_autoconfigure(\$options,\$lib_gd_path,\@INC,\@LIBPATH,\@LIBS);

@INC     = qw(-I/usr/include -I/usr/include/gd) unless @INC;
@LIBPATH = qw(-L/usr/lib/X11 -L/usr/X11R6/lib -L/usr/X11/lib -L/usr/lib) unless @LIBPATH;
@LIBS    = qw(-lgd) unless @LIBS;

# support for AMD64 libraries
if (-d '/usr/lib64') {
  my @libs64 = map {my $a = $_; $a=~ s/lib$/lib64/; $a} @LIBPATH;
  @LIBPATH = (@LIBPATH,@libs64);
}

#############################################################################################
# Build options passed in to script to support reproducible builds via Makefiles
#############################################################################################
use Getopt::Long;
my $result = GetOptions("options=s"       => \$options,
			"lib_gd_path=s"   => \$lib_gd_path,
			"lib_ft_path=s"   => \$lib_ft_path,
			"lib_png_path=s"  => \$lib_png_path,
			"lib_jpeg_path=s" => \$lib_jpeg_path,
			"lib_xpm_path=s"  => \$lib_xpm_path,
			"lib_zlib_path=s" => \$lib_zlib_path,
		       );
unless ($result) {
  print STDERR <<END;
Usage: perl Makefile.PL [options]

Configure GD module.

 Options:
     -options       "JPEG,FT,PNG,GIF,XPM,ANIMGIF"   feature options, separated by commas
     -lib_gd_path   path            path to libgd
     -lib_ft_path   path            path to Freetype library
     -lib_png_path  path            path to libpng
     -lib_jpeg_path path            path to libjpeg
     -lib_xpm_path  path            path to libxpm
     -lib_zlib_path path            path to libpng

If no options are passed on the command line.  The program will
attempt to autoconfigure itself with the gdlib-config program (present
in GD versions 2.0.27 or later).  Otherwise it will prompt for these
values interactively.
END
}

if( defined($options) )
{
    print "Included Features:          $options\n";
}
if( defined($lib_gd_path) )
{
    print "GD library used from:       $lib_gd_path\n";
}
if( defined($lib_ft_path) )
{
    print "FreeType library used from: $lib_ft_path\n";
    @INC     = ("-I$lib_ft_path/include", @INC);
    @LIBPATH = ("-L$lib_ft_path/lib", @LIBPATH);
}
if( defined($lib_png_path) )  
{
    print "PNG library used from:      $lib_png_path\n";
    @INC     = ("-I$lib_png_path/include", @INC);
    @LIBPATH = ("-L$lib_png_path/lib", @LIBPATH); 
}
if( defined($lib_jpeg_path) )  
{
    print "JPEG library used from:      $lib_jpeg_path\n";
    @INC     = ("-I$lib_jpeg_path/include", @INC);
    @LIBPATH = ("-L$lib_jpeg_path/lib", @LIBPATH); 
}
if( defined($lib_xpm_path) )  
{
    print "XPM library used from:      $lib_xpm_path\n";
    @INC     = ("-I$lib_xpm_path/include", @INC);
    @LIBPATH = ("-L$lib_xpm_path/lib", @LIBPATH); 
}
if( defined($lib_zlib_path) ) 
{
    print "Zlib library used from:     $lib_zlib_path\n";
    @INC     = ("-I$lib_zlib_path/include", @INC);
    @LIBPATH = ("-L$lib_zlib_path/lib", @LIBPATH); 
}
#############################################################################################

if ($^O eq 'VMS'){
  warn "This is a build on OpenVMS. In case of problems with the build\n";
  warn "do not bother Lincoln Stein but get in touch with\n";
  warn "Martin P.J. Zinser (zinser\@decus.de)\n\n";

  if ($ENV{"LIB_ROOT"} eq "") {
    warn "Define lib_root as a concealed logical pointing to the\n";
    warn "Top directory where you have your libraries installed\n";
    warn "E.g. define/job/trans=conc lib_root public\$device:[public.util.libs.]\n";
    warn "Also define the logical pubbin to point to the location\n";
    warn "of the object libraries\n";
    warn "Then re-invoke Makefile.PL\n";
    warn "Exiting now...\n";
    exit;
  }

  @INC     = qw(-I/lib_root/gd -I/lib_root/libpng -I/lib_root/zlib);
  @LIBPATH = qw(-Lpubbin);
  @LIBS    = qw(-llibgd.olb -llibpng.olb -llibz.olb);
}

# workaround for solaris systems?
elsif ($^O =~ /solaris/i) {
    push @LIBS,'-liconv';
}

###################################################################
# path to libgd, skip prompt if passed in from above
###################################################################
my $PREFIX = $lib_gd_path;
if( ! defined($lib_gd_path) )
{
  warn "\n";
  $PREFIX = prompt('Where is libgd installed?','/usr/lib');
}

unless ($AUTOCONFIG || $PREFIX eq '/usr/lib') {
  $PREFIX =~ s!/lib$!!;
  unshift @INC,"-I$PREFIX/include";
  unshift @LIBPATH,"-L$PREFIX/lib";
}

# FEATURE FLAGS

##################################################################################################################
# If build options have not been passed in then prompt for settings
##################################################################################################################
my ($JPEG, $FT, $XPM, $GIF,$ANIMGIF,$UNCLOSEDPOLY,$FONTCONFIG,$PNG,$FTCIRCLE,$VERSION_33);
if( defined($options) )
{
  $JPEG      = $options =~ m/JPEG/i;
  $FT        = $options =~ m/FT|FREETYPE/i;
  $XPM       = $options =~ m/XPM/i;
  $GIF       = $options =~ m/GIF/i;
  $PNG       = $options =~ m/PNG/i;
  $ANIMGIF   = $GIF && $options =~ m/ANIMGIF/i;
  $VERSION_33= $options =~ m/VERSION_33/i;
  $UNCLOSEDPOLY  = $options =~ m/UNCLOSEDPOLY/i;
  $FONTCONFIG  = $options =~ m/FONTCONFIG/i;
  $FTCIRCLE  = $options =~ m/FTCIRCLE/i;
}
else
{
    warn "\nPlease choose the features that match how libgd was built:\n";
    $JPEG    = lc prompt('Build JPEG support?','y') eq 'y';
    $PNG     = lc prompt('Build PNG support?','y') eq 'y';
    $FT      = lc prompt('Build FreeType support?','y') eq 'y';
    $GIF     = lc prompt('Build GIF support?','y') eq 'y';
    $ANIMGIF = $GIF && lc prompt('Build support for animated GIFs?','y') eq 'y';
    $XPM     = $^O !~ /^freebsd|MSWin32$/ && lc prompt('Build XPM support?','y') eq 'y';
}
##################################################################################################################

my $FCGI    = 0;   # set to 1 to build compatability with fastCGI

#### no user-serviceable parts below #####

if (!$AUTOCONFIG) {
  warn "\nIf you experience compile problems, please check the \@INC, \@LIBPATH and \@LIBS\n",
       "arrays defined in Makefile.PL and manually adjust, if necessary.\n\n";

  push @LIBS,'-lfreetype'      if $FT;
  push @LIBS,'-ljpeg'          if $JPEG;
  push @LIBS,'-lpng','-lz'     if $PNG;
  push @LIBS, '-lm'       unless $^O eq 'MSWin32';
  push @INC, '-I/lib_root/libjpeg' if ($JPEG && $^O eq 'VMS');
  push @INC, '-I/lib_root/ft2/include/freetype' if ($FT && $^O eq 'VMS');
  push @INC, '-I/X11' if ($XPM && $^O eq 'VMS');

  # FreeBSD 3.3 with libgd built from ports croaks if -lXpm is specified 
  if ($^O ne 'freebsd' && $^O ne 'MSWin32') { 
    push @LIBS,'-lX11','-lXpm' if $XPM; 
  }
}

my $CAPI = defined $ExtUtils::MakeMaker::CAPI_support;
my $DEFINES = '';
$DEFINES    .= ' -DHAVE_JPEG'    if $JPEG;
$DEFINES    .= ' -DHAVE_FT'      if $FT;
$DEFINES    .= ' -DHAVE_XPM'     if $XPM;
$DEFINES    .= ' -DHAVE_GIF'     if $GIF;
$DEFINES    .= ' -DHAVE_PNG'     if $PNG;
$DEFINES    .= ' -DFCGI'         if $FCGI;
$DEFINES    .= ' -DHAVE_ANIMGIF' if $ANIMGIF;
$DEFINES    .= ' -DVERSION_33'   if $VERSION_33;
$DEFINES    .= ' -DHAVE_UNCLOSEDPOLY' if $UNCLOSEDPOLY;
$DEFINES    .= ' -DHAVE_FONTCONFIG'   if $FONTCONFIG;
$DEFINES    .= ' -DHAVE_FTCIRCLE'  if $FTCIRCLE;
open F,">.config.cache";
print F $DEFINES,"\n";
close F;

# Patch to build statically
@LIBS = ( '-lexpat', '-liconv', '-lz', '-lm' );
push @LIBS, ( '-ljpeg_s -lpng12_s -lgd_s -lfontconfig_s -lfreetype_s' );

WriteMakefile(
    'NAME'	=> 'GD',
    'VERSION_FROM'	=> 'GD.pm',
    'PREREQ_PM' => {
		    'Math::Trig' => 0,
		    },
    'PM'        => { 'GD.pm' => '$(INST_LIBDIR)/GD.pm',
                     'GD/Polyline.pm' => '$(INST_LIBDIR)/GD/Polyline.pm',
                     'GD/Polygon.pm' => '$(INST_LIBDIR)/GD/Polygon.pm',
                     'GD/Simple.pm' => '$(INST_LIBDIR)/GD/Simple.pm',
                     'GD/Image.pm' => '$(INST_LIBDIR)/GD/Image.pm',
                     'qd.pl' => '$(INST_LIBDIR)/qd.pl'},
    'dist'      => {'COMPRESS'=>'gzip -9f', 'SUFFIX' => 'gz',
	            'ZIP'=>'/usr/bin/zip','ZIPFLAGS'=>'-rl'},
    'LIBS'      => [join(' ',$ENV{'GD_LIBS'},@LIBPATH,@LIBS)],
    'INC'       => join(' ',$ENV{'GD_INC'},@INC),
    'PL_FILES'  => {'bdf_scripts/bdf2gdfont.PLS' => 'bdf_scripts/bdf2gdfont.pl',
		    'GD/Image.pm.PLS' => 'GD/Image.pm',
		   },
#    'CFLAGS'    => '-nostdinclude',
    'EXE_FILES' => ['bdf_scripts/bdf2gdfont.pl'],
    'AUTHOR'    => 'Lincoln Stein (lstein@cshl.org)',
    'ABSTRACT'  => 'Interface to Gd Graphics Library',
     $CAPI ? ('CAPI'      => 'TRUE') : (),
    'DEFINE'	=> $DEFINES,
);

exit 0;

sub try_to_autoconfigure {
  my ($options,$lib_gd_path,$INC,$LIBPATH,$LIBS) = @_;
  my $config = `gdlib-config --all`;
  return unless $config;
  $AUTOCONFIG++;

  my ($version) = $config =~ /^GD library\s+(\S+)/m;
  warn "Configuring for libgd version $version.\n";

  my ($cflags)     = $config =~ /^cflags:\s+(.+)/m;
  my ($ldflags)    = $config =~ /^ldflags:\s+(.+)/m;
  my ($libs)       = $config =~ /^libs:\s+(.+)/m;
  my ($libdir)     = $config =~ /^libdir:\s+(.+)/m;
  my ($features)   = $config =~ /^features:\s+(.+)/m;
  my ($includedir) = $config =~ /^includedir:\s+(.+)/m;

  @$INC          = map {s/^-I// && "-I$_"} split /\s+/,$cflags;
  @$LIBPATH      = map {s/^-L// && "-L$_"} split /\s+/,$ldflags;
  @$LIBS         = split /\s+/,$libs;

  push @$LIBS,"-lgd";
  push @$LIBPATH,"-L$libdir";
  ($$lib_gd_path = $libdir) =~ s!/[^/]+$!!;
  $$options      = $features;

  my ($minor)    = $version =~ /^2\.\d+\.(\d+)$/;
  $$options     .= " GD_UNCLOSEDPOLY GD_ANIMGIF GD_FTCIRCLE VERSION_33" if defined($minor) && $minor >= 33;

  my @correct_inc = map {s/^-I// && $_} split /\s+/,$cflags;
  check_for_stray_headers(@correct_inc);
}

sub check_for_stray_headers {
  my @official_libraries = @_;
  my %official_libraries = map {$_=>1} @official_libraries;
  print STDERR "Checking for stray libgd header files...";
  my $cc          = $Config{'cc'};
  my $data        = `$cc -print-search-dirs`;
  $data         ||= '';
  my ($libraries) = $data =~ /^libraries: =(.+)/m;
  my %libraries   = map {$_=>1} (split /:/,$libraries),'/include','/usr/include','/usr/local/include','/opt/include','/usr/X11R6/include';
  my $problems;
  foreach (keys %libraries) {
    s/\blib\b/include/;
    next if $official_libraries{$_};

    next unless -e "${_}/gd.h";
    warn "\n\n** WARNING: found gd.h header file in ${_}gd.h, but it is expected at $official_libraries[0]/gd.h. This may cause compile errors! **\n";
    $problems++;
  }
  print STDERR $problems ? "** Possible problems found **\n" : "none found.\n";
  print STDERR "\n";
}

sub MY::postamble {
    my $postamble = <<'END';
html: GD.pm
	pod2html --outfile=GD.html GD.pm

END
    $postamble;
}

