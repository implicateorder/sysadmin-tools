sysadmin-tools
==============

System administration tools

A bunch of the tools found here are open source tools written by other authors. 

Following categorizations are valid given these tools (which is in itself work-in-progress)

1) Shell scripts
2) Perl scripts
3) dtrace scripts

The dtrace scripts are embellishments of concepts and code snippets from Brendan Gregg's excellent book on DTrace.

Following scripts are most important -

1) iosltop (which displays IO rate, throughput and latency at a 5-second interval, in a top-like manner)
2) biowait (which displays top blocked iowait consumers)
3) connect.d (which displays top 'n' tcp latencies)
4) hpstckgrowth.d (which displays top 10 heap and stack memory hogs)
5) kmem_track.d (which tracks top 50 kernel memory cache hogs)

