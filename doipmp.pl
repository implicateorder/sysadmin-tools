#!/opt/soe/local/bin/perl
#!/opt/perl/bin/perl

#-----------------------------------------------------------------------------
# Author: Dwai  Lahiri
# Created: 2/21/05
# Description: Configure IPMP non-interactively, taking inputs from cmdline
# SCCS Version: 1.3
# Fixed linebreak problem with hostname.<interface> files (added linebreak EOF)
# Added /etc/netmasks entry creation
# Fixed netid code (use pack/unpack/substr)
#-----------------------------------------------------------------------------

use Getopt::Std;
use File::Copy;
my $os_ver = qx/uname -r/;
my ($majver, $minver) = split('.', $os_ver);
chomp($majver, $minver);

my %Args;
my $log         = "/var/tmp/ipmp-config.log";
my $null        = "/dev/null";
my $eeprom      = "/usr/sbin/eeprom";
my $lma_get     = qw/local-mac-address?/;
my $lma_set     = qw/local-mac-address?=true/;
my $ipnodes_tmp = "/tmp/ipnodes.ipmp";
my $hosts_tmp   = "/tmp/hosts.ipmp";

#------------
# Main
#------------

getopts( "p:i:m:s:I:M:n:v:g:h", \%Args );

if ( $Args{h} ) {
    printUsage() && exit 0;
}

my $prim_if  = $Args{p} || printUsage() && die;
my $prim_ip  = $Args{i} || printUsage() && die;
my $prim_msk = $Args{m} || printUsage() && die;
my $sec_if   = $Args{s} || printUsage() && die;
my $sec_ip   = $Args{I} || printUsage() && die;
my $sec_msk  = $Args{M} || printUsage() && die;
my $name     = $Args{n} || printUsage() && die;
my $vip      = $Args{v} || printUsage() && die;
my $nic_grp  = $Args{g} || $name;
my $namea = $name . a;
my $nameb = $name . b;

print "Saving copies of important files.... \n";
print
"Saving copies of /etc/hosts, /etc/inet/ipnodes, /etc/netmasks, /etc/hostname.$prim_if, /etc/hostname.$sec_if...";
copy( "/etc/hosts",             "/etc/hosts.$$" );
copy( "/etc/inet/ipnodes",      "/etc/inet/ipnodes.$$" );
copy( "/etc/netmasks",          "/etc/netmasks.$$" );
copy( "/etc/hostname.$prim_if", "/etc/hostname.$prim_if.$$" );
copy( "/etc/hostname.$sec_if",  "/etc/hostname.$sec_if.$$" );

# Check whether entry already exists in /etc/hosts  - if wrong entry exists,
# fix them, otherwise add entries

print "Opening /etc/hosts to check for old entries... \n";
open( HOSTR, "< /etc/hosts" ) or die "Unable to read /etc/hosts: $! \n";
print "And writing changes to the temp file... \n";
open( HOSTW, ">> /tmp/hosts.ipmp" )
  or die "Unable to write to /tmp/hosts.impm: $! \n";
@hosts = <HOSTR>;
close(HOSTR);
system("> $hosts_tmp");

@matches =
  grep( /\b($vip)\b|\b($name)\b|\b($prim_ip)\b|\b($sec_ip)\b/, @hosts );
print @matches;
if ( @matches = 0 ) {
    foreach $line (@hosts) {
        $line =~ s/^\s?//gix;
        print HOSTW "$line";
    }
    print HOSTW "$vip\t$name\tloghost\n";
    print HOSTW "$prim_ip\t$namea\n";
    print HOSTW "$sec_ip\t$nameb\n";
    copy( "$hosts_tmp", "/etc/hosts" );
}
else {
    for (@hosts) {
        $_ =~ s/^\s?//gix;
        if ( $_ =~ "\b^$vip\b|\b$name\b" ) {
            ( $val1, $val2 ) = split( ' ', $_ );
            if ( $val1 eq $vip and $val2 eq $name ) {

                # Do Nothing because entry already exists
                print HOSTW "$_";
            }
            elsif ( $val1 eq $vip and $val2 ne $name ) {
                $val2 = $name;
            }
            elsif ( $val1 ne $vip and $val2 eq $name ) {
                $val1 = $vip;
            }
            print HOSTW "$val1\t$val2\n";
        }
        elsif ( $_ =~ "^\b$prim_ip\b" ) {
            ( $val1, $val2 ) = split( ' ', $_ );
            if ( $val1 eq $prim_ip ) {
                $val2 = $name . a;
                print HOSTW "$val1\t$val2\n";
            }
        }
        elsif ( $_ =~ "\b^$sec_ip\b" ) {
            ( $val1, $val2 ) = split( ' ', $_ );
            if ( $val1 eq $sec_ip ) {
                $val2 = $name . b;
                print HOSTW "$val1\t$val2\n";
            }
        }
        else {
            print HOSTW "$_";
        }
    }
    copy( "$hosts_tmp", "/etc/hosts" );
}
close(HOSTW);
open( READTMP, "< $hosts_tmp" ) or die;
@ipmp_hosts = <READTMP>;
close(READTMP);
open( IPNDW, ">> $ipnodes_tmp" ) or die;
system("> $ipnodes_tmp");
if ($minver = 10) {
    print "This is Solaris $minver...no need to fix ipnodes... \n";
}
else {
@ipnodes =
  grep( /\b($vip)\b|\b($name)\b|\b($prim_ip)\b|\b($sec_ip)\b|\b(localhost)\b/,
    @ipmp_hosts );

if ( @ipnodes != 0 ) {
    foreach $line (@ipnodes) {
        $line =~ s/^\s?//gix;
        print IPNDW "$line";
    }
    copy( "$ipnodes_tmp", "/etc/inet/ipnodes" );
}
close(IPNDW);
}

&nmCreate;
&createHfiles;
&checkEprom;

#-------------
# Sub-routines
#-------------

sub createHfiles {

    # Create /etc/hostname.<interface> files

    system("> /etc/hostname.$prim_if");
    system("> /etc/hostname.$sec_if");
    open( PRIM_IF, ">> /etc/hostname.$prim_if" )
      or die "Unable to open /etc/hostname.$prim_if: $! \n";
    print PRIM_IF "$namea netmask + broadcast + \\
group $nic_grp deprecated -failover up \\
addif $name netmask + broadcast + failover up\n";
    close(PRIM_IF);
    open( SEC_IF, ">> /etc/hostname.$sec_if" )
      or die "Unable to open /etc/hostname.$sec_if: $! \n";
    print SEC_IF "$nameb netmask + broadcast + \\
group $nic_grp deprecated -failover standby up\n";
    close(SEC_IF);
}

sub printUsage {

    # Print Usage

    print
      "Usage: $0 [ -p <primary interface> -i <primary IP> -m <primary mask> \\
-s <secondary interface> -I <secondary IP> -M <secondary Mask> \\
-n <virtual hostname> -v <virtual IP> -g <NIC Group Name> ]|[ -h ]\n";
    print "Eg: $0 -p ce0 -i 10.165.214.2 -m 255.255.255.0 \\
-s ce2 -I 10.165.214.3 -M 255.255.255.0 -n foobar -v 10.165.214.4 -g foobar_nic_group \n";
}

sub checkEprom {

    # Check for "local-mac-address?=true in eeprom and fix it if set to false

    $lma_string = qx/$eeprom $lma_get/;
    ( $lma_junk, $lma_status ) = split( '\?', $lma_string );
    chomp $lma_status;
    if ( $lma_status eq "true" ) {
        print
          "local-mac-address? value is already set to true in the EEPROM...\n";
    }
    else {
        print "Setting local-mac-address? value to \"true\" in the EEPROM...\n";
        print "You have to reboot the server for this to take effect...\n";
        @lmaset = qx/$eeprom $lma_set > $null 2>&1/;
        if ( @lmaset = 0 ) {
            print
              "eeprom value changed from false to true (local-mac-address)\n";
            print "Please reboot the server for changes to take effect...\n";
        }
        else {
            print "ERROR: Unable to change local-mac-address? state to true...";
        }
    }
}

sub nmCreate {

    #Calculate the netid and populate /etc/netmasks if entry absent

    ( $ip1, $ip2, $ip3, $ip4 ) = split( '\.', $vip );
    ( $nm1, $nm2, $nm3, $nm4 ) = split( '\.', $prim_msk );

    $bin_ip1 = unpack( "B*", pack( "n", $ip1 ) );
    $bin_ip2 = unpack( "B*", pack( "n", $ip2 ) );
    $bin_ip3 = unpack( "B*", pack( "n", $ip3 ) );
    $bin_ip4 = unpack( "B*", pack( "n", $ip4 ) );

    $bin_nm1 = unpack( "B*", pack( "n", $nm1 ) );
    $bin_nm2 = unpack( "B*", pack( "n", $nm2 ) );
    $bin_nm3 = unpack( "B*", pack( "n", $nm3 ) );
    $bin_nm4 = unpack( "B*", pack( "n", $nm4 ) );

    $bin_netid1 = $bin_ip1 & $bin_nm1;
    $bin_netid2 = $bin_ip2 & $bin_nm2;
    $bin_netid3 = $bin_ip3 & $bin_nm3;
    $bin_netid4 = $bin_ip4 & $bin_nm4;

    $nint1 =
      unpack( "N", pack( "B32", substr( "0" x 32 . $bin_netid1, -32 ) ) );
    $netid1 = sprintf( "%d", $nint1 );
    $nint2 =
      unpack( "N", pack( "B32", substr( "0" x 32 . $bin_netid2, -32 ) ) );
    $netid2 = sprintf( "%d", $nint2 );
    $nint3 =
      unpack( "N", pack( "B32", substr( "0" x 32 . $bin_netid3, -32 ) ) );
    $netid3 = sprintf( "%d", $nint3 );
    $nint4 =
      unpack( "N", pack( "B32", substr( "0" x 32 . $bin_netid4, -32 ) ) );
    $netid4 = sprintf( "%d", $nint4 );

    chomp( $netid1, $netid2, $netid3, $netid4 );

    $netid = $netid1 . "." . $netid2 . "." . $netid3 . "." . $netid4;
    chomp $netid;
    open( NMR, "< /etc/netmasks" ) or die "Unable to read /etc/netmasks: $! \n";
    my @netmasks = <NMR>;
    close(NMR);

    @chknm = grep( /\b^($netid)\b/, @netmasks );
    open( NMW, ">> /tmp/netmasks.ipmp" )
      or die "Unable to write to /tmp/netmasks.ipmp: $! \n";
    system("> /tmp/netmasks.ipmp");

    if ( @chknm = 0 ) {
        print NMW "@netmasks \n";
        print NMW "$netid\t$prim_msk\n";
        copy( "/tmp/netmasks.ipmp", "/etc/netmasks" );
    }
    close(NMW);
}
