#!/usr/bin/perl
use strict;
use warnings;
use v5.10;
use Getopt::Long qw(:config bundling);
use FindBin;
use Cwd            qw(abs_path);
use File::Basename qw(basename);
use WWW::Mechanize;
use Term::ReadKey;
use MIME::Base64 qw(encode_base64);

require "$FindBin::Bin/riverrats_config.pl";
our ($event_prefix, $club_id);

binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

my $site = 'https://riverratssailing.org';

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
my $session = basename($data_dir);
$session =~ /^Session-\d+$/
    or die "data-dir must be named Session-N (e.g. Session-3), got: $session\n";

my $event_name = "${event_prefix}${session}";
dbg(1, "event:    $event_name");
dbg(1, "data-dir: $data_dir");

my ($user, $pass) = load_credentials();

my $mech = WWW::Mechanize->new(
    autocheck  => 0,
    cookie_jar => {},
    ssl_opts   => { verify_hostname => 1 },
);
$mech->agent(
    'Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0'
);

do_login($mech, $user, $pass);
undef $pass;

my $item_id = find_event($mech, $event_name);
dbg(1, "item_id:  $item_id");

my $reg_count  = fetch_csv($mech, $item_id, 1, "$data_dir/registration_data.csv");
my $ant_count  = fetch_csv($mech, $item_id, 2, "$data_dir/registrant_data.csv");
my $pdf_bytes  = fetch_pdf($mech, $item_id, "$data_dir/Registration_details.pdf");

say "registration_data.csv:    $reg_count registrations";
say "registrant_data.csv:      $ant_count registrants";
say "Registration_details.pdf: $pdf_bytes bytes";

exit 0;

# ─── subroutines ─────────────────────────────────────────────────────────────

sub do_login {
    my ($mech, $user, $pass) = @_;

    my $url = "$site/content.aspx?page_id=31&club_id=${club_id}&action=login&user=5";
    dbg(1, "GET $url");
    $mech->get($url);
    http_die($mech, 'GET login page');
    dbg(3, "--- login page ---\n" . $mech->content);

    # Let Mechanize handle the form so all hidden fields (ViewState etc.) are
    # included automatically.
    my $form = $mech->form_number(1)
        or die "Cannot find login form on login page\n";

    if ($debug >= 2) {
        my @names = map { $_->name // '(unnamed)' } $form->inputs;
        dbg(2, "login form fields: " . join(', ', @names));
    }

    $mech->field('ctl00$ctl00$login_name',    $user);
    $mech->field('ctl00$ctl00$password',      $pass);
    # ClubExpress JavaScript does btoa(password) into hiddenPassword before submit;
    # the server authenticates against this base64-encoded field.
    $mech->field('ctl00$ctl00$hiddenPassword', encode_base64($pass, ''));

    # __EVENTTARGET tells ASP.NET which control fired the postback
    $form->find_input('__EVENTTARGET')->value('ctl00$ctl00$login_button')
        if $form->find_input('__EVENTTARGET');

    dbg(1, "POST login as $user");
    $mech->submit();
    http_die($mech, 'POST login');
    dbg(1, "post-login URI: " . $mech->uri);
    dbg(3, "--- login response (first 2 kB) ---\n" . substr($mech->content, 0, 2000));

    # If we're still on the login page the credentials were rejected
    if ($mech->uri =~ /action=login/) {
        dbg(2, "login response:\n" . $mech->content);
        die "Login failed — credentials rejected. Check "
          . "~/.config/riverrats/credentials\n";
    }

    dbg(1, "login OK");
}

sub find_event {
    my ($mech, $event_name) = @_;

    my $url = "$site/content.aspx?page_id=4004&club_id=${club_id}&actr=2";
    dbg(1, "GET $url");
    $mech->get($url);
    http_die($mech, 'GET events page');

    # If login failed we'd be bounced back to the login page
    if ($mech->uri =~ /action=login/) {
        die "Redirected to login page — authentication failed. "
          . "Check credentials in ~/.config/riverrats/credentials\n";
    }
    dbg(3, "--- events page ---\n" . $mech->content);

    my $form = $mech->form_number(1)
        or die "Cannot find search form on events page\n";

    $mech->field('ctl00$ctl00$title_text', $event_name);
    $form->find_input('__EVENTTARGET')->value('ctl00$ctl00$search_button')
        if $form->find_input('__EVENTTARGET');

    dbg(1, "POST search for '$event_name'");
    $mech->submit();
    http_die($mech, 'POST event search');

    my $body = $mech->content;
    dbg(2, "--- event search (first 3 kB) ---\n" . substr($body, 0, 3072));
    dbg(3, "--- event search full ---\n$body");

    # Edit links look like:
    #   /content.aspx?page_id=4055&club_id=NNN&item_id=NNN&...
    my ($item_id) = $body =~ /page_id=4055[^"']*?item_id=(\d+)/;
    unless (defined $item_id) {
        print STDERR "ERROR: event '$event_name' not found on website\n";
        print STDERR "Re-run with -dd to dump the search response\n"
            if $debug < 2;
        dbg(2, "search response:\n$body");
        exit 1;
    }

    return $item_id;
}

sub fetch_csv {
    my ($mech, $item_id, $type, $file) = @_;
    # $type: 1 = Registration Data, 2 = Registrant Data

    my $url   = "$site/popup.aspx?page_id=4036&club_id=${club_id}&item_id=${item_id}";
    my $label = $type == 1 ? 'registration' : 'registrant';

    # Fresh GET for each export so the VIEWSTATE is current
    dbg(1, "GET $url  ($label data)");
    $mech->get($url);
    http_die($mech, "GET export form ($label)");
    dbg(3, "--- export form ($label) ---\n" . $mech->content);

    my %f = hidden_fields($mech->content);
    $f{'__EVENTTARGET'}   = 'ctl00$save_button';
    $f{'__EVENTARGUMENT'} = '';

    # Radio button selects which data set: 1=Registration, 2=Registrant
    $f{'ctl00$export_radiobuttonlist'} = $type;

    # Telerik status multi-select — matches the manual HAR capture:
    # indices 0=Open, 1=Paid, 3=Not paid in time limit
    $f{'ctl00$registration_status_dropdown'} =
        'Open, Paid, Not paid in time limit';
    $f{'ctl00_registration_status_dropdown_ClientState'} =
        '{"logEntries":[],"value":"Open, Paid, Not paid in time limit",'
      . '"text":"Open, Paid, Not paid in time limit","enabled":true,'
      . '"checkedIndices":[0,1,3],"checkedItemsTextOverflows":false}';

    dbg(1, "POST $label export");
    $mech->post($url, Content => \%f);
    http_die($mech, "POST $label export");

    my $ct = $mech->ct;
    unless ($ct =~ m{text/csv}i) {
        print STDERR "ERROR: expected text/csv for $label export, got: $ct\n";
        dbg(2, "response body:\n" . $mech->content);
        exit 1;
    }

    my $csv = $mech->content;
    dbg(3, "--- $label CSV ---\n$csv");

    open(my $fh, '>', $file) or die "Cannot write $file: $!\n";
    binmode $fh;
    print $fh $csv;
    close $fh;

    # Count non-blank lines; subtract 1 for the header row
    my $lines = () = $csv =~ /[^\n]*\S[^\n]*/g;
    my $count = $lines > 0 ? $lines - 1 : 0;

    return $count;
}

sub fetch_pdf {
    my ($mech, $item_id, $file) = @_;

    # Step 1: GET the reports popup (report list)
    # Note the intentional double && in the URL — matches ClubExpress's own link
    my $url = "$site/popup.aspx?page_id=128&club_id=${club_id}&&report_group_id=14&sp1=${item_id}";
    dbg(1, "GET $url  (reports popup)");
    $mech->get($url);
    http_die($mech, 'GET reports popup');
    dbg(3, "--- reports popup ---\n" . $mech->content);

    # Step 2: POST to select report 277 "Registration Details with Page Break"
    my %f = hidden_fields($mech->content);
    $f{'__EVENTTARGET'}     = 'ctl00$run_button';
    $f{'__EVENTARGUMENT'}   = '';
    $f{'report_id'}         = '277';
    $f{'ctl00$report_list'} = '277';
    $f{'submit_step'}       = 'SelectReport';
    $f{'next_step'}         = 'SelectReport';
    $f{'sp1'}               = $item_id;

    dbg(1, "POST select report 277 (Registration Details with Page Break)");
    $mech->post($url, Content => \%f);
    http_die($mech, 'POST report selection');
    dbg(3, "--- report output options ---\n" . $mech->content);

    # Step 3: Extract report_queue_id and member_id from the OutputOptions form
    # report_queue_id is generated fresh by the server for each report request
    my %opts      = hidden_fields($mech->content);
    my $rq_id     = $opts{'report_queue_id'};
    my $member_id = $opts{'member_id'} // '';

    unless ($rq_id && $rq_id ne '0') {
        print STDERR "ERROR: did not receive a valid report_queue_id\n";
        dbg(2, "report options response:\n" . $mech->content);
        exit 1;
    }
    dbg(1, "report_queue_id=$rq_id  member_id=$member_id");

    # Step 4: GET the PDF from ClubExpress's external report renderer
    # The browser's JavaScript strips ASP.NET fields and submits these via GET.
    # output_format: 1=PDF, 4=Word, 5=Excel, 17=HTML, 19=CSV
    my $pdf_url = 'https://reports.clubexpress.com/create_report.ashx'
                . "?club_id=${club_id}"
                . "&member_id=${member_id}"
                . "&output_format=1"
                . "&papersize=Default"
                . "&report_queue_id=${rq_id}"
                . "&report_title=Registration+Details"
                . "&sp1=${item_id}";

    dbg(1, "GET $pdf_url");
    $mech->get($pdf_url);
    http_die($mech, 'GET PDF from reports.clubexpress.com');

    my $ct = $mech->ct;
    unless ($ct =~ m{application/pdf}i || $ct =~ m{application/octet-stream}i) {
        print STDERR "ERROR: expected PDF, got: $ct\n";
        dbg(2, "response body (first 2 kB):\n" . substr($mech->content, 0, 2048));
        exit 1;
    }

    my $pdf = $mech->content;
    open(my $fh, '>', $file) or die "Cannot write $file: $!\n";
    binmode $fh;
    print $fh $pdf;
    close $fh;

    return length($pdf);
}

# ─── utilities ───────────────────────────────────────────────────────────────

sub hidden_fields {
    my ($html) = @_;
    my %fields;

    # Match every <input type="hidden" ...> regardless of attribute order
    while ($html =~ /<input\b([^>]*)>/gi) {
        my $attrs = $1;
        next unless $attrs =~ /\btype\s*=\s*["']?hidden["']?/i;
        my ($name)  = $attrs =~ /\bname\s*=\s*["']([^"']*)["']/i;
        my ($value) = $attrs =~ /\bvalue\s*=\s*["']([^"']*)["']/i;
        next unless defined $name && $name ne '';
        $value //= '';
        $value =~ s/&amp;/&/g;
        $value =~ s/&quot;/"/g;
        $value =~ s/&lt;/</g;
        $value =~ s/&gt;/>/g;
        $fields{$name} = $value;
    }

    return %fields;
}

sub http_die {
    my ($mech, $step) = @_;
    return if $mech->success;
    my $status = $mech->status // '?';
    my $uri    = $mech->uri   // '?';
    print STDERR "ERROR: $step — HTTP $status at $uri\n";
    dbg(2, "response body:\n" . ($mech->content // '(empty)'));
    exit 1;
}

sub load_credentials {
    my $cred_file = "$ENV{HOME}/.config/riverrats/credentials";

    if (-r $cred_file) {
        my ($user, $pass);
        open(my $fh, '<', $cred_file) or die "Cannot open $cred_file: $!\n";
        while (<$fh>) {
            chomp; s/#.*//; s/^\s+|\s+$//g; next unless /\S/;
            if (/^username\s*=\s*(.+)$/) { ($user = $1) =~ s/\s+$// }
            if (/^password\s*=\s*(.+)$/) { ($pass = $1) =~ s/\s+$// }
        }
        close $fh;
        die "No 'username' in $cred_file\n" unless defined $user;
        die "No 'password' in $cred_file\n" unless defined $pass;
        dbg(1, "credentials from $cred_file (username=$user)");
        return ($user, $pass);
    }

    print "Username: ";
    chomp(my $user = <STDIN>);
    print "Password: ";
    ReadMode('noecho');
    chomp(my $pass = <STDIN>);
    ReadMode('restore');
    print "\n";
    return ($user, $pass);
}

sub dbg {
    my ($level, $msg) = @_;
    return if $level > $debug;
    print STDERR $msg, "\n";
}

sub usage {
    (my $prog = $0) =~ s{.*/}{};
    return <<END;
Downloads registration_data.csv and registrant_data.csv for a Junior Sailing
session directly from riverratssailing.org (ClubExpress).

usage:
   $prog [--data-dir <dir>] [-d|-dd|-ddd] [--help]

Options:
   --data-dir <dir>   Directory to write the downloaded files into.
                      Must be named Session-N (e.g. Session-3).
                      Default: current directory.

   -d                 Debug level 1: log each HTTP request to stderr.
   -dd                Debug level 2: also dump response body on errors.
   -ddd               Debug level 3: dump all HTML and CSV responses.

   --help             Show this message.

Credentials are read from ~/.config/riverrats/credentials.
See README.md for setup instructions.

On success, stdout reports each file and its entry count:
   registration_data.csv: 42 registrations
   registrant_data.csv:   85 registrants
END
}
