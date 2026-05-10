# Shared configuration for River Rats Sailing scripts.
# Used by grab-session-data.pl, gen-all.pl
#
# Callers must declare the variables they use with "our":
#   require "$FindBin::Bin/riverrats_config.pl";
#   our ($event_prefix, $club_id, @sessions);

our $event_prefix = 'Junior Sailing ';   # prepended to "Session-N" in event titles
our $club_id      = 643531;              # ClubExpress club ID for riverratssailing.org
our @sessions     = qw(Session-1 Session-2 Session-3 Session-4 Session-5 Session-6 Session-7);

1;
