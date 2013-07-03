#!/usr/bin/perl -w

# ---------------------------------------------------------------------------------------------------- #
# $Id: vxmigrate.pl,v 1.10 2012/08/15 19:56:50 i08129r Exp i08129r $
# $Log: vxmigrate.pl,v $
# Revision 1.10  2012/08/15 19:56:50  i08129r
# added more commentary around the code
#
# Revision 1.9  2012/08/15 19:44:57  i08129r
# Modularized the gencfg code
# modified printUsage grammar
#
# Revision 1.8  2012/08/13 15:47:47  i08129r
# Updated with additional modules to prep new disks
# Updated with additional module to rename old plexes
# Added checks to validate that new disks are specified in cfg file
#
# Revision 1.7  2012/08/10 21:30:07  i08129r
# Added --prepare functionality
# Added --rename functionality
#
# Revision 1.6  2012/08/07 14:45:04  i08129r
# modified hostname cmd to be /bin/hostname instead of /usr/bin/hostname.
#
# Revision 1.5  2012/08/07 14:13:43  i08129r
# Updated help message and added comments in the script.
#
# Revision 1.4  2012/08/06 21:42:14  i08129r
# Changed the logic to generate Cfg file
#
# Revision 1.3  2012/08/06 16:55:26  i08129r
# Added Data::Dumper code (commented out) to debug Data Structures in the script
#
# Revision 1.2  2012/08/06 15:13:42  i08129r
# Updated with RCS variables
#
# ---------------------------------------------------------------------------------------------------- #

use Getopt::Long;
use File::Copy;
use Data::Dumper;

my $host = qx/\/bin\/hostname/;
chomp $host;

my $infile;
my $help;
my $mirror;
my $gencfg;
my $cfgfile;
my $dissociate;
my $decom;
my $prepare;
my $rename;

my $sudo = "/bin/env sudo";

my $vxassist      = "/usr/sbin/vxassist";
my $vxdg          = "/usr/sbin/vxdg";
my $vxplex        = "/usr/sbin/vxplex";
my $vxedit        = "/usr/sbin/vxedit";
my $vxdisk        = "/usr/sbin/vxdisk";
my $vxdisksetup   = "/opt/VRTS/bin/vxdisksetup";
my $vxdiskunsetup = "/opt/VRTS/bin/vxdiskunsetup";
my $vxprint       = "/usr/sbin/vxprint";

GetOptions(
    "infile=s"   => \$infile,
    "help"       => \$help,
    "prepare"    => \$prepare,
    "mirror"     => \$mirror,
    "gencfg"     => \$gencfg,
    "cfgfile=s"  => \$cfgfile,
    "dissociate" => \$dissociate,
    "decomm"     => \$decomm,
    "rename"     => \$rename
);

if ( !$infile ) {
    $infile = "/var/tmp/$host-ldvlist.txt";
}
if ($help) {
    &printUsage && exit(0);
}

if ( !$cfgfile ) {
    $cfgfile = "/var/tmp/vxmigrate.cfg";
}

if ( ( $mirror or $dissociate or $decomm or $prepare or $rename ) && $gencfg ) {
    die
      "Can't run configuration mode and execution mode in the same instance \n";
}
elsif ($gencfg) {

    &doGenCfg;
}
elsif ($prepare) {

    &doPrepare;
}
elsif ($mirror) {

    &doMirror;
}
elsif ($dissociate) {
    &doDissociate;
}
elsif ($decomm) {
    &doDecomm;
}
elsif ($rename) {
    &doRename;
}
else {
    &printUsage && exit(1);
}

sub doGenCfg {

 # Create the config file that will be used to do mirror/unmirror activities etc
 #

    my %cHoH = &readCfg;

    # Comment out Data::Dumper output -- useful for debugging
    #print Dumper( \%cHoH );
    my %p2v = &genDg2Vol2Plex;

    #print Dumper( \%p2v );

    open( WCFG, "> $cfgfile" ) or die "Unable to create $cfgfile: $! \n";
    print WCFG "VOLNAME:OLD PLEX : DGNAME | OLD DISK LIST:NEW DISK LIST\n";

# do nasty hacks to get the association between dgname, volname, plexname and dmname going
# Essentially do what is known in the SQL world as an union between the two data structures (%p2v and %cHoH)
# to map together by primary key (volname) the associated, dg names, source plex names and source Disk media
# names 

    for my $vol ( sort keys %cHoH ) {
        my @plxs = @{ $p2v{$vol} };
        my @dms  = @{ $cHoH{$vol} };
        for (@dms) {
            push( @plxs, $_ );
        }
        my @ucfg = &uniq2(@plxs);
        print WCFG "$vol:@ucfg:\n";
    }
    close(WCFG);
    open( RCFG, "< $cfgfile" ) or die "Can't ipen $cfgfile: $! \n";
    my @RCFG = <RCFG>;
    close(RCFG);
    open( WCFG, "> $cfgfile" ) or die "Unable to write to $cfgfile: $! \n";
    for (@RCFG) {
        s/\s+\|/:/;
        s/\s+:/:/;
        print WCFG "$_";
    }
    close(WCFG);
}

sub genDg2Vol2Plex {
    open( RIF, "< $infile" ) or die "Unable to open $infile: $! \n";
    my @RIF = <RIF>;
    close(RIF);
    my %plex2vol;
    my %dg2vol2plex;
    my %vol2dm;
    my %volhash;
    foreach my $line (@RIF) {
        (
            $hostname, $lunid,  $dgname, $volname,   $volsize,
            $srcplex,  $srcdev, $srcdm,  $srcdmtype, $srcdmsize
        ) = split( /,/, $line );

        chomp(
            $hostname, $lunid,  $dgname, $volname,   $volsize,
            $srcplex,  $srcdev, $srcdm,  $srcdmtype, $srcdmsize
        );

        # Get unique volnames as keys of the hash %vol2dm
        $vol2dm{$volname} = $srcdev;

        # Get unique dgnames as keys of the hash %vdgdm
        $dg2vol{$dgname}    = $volname;
        $plex2vol{$srcplex} = $volname;
    }

   # Create a hash of arrays with $volname as the key (maps vol -> plex, dgname)
    foreach my $line (@RIF) {
        (
            $hostname, $lunid,  $dgname, $volname,   $volsize,
            $srcplex,  $srcdev, $srcdm,  $srcdmtype, $srcdmsize
        ) = split( /,/, $line );

        chomp(
            $hostname, $lunid,  $dgname, $volname,   $volsize,
            $srcplex,  $srcdev, $srcdm,  $srcdmtype, $srcdmsize
        );
        foreach my $dg ( sort keys %dg2vol ) {
            if ( $dgname eq $dg ) {
                for my $v ( sort keys %vol2dm ) {
                    if ( $v eq $volname ) {
                        push( @{ $volhash{$v} }, $srcplex, ":", $dg, "|" );
                    }
                }
            }
        }
    }
    my %jvolhash;
    for my $xvol ( keys %volhash ) {
        my @foobar       = @{ $volhash{$xvol} };
        my @uniqelements = uniq2(@foobar);
        $jvolhash{$xvol} = [@uniqelements];
    }

# return the hash (key volname) of hash of arrays (key volname, values are source plex names and dg names)

    return %jvolhash;

}

sub readCfg {

# Jump through hoops to generate a unique list of src disks corresponding to multiple instances of
# a volume in output file

    open( RIF, "< $infile" ) or die "Unable to open $infile: $! \n";
    my @RIF = <RIF>;
    close(RIF);

    my %vol2dm;
    my %vols;
    my %vdgdm;
    my %plex2vol;

    my (
        $hostname, $lunid,  $dgname, $volname,   $volsize,
        $srcplex,  $srcdev, $srcdm,  $srcdmtype, $srcdmsize
    );

    foreach my $line (@RIF) {
        (
            $hostname, $lunid,  $dgname, $volname,   $volsize,
            $srcplex,  $srcdev, $srcdm,  $srcdmtype, $srcdmsize
        ) = split( /,/, $line );

        chomp(
            $hostname, $lunid,  $dgname, $volname,   $volsize,
            $srcplex,  $srcdev, $srcdm,  $srcdmtype, $srcdmsize
        );

        # Get unique volnames as keys of the hash %vol2dm
        $vol2dm{$volname} = $srcdev;

        # Get unique dgnames as keys of the hash %vdgdm
        $vdgdm{$dgname}     = $volname;
        $plex2vol{$srcplex} = $volname;
    }

# Create a hash of arrays with $volname as the key (maps vol -> src disk names, dgname)
    my %HoH;
    foreach my $line (@RIF) {
        (
            $hostname, $lunid,  $dgname, $volname,   $volsize,
            $srcplex,  $srcdev, $srcdm,  $srcdmtype, $srcdmsize
        ) = split( /,/, $line );
        chomp(
            $hostname, $lunid,  $dgname, $volname,   $volsize,
            $srcplex,  $srcdev, $srcdm,  $srcdmtype, $srcdmsize
        );
        foreach my $dg ( sort keys %vdgdm ) {
            chomp $dg;
            if ( $dg eq $dgname ) {
                foreach my $vol ( sort keys %vol2dm ) {
                    chomp $vol;
                    if ( $vol eq $volname ) {
                        push( @{ $vols{$vol} }, $srcdm, ":", $dgname, "|" );

                    }
                }

            }
        }
    }
    my %rhash;
    for $xvol ( keys %vols ) {
        my @foobar = sort @{ $vols{$xvol} };
        @uniqelements = uniq2(@foobar);
        $rhash{$xvol} = [@uniqelements];
    }

# Return hash (key volname) of hash of arrays (key volname, values being source disk media names and dg names)
    return %rhash;
}

# Complex data structures in Perl are a total P.I.T.A :(

sub uniq2 {

    # generate a unique list of elements in a given list
    my %seen = ();
    my @r    = ();
    foreach my $a (@_) {
        unless ( $seen{$a} ) {
            push @r, $a;
            $seen{$a} = 1;
        }
    }
    return @r;
}

sub doMirror {

    open( RCFG, "< $cfgfile" ) or die "Can't read $cfgfile: $! \n";
    @RCFG = <RCFG>;
    close(RCFG);
    for $line (@RCFG) {
        next if ( $line =~ m/DGNAME/ );
        next if ( $line =~ m/^\s*$/ );
        my ( $volname, $plexname, $dgname, $oldd, $newd ) = split( /:/, $line );
        chomp( $dgname, $volname, $plexname, $oldd, $newd );
        @newdms = split( / /, $newd );
        my $ndmc = scalar @newdms;
        if ( $ndmc lt 1 ) {
            print
"No new disks have been specified for $dgname -> $volname...skipping!\n\n";
            next;
        }
        my $tasktag = "m-$volname";
        my @mirrcmd = "$sudo $vxassist -g $dgname mirror $volname @newdms";
        print "@mirrcmd \n";
    }
}

sub doDissociate {

    open( RCFG, "< $cfgfile" ) or die "Can't read $cfgfile: $! \n";
    @RCFG = <RCFG>;
    close(RCFG);
    for $line (@RCFG) {
        next if ( $line =~ m/DGNAME/ );
        next if ( $line =~ m/^\s*$/ );
        my ( $volname, $plexname, $dgname, $oldd, $newd ) = split( /:/, $line );
        chomp( $dgname, $volname, $plexname, $oldd, $newd );
        my @olddms = split( / /, $oldd );
        my @detcmd = "$sudo $vxplex -g $dgname -v $volname det $plexname";
        my @discmd = "$sudo $vxplex -g $dgname -v $volname dis $plexname";
        print "@detcmd \n @discmd \n";
    }
}

sub doDecomm {

    open( RCFG, "< $cfgfile" ) or die "Can't read $cfgfile: $! \n";
    @RCFG = <RCFG>;
    close(RCFG);
    for my $line (@RCFG) {
        next if ( $line =~ m/DGNAME/ );
        next if ( $line =~ m/^\s*$/ );
        my ( $volname, $plexname, $dgname, $oldd, $newd ) = split( /:/, $line );
        chomp( $dgname, $volname, $plexname, $oldd, $newd );
        my @olddms = split( / /, $oldd );
        my @rmcmd = "$sudo $vxedit -g $dgname -r rm $plexname";
        print "@rmcmd \n";
    }
    print
"Warning! There might be repetitions of some disk names...just verify before executing the cmds...\n";
    for my $line (@RCFG) {
        next if ( $line =~ m/DGNAME/ );
        next if ( $line =~ m/^\s*$/ );
        my ( $volname, $plexname, $dgname, $oldd, $newd ) = split( /:/, $line );
        chomp( $dgname, $volname, $plexname, $oldd, $newd );
        my @olddms = split( / /, $oldd );
        for $olddm (@olddms) {
            next if ( !$olddm );
            chomp $olddm;
            my @drmcmd = "$sudo $vxdg -g $dgname rmdisk $olddm";
            print "@drmcmd \n";
        }
    }
}

sub doPrepare {

    open( RCFG, "< $cfgfile" ) or die "Can't read $cfgfile: $! \n";
    @RCFG = <RCFG>;
    close(RCFG);
    my $vxdisklistfile = "/var/tmp/vxdisk-list.txt";
    my @vxdisklist     = "$sudo $vxdisk -o alldgs list > $vxdisklistfile";
    qx/@vxdisklist/;
    open( RVDL, "< $vxdisklistfile" )
      or die "Can't read $vxdisklistfile: $! \n";
    my @RVDL = <RVDL>;
    close(RVDL);

    for my $line (@RCFG) {
        next if ( $line =~ m/DGNAME/ );
        next if ( $line =~ m/^\s*$/ );
        my ( $volname, $plexname, $dgname, $oldd, $newd ) = split( /:/, $line );
        chomp( $volname, $plexname, $dgname, $oldd, $newd );
        my @newdms = split( / /, $newd );
        my $ndmc = scalar @newdms;
        if ( $ndmc lt 1 ) {
            print
"There are no valid new disks in the config file for $dgname -> $volname...skipping!\n\n";
            next;
        }
        for my $vdl (@RVDL) {
            for my $newdisk (@newdms) {
                chomp $newdisk;
                chomp $vdl;
                if ( $vdl =~ m/$newdisk/ ) {
                    my ( $device, $type, $disk, $group, $status ) =
                      split( /\s+/, $vdl );
                    chomp( $device, $type, $disk, $group, $status );
                    if ( $type =~ m/auto:ZFS|auto:ASM|auto:slice/i ) {
                        print
"Please double check whether $newdisk is a valid disk! It is presented as $type in vxdisk list\n";
                    }
                    else {

                        if ( $group =~ m/^\s*\-\s*$/ ) {
                            my @chkcmd = "$sudo $vxprint -g $dgname $newdisk";
                            ( qx/@chkcmd/
                                  and print "$newdisk already in $dgname \n" )
                              or &prepCmdGen( $dgname, $newdisk );
                        }
                        elsif ( $group =~ m/\(\w+\s*\W*\)\s*/i ) {
                            print "$newdisk is part of a deported DG $group \n";
                        }
                        else {
                            print "Unknown error: $! \n";
                        }
                    }
                }
            }
        }
    }
}

sub prepCmdGen {

    my ( $dgname, $newdisk ) = @_;
    chomp( $dgname, $newdisk );
    my @prepcmd1 = "$sudo $vxdisksetup -i $newdisk format=cdsdisk";
    my @prepcmd2 = "$sudo $vxdg -g $dgname adddisk $newdisk=$newdisk";
    print "@prepcmd1 \n";
    print "@prepcmd2 \n";

}

sub doRename {

    open( RCFG, "< $cfgfile" ) or die "Can't read $cfgfile: $! \n";
    @RCFG = <RCFG>;
    close(RCFG);
    for my $line (@RCFG) {
        next if ( $line =~ m/DGNAME/ );
        next if ( $line =~ m/^\s*$/ );
        my ( $volname, $plexname, $dgname, $oldd, $newd ) = split( /:/, $line );
        chomp( $volname, $plexname, $dgname, $oldd, $newd );
        my $newplex =
qx/$sudo $vxprint -g $dgname $volname\|grep \"^pl\"\|awk \'\{print \$2\}\'/;
        chomp $newplex;
        my @rencmd = "$sudo $vxedit -g $dgname rename $newplex $plexname";
        print "@rencmd \n";
    }
}

sub printUsage {

    print
"Usage: $0 --help|--infile=<filename> --gencfg | --cfgfile=<filename> [ --prepare|--mirror|--dissociate|--decomm ] \n
	--help 	- 	print this message 
	--infile - 	pass input config file 
	--gencfg - 	generate the actual configuration file from --infile
	--cfgfile -	read entries from cfgfile to execute commands
	--prepare - 	generates code to prepare new luns for migration
	--mirror -	generates code to mirror volume to new disks
	--dissocate -	generates code to remove oldplex from mirror
	--decomm -	generates code to decommission old luns from dg
	--rename - 	generates code to rename new plex to old plex name \n";
    print
"\nThis script will take as input, the output of the fdgvolsz.sh shell script and create a configuration file when run in the --gencfg mode.\n 
The output of the --gencfg cmd can be used to generate code appropriate for each of the other actions, ie., --prepare, --mirror, --dissociate, --decomm or --rename. \n
You might want to save the output of each of those switches to review and run.\n";

}
