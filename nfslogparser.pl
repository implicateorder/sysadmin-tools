#!/usr/bin/perl 

use Data::Dumper;
use POSIX;

#use strict 'refs';

my $lscmd = "/usr/bin/ls";
my $lsopt = "-latr";

my @files = qx/$lscmd $lsopt/;
my @fnames;

foreach my $line (@files) {
   chomp $line;
   my ( $perm, $inode, $user, $group, $size, $month, $day, $time, $name) = split(/\s+/, $line);
   chomp $name;
   next if ($name =~ /\.|\.\.|$0|gz|undef/);
   push(@fnames, $name);
}

foreach my $file (@fnames) {
   next unless (-f $file);
   next unless (defined $file);
   ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
   my $year = POSIX::strftime("%Y", localtime($mtime));
   print "$year is \n";
   my %stats = &getInfo($file);
   foreach my $host (sort keys(%stats)) {
	my %h1 = %{$stats{$host}};
	foreach my $mon (keys(%h1)) {
	    my %h2 = %{$h1{$mon}};
	    foreach my $day (keys(%h2)) {
		my %h3 = %{$h2{$day}};
		foreach my $time (keys(%h3)) {
		    my %h4 = %{$h3{$time}};
		    foreach my $server (keys(%h4)) {
			my %h5 = %{$h4{$server}};
			foreach my $resp (keys(%h5)) {
		            my $count = $h5{$resp};
		    	    print "$host,$year,$mon,$day,$time,$server,$resp,$count \n";
			}
		    }
		}
	    }
	}
    }
}

  


sub getInfo {
    my $file = shift;
    print "Processing $file...\n";
    open(RIF, "< $file") or die "can't open $file: $! \n";
    my %hash = ();
    for (<RIF>) {
	next unless ($_ =~ m/nfs/i);
	chomp;
        if ($_ =~ m/not responding/i ) {
	   my ($str1, $str2) = split(/nfs:/, $_);
	   my @ctl = split(/\s+/, $str1);
	   my $mon = $ctl[0]; 
	   my $day = $ctl[1]; 
	   my $time = $ctl[2];
	   #$time =~ s/\://gix;
	   my $host = $ctl[3];
	   #$host =~ s/\-//gix;
	   my $process = $ctl[4]; 
	   my @msg = split(/\s+/, $str2);
	   my $server = $msg[2];
	   if (!defined $server) { $server = "TBD"; };
	   $hash{$host}{$mon}{$day}{$time}{$server}{"NORESP"}++;

	}
	elsif ( $_ =~ m/OK/ ) {
	   my ($str1, $str2) = split(/nfs:/, $_);
	   my @ctl = split(/\s+/, $str1);
	   my $mon = $ctl[0]; 
	   my $day = $ctl[1]; 
	   my $time = $ctl[2];
	   #$time =~ s/\://gix;
	   my $host = $ctl[3];
	   #$host =~ s/\-//gix;
	   my $process = $ctl[4]; 
	   my @msg = split(/\s+/, $str2);
	   my $server = $msg[2];
	   if (!defined $server) { $server = "TBD"; };
	   $hash{$host}{$mon}{$day}{$time}{$server}{"OK"}++;
	}
	else {
	    # Do nothing;
	}
     }
     return %hash;
     close(RIF);
}
