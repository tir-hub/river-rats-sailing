#!/usr/bin/perl
use strict;
use warnings;
use v5.10;
use Getopt::Long;
use Data::Dumper;
use Text::ParseWords;

my $cmd = $0;

my $additional_charges_file = "Additional-Charges.csv";
my $additional_data_file   = "Additional-Data.csv";
my $length = 24;
my $verbose;
my $help = 0;

GetOptions ("length=i"    => \$length,
            "charges=s"   => \$additional_charges_file,
            "data=s"   => \$additional_data_file,
            "verbose"     => \$verbose,
            "help"        => \$help)
    ||  die usage();


if ($help) {
    say usage();
    exit(0);
}



# Registrant titles
# "Title","Date/Time","Status","Trans. Ref. Num.","Registrant Fees","First Name","Middle Initial","Last Name","Nickname","Email","Phone","Address 1","Address 2","City","State","Postal Code","Country","Company","Cell Phone","Work Title","Primary Member?","Member?","Member Number","Registrant Type","Primary Registrant Name","Sequence Number","Age","Sailing Level","TShirt size","List food allergies","List drug allergies","List environmental allergies","Restricted nonprescription medications","Has Epipen","Sweeps","Permission for Lunch OffPremises","PhotoWeb Release"

# Registration titles
#"Title","Date/Time","Total Fee","Status","Trans. Ref. Num.","First Name","Middle Initial","Last Name","Nickname","Member Number","Email","Phone","Address 1","Address 2","City","State","Postal Code","Country","Company","Work Title","Cell Phone","Primary Member?","Companion Count","Member?","Registrant Type","Sequence Number","Nondiscriminatory Policy","Parental lnvolvement","Parent and Student Meeting","Courtesy and Respect Agreement","Emergency Contact First Name","Emergency Contact Last Name","Emergency Contact Phone Number","Emergency Contact Alternate Phone Number"

# Registrant names
my $email = "email";
my $paid = "paid";
my $price = "price";
my $date = "date";
my $rack_type = "rackType";
my $boat_type = "boatType";
my $single_racks = "singles";
my $double_racks = "doubles";
my $lower = "lower";
my $comments = "comments";
my $boat_type_comments = "boatTypeComments";

# values
my $single = "Single";
my $double = "Double";



my $charges = parse_charges($additional_charges_file);

say "";
say "charges";
say Dumper($charges);


parse_data($additional_data_file, $charges);

say "";
say "charges+data";
say Dumper($charges);

generate_kayak_csv($charges);

sub parse_charges {
    my ($file) = @_;
    local $_;

    open(FILE, '<', $file) || die $! . ": ${file}";
    my @lines = <FILE>;
    close FILE;
    
    chomp @lines;

    my %result = ();
    my $result = \%result;

    foreach (@lines) {
	if (/^"Kayak Rack Space/) {
	    parse_charges_line($_, $result);
	}
    }
    return $result;
}

sub parse_charges_line {
    my ($line, $result) = @_;
    local $_;

    $line =~ s/\r$//;

    if ($line =~ m/,$/) {
	$line = $line . "\"\"";
    }

    my @items = parse_line(',', 0, $line);

    my $name = $items[10];

    $result->{$name}->{$rack_type} = $items[0];
    $result->{$name}->{$date} = $items[8];
    $result->{$name}->{$email} = $items[11];
    if ($items[0] =~ m/Single/) {
	$result->{$name}->{$single_racks} = $items[12];
    } elsif ($items[0] =~ m/Double/) {
	$result->{$name}->{$double_racks} = $items[12];
    }
    $result->{$name}->{$price} = $items[13];
    $result->{$name}->{$paid} = $items[14];

}

sub parse_data {
    my ($file, $result) = @_;
    local $_;

    open(FILE, '<', $file) || die $! .  ": ${file}";
    my @lines = <FILE>;
    close FILE;
    
    chomp @lines;

    my @result = ();

    foreach (@lines) {
	if (/Require Lower Rack?/) {
	    parse_lower_rack_line($_, $result);
	}
	elsif (/Rack Boat Type/) {
	    parse_boat_type_line($_, $result);
	}
	
    }
}

sub parse_lower_rack_line {
    my ($line, $result) = @_;
    local $_;

    $line =~ s/\r$//;

    if ($line =~ m/,$/) {
	$line = $line . "\"\"";
    }

    my @items = parse_line(',', 0, $line);

    my $name = $items[0];
    $name =~ s/(.*)\(\d+\)\s*/$1/;
    $name =~ s/\s*$//;

    if ($result->{$name}) {
	$result->{$name}->{$lower} = $items[2];
	$result->{$name}->{$comments} = $items[5];
    }
}

sub parse_boat_type_line {
    my ($line, $result) = @_;
    local $_;

    $line =~ s/\r$//;

    if ($line =~ m/,$/) {
	$line = $line . "\"\"";
    }

    my @items = parse_line(',', 0, $line);

    if (!@items) {
	return;
    }

    my $name = $items[0];
    $name =~ s/(.*)\(\d+\)\s*/$1/;
    $name =~ s/\s*$//;

    if ($result->{$name}) {
	$result->{$name}->{$boat_type} = $items[2];
	$result->{$name}->{$boat_type_comments} = $items[5];
    }
}




sub generate_kayak_csv {
    my ($charges) = @_;
    local $_;

    open(FILE, '>', "Kayak-racks.csv") || die $!;
    say FILE 'Name,Boat_type,Single Racks,Double Racks,Lower,Email,Price,Paid,Comments,Boat_type_comments,Rack_number';

    foreach my $name (sort keys %$charges) {
	my $type_val = $charges->{$name}->{$rack_type};
	my $boat_type_val = $charges->{$name}->{$boat_type};
	my $singles_val = $charges->{$name}->{$single_racks};
	my $doubles_val = $charges->{$name}->{$double_racks};
	my $lower_val = $charges->{$name}->{$lower};
	my $email_val = $charges->{$name}->{$email};
	my $price_val = $charges->{$name}->{$price};
	my $paid_val = $charges->{$name}->{$paid};
	my $comments_val = $charges->{$name}->{$comments};
	my $boat_type_comments_val = $charges->{$name}->{$boat_type_comments};

	if (!$singles_val) {
	    $singles_val = "";

	}
	if (!$doubles_val) {
	    $doubles_val = "";

	}
	if (!$lower_val) {
	    $lower_val = "No";
	}
	if (!$boat_type_val) {
	    $boat_type_val = "";
	}
	if (!$comments_val) {
	    $comments_val = "";
	}
	if (!$boat_type_comments_val) {
	    $boat_type_comments_val = "";
	}


	$type_val =~ s/Kayak Rack Space \((\w*)\)/$1/;
	
	say FILE "\"${name}\",\"${boat_type_val}\",\"${singles_val}\",\"${doubles_val}\",\"${lower_val}\",\"${email_val}\",\"${price_val}\",\"${paid_val}\",\"${comments_val}\",\"${boat_type_comments_val}\",";
    }

    close FILE;
}


sub usage {

my $usage = <<'END_MESSAGE';
usage: ${cmd} [--charges=file] [--data=file]

--charges charges csv file.  Defauts to Addtional-Charges.csv
--data    data csv file.  Defauts to Addtional-Charges.csv

First:
Download addtional charges:
     Control Panel->Money->Reports->Member/User Transactions->Additional Charges->
           All,Paid Only->Active Members checked, Member Type: Family Member, All Members->
           Select Period: This Year->CSV(Unformated)->Run Report
and save the report in a file called Additional-Charges.csv



Download addtional data
Control-Panel->People->Reports->Membership Info->Additional Member Data->
           All,Paid Only->Active Members checked, Member Type: Family Member,Primary Members Only->
           CSV(Unformated)->Run Report
and save the report in a file called Additional-Data.csv

then run commnand

END_MESSAGE

return $usage

}
