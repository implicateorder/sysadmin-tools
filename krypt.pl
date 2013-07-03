#!/usr/bin/perl

#---------------------------------------------------------------------------------------------------------#
# $Log: krypt.pl,v $
# Revision 1.1  2012/08/07 14:22:15  i08129r
# Initial revision
#
# $Id: krypt.pl,v 1.1 2012/08/07 14:22:15 i08129r Exp i08129r $
#---------------------------------------------------------------------------------------------------------#

use strict;
use Term::ReadKey;
use Crypt::Simple;

my $password;

&testKrypt;

sub testKrypt {
    print "Enter your password here:";
    ReadMode('noecho');
    my $password = ReadLine(0);
    ReadMode('normal');
    chomp $password;
    my $encrypted = encrypt($password);
    print "\n$encrypted\n";
}
