#!/usr/bin/perl -w

# $Id$
# $Log$
# NOTE: This script is meant to work for luns that are multi-pathed using Solaris' MPXIO driver
#

use Getopt::Long;
use Data::Dumper;

my $help = '';
my $lun = '';
my $getframe = '';
my $getlunid = '';
my $getsize = '';
my $getnumpaths = '';
my $getall = '';

GetOptions(
    'help' 	=> \$help,
    'lun=s'	=> \$lun,
    'getframe'  => \$getframe,
    'getlunid'  => \$getlunid,
    'getsize'   => \$getsize,
    'getnumpaths' => \$getnumpaths,
    'getall'    => \$getall
);

if ($help) {
    &printUsage && exit(0);
}

if (! $lun ) {
    &printUsage && exit(1);
}

# Make sure that the lun provided actually is a valid type

my ($foo, $dev, $type, $alun, $guid, $ctl, $ltype);

if ($lun =~ m/^\/dev/) {
    ($foo, $dev, $type, $alun)  = split('/', $lun);
    chomp($dev, $type, $alun);
    ($ctl, $guid) = split('t',$alun);
     $guid =~ s/d\d+//;
     $guid =~ s/s\d+//;
     &validateGuidLength($guid);
     $ltype = &getLunType($lun);
}
elsif ($lun =~ m/^c\d+/) {
    ($ctl, $guid) = split('t', $lun);
     $guid =~ s/d\d+//;
     &validateGuidLength($guid);
     $ltype = &getLunType($lun);
}
elsif ( $lun =~ m/\d+/) {
	$guid = $lun;
        &validateGuidLength($guid);
        $ltype = &getLunType($lun);
}
else {
     print "$lun is unknown type...\n" && ( &printUsage && exit(1));
}

if ($ltype !~ m/SYMMETRIX/i) {
    print "$ltype Lun $lun Lun ID cannot be evaluated using this script...please contact the Storage team for the correct Hexadecimal Lun ID \n";
    exit(1);
}

if ($getall) {
    &getAll($lun);
}

if ($getframe) {
    &getFrameId($lun);
}

if ($getsize) {
   &getSize($lun);
}

if ($getnumpaths) {
    &getNumPaths($lun);
}

if ($getlunid) {
    &getLunId($lun);
}

# Subroutines

sub validateGuidLength {

    my $guid = shift;
    chomp $guid;
    my $guidlen = length($guid);
    chomp $guidlen;
    if ( $guidlen lt "32" ) {
        die "Exiting...$guid GUID is not of an MPXIO lun, GUID has to be 32 chars\n";
    }
}

sub getLunId {
    my $lunid = &calcAll($guid,"lunid");
    chomp $lunid;
    print "$lunid\n";

}

sub calcAll {
    my ($guid, $what) = @_;
    chomp $guid;
    my $frameid = substr($guid,16,-12);
    my $factor = substr($guid,22,-8);
    my $lunid1 = substr($guid,24,-6);
    my $lunid2 = substr($guid,26,-4);
    my $lunid3 = substr($guid,28,-2);
    my $lunid4 = substr($guid,30);
    chomp($lunid1, $lunid2, $lunid3, $lunid4);
    my $xlunid1 = $lunid1 - $factor;
    my $xlunid2 = $lunid2 - $factor;
    my $xlunid3 = $lunid3 - $factor;
    my $xlunid4 = $lunid4 - $factor;
    #print "$xlunid1, $xlunid2\n";
    my $hex1 = &hexitize($xlunid1);
    my $hex2 = &hexitize($xlunid2);
    my $hex3 = &hexitize($xlunid3);
    my $hex4 = &hexitize($xlunid4);
    chomp($hex1, $hex2, $hex3, $hex4, $frameid, $factor);
    if($what eq "lunid") {
 	my $lunid = $hex1.$hex2.$hex3.$hex4;
	return($lunid);
     }
     if ($what eq "frameid") {
	return($frameid);
     }
}

sub hexitize {
    my $num = shift;
    if ($num > 10) {
        $num = $num - 1;
    }
    my $cmd = "/usr/bin/echo \"obase=16;$num\" | /usr/bin/bc";
    my $hex = qx/$cmd/;
    return $hex;
}

sub getFrameId { 
  my $frameid = &calcAll($guid,"frameid");
  chomp($frameid);
   print "$frameid\n";
}

sub getNumPaths {

  my $lun = shift;
  chomp $lun;
  my $flun = "/dev/rdsk/".$lun."s2";
  chomp $flun;
  my @getlunpathscmd = "/usr/sbin/mpathadm list lu $flun|/usr/bin/grep \"Path Count\"";
  my @result = qx/@getlunpathscmd/;
  chomp @result;
  for $line (@result) {
	my ($label, $value) = split(/:/, $line);
	$label =~ s/\s+//;
	$value =~ s/\s+//;
	print "$lun has $value $label\n";
  }
}

sub getSize {

  my $lun = shift;
  chomp $lun;
  my $flun = "/dev/rdsk/".$lun."s2";
  chomp $flun;
  my @getlunsizecmd = "/usr/sbin/luxadm display $flun|/usr/bin/grep \"capacity\"";
  my $result = qx/@getlunsizecmd/;
  chomp $result;
  my ( $label, $size ) = split(/:/, $result);
  $size =~ s/^\s+//;
  print "$lun size is $size\n";

}

sub getLunType {

    my $lun = shift;
    chomp $lun;
    my $flun = "/dev/rdsk/".$lun."s2";
    my @getluntypecmd = "/usr/sbin/luxadm display $flun|/usr/bin/grep \"Product ID\"";
    my $result = qx/@getluntypecmd/;
    chomp $result;
    my ($label, $type) = split(/:/, $result);
    $type =~ s/\s+//;
    $type =~ s/\s+$//;
    return $type;
}

sub getAll {

   my $lun = shift;
   chomp $lun;
   my $type = &getLunType($lun);
   chomp $type;
   &getFrameId($lun);
   &getLunId($lun);
   print "Lun Type is $type \n";
   &getSize($lun);
   &getNumPaths($lun);

}

sub printUsage {

print "Usage: $0 [--help|--lun=<lun> --getlunid|--getframe|--getsize|--getnumpaths|--getall]\n";

}
