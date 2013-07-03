#!/usr/bin/env perl -w
#
# ---------------------------------------------------------------------------------------------- #
# This script needs the GraphViz2 module installed. So, run this script from a host where the
# perl module is installed.
# The cfg file needs to be prepared in this format (see below). Remove one leading # sign and
# copy to a file (eg: /var/tmp/graph_test.cfg) to test functionality
## START_TOPO
##cluster:tier:node:dc
#cluster01:web:web1:itasca
#cluster02:middleware:mid1:itasca
#cluster03:db:db1:itasca
#cluster11:web:web2:elk
#cluster12:middleware:mid2:elk
#cluster13:db:db2:elk
## END_TOPO
## START_EDGE
##nodes:dir:style:label
#web1:web2:both:invis:UNDEF
#mid1:mid2:both:invis:UNDEF
#db1:db2:both:invis:UNDEF
#web1,web2:mid1,mid2:::p9099
#db1,db2:DBSID:both::Database
#mid1,mid2:db1,db2:::p1514
## END_EDGE
# Subsequent modification of this script will automatically push the output to a wiki or generate
# a png/gif/pdf/jpg if so indicated.
# ---------------------------------------------------------------------------------------------- #

use Getopt::Long;
use GraphViz2;

my $help = '';
my $cfg = '';
my $output = '';

GetOptions (

'help' => \$help,
'cfg=s' => \$cfg,
'output=s' => \$output
);

if ($help) {
    &printUsage && exit(0);
}

if (! $cfg) {
    die "Cannot continue without input/configuration file: $! \n";
}
if (! $output) {
    $output = "/tmp/graph_out.dot";
}


my $g = GraphViz2->new( 
	edge => {color => 'grey'},
	global => {directed => 1},
	graph => {clusterrank => 'local', compound => 1, rankdir => 'LR'},);

open(RCFG, "< $cfg") or die "Unable to open $cfg: $! \n";
@rcfg = <RCFG>;
close(RCFG);
my %DC;

foreach my $line (@rcfg) {
    if (($line =~ m/START_TOPO/i)..($line =~ m/END_TOPO/i)) {
	next if ($line =~ m/^#/);
	#print "TOPO: $line \n";
	my ($cluster, $tier,$nodes,$dc) = split(':', $line);
	chomp($cluster,$tier,$nodes,$dc);
	if (! $dc ) {
	    $dc = "Itasca";
	}
	print "DC is $dc \n";
	print "TIER is $tier \n";
	my @nodelist = split(',',$nodes);
	$g -> push_subgraph (
	    name => 'cluster_'.$dc,
	    graph => { label => $dc },
	    node => { color => 'lightgray', shape => 'rectangle' });
	if ($tier) {
	$g -> push_subgraph (
	     name => 'cluster_'.$tier."_".$dc, graph => {label => $tier});
	}
	foreach my $node (@nodelist) {
		print "NODE: $node \n";
		$g -> add_node(name => $node);
	}
	$g -> pop_subgraph;
	$g -> pop_subgraph;
	
    }
    if (($line =~ m/START_EDGE/i)..($line =~ m/END_EDGE/i)) {
	next if ($line =~ m/^#/);
	print "EDGE: $line \n";

	my ($enodesrc, $enodedest, $dir,$style,$label) = split(':', $line);

	chomp($enodesrc, $enodedest, $dir,$style,$label);
	$enodesrc =~ s/^/\{/;
	$enodesrc =~ s/$/\}/;
	$enodedest =~ s/^/\{/;
	$enodedest =~ s/$/\}/;

	my @enodesrclist = split(',', $enodesrc);
	print "SRC @enodesrclist \n";

	my @enodedestlist = split(',', $enodedest);
	print "DST @enodedestlist \n";

	if ($label = "UNDEF") {

	    $g -> add_edge(from => "@enodesrclist", to => "@enodedestlist", style => $style, dir => $dir);
	}
	else {
	    $g -> add_edge(from => "@enodesrclist", to => "@enodedestlist", style => $style, dir => $dir, label => $label);
	}
	
    }
}

my($format) = 'dot';
$g -> run(format => $format, output_file => $output);

sub printUsage {

    print "Usage: $0 --help|[--cfg=<cfgfile> --output=<outfile>] \n";

}
