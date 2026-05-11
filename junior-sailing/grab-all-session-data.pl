#!/usr/bin/env perl
use strict;
use warnings;
use v5.10;
use Getopt::Long qw(:config bundling);
use FindBin;
use Cwd       qw(abs_path);
use File::Path qw(make_path);

require "$FindBin::Bin/riverrats_config.pl";
our (@sessions);

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $data_dir = '.';
my $debug    = 0;
my $help     = 0;

GetOptions(
    'data-dir=s' => \$data_dir,
    'debug|d+'   => \$debug,
    'help|h'     => \$help,
) or die usage();

if ($help) { say usage(); exit 0; }

$data_dir = abs_path($data_dir);

say "data-dir: $data_dir";

my $grabber = "$FindBin::Bin/grab-session-data.pl";
my @debug_flag = $debug ? ('-' . 'd' x $debug) : ();

my @failed;

for my $session (@sessions) {
    my $session_dir = "$data_dir/$session";
    make_path($session_dir) unless -d $session_dir;

    say "=== $session ===";
    my @cmd = ($grabber, "--data-dir=$session_dir", @debug_flag);
    system(@cmd);
    if ($? != 0) {
        warn "ERROR: grab-session-data.pl failed for $session\n";
        push @failed, $session;
    }
    say '';
}

if (@failed) {
    warn "Failed sessions: " . join(', ', @failed) . "\n";
    exit 1;
}

say "All sessions downloaded successfully.";
exit 0;

sub usage {
    (my $prog = $0) =~ s{.*/}{};
    return <<END;
Downloads registration_data.csv, registrant_data.csv, and
Registration-details.pdf for every session from riverratssailing.org.

usage:
   $prog [--data-dir <dir>] [-d|-dd|-ddd] [--help]

Options:
   --data-dir <dir>   Parent directory containing (or to create) Session-N
                      subdirectories. Default: current directory.
                      Example: --data-dir ~/Documents/Data/RiverRats/2026

   -d                 Debug level 1: log each HTTP request to stderr.
   -dd                Debug level 2: also dump response body on errors.
   -ddd               Debug level 3: dump all HTML and CSV responses.

   --help             Show this message.

Credentials are read from ~/.config/riverrats/credentials (see README.md).
The account must have Admin or Event Coordinator role on ClubExpress.
Session directories are created automatically if they do not exist.
END
}
