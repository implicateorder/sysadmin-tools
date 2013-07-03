#!/usr/bin/perl -w
#

open(RIF, "< /var/tmp/rhel_nonprod_vsm.txt") or die "Unable to read file /var/tmp/rhel_nonprod_vsm.txt: $! \n";
my @RIF = <RIF>;
close(RIF);

for (@RIF) {
	if ( $_ =~ m/^(\w+\d*)\-(\w+\d*)\-(\w+\d*)/...m/^(\w+\d*)\-(\w+\d*)\-(\w+\d*)/ ) {
	   my @foo;
	   if ( $_ =~ m/^(\w+\d*)\-(\w+\d*)\-(\w+\d*)/ ) {
		my $host = $_;
		push(@foo,$host);
	   }

	   for (@foo) {
	     next if ( m/^\s*$/);
	     
	   }
	}
}
