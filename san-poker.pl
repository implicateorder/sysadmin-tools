#!/usr/bin/perl -w

# $Id: san-poker.pl,v 1.1 2008/09/26 18:06:01 ch1dlah1 Exp ch1dlah1 $
# $Log: san-poker.pl,v $
# Revision 1.1  2008/09/26 18:06:01  ch1dlah1
# Initial revision
#
# $Author: ch1dlah1 $

use strict;
use Getopt::Long;

my $fcinfo = "/usr/sbin/fcinfo";
my $luxadm = "/usr/sbin/luxadm";
my $format = "/usr/sbin/format";
my $iostat = "/usr/bin/iostat";
my $cfgadm = "/usr/sbin/cfgadm";
my $mpathadm = "/usr/sbin/mpathadm";

my $help = '';
my $getwwn = '';
my $getluns = '';
my $getpaths = '';
my $all = '';

GetOptions(
'help' => \$help,
'all' => \$all,
'getwwn' => \$getwwn,
'getluns' => \$getluns,
'getpaths' => \$getpaths
);

if ( $help ) {
    &printUsage && exit(0);
}

if ( $all && ( $getwwn or $getluns or $getpaths )) {
	&printUsage && exit(1);
}

if ( $all && !($getwwn or $getluns or $getpaths)) {
	&getAll;
}

if ( $getwwn ) {
	&getWwns;
}

if ( $getluns ) {
	&getLuns;
}

if ( $getpaths ) {
	&getPaths;
}

sub printUsage {

print "Usage: $0 [--help|--all|--getwwn|--getluns|--getpaths]
	--help 		-	print this message
	--all		-	run all options
	--getwwn	- 	get WWN of all HBAs on the system
	--getluns	-	get LUN info 
	--getpaths	-	get path info (mpxio)
This program has been written to work only on Solaris systems with the Leadville SAN Stack and mpxio enabled\n";
}

my %wwns;
my @hbadevs;
my %sanpaths;
my $sanpaths;
my @sandevs;
my %luninfo;
my @lunlist;

sub getWwns {
 print "Probing the system for HBAs connected in Fabric mode...\n";
 my @cfgadmout = qx/$cfgadm -al|grep \"fc-fabric\"/;

 my ($hba, $topology, $receptacle, $occupant, $condition);
 for (@cfgadmout) {
    chomp($_);
    ($hba, $topology, $receptacle, $occupant, $condition) = split(' ', $_);
    push(@hbadevs, $hba);
 }
  print "Found following HBAs connected in a Fabric Topology...\n";
  for (@hbadevs) {
	chomp;
	my $hbadev = "/dev/cfg/$_";
	print "$hbadev \n";
	print "Gathering Port WWNs for each HBA...\n";
	
	my $wwn = qx/$luxadm -e dump_map $hbadev|grep \"Host Bus Adapter\"/;
	my ($pos, $portid, $hard_addr, $pwwn, $nwwn, $type) = split(' ', $wwn);
	$wwns{$hbadev} = $pwwn;
   }

   foreach my $dev (keys(%wwns)) {
	print "$dev --> $wwns{$dev} \n";
   }
}

sub getPaths {
    print "Probing system for SAN Multipathing information...\n";
    my @mpathadmlist = qx/$mpathadm list lu | grep \"rdsk\"/;
    my ($totalpaths, $operpaths);
    foreach my $lun (@mpathadmlist) {
	$lun =~ s/^\s+//;
	my @tpathfull = qx/$mpathadm list lu $lun/;
	for (@tpathfull) {
	    next if ( $_ !~  m/Total Path Count/i );
	    my $label;
	    ($label, $totalpaths) = split(':', $_);
	}
	for (@tpathfull) {
	    next if ( $_ !~ m/Operational Path Count/i );
	    my $label;
	    ($label, $operpaths) = split(':', $_);
	}
	chomp($totalpaths, $operpaths);
	$sanpaths{$lun} = "TOTAL PATHS = $totalpaths, OPERATIONAL PATHS = $operpaths";
    }
    foreach my $lun (keys(%sanpaths)) {
	my $nlun = $lun;
	chomp($nlun);
	print " $nlun --> $sanpaths{$lun} \n";
    }
}

sub getLuns {

    print "Poking the system for LUN information...\n";
    my @luxadmout = qx/$luxadm probe |grep "Logical Path"/;
    for (@luxadmout) {
	my ($label, $lun) = split(':', $_);
	chomp($lun);
	push(@lunlist, $lun);	
    }
    foreach my $lun (@lunlist) {
	chomp $lun;
	my @luxadminfo = qx/$luxadm display $lun/;
	print "Properties of $lun...\n";
	print "@luxadminfo";
	sleep(2);
    }
}

sub getAll {

    &getWwns;
    &getPaths;
    &getLuns;
    
}
