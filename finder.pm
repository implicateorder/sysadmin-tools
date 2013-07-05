package finder;

# ---------------------------------------------------------------------------------------------------------------------------- #
#$Id: finder.pm,v 1.3 2012/11/06 20:49:15 i08129r Exp i08129r $
#$Log: finder.pm,v $
#Revision 1.3  2012/11/06 20:49:15  i08129r
#Prettified the comments section
#
#Revision 1.2  2012/11/06 20:40:47  i08129r
#Added additional commentary around this perl module
#This can be called with any perl script. It contains following translation hashes (which are returned to calling perl script)
#vxio device mappings, vxdmp device mappings, /dev/dsk device mappings, /dev/rdsk device mappings and /dev/rmt device mappings
#so when a dtrace script maps a device through the io::: provider, it will translate a vxio<minornumber> value into a
#DGNAME->VOLNAME, or a vxdmp<minornumber> value into a corresponding vxdmp device name. Same with disks or tape devices.
#
#Revision 1.1  2012/11/06 20:39:22  i08129r
#Initial revision
# Need comments
# ---------------------------------------------------------------------------------------------------------------------------- #

use Data::Dumper;
require Exporter;
@EXPORT_OK = qw(fndvxio fndvxdmp fnddsk fnddrdsk fnddrmt);
@EXPORT    = @EXPORT_OK;
@ISA       = qw(Exporter);

sub fndvxio {
    my $findvxio = <<EOF;
ls -lR /dev/vx/rdsk
EOF

    open( FVXIO, "$findvxio|" ) or die "Can't run ls: $!\n";
    while ( my $line = <FVXIO> ) {

        #	if (($line =~ m/^\/dev.*\:/) ... ($line =~ m/^\/dev.*\:/)) {
        if ( ( $line =~ m/^\/dev.*\:/ ) ... ( $line =~ m/^$/ ) ) {
            if ( $line =~ m/^\/dev.*\:{1}/ ) {
                $dgline = $line;
                ( $junk, $ppdir, $pdir, $dir, $dg ) = split( "/", $dgline );
                next if ( !$dg );
                $dg =~ s/\://;
            }

            #next if ($line =~ m/^d.*/);
            for ( $line =~ m/^c.+/i ) {

                #print "$line\n";
                (
                    $type, $one,   $owner, $group, $maj,
                    $min,  $month, $date,  $ctime, $vol
                ) = split( '\s+', $line );
                $maj =~ s/\,//;
                chomp $dg;
                my @val = ( $dg, $maj, $vol );

                #print "@val \n";
                $fvxio{$min} = \@val;
            }
        }
    }
    close(FVXIO);
    return %fvxio;

    #print Dumper(\%fvxio);
}

sub fndvxdmp {
    my $findvxdmp = <<EOF;
ls -lR /dev/vx/dmp
EOF

    open( FVXDMP, "$findvxdmp|" ) or die "can't run ls: $!\n";
    while ( my $line = <FVXDMP> ) {
        if ( $line =~ m/^b.*/ ) {
            (
                $type, $one,   $owner, $group, $maj,
                $min,  $month, $date,  $ctime, $device
            ) = split( ' ', $line );
            $maj =~ s/\,//;

            #next if ($min = '');
            my @val = ( $maj, $device );
            $fvxdmp{$min} = \@val;
        }
    }
    close(FVXDMP);
    return %fvxdmp;

    #print Dumper(\%fvxdmp);

}

sub fnddsk {
    my $devdsk = <<EOF;
ls -l /dev/dsk|/usr/bin/awk \'\{print \$9, \$11\}\'
EOF

    open( DDSK, "$devdsk|" ) or die "$! \n";
    while ( my $line = <DDSK> ) {
        my ( $ctd, $device ) = split( ' ', $line );
        next if ( $line =~ /^\s*$/ );
        chomp( $ctd, $device );
        next if ( !$device ) or ( !$ctd );
        $device =~ s/^\.\.\/\.\.//;
        my $devstr = qx/ls -l $device/;
        chomp $devstr;
        my ( $type, $one, $owner, $group, $maj, $min, $month, $day, $time,
            $dev ) = split( ' ', $devstr );
        chomp(
            $type, $one,   $owner, $group, $maj,
            $min,  $month, $day,   $time,  $dev
        );
        next if ( !$maj );
        $maj =~ s/\,$//;
        my $majmin = "$maj" . "$min";
        my @devarray = ( $ctd, $maj, $min, $device );
        $ddsk{$majmin} = \@devarray;
    }
    close(DDSK);
    return %ddsk;

    #print Dumper(\%ddsk);
}

sub fnddrdsk {
    my $devrdsk = <<EOF;
ls -l /dev/rdsk|/usr/bin/awk \'\{print \$9, \$11\}\'
EOF

    open( DRDSK, "$devrdsk|" ) or die "$!\n";
    while ( my $line = <DRDSK> ) {
        my ( $ctd, $device ) = split( ' ', $line );
        next if ( $line =~ /^\s*$/ );
        chomp( $ctd, $device );
        next if ( !$device ) or ( !$ctd );
        $device =~ s/^\.\.\/\.\.//;
        my $devstr = qx/ls -l $device/;
        chomp $devstr;
        my ( $type, $one, $owner, $group, $maj, $min, $month, $day, $time,
            $dev ) = split( ' ', $devstr );
        chomp( $ctd, $device );
        next if ( !$device ) or ( !$ctd );

        $maj =~ s/\,$//;
        my $majmin = "$maj" . "$min";
        my @devarray = ( $ctd, $maj, $min, $device );
        $drdsk{$majmin} = \@devarray;
    }
    close(DRDSK);
    return %drdsk;

    #print Dumper(\%drdsk);
}

sub fnddrmt {
    my $devrmt = <<EOF;
ls -l /dev/rmt|/usr/bin/awk \'\{print \$9, \$11\}\'
EOF

    open( DRMT, "$devrmt |" ) or die "$! \n";
    while ( my $line = <DRMT> ) {
        my ( $rmt, $device ) = split( ' ', $line );
        next if ( $line =~ /^\s*$/ );
        chomp( $rmt, $device );
        next if ( !$device ) or ( !$rmt );
        $device =~ s/^\.\.\/\.\.//;
        my $devstr = qx/ls -l $device/;
        chomp $devstr;
        my ( $type, $one, $owner, $group, $maj, $min, $month, $day, $time,
            $dev ) = split( ' ', $devstr );
        chomp(
            $type, $one,   $owner, $group, $maj,
            $min,  $month, $day,   $time,  $dev
        );
        next if ( !$maj );
        $maj =~ s/\,$//;
        my $rmt      = "/dev/rmt" . "/" . "$rmt";
        my @devarray = ( $rmt, $maj, $min, $device );
        my $majmin   = "$maj" . "$min";
        $drmt{$majmin} = \@devarray;
    }
    close(DRMT);
    return %drmt;

    #print Dumper(\%drmt);
}
1;
__END__
