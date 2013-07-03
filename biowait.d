#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option destructive
#pragma D option bufsize=16m

/* This script will display the top 10 blocked io wait events on the system
*  in a "top" like manner, showing the responsible PID, execname, Device details and count of such events
*/

dtrace:::BEGIN {
   printf("%s\n", "Tracing...Ctrl-C to quit");
}

io:genunix:biowait:wait-start, io:genunix:biowait:wait-done {
   @biowaiters[pid,execname,args[1]->dev_statname, args[1]->dev_major, args[1]->dev_minor] = count(); 
}


profile:::tick-5sec
{
     system("clear");
     trunc(@biowaiters, 10);
     printf("%-8s %16s %16s %8s %8s %8s\n", "PID", "CMD", "DEVICE", "MAJOR#", "MINOR#", "COUNT");
     printa("%-8d %16s %16s %8d %8d %8@d\n", @biowaiters);
}
