#!/usr/bin/perl
use strict;
use warnings;
use v5.10;
use Getopt::Long;
use Data::Dumper;
# use Text::CSV;
use Text::ParseWords;

my $registration_file = "registration_data.csv";
my $registrant_file   = "registrant_data.csv";
my $length = 24;
my $verbose;
my $help = 0;

GetOptions ("length=i" => \$length,
            "registration=s"   => \$registration_file,
            "registrant=s"   => \$registrant_file,
            "verbose"  => \$verbose,
            "help"     => \$help)
    ||  die usage();


if ($help) {
    say usage();
    exit(0);
}

say "generating reports";

# Registrant titles
# "Title","Date/Time","Status","Trans. Ref. Num.","Registrant Fees","First Name","Middle Initial","Last Name","Nickname","Email","Phone","Address 1","Address 2","City","State","Postal Code","Country","Company","Cell Phone","Work Title","Primary Member?","Member?","Member Number","Registrant Type","Primary Registrant Name","Sequence Number","Age","Sailing Level","TShirt size","List food allergies","List drug allergies","List environmental allergies","Restricted nonprescription medications","Has Epipen","Sweeps","Permission for Lunch OffPremises","PhotoWeb Release"

# Registration titles
#"Title","Date/Time","Total Fee","Status","Trans. Ref. Num.","First Name","Middle Initial","Last Name","Nickname","Member Number","Email","Phone","Address 1","Address 2","City","State","Postal Code","Country","Company","Work Title","Cell Phone","Primary Member?","Companion Count","Member?","Registrant Type","Sequence Number","Nondiscriminatory Policy","Parental lnvolvement","Parent and Student Meeting","Courtesy and Respect Agreement","Emergency Contact First Name","Emergency Contact Last Name","Emergency Contact Phone Number","Emergency Contact Alternate Phone Number"

# Registrant names
my $first_name_title = '"First Name"';
my $last_name_title = '"Last Name"';
my $transaction_title = '"Trans. Ref. Num."';
my $t_shirt_title = '"TShirt size"';
my $off_prem_lunch_title = '"Permission for Lunch OffPremises"';
my $phone_title = '"Phone"';
my $cell_phone_title = '"Cell Phone"';
my $emergency_first_name_title = '"Emergency Contact First Name"';
my $emergency_last_name_title = '"Emergency Contact Last Name"';
my $emergency_phone_title = '"Emergency Contact Phone Number"';
my $event_title_title = '"Title"';
my $food_alergies = '"List food allergies"';
my $drug_alergies = '"List drug allergies"';
my $environ_alergies = "List environmental allergies";
my $epipen = '"Has Epipen"';
my $restricted_nonprescription = '"Restricted nonprescription medications"';
my $sailing_level_title = '"Sailing Level"';

my $registrations = parse_csv($registration_file);
my $unsorted_registrants = parse_csv($registrant_file);

my @registrants = sort {lc($a->{$last_name_title}) cmp lc($b->{$last_name_title})} @$unsorted_registrants;
my $registrants = \@registrants;

my $event_title = $registrants->[0]->{${event_title_title}};

say "";
say "registrations";
say Dumper($registrations);

say "";
say "registrants";
say Dumper($registrants);

my $registrations_hash = registrations_to_hash($registrations);

say "";
say "registrations_hash";
say Dumper($registrations_hash);

generate_attendance_csv($registrations_hash, $registrants);
generate_attendance_txt($registrations_hash, $registrants);
generate_sailing_level_counts_csv($registrations_hash, $registrants);

sub parse_csv {
    my ($file) = @_;
    local $_;

    open(FILE, '<', $file) || die $! . ": ${file}";
    my @lines = <FILE>;
    close FILE;
    
    chomp @lines;
    my $line;

    ($line, @lines) = @lines;
    $line =~ s/\r$//;
    
    my @titles = split(/,/, $line);
    say @titles;

    my @result = ();

    foreach (@lines) {
	my $result = parse_csv_line(\@titles, $_);
	@result = (@result, $result);
    }
    return \@result;
}

sub parse_csv_line {
    my ($titles, $line) = @_;
    local $_;

    $line =~ s/\r$//;

    if ($line =~ m/,$/) {
	say "line ends with ,";
	$line = $line . "\"\"";
    }

    my @titles = @$titles;
    my @items = parse_line(',', 0, $line);

    my %result = ();
    my $result = \%result;

    foreach my $title (@titles) {
	my $item;
	($item, @items) = @items;

# 	say "${title} -> ${item}";
	$result->{$title} = $item;
    }

    return $result;

}

sub generate_attendance_csv {
    my ($registation_hash, $registrants) = @_;
    local $_;

    my $short_event = $event_title;
    my $file = "Attendance ${short_event}.csv";
    open(FILE, '>', $file) || die $! . ": ${file}";
    say FILE '"Student","T-shirt","Contact","Lunch-off-prem", "Alergies", "Full Signature and Time"';

    foreach my $registrant (@$registrants) {
	my ($name, $t_shirt, $contact, $phone, $cell, $emergency_contact, $emergency_phone,  $lunch, $alergies) = generate_attendance($registation_hash, $registrant);
	say FILE "\"${name}\",\"${t_shirt}\",\"${contact}\",\"${lunch}\",\"${alergies}\",In:  ______________ Time:_______";
	say FILE ",,\"${phone}\",";
	if ($cell) {
	    say FILE ",,\"${cell} M\",,,Out: ______________ Time:_______";
	    say FILE ",,\"${emergency_contact}\",";
	} else {
	    say FILE ",,\"${emergency_contact}\",,,Out: ______________ Time:_______";
	}
	say FILE ",,\"${emergency_phone}\",";
	say FILE ",,,";
    }

    close FILE;
}

sub generate_attendance_txt {
    my ($registation_hash, $registrants) = @_;
    local $_;
    my $name;
    my $t_shirt;
    my $contact;
    my $phone;
    my $cell_phone;
    my $emergency_contact;
    my $emergency_phone;
    my $lunch;
    my $alergies;

format ATTENDANCE_TOP =

@|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
                        "${event_title} Attendance"

Name                T-Shirt          Contact          Lunch      Alergies    Full Signature and Time
                                                      off-prem
--------------------------------------------------------------------------------------------------------------

.

format ATTENDANCE =
@<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<< @<<<<<<<   @<<<<<<<    @||||||||||||||||||||||||||||||||
$name,             $t_shirt,         $contact,        $lunch,    $alergies,  "In:  ______________ Time:_______"
                                     @<<<<<<<<<<<<<<<          
                                     $phone                    
                                     @<<<<<<<<<<<<<<<                        @||||||||||||||||||||||||||||||||
                                     $cell_phone,                            "Out: ______________ Time:_______"
                                     @<<<<<<<<<<<<<<<          
                                     $emergency_contact
                                     @<<<<<<<<<<<<<<<          
                                     $emergency_phone                    

.    

    my $file = "Attendance.txt";
    open(FILE, '>', "Attendance.txt") || die $! . ": ${file}";
    select FILE;

    $~ = 'ATTENDANCE_TOP';
    write;
    

    foreach my $registrant (@$registrants) {
	my $cell;
	($name, $t_shirt, $contact, $phone, $cell, $emergency_contact, $emergency_phone,  $lunch, $alergies) = generate_attendance($registation_hash, $registrant);
	$cell_phone = '';
	if ($cell) {
	    $cell_phone = "${cell} M";
	}
	$~ = 'ATTENDANCE';
	write;
    }

    close FILE;
}

sub generate_attendance {
    my ($registation_hash, $registrant) = @_;
    local $_;

    my $name = name($registrant);
    my $t_shirt = $registrant->{$t_shirt_title};
    my $lunch_perm = $registrant->{$off_prem_lunch_title};
    my @contacts = contacts($registation_hash, $registrant);
    my $alergies = alergies($registrant);

    return ($name, $t_shirt, @contacts, $lunch_perm, $alergies);
}

sub generate_sailing_level_counts_csv {
    my ($registation_hash, $registrants) = @_;
    local $_;

    my $total = 0;
    my $beginner = 0;
    my $intermediate = 0;
    my $advanced = 0;
    my $unsure = 0;

    my $file = "sailing-level-counts.csv";
    open(FILE, '>', $file) || die $! . ": ${file}";
    say FILE '"Total","Beginners","Intermediates","Advanced","Unsure"';


    foreach my $registrant (@$registrants) {
	$total++;
        my $level = $registrant->{$sailing_level_title};
	if ($level eq "Beginner") {
	    $beginner++;
	}
	if ($level eq "Intermediate") {
	    $intermediate++;
	}
	if ($level eq "Advanced") {
	    $advanced++;
	}
	if ($level eq "Unsure") {
	    $unsure++;
	}
    }
	
    say FILE "${total},${beginner},${intermediate},${advanced},${unsure}";

    close FILE;
}

sub alergies {
    my ($registrant) = @_;
    local $_;

    my $no = "No";
    my $yes = "Yes";

    if (is_alergy($registrant->{$food_alergies})) {
	return $yes;
    }
    if (is_alergy($registrant->{$drug_alergies})) {
	return $yes;
    }
    if (is_alergy($registrant->{$environ_alergies})) {
	return $yes;
    }
    
    if ($registrant->{$restricted_nonprescription}) {
	return $yes;
    }
    if ($registrant->{$epipen} =~ m/^Y/i) {
	return $yes;
    }

    return $no;

}

sub is_alergy {
    my ($item) = @_;
    local $_;

    if (!$item) {
	return 0;
    }

    chomp $item;
    
    if ($item && $item !~ m/none/i) {
	return 1;
    }

    return 0;
    
}

sub name {
    my ($registrant) = @_;
    local $_;

    my $first_name = $registrant->{$first_name_title};
    $first_name =~ s/"//g;
    my $last_name = $registrant->{$last_name_title};
    $last_name =~ s/"//g;
    my $name = "${first_name} ${last_name}"; 

    return $name;
}

sub emergency_name {
    my ($registration) = @_;
    local $_;

    my $first_name = $registration->{$emergency_first_name_title};
    $first_name =~ s/"//g;
    my $last_name = $registration->{$emergency_last_name_title};
    $last_name =~ s/"//g;
    my $name = "${first_name} ${last_name}"; 

    return $name;
}

sub contacts {
    my ($registation_hash, $registrant) = @_;
    local $_;

    my $registration = $registation_hash -> {$registrant->{$transaction_title}};
    
    my $name = name($registration);
    my $phone = $registration->{$phone_title};
    my $cell = $registration->{$cell_phone_title};
    my $emergency_name = emergency_name($registration);
    my $emergency_phone = $registration->{$emergency_phone_title};

    $name =~ s/"//g;
    $phone =~ s/"//g;
    $cell =~ s/"//g;
    $emergency_name =~ s/"//g;
    $emergency_phone =~ s/"//g;
    
    return ($name, $phone, $cell, $emergency_name, $emergency_phone);
}

sub registrations_to_hash {
    my ($registrations) = @_;
    local $_;

    my %registrations = ();
    my $result = \%registrations;

    foreach my $registration (@$registrations) {
$result -> {$registration -> {$transaction_title}} = $registration;
    }
    return $result;
}

sub usage {

my $usage = <<'END_MESSAGE';

Generates the attendance file for the class in both text and csv form.

usage:
   $0 [--registrant=file] [--registration=file]

   default registrant filename: registrant_data.csv
   default registration filename: registration.csv
   generated attendance csv filename: Attendance <class> Junior Sailing Class Session-<session-number>.csv     example: Attendance M-W-F Junior Sailing Class Session-1.csv
   generated attendabce text filename:  Attendance.txt

First export the registration and registrant data into a directory, then run this program.

To export the the reistration and registrant data:
    * login to website
    * select "Events" tab
    * click pencil icon on right
    * select the calendar like icon it the little admin pannel towards the top right to "export"
    * check "Registration Data" or "Restrant Data".. you will do this process twice, once for each
    * then in the "Status" check "Paid" and possibly "Open" then click "Export"



END_MESSAGE

}
