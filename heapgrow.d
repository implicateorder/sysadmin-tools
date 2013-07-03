#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option destructive


fbt::brk:entry
/execname != "dtrace"/ 
{ 
	@mem[execname,pid,curpsinfo->pr_psargs] = count();

} 

profile:::tick-60sec 
{ 
	system("clear");
	printf("Tracing...Ctrl-C to exit\nTracking processes that are growing their heap size...\naggregation printed at 60s intervals\n");
	trunc(@mem,10); 
	printf("%-8s %-8s %-40s %-8s\n", "EXEC", "PID", "COMMAND", "COUNT");
	printa("%-8s %-8d %-40s %-@8d\n", @mem);

}
