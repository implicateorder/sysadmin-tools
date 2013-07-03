#!/usr/bin/perl -w

use Getopt::Long;
use HTML::WikiConverter;

my $help  = '';
my $wikitize = '';
my $infile = '';
my $outfile = '';
my $dialect = '';

GetOptions(
    'wikitize' => \$wikitize,
    'outfile=s' => \$outfile,
    'infile=s' => \$infile,
    'dialect=s' => \$dialect,
    'help' => \$help
);

if ($help) {
    &printUsage && exit(0);
}
if (defined $infile) {
   print "Validating $infile...\n";
}
else {
    &printUsage && exit(1);
}
if (defined $outfile) {
    print "Validating $outfile...\n";
}
else {
    $outfile = "outfile.wiki";
}
if (!$dialect) {
    $dialect = "Docuwiki";
}

if ($wikitize) {
	if ( -f $infile ) {
	    print "Wikitizing $infile...\n";
	    &wikitizeIt($infile, $outfile, $dialect);
	}
	else {
	    print "$infile is not a valid file:$! \n";
	    &printUsage && exit(1);
	}
}

sub wikitizeIt {
    my ($infile, $outfile, $dialect) = @_;
    my @dialects = HTML::WikiConverter->available_dialects;
    print @dialects;
    my $wc = new HTML::WikiConverter( dialect => $dialect );
    open(WOF, "|tee $outfile") or die "can't write to $outfile: $! \n";
    print WOF $wc->html2wiki( file => $infile );
    close(WOF);
}

sub printUsage {
    print "Usage: $0 [ --infile=<filename> --wikitize --outfile=<outfile> --dialect=<dialect>]|[--help] \n";
}
