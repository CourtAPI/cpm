package App::cpm::Util;
use strict;
use warnings;

use Config;
use Cwd ();
use Digest::MD5 ();
use File::Spec;

use Exporter 'import';

our @EXPORT_OK = qw(perl_identity maybe_abs WIN32 determine_home get_ncpu);

use constant WIN32 => $^O eq 'MSWin32';

sub perl_identity {
    my $digest = Digest::MD5::md5_hex($Config{perlpath} . Config->myconfig);
    $digest = substr $digest, 0, 8;
    join '-', $Config{version}, $Config{archname}, $digest
}

sub maybe_abs {
    my $path = shift;
    if (File::Spec->file_name_is_absolute($path)) {
        return $path;
    }
    my $cwd = shift || Cwd::cwd();
    File::Spec->canonpath(File::Spec->catdir($cwd, $path));
}

sub determine_home { # taken from Menlo
    my $homedir = $ENV{HOME}
      || eval { require File::HomeDir; File::HomeDir->my_home }
      || join('', @ENV{qw(HOMEDRIVE HOMEPATH)}); # Win32

    if (WIN32) {
        require Win32; # no fatpack
        $homedir = Win32::GetShortPathName($homedir);
    }

    File::Spec->catdir($homedir, ".perl-cpm");
}


#
## Taken verbatim from MCE::Util
#
###############################################################################
## ----------------------------------------------------------------------------
## The get_ncpu subroutine, largely adopted from Test::Smoke::Util.pm,
## returns the number of logical (online/active/enabled) CPU cores;
## never smaller than one.
##
## A warning is emitted to STDERR when it cannot recognize the operating
## system or the external command failed.
##
###############################################################################

my $g_ncpu;

sub get_ncpu {

   return $g_ncpu if (defined $g_ncpu);

   local $ENV{PATH} = "/usr/sbin:/sbin:/usr/bin:/bin:$ENV{PATH}";
   $ENV{PATH} =~ /(.*)/; $ENV{PATH} = $1;   ## Remove tainted'ness

   my $ncpu = 1;

   OS_CHECK: {
      local $_ = lc $^O;

      /linux/ && do {
         my ( $count, $fh );
         if ( open $fh, '<', '/proc/stat' ) {
            $count = grep { /^cpu\d/ } <$fh>;
            close $fh;
         }
         $ncpu = $count if $count;
         last OS_CHECK;
      };

      /bsd|darwin|dragonfly/ && do {
         chomp( my @output = `sysctl -n hw.ncpu 2>/dev/null` );
         $ncpu = $output[0] if @output;
         last OS_CHECK;
      };

      /aix/ && do {
         my @output = `lparstat -i 2>/dev/null | grep "^Online Virtual CPUs"`;
         if ( @output ) {
            $output[0] =~ /(\d+)\n$/;
            $ncpu = $1 if $1;
         }
         if ( !$ncpu ) {
            @output = `pmcycles -m 2>/dev/null`;
            if ( @output ) {
               $ncpu = scalar @output;
            } else {
               @output = `lsdev -Cc processor -S Available 2>/dev/null`;
               $ncpu = scalar @output if @output;
            }
         }
         last OS_CHECK;
      };

      /gnu/ && do {
         chomp( my @output = `nproc 2>/dev/null` );
         $ncpu = $output[0] if @output;
         last OS_CHECK;
      };

      /haiku/ && do {
         my @output = `sysinfo -cpu 2>/dev/null | grep "^CPU #"`;
         $ncpu = scalar @output if @output;
         last OS_CHECK;
      };

      /hp-?ux/ && do {
         my $count = grep { /^processor/ } `ioscan -fkC processor 2>/dev/null`;
         $ncpu = $count if $count;
         last OS_CHECK;
      };

      /irix/ && do {
         my @out = grep { /\s+processors?$/i } `hinv -c processor 2>/dev/null`;
         $ncpu = (split ' ', $out[0])[0] if @out;
         last OS_CHECK;
      };

      /osf|solaris|sunos|svr5|sco/ && do {
         if (-x '/usr/sbin/psrinfo') {
            my $count = grep { /on-?line/ } `psrinfo 2>/dev/null`;
            $ncpu = $count if $count;
         }
         else {
            my @output = grep { /^NumCPU = \d+/ } `uname -X 2>/dev/null`;
            $ncpu = (split ' ', $output[0])[2] if @output;
         }
         last OS_CHECK;
      };

      /mswin|mingw|msys|cygwin/ && do {
         if (exists $ENV{NUMBER_OF_PROCESSORS}) {
            $ncpu = $ENV{NUMBER_OF_PROCESSORS};
         }
         last OS_CHECK;
      };

      warn "MCE::Util::get_ncpu: command failed or unknown operating system\n";
   }

   $ncpu = 1 if (!$ncpu || $ncpu < 1);

   return $g_ncpu = $ncpu;
}
1;
