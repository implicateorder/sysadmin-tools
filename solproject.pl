#!/usr/bin/perl

use Data::Dumper;

my @getmemcmd = qw(/usr/sbin/prtconf|grep -i "Memory size"|awk -F\\: '{print $2}');

my $memstring = qx/@getmemcmd/ or die "unable to get physical memory size: $! \n";
$memstring =~ s/^\s+//;

my ($mem, $unit) = split(/ /, $memstring);
chomp ($mem, $unit);
print $mem;

my $mfactor = 1024;
if ( $unit =~ m/Mega/i) {
    $mfactor *= 1024;
}
elsif ( $unit =~ m/Gig/i ) {
    $mfactor *= (1024 * 1024);
}
else {
    # do nothing
}

my $totalmem = $mem * $mfactor;
print "$totalmem \n";
my $resmem = 10 * 1024 * 1024 * 1024;
my $shmmax = $totalmem - $resmem;
my $shmrep = $shmmax / 1024 / 1024 / 1024;

my $semids = 4100;
my $shmids = 512;
my $nsems = 5120;
my $fdcur = 8192;

my %projhash = (
    'project.max-shm-memory' => $shmmax,
    'project.max-sem-ids' => $semids,
    'process.max-sem-nsems' => $nsems,
    'project.max-shm-ids' => $shmids,
    'process.max-file-descriptor' => $fdcur
);

# Check if process exists...



my $project = "/usr/bin/project";
my $projadd = "/usr/sbin/projadd";
my $projmod = "/usr/sbin/projmod";

my $checkproj = system($project -l user.oracle);
print "DBG: $checkproj \n";

if ($checkproj eq -1 ) {
    print "Run the following...\n";
    print "$projadd -p 200 -U oracle -c \"oracle kernel params\" user.oracle \n";

    foreach my $key (sort keys %projhash) {
         my $val = $projhash{$key};
         if ($key =~ m/file-descriptor/) {
	
	    my $nstring = "$key=(basic,$val,deny)";
	    print "$projmod -a -K \"$nstring\" user.oracle \n";
        }
        else {
	    my $nstring = "$key=(priv,$val,deny)";
	    print "$projmod -a -K \"$nstring\" user.oracle \n";
        }
    }
}
else {
    print "project user.oracle already exists...\n";
}


