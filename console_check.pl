#!/usr/bin/perl -wd
#---------------------------------------------------------------------------------------------------#
# Dwai Lahiri	8/1/2012
#$Log: console_check.pl,v $
#Revision 1.3  2012/08/07 19:45:23  i08129r
#The encryption part of the script has been completed. It requires krypt.pl to be ran to generate 
#the encrypted string that will be passed to the console_check.pl script via cmdline
#Split logging to send console screen scrapes to file regex console_log_mm-dd-yyyy.log and script status 
#to console_check_mm-dd-yyyy.log files
#Added time stamps (mm-dd-yyyy HH:MM) to the script status log messages
#
#Revision 1.1  2012/08/07 14:15:20  i08129r
#Initial revision
#
#$Id: console_check.pl,v 1.3 2012/08/07 19:45:23 i08129r Exp i08129r $
#---------------------------------------------------------------------------------------------------#
use strict;
use Getopt::Long;
use Net::Telnet;
use Net::SSH;
use Expect;
use Crypt::Simple;

# Read input from cmdline switch --host=<blah>
# Identify type of console --type switch(ie whether it is cyclades or RSC or iLO or ILOM)
# Telnet to console if it is cyclades
# Read username from --user=<...> and password from the --passwd=<...> switches

my $help;
my $host;
my $user;
my $passwd;
my $type;
my $timeout;
my $option;

my $ssh = "/bin/ssh";

my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
  localtime(time);
$year += 1900;
$mon  += 1;
my $date   = "$mon-$mday-$year";
my $tstamp = "$mon-$mday-$year $hour:$min";
my $prompt = '[\]\$\>\#]\s*$';

# Get the long options for the script

$option = GetOptions(
    "help"      => \$help,
    "host=s"    => \$host,
    "user=s"    => \$user,
    "passwd=s"  => \$passwd,
    "type=s"    => \$type,
    "timeout=s" => \$timeout
);

# All the functions used in the script

sub printUsage {

    # Take input message (passed into the function from code in Main) and print
    # general usage information
    my @message = @_;
    print "@message \n
Usage: $0 --help|--host=<hostname> --user=<username> --passwd=<password> --type=<type> --timeout=<timeout in seconds>\n
	--help	-	print this message
	--host  -	pass target hostname (cyclades console access name or iLo, ILOM, RSC, SC name)
	--user	-	pass username to log into target host
	--passwd -	pass password to log into target host (corresponding to username)
	--type	-	pass the type of console access (cyclades or RSC or SC or iLo...etc)
	--timeout -	timeout (in seconds) or default of 30s \n";
}

sub deCryptIt {

# Decrypt encrypted password entered from command line (Use krypt.pl to generate it)
    my $xpasswd = shift;
    my $dpasswd = decrypt($xpasswd);
    return $dpasswd;
}

sub testCyclades {
    #
    # Usual prompt while connecting to the Cyclades is this
    # A non-empty Data Buffering File was found. Choose which action
    # should be performed ( (I)gnore or (D)isplay ) :
    #my $prompt = "isplay \) \:";
    my $logfile = "/var/tmp/console_check_$date.log";
    my $conslog = "/var/tmp/console_log_$date.log";
    open( WOF, ">> $logfile" ) or die "Unable to write to/open $logfile: $! \n";
    my ( $host, $user, $passwd, $timeout ) = @_;
    chomp( $host, $user, $passwd, $timeout );
    my $dexpasswd = &deCryptIt($passwd);
    chomp $dexpasswd;
    print WOF "\n$tstamp:\tTrying to connect to $host\n";
    my $telnet = new Net::Telnet($host)
      or print WOF "$tstamp:\tUnable to telnet to $host: $! \n" && die;
    my $exp = Expect->exp_init($telnet);
    my $spawn_ok;

    #my $prompt = '[\]\$\>\#]\s*$';
    #
    # Uncomment the line below to turn on debugging for this script
    #$exp->exp_internal(1);

    $exp->log_file($conslog);
    my $ahost = $host;
    $ahost =~ s/\-c$//;

    # print "$tstamp:\tSending a carriage return to $host\n";
    $exp->send("\n");
    sleep 2;
    $exp->expect(
        $timeout,
        [
            qr'isplay \) \: $',
            sub {
                $spawn_ok = 1;
                my $fh = shift;
                $fh->send("I\n");
                exp_continue;
              }
        ],
        [
            qr'how and erase \) \: $',
            sub {
                $spawn_ok = 1;
                my $fh = shift;
                $fh->send("I\n");
                exp_continue;
              }
        ],
        [
            qr'5 \- Quit\s*\n*Enter your option \:\s*$',
            sub {
                $spawn_ok = 1;
                my $fh = shift;
                $fh->send("5\n");
                print WOF
"\n$tstamp:\t$host console is in use...please investigate manually\n";
                $exp->soft_close();
              }
        ],
        [
            '-re',
            qr/$ahost console login: $/,
            sub {
                print WOF "\n$tstamp:\t$host already at UNIX Console prompt\n";
                $exp->soft_close();
              }
        ],
        [
            qr'ogin: $',
            sub {
                my $fh = shift;
                if ( $fh->send("$user\n") ) {
                    exp_continue;
                }
                else {
                    print WOF
                      "\n$tstamp:\t$host: Unable to pass $user to login: $! \n";
                }
              }
        ],
        [
            qr'ssword: $',
            sub {
                my $fh = shift;
                $fh->send("$dexpasswd\n")
                  or print WOF
"\n$tstamp:\t$host: Failed to authenticate to SP with expected password \n";
                exp_continue;
              }
        ],
        [
            qr'$prompt',
            sub {
                my $fh = shift;
                $fh->send("exit\n");
                print WOF
                  "\n$tstamp:\tConnected successfully to $host as $user \n";
                exp_continue;
              }
        ],
        [
            eof => sub {
                if ($spawn_ok) {
                    print WOF
                      "\n$tstamp:\t$host -- ERROR: premature EOF in login.\n"
                      && die "\n$host -- ERROR: premature EOF in login.\n";
                }
                else {
                    print WOF
                      "\n$tstamp:\t$host -- ERROR: could not spawn telnet.\n"
                      && die "\n$host -- ERROR: could not spawn telnet. \n";
                }

              }
        ],
        [
            timeout => sub {
                print WOF "\n$tstamp:\t$host -- No login.\n"
                  && die "$host timed out after $timeout seconds! $! \n";
              }
        ],
        '-re',
        qr'[#>:] $',    #' wait for shell prompt, then exit expect
    );
    close(WOF);

}

sub testRSC {
    #
    my $logfile = "/var/tmp/console_check_$date.log";
    my $conslog = "/var/tmp/console_log_$date.log";
    open( WOF, ">> $logfile" ) or die "Unable to write to/open logfile: $! \n";

    #my $prompt = "rsc\>";
    my ( $host, $user, $passwd, $timeout ) = @_;
    chomp( $host, $user, $passwd, $timeout );
    my $dexpasswd = &deCryptIt($passwd);
    chomp $dexpasswd;
    my $telnet = New Net::Telnet($host)
      or print WOF "$tstamp:\tUnable to telnet to $host: $! \n" && die;
    my $exp = Expect->exp_init($telnet);
    my $spawn_ok;
    $exp->log_file($conslog);
    my $ahost = $host;
    $ahost =~ s/\-c$//;

    #my $prompt = '[\]\$\>\#]\s*$';
    $exp->expect(
        $timeout,
        [
            qr'rsc\> $',
            sub {
                $spawn_ok = 1;
                my $fh = shift;
                $fh->send("I\n");
                exp_continue;
              }
        ],
        [
            '-re',
            qr/$ahost console login: $/,
            sub {
                print WOF "$tstamp:\t$host already at UNIX Console prompt\n";
                $exp->soft_close();
              }
        ],
        [
            'login: $',
            sub {
                my $fh = shift;
                $fh->send("$user\n");
                exp_continue;
              }
        ],
        [
            'Password: $',
            sub {
                my $fh = shift;
                $fh->send("$dexpasswd\n");
                exp_continue;
              }
        ],
        [
            qr'$prompt',
            sub {
                my $fh = shift;
                $fh->send("exit\n");
                print WOF
                  "$tstamp:\tConnected successfully to $host as $user \n";
                exp_continue;
              }
        ],
        [
            eof => sub {
                if ($spawn_ok) {
                    print WOF
                      "$tstamp:\t$host -- ERROR: premature EOF in login.\n"
                      && die;
                }
                else {
                    print WOF
                      "$tstamp:\t$host -- ERROR: could not spawn telnet.\n"
                      && die;
                }

              }
        ],
        [
            timeout => sub {
                print WOF "$tstamp:\t$host -- No login.\n" && die;
              }
        ],
        '-re',
        qr'[#>:] $',    #' wait for shell prompt, then exit expect
    );
    my $string = $exp->exp_match();
    if ($string) {
        print "DEBUG $string \n";
    }
    close(WOF);

}

sub testSP {
    #
    # This is for all ssh-enabled consoles

    my $logfile = "/var/tmp/console_check_$date.log";
    my $conslog = "/var/tmp/console_log_$date.log";
    open( WOF, ">> $logfile" ) or die "Unable to write to/open logfile: $! \n";
    my ( $host, $user, $passwd, $timeout ) = @_;
    chomp( $host, $user, $passwd, $timeout );
    my $dexpasswd = &deCryptIt($passwd);
    chomp $dexpasswd;
    my $exp = Expect->spawn("$ssh -l $user $host")
      or print WOF "$tstamp:\tUnable to ssh to $host: $! \n" && die;
    my $spawn_ok;
    $exp->log_file($conslog);
    my $prompt = '[\-\>\]\$\>\#]\s*$';

    #$exp->exp_internal(1);
    $exp->expect(
        $timeout,
        [
            qr'ogin: $',
            sub {
                $spawn_ok = 1;
                my $fh = shift;
                $fh->send("I\n");
                exp_continue;
              }
        ],
        [
            'ssword: $',
            sub {
                my $fh = shift;
                $fh->send("$dexpasswd\n");
                exp_continue;
              }
        ],
        [
            qr/$prompt/,
            sub {
                my $fh = shift;
                $fh->send("exit\n");
                print WOF
                  "$tstamp:\tConnected successfully to $host as $user \n";
                exp_continue;
              }
        ],
        [
            eof => sub {
                if ($spawn_ok) {
                    print WOF "$tstamp:\t$host ERROR: premature EOF in login.\n"
                      && die ":! \n";
                }
                else {
                    print WOF
                      "$tstamp:\t$host ERROR: could not spawn session.\n"
                      && die ":! \n";
                }

              }
        ],
        [
            timeout => sub {
                print WOF "$tstamp:\t$host -- No login.\n" && die ":! \n";
              }
        ],
        '-re',
        qr'[#>:] $',    #' wait for shell prompt, then exit expect
    );
    close(WOF);
}

if ($help) {
    &printUsage("Regular Help Message") && exit(0);
}

if ( ( !$user ) or ( !$passwd ) ) {
    &printUsage("Please pass the username and password from cmdline!")
      && exit(1);
}
if ( !$host ) {
    &printUsage("Please pass the hostname from cmdline!") && exit(1);
}
if ( !$timeout ) {
    $timeout = "30";
}

if ( $type =~ m/cyclades/i ) {
    &testCyclades( $host, $user, $passwd, $timeout );

}
elsif ( $type =~ m/RSC/i ) {

    &testRSC( $host, $user, $passwd, $timeout );
}
elsif ( $type =~ m/SC|iLo|ILOM|ALOM/ ) {
    &testSP( $host, $user, $passwd, $timeout );
}
else {
    &printUsage("Unknown Connection Type") && exit(1);
}
