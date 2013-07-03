#!/usr/sbin/dtrace -s
#pragma D option quiet

dtrace:::BEGIN
{
   printf("Tracing top 10 IO sizes and latency events...Hit Ctrl-C to end\n");
}

io:::start {
    start_time[arg0] = timestamp;
    this->size = args[0]->b_bcount;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    @Size[pid, curpsinfo->pr_psargs, this->device, this->major, this->minor] = quantize(this->size);
    trunc(@Size,10);
}

io:::done /this->start = start_time[arg0]/ {
    this->delta = (timestamp - this->start) /1000;
    this->size = args[0]->b_bcount;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    @Latency[this->device, this->major, this->minor] = quantize(this->delta);
    trunc(@Latency,10);
    start_time[arg0] = 0;
}

dtrace:::END
{
    printf("\n%8s %16s %16s %8s %8s\n", "PID", "CMD", "DEVICE", "MAJNO", "MINNO");
    printa("%8d %16s %16s %8d %8d\n\n%@d\n", @Size);
    printf("\n%16s %8s %8s\n\n", "DEVICE", "MAJNO", "MINNO");
    printa("%16s %8d %8d\nLatency(us)\n\n%@d\n", @Latency);
}
