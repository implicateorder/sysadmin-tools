#!/usr/bin/perl -w
use strict;
use Net::DNS;
use Getopt::Long;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

##########################
#
#	dnsResponseTimePing.pl - One time DNS-Query latency check
#
##########################
#  SYNOPSIS
#
#  dnsResponseTimePing.pl -h host -s server [-r] [-v] [-d] [-t timeout]
#
#  dnsResponseTimePing.pl -h www.icrc.org  -s 129.132.98.12  -r -v -d -t 5
#	
#  h:		host to be resolved
#  s:		DNS servers to ask
#  r:		make query recursive
#  v:		turn on debug
#  d:		Use dig instead of PERL Net-DNS
#  t:		timeout in seconds (default 10s)
#
##########################
#  DESCRIPTION
#                                                                                
# This scripts single-queries a server to resolve a host against a DNS server.
# 
# It returns ONLY the resolution time in milliseconds, if the resolution was successfull, 
# otherwise, it returns 0.
#
#########################
#  AUTHOR
#
# dnsResponseTimePing.pl Modifications
#  6. Dec 2009 / Wayne Anderson wfrazee at wynwebtechnologies.com
#    - modified for single-ping
#    - added support for using dig
#    - modified for Cacti v0.8.7b
#    - added basic commentary and whitspace to help those who may come later
#    - got rid of pod2usage crap
#
# dnsResponseTimeLoop.pl
#  12. Jan 2005 / Rolf Sommerhalder rolf.sommerhalder at alumni.ethz.ch
#    - modified for Cacti v0.8.6
# 
#  Copyright (c) 2003 Hannes Schulz <mail@hannes-schulz.de>
#    - originally written for Nagios
#
########################




############################
# Creating basic variables which align to the key data elements we need to capture from the command line
#
# The host should be a string DNS hostname of some kind that we are trying to resolve.
#
# The server should be a string and may be either a hostname which can be resolved to a DNS server or an IP address of the DNS server.
#
# Recursive will be a boolean/binary value of whether we set the recursive query flag.  
# Defaults to off (0).
#
# Verbose will be a boolean/binary value of whether we set the flag to provide additional debug data. 
# Defaults to off(0).
#
# Usedig will be a boolean / binary value of whether we use dig on the command line instead of Net-DNS and timestamps to calculate resolution time.
# Defaults to off(0).
#
# Timeout is an expected integer value for how long we should wait for queries to return.  Defaults to 10. 
#
###
  
my ($host,$server,$recursive,$verbose,$usedig,$timeout, $count, $interval);


#Get the options from the command line.
GetOptions(
	"h=s" => \$host,
	"s=s" => \$server,
	"r!"  => \$recursive,
	"v!"  => \$verbose,
	"d!"  => \$usedig,
	"t=i" => \$timeout,
	"count=i" => \$count,
	"sleep=i" => \$interval
);


# If we dont have a server or a host value, we dont have enough information to continue.
# We have defaults for anything else, so just those two are critical values.

if(!$server || !$host) {
 print "Not enough arguments. Require at least host and server specified.\n";
 exit 0; 
}

if(!$count) {
   $count = 1;
}
if(!$interval) {
   $interval = 1;
}


# Set our defaults if any of the non-critical values are not specified on the command line
if (!$recursive) {$recursive= 0;}
if (!$verbose) {$verbose= 0;}
if (!$usedig) {$usedig= 0;}
if (!$timeout) {$timeout= 10};


# Instantiate variables we need no matter what we do.
my $query;
my $elapsed = 0;


###############
# IF we arent using dig...
# 
# Create the DNS Resolver
# The PERL DNS resolver frankly leaves a lot to be desired in my opinion. Dont expect your 
# resolution times to be neccessarily precise with the perl resolver.  At the same time, 
# it should be suitable for the basic purposees here.
#
# At this step we are just creating the DNS resolution object to make our queries against.
#
# This does two things.  Basically instantiates the objects and also sets the conditions for
# the additional verbose and recursive options we collected at the command line.
#
#######

printf("%-16s %-26s %-8s\n", "NAMESERVER", "TARGET", "Response Time(ms)");
while ($count gt 0) {

    &runIt;
    $count--;
    sleep($interval);
}

sub runIt {
if (!$usedig) {
  my $res= Net::DNS::Resolver->new(
    nameservers		=> [$server],
    recurse		=> $recursive,
    debug		=> $verbose,
    retrans		=> $timeout,	# default= 5
    retry		=> 1, 		# default= 4
    #udp_timeout	=> $timeout,	# default= undef, e.g. retrans and retry are used
    persistent_udp	=> 0,		# If set to true, Net::DNS will keep a single UDP socket open for all queries
    igntc		=> 1,		# If true truncated packets will be ignored. If false truncated packets will cause the query to be retried using TCP
    dnssec		=> 0,		# disable EDNS0 (extended) queries and disables checking flag (cdflag)
    udppacketsize	=> 512,		# default= 512, if larger than Net::DNS::PACKETSZ() an EDNS extension will be added
  );



  # Instantiate some variables including a boolean for whether the query went ok and some time tracking.
  my $wasok;
  my ($t0, $t1, $startTime);


  # Capture what the system time is right now before we executed the query.
  $startTime= [gettimeofday];
  $t0= [gettimeofday];

  # Make our actual DNS query using the resolver object we setup before.
  if ($host =~ m/(\d+).(\d+).(\d+).(\d+)/) {
      $query= $res->send($host, 'PTR');
  }
  else {
      $query= $res->send($host, 'A');
  }

  #########################
  # Capture what the system time is right now after we executed the query.
  #
  # Remember that the query times here are not exact when we use this method.
  # There is additional time that it takes PERL to process a couple steps in 
  # between the ACTUAL time that the resolution step took using our resolver
  # object and the times that it captured the timestamp.
  #
  ###

   $t1= [gettimeofday];


  # Calculate the elapsed time that it took to actually make the query.  
  # Hold on to this value for a moment.

   $elapsed= int (tv_interval($t0, $t1) *1000);


  #########################
  # If we got a value back of some kind, we need to check to see whether it was an error so 
  # we can flag that back instead of providing our rough time estimation.
  ###

     if ($query) {

     # If the resolution code we get back DOES NOT equal NOERROR...
     if (! ($query->header->rcode eq "NOERROR") ) {
   
       # We need to flag an error as our response.
       # Do noting $elapsed= 0;			# query returned error

       if ($verbose) {
        print "\n";
        print $query->header->rcode;
        print "\n";
       }
     }

     elsif ($query->header->ancount ==0) {
       $elapsed= 0;			# did not resolve into an A record

       if ($verbose) {
         print "\n";
         print "Did not resolve to A record.";
         print "\n";
       }
     }
   }
   else {
      $elapsed= 0;			# timeout occurred
      if ($verbose) {
        print "\n";
        print "Timed out.";
        print "\n";
      }
    }

## END the using-perl-net-DNS method.

} else {				

  my $errorflag= 0;

  # We need to pre-compute whether recursion is being used and adjust our command line appropriately.
  my $recursion = "";
  if (!$recursive) {
    $recursion = "+norecurse";
  }

  ## Using Dig
  $query = `dig \@$server $host +stats +noquestion +noanswer +noauthority +noadditional +time=$timeout $recursion`;

  ## If dig includes a line indicating how much time the query took...
  if ($query =~ m/\;\; Query time: (\d+) (\w+)/) {

    # Capture that time and the type of time from the line.
    $elapsed= $1;
    my $timetype = $2;

    # If it gives it to us in seconds, we need to multiply it out as that is a huge time to display.
    if($timetype eq "sec") {
	$elapsed = $elapsed * 1000;
    }

  } else {
    
    # Otherwise we indicate we didnt get a time back.
    $elapsed= 0;
	
    $errorflag= 1;
    if($verbose) {
      print "\n";
      print "No query time returned by dig.\n";
      print "\n";
    }

  }
  
  # Now that theoretically we have a time back of some kind, lets make sure there wasnt an error.
  if($query =~ m/ status: (\w+)\, /) {

     my $statuscode = $1;

     if($statuscode ne "NOERROR") {
       $elapsed= 0;
       $errorflag= 1;

       if ($verbose) {
         print "\n";
         print "Dig returned an error code.";
         print "\n";
       }

     }
  }  


  if($verbose && $errorflag) {
    print "\n";
    print $query;
  }

}


printf("%-16s %-16s %-8d\n", $server, $host, $elapsed);
}
