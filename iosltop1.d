#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option destructive

dtrace:::BEGIN
{
   printf("Tracing top IO sizes and latency events...Hit Ctrl-C to end tracing \n");
}

io:::start {
    start_time[arg0] = timestamp;
    this->size = args[0]->b_bcount;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    this->mount = args[2]->fi_mount;

    this->pid = pid;
    this->thruput = args[0]->b_bcount / 1024;

    @Size["D", this->pid, curpsinfo->pr_psargs, this->mount, this->device, this->major, this->minor] = quantize(this->size);

    @TotalThruput[this->pid,curpsinfo->pr_psargs, this->device] = avg(this->thruput);
    normalize(@TotalThruput, (timestamp - start_time[arg0]) / 1000000);

}

io:::done /(args[0]->b_flags & B_READ) && (this->start = start_time[arg0])/ {
    this->delta = (timestamp - this->start) /1000 /1000 ;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    this->mount = args[2]->fi_mount;
    this->thruput  =  args[0]->b_bcount / 1024;
    this->finame = args[2]->fi_pathname;

    @Latency["D", pid,"Read (ms)", this->finame, this->device, this->major, this->minor] = quantize(this->delta);
    @AvgLat[this->device, "READ IO"] = avg(this->delta);
    @Thruput[this->device, "READ IO"] = avg(this->thruput);

    /* Normalize the output to give per second values */
    /* default dtrace output is in nanoseconds	      */

    normalize(@Thruput, (timestamp - start_time[arg0]) / 1000000);
    start_time[arg0] = 0;
}

io:::done /(args[0]->b_flags & B_WRITE) && (this->start = start_time[arg0])/ {
    this->delta = (timestamp - this->start) /1000 / 1000;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    this->mount = args[2]->fi_mount;
    this->finame = args[2]->fi_pathname;
    this->thruput  = args[0]->b_bcount / 1024;
    @Latency["D", pid, "Write (ms)", this->finame, this->device, this->major, this->minor] = quantize(this->delta);
    @AvgLat[this->device, "WRITE IO"] = avg(this->delta);
    @Thruput[this->device, "WRITE IO"] = avg(this->thruput);

    /* Normalize the output to give per second values */
    /* default dtrace output is in nanoseconds	      */

    normalize(@Thruput, (timestamp - start_time[arg0]) / 1000000);
    start_time[arg0] = 0;
}


profile:::tick-5sec
{
    system("clear");
    trunc(@Size,2); trunc(@Latency,2); trunc(@AvgLat,5); trunc(@Thruput,5); trunc(@TotalThruput, 5);
    printf("\n%1s %8s %16s %16s %16s %8s %8s %10s\n", "D", "PID", "CMD", "MOUNT POINT", "DEVICE", "MAJNO", "MINNO", "Blk Sz");
    printa("%1s %8d %16s %16s %16s %8d %8d\n%@d\n", @Size);
    printa("%1s %8d %16s %16s %16s %8d %8d\n%@d", @Latency);
    
/*    printf("\n%8s\t%30s\t\t%10s\t%10s\n", "PID", "CMD", "DEVICE", "AVG THRUPUT (Kb/s)");
 *   setopt("aggsortrev","4");
 *   printa("%8d\t%30s\t\t%10s\t%@d\n", @TotalThruput);
*/

    setopt("aggsortrev","3");
    printf("\n%16s\t%10s\t%10s\n", "DEVICE", "TYPE","IO AVG LATENCY (ms)"); 
    printa("%16s\t%10s\t%@d\n", @AvgLat);

    setopt("aggsortrev","3");
    printf("\n%16s\t%10s\t%10s\n", "DEVICE","TYPE","AVG THRUPUT (Kb/s)"); 
    printa("%16s\t%10s\t%@d\n", @Thruput);

}
