#!/usr/bin/perl -w
#
#$Id: getdmppaths.pl,v 1.2 2012/09/18 17:41:41 i08129r Exp i08129r $
#$Log: getdmppaths.pl,v $
#Revision 1.2  2012/09/18 17:41:41  i08129r
#Added logic to do pre-run checks for path validity down multiple controllers
#
#Revision 1.1  2012/09/18 17:31:52  i08129r
#Initial revision
#
#

use Data::Dumper;
use Getopt::Long;

my $help     = '';
my $count    = '';
my $interval = '';
my $precheck = '';

my $option;

$option = GetOptions(
    "help"       => \$help,
    "count=s"    => \$count,
    "interval=s" => \$interval,
    "precheck"   => \$precheck
);

# Main

my $dmpadm = "/usr/sbin/vxdmpadm";
my $sudo   = "/usr/bin/env sudo";
my @ctlr;

my @enclosurecmd = qx/$sudo $dmpadm -v getdmpnode/;
my @enclosures;
my %encfoo;

if ($help) {
    &printUsage && exit(0);
}
if ( $help && ( $count or $interval ) ) {
    &printUsage && exit(1);
}

if ( !$count ) {
    $count = 100;
}
if ( !$interval ) {
    $interval = 20;
}

if ($precheck) {

    # first check if all luns are visible down all controllers

    &checkCtlrsbyLun && exit 0;
}
else {

    for (@enclosurecmd) {
        chomp;
        next if ( $_ =~ m/ENCLR-NAME|\=/ );
        my (
            $device, $state,     $enclrtype, $paths, $enbl,
            $dsbl,   $enclrname, $serno,     $arrayvolid
        ) = split( '\s+', $_ );
        chomp(
            $device, $state,     $enclrtype, $paths, $enbl,
            $dsbl,   $enclrname, $serno,     $arrayvolid
        );
        next if ( $enclrtype =~ m/Disk/i );
        $encfoo{$enclrname} = "$paths, $enbl, $dsbl";
    }

    foreach my $enclrname ( sort keys %encfoo ) {
        chomp $enclrname;
        push( @enclosures, $enclrname );
    }

    while ($count) {
        for my $enclosure (@enclosures) {
            chomp $enclosure;
            next if ( $enclosure =~ m/^\s*$/ );
            print "Checking Enclosure $enclosure \n";
            my @getcmd = "$sudo $dmpadm -v getdmpnode enclosure=$enclosure";
            system(@getcmd);
            print "Checking for disabled subpaths on $enclosure \n";
            my %downstat = &checkDownPaths;
            foreach my $subpath ( sort keys %downstat ) {
                chomp $subpath;
                print "$subpath $downstat{$subpath} \n";
            }
        }
        sleep $interval;
        $count--;

    }
}

sub printUsage {

    print "$0 --help|--precheck|--count=<count> --interval=<interval> \n
	--help 	- print this message
	--count - specify number of run iterations you want to run this program for
	--interval - interval between each iteration 
	--precheck - run a pre-run check to validate luns are visible down all controllers or more than one controller\n";
}

sub checkCtlrsbyLun {
    my @getctlr = qx/$sudo $dmpadm getctlr/;

    for (@getctlr) {
        next if ( $_ =~ m/^LNAME|\=/ );
        next unless ( $_ =~ m/fiber|fp|ql/ );
        my ( $controller, $pname, $vendor, $ctlrid ) = split( '\s+', $_ );
        push( @ctlr, $controller );
    }

    print "@ctlr controllers detected with SAN Storage capabilities \n";

    my @getdmpnodes = qx/$sudo $dmpadm getdmpnode/;
    my @dmpnodes;

    for (@getdmpnodes) {
        next if ( $_ =~ m/^NAME|^\=/ );
        my ( $dmpnode, $state, $enclrtype, $paths, $enbl, $dsbl, $enclrname ) =
          split( '\s+', $_ );
        next if ( $enclrtype =~ m/Disk/i );
        push( @dmpnodes, $dmpnode );
    }

    for my $controller (@ctlr) {
        chomp $controller;
        my @getsubpaths = qx/$sudo $dmpadm getsubpaths ctlr=$controller/;
        foreach my $dmpnode (@dmpnodes) {
            my @match = grep( /$dmpnode/, @getsubpaths )
              or print "$dmpnode doesn't match on $controller\n";
            foreach my $line (@match) {
                chomp $line;
                my ( $path, $state, $pathtype, $dmpnodename, $enclrtype,
                    $enclrname, $attrs )
                  = split( '\s+', $line );
                chomp( $path, $state, $pathtype, $dmpnodename, $enclrtype,
                    $enclrname, $attrs );
                if ( $state =~ m/DISABLE/ ) {
                    print
"$dmpnode in state $state on controller $controller down path $path \n";
                }
                else {
                    print
"$dmpnode matches and active on controller $controller down path $path \n";
                }
            }
        }
    }
}

sub checkDownPaths {
    my @getctlr = qx/$sudo $dmpadm getctlr/;

    for (@getctlr) {
        next if ( $_ =~ m/^LNAME|\=/ );
        next unless ( $_ =~ m/fiber|fp|ql/ );
        my ( $controller, $pname, $vendor, $ctlrid ) = split( '\s+', $_ );
        push( @ctlr, $controller );
    }

    my @getdmpnodes = qx/$sudo $dmpadm getdmpnode/;
    my @dmpnodes;

    for (@getdmpnodes) {
        next if ( $_ =~ m/^NAME|^\=/ );
        my ( $dmpnode, $state, $enclrtype, $paths, $enbl, $dsbl, $enclrname ) =
          split( '\s+', $_ );
        next if ( $enclrtype =~ m/Disk/i );
        push( @dmpnodes, $dmpnode );
    }

    my %bar;
    foreach my $dmpnode (@dmpnodes) {
        chomp $dmpnode;
        my @getsubpaths = qx/$sudo $dmpadm getsubpaths dmpnodename=$dmpnode/
          or die "Unable to get dmp subpaths: $! \n";
        for my $line (@getsubpaths) {

            chomp $line;
            next if ( $line =~ m/^NAME|\=/i );
            my (
                $name,    $state,   $pathtype, $ctlrname,
                $enctype, $encname, $attrs
            ) = split( '\s+', $line );
            chomp(
                $name,    $state,   $pathtype, $ctlrname,
                $enctype, $encname, $attrs
            );
            foreach my $controller (@ctlr) {
                chomp $controller;
                if ( $controller = $ctlrname ) {
                    next if ( $state =~ m/ENABLE/ );
                    $bar{$name} = "$dmpnode $controller $state";
                }
                else {
                    next;
                }
            }
        }

    }
    return %bar;
}
