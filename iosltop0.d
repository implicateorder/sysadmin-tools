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
    @Size[pid, curpsinfo->pr_psargs, this->device, this->major, this->minor] = quantize(this->size);
}

io:::done /(args[0]->b_flags & B_READ) && (this->start = start_time[arg0])/ {
    this->delta = (timestamp - this->start) /1000;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    @Latency[pid,"Read (us)",this->device, this->major, this->minor] = quantize(this->delta);
    start_time[arg0] = 0;
}

io:::done /(args[0]->b_flags & B_WRITE) && (this->start = start_time[arg0])/ {
    this->delta = (timestamp - this->start) /1000;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    @Latency[pid, "Write (us)", this->device, this->major, this->minor] = quantize(this->delta);
    start_time[arg0] = 0;
}


profile:::tick-5sec
{
    system("clear");
    trunc(@Size,2); trunc(@Latency,2);
    printf("\n%8s %16s %16s %8s %8s\n", "PID", "CMD", "DEVICE", "MAJNO", "MINNO");
    printa("%8d %16s %16s %8d %8d\nBlk-sz (K)\n%@d\n", @Size);
    printa("%8d %16s %16s %8d %8d\n\n%@d\n", @Latency);


    /* printa("%16s %8d %8d %10s\n%@d\n", @Latency);*/

}
