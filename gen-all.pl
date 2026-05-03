#!/usr/bin/perl
use strict;
use warnings;
use v5.10;
use Getopt::Long;
use Data::Dumper;
use FindBin;
use Cwd qw(cwd abs_path);
use Text::ParseWords;

my $data_dir = ".";
my $verbose;
my $help = 0;

GetOptions (
            "data-dir=s" => \$data_dir,
            "verbose"    => \$verbose,
            "help"       => \$help)
    ||  die usage();

if ($help) {
    say usage();
    exit(0);
}

say "generating all reports";

$data_dir = abs_path($data_dir);

my %tshirts = ();
my $tshirts = \%tshirts;
my %tshirt_counts = ();
my $tshirt_counts = \%tshirt_counts;
my $levels = "";
my @all_students = ();
my @classes = qw(Session-1 Session-2 Session-3 Session-4 Session-5 Session-6 Session-7);
my $sailing_level_counts_file = "${data_dir}/sailing-level-counts.csv";

for my $class (@classes) {
    say $class;
    my $pwd = cwd;
    chdir "${data_dir}/${class}";
    invoke ("$FindBin::Bin/gen-attendance.pl");
    collect_tshirts();
    collect_levels($class);
    collect_students();
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
generate_tshirt_counts_csv($tshirt_counts);
generate_levels_csv();
generate_student_counts_csv();
generate_student_list_csv();


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

    my $session_levels_file = "sailing-level-counts.csv";
    open(FILE, '<', $session_levels_file) || die $! . ": ${session_levels_file}";
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

    my $file = "${data_dir}/TShirts.csv";
    open(FILE, '>', $file) || die $! . ": ${file}";
    say FILE '"Student","T-shirt","Delivered"';

    for my $key (sort keys %tshirts) {
	my $size = $tshirts->{$key};
	say FILE "\"${key}\",\"${size}\",";
    }

    close FILE;
}

sub generate_tshirt_counts_csv {
    my ($tshirt_counts) = @_;
    local $_;

    my $file = "${data_dir}/TShirt-counts.csv";
    open(FILE, '>', $file) || die $! . ": ${file}";
    say FILE '"Size","Count"';

    for my $key (sort keys %$tshirt_counts) {
        my $count = $tshirt_counts->{$key};
        say FILE "\"${key}\",${count}";
    }

    close FILE;
}

sub generate_levels_csv {
    local $_;

    open(FILE, '>', $sailing_level_counts_file) || die $! . ": ${sailing_level_counts_file}";
    say FILE $levels;

    close FILE;
}


sub parse_csv_file {
    my ($file) = @_;
    local $_;

    open(FILE, '<', $file) || die $! . ": ${file}";
    my @lines = <FILE>;
    close FILE;

    chomp @lines;
    my ($header, @data) = @lines;
    $header =~ s/\r$//;

    my @raw = split(/,/, $header);
    my %col;
    for my $i (0..$#raw) {
        (my $t = $raw[$i]) =~ s/"//g;
        $col{$t} = $i;
    }

    my @rows;
    for my $line (@data) {
        $line =~ s/\r$//;
        next unless $line =~ /\S/;
        $line .= '""' if $line =~ /,$/;
        my @fields = parse_line(',', 0, $line);
        push @rows, \@fields;
    }

    return (\%col, \@rows);
}

sub collect_students {
    local $_;

    # Build trans-ref -> city map from registration_data.csv (parent record)
    my ($reg_col, $reg_rows) = parse_csv_file("registration_data.csv");
    my %city_for_trans;
    for my $row (@$reg_rows) {
        my $trans = $row->[$reg_col->{'Trans. Ref. Num.'}] // '';
        my $city  = $row->[$reg_col->{'City'}]             // '';
        $city =~ s/^\s+|\s+$//g;
        $city_for_trans{$trans} = $city if $trans;
    }

    # Read student names from registrant_data.csv and join city via trans ref
    my ($ant_col, $ant_rows) = parse_csv_file("registrant_data.csv");
    for my $row (@$ant_rows) {
        my $first = $row->[$ant_col->{'First Name'}]       // '';
        my $last  = $row->[$ant_col->{'Last Name'}]        // '';
        my $trans = $row->[$ant_col->{'Trans. Ref. Num.'}] // '';

        $first =~ s/^\s+|\s+$//g;
        $last  =~ s/^\s+|\s+$//g;

        my $city = $city_for_trans{$trans} // '';

        push @all_students, { first => $first, last => $last, city => $city };
    }
}

sub soundex_code {
    my ($name) = @_;
    return 'Z000' unless $name;
    $name = uc($name);
    $name =~ s/[^A-Z]//g;
    return 'Z000' unless $name;
    my $first = substr($name, 0, 1);
    (my $coded = $name) =~ tr/AEIOUYHWBFPVCGJKQSXZDTLMNR/000000000111122222233455566/;
    my $rest = substr($coded, 1);
    $rest =~ s/(.)\1+/$1/g;
    $rest =~ s/0//g;
    $rest .= '000';
    return $first . substr($rest, 0, 3);
}

sub normalize_for_match {
    my ($s) = @_;
    $s = lc($s);
    $s =~ s/[^a-z]//g;
    return $s;
}

sub levenshtein {
    my ($s, $t) = @_;
    my @s = split //, $s;
    my @t = split //, $t;
    my @d;
    $d[$_][0] = $_ for 0..@s;
    $d[0][$_] = $_ for 0..@t;
    for my $i (1..@s) {
        for my $j (1..@t) {
            my $cost = $s[$i-1] eq $t[$j-1] ? 0 : 1;
            my $sub  = $d[$i-1][$j-1] + $cost;
            my $del  = $d[$i-1][$j]   + 1;
            my $ins  = $d[$i][$j-1]   + 1;
            $d[$i][$j] = $del < $ins ? ($del < $sub ? $del : $sub)
                                     : ($ins < $sub ? $ins : $sub);
        }
    }
    return $d[@s][@t];
}

sub is_fair_haven {
    my ($city) = @_;
    return levenshtein(normalize_for_match($city), 'fairhaven') <= 2;
}

sub deduplicate_students {
    my %seen;
    my @unique;
    for my $s (@all_students) {
        my $norm_last  = normalize_for_match($s->{last});
        my $norm_first = normalize_for_match($s->{first});
        my $key        = "${norm_last}:" . soundex_code($norm_first);
        push @unique, $s unless $seen{$key}++;
    }
    return @unique;
}

sub generate_student_counts_csv {
    local $_;

    my @unique          = deduplicate_students();
    my $total           = scalar @all_students;
    my $unique_count    = scalar @unique;
    my $fair_haven_count = scalar grep { is_fair_haven($_->{city}) } @unique;

    my $file = "${data_dir}/student-counts.csv";
    open(FILE, '>', $file) || die $! . ": ${file}";
    say FILE '"Metric","Count"';
    say FILE "\"Total registrations\",${total}";
    say FILE "\"Unique students (estimated)\",${unique_count}";
    say FILE "\"Students from Fair Haven (estimated)\",${fair_haven_count}";
    close FILE;
}

sub generate_student_list_csv {
    local $_;

    my @unique = deduplicate_students();

    my $file = "${data_dir}/student-list.csv";
    open(FILE, '>', $file) || die $! . ": ${file}";
    say FILE '"Name (normalized)","Town"';

    for my $s (sort { normalize_for_match($a->{last})  cmp normalize_for_match($b->{last})
                   || normalize_for_match($a->{first}) cmp normalize_for_match($b->{first}) } @unique) {
        my $key  = normalize_for_match($s->{last}) . '|' . normalize_for_match($s->{first});
        my $city = $s->{city};
        say FILE "\"${key}\",\"${city}\"";
    }

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
   ${0} [--data-dir=<path>] [--help]

   --data-dir   Directory containing Session-1..Session-7 subdirectories.
                Defaults to the current directory.
                Example: --data-dir ~/RiverRats/2026

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
