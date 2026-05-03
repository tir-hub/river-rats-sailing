#!/usr/bin/perl
use strict;
use warnings;
use v5.10;
use Getopt::Long;
use Data::Dumper;
use Cwd qw(cwd);

my $verbose;
my $help = 0;

GetOptions (
            "verbose"  => \$verbose,
            "help"     => \$help)
    ||  die usage();

if ($help) {
    say usage();
    exit(0);
}

say "generating all reports";

my %tshirts = ();
my $tshirts = \%tshirts;
my %tshirt_counts = ();
my $tshirt_counts = \%tshirt_counts;
my $levels = "";
my @classes = qw(Session-1 Session-2 Session-3 Session-4 Session-5 Session-6 Session-7);
my $sailing_level_counts_file = "sailing-level-counts.csv";

for my $class (@classes) {
    say $class;
    my $pwd = cwd;
    chdir $class;
    invoke ("../gen-attendance.pl");
    collect_tshirts();
    collect_levels($class);
    chdir $pwd;
}

# say Dumper($tshirts);

for my $key (sort keys %tshirts) {
    my $size = $tshirts->{$key};
    say "${key}: " . $size;
    if (!$tshirt_counts->{$size}) {
	$tshirt_counts->{$size} = 0;
    }
    $tshirt_counts->{$size} = $tshirt_counts->{$size} + 1;
}

# say Dumper($tshirt_counts);

for my $key (sort keys %tshirt_counts) {
    my $count = $tshirt_counts->{$key};
    say "${key}: " . $count;
}

generate_csv($tshirts);
generate_levels_csv();


sub collect_tshirts {
    local $_;
    
    my @lines = invoke("grep In: Attendance*Junior*Sailing*Session*csv");
    chomp @lines;

    for my $line (@lines) {
	my @fields = split(/\s*,\s*/, $line);
	my $name = lc($fields[0]);
	$name =~ s/"//g;
	$name =~ s/^\s+//;
	$name =~ s/\s+$//;
	$name =~ s/\s+/ /;


	my $size = $fields[1];
	$size =~ s/"//g;
#	say "${name}: ${size}";

	$tshirts->{$name} = $size;
    }
}

sub collect_levels {
    my ($class) = @_;
    local $_;

    $levels = $levels . "\n\"${class}\"\n";

    open(FILE, '<', $sailing_level_counts_file) || die $! . ": ${sailing_level_counts_file}";
    my @file_content = <FILE>;
    say "level file_content: @{file_content}";
    foreach my $file_content (@file_content) {
	$levels = $levels . $file_content;
    }
    close FILE;

}

sub generate_csv {
    my ($tshirts) = @_;
    local $_;

    my $file = "TShirts.csv";
    open(FILE, '>', $file) || die $! . ": ${file}";
    say FILE '"Student","T-shirt","Delivered"';

    for my $key (sort keys %tshirts) {
	my $size = $tshirts->{$key};
	say FILE "\"${key}\",\"${size}\",";
    }

    close FILE;
}

sub generate_levels_csv {
    local $_;

    my $file = "TShirts.csv";
    open(FILE, '>', $sailing_level_counts_file) || die $! . ": ${sailing_level_counts_file}";
    say FILE $levels;

    close FILE;
}


sub invoke {
    my ($cmd) = @_;
    local $_;

    say "invoking ${cmd}";
    my @result = `$cmd`;
    if ($?) {
	die $?;
    }
    return @result;
    
}
	

sub usage {

my $usage = <<'END_MESSAGE';
Generates all the attendance files for each session. Will also generate these summary files:
   TShirst.csv:              File listing each student and their TShirt size.
   sailing-level-counts.csv: File listing the number of beginner, intermediate, and advanced students in each class.

To run this, create directories foreach class named as follows:
   Session-1, Session-2, Session-3, Session-4, Session-5, Session-6,  Session-7

In each directory, export the class's registration and registrant data. Name the registration data registration_data.csv and the registrant data registrant_data.csv  See instructions at end of usage.
Then run this program from the parent directory containing the MWF-1, MWF-2.. directories.
usage:
   ${0} [--help]

First export the registration and registrant data into a directory, then run this program.

To export the the registration and registrant data:
    * login to website
    * select "Events" tab
    * click pencil icon on right
    * select the calendar like icon it the little admin pannel towards the top right to "export"
    * check "Registration Data" or "Restrant Data".. you will do this process twice, once for each
    * then in the "Status" check "Paid" and possibly "Open" then click "Export"



END_MESSAGE

}
