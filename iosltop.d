#!/usr/sbin/dtrace -s
#pragma D option quiet
#pragma D option destructive

dtrace:::BEGIN
{
   printf("Tracing top 10 IO sizes and latency events...Hit Ctrl-C to end tracing and show results :-)\n");
}

io:::start {
    start_time[arg0] = timestamp;
    this->size = args[0]->b_bcount;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    @Size[pid, curpsinfo->pr_psargs, this->device, this->major, this->minor] = quantize(this->size);
    trunc(@Size,2);
}

io:::done /(args[0]->b_flags & B_READ) && (this->start = start_time[arg0])/ {
    this->delta = (timestamp - this->start) /1000;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    @Latency[this->device, this->major, this->minor, "Read I/Os (us)"] = quantize(this->delta);
    trunc(@Latency,2);
    start_time[arg0] = 0;
}

io:::done /(args[0]->b_flags & B_WRITE) && (this->start = start_time[arg0])/ {
    this->delta = (timestamp - this->start) /1000;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    @Latency[this->device, this->major, this->minor, "Write I/Os (us)"] = quantize(this->delta);
    trunc(@Latency,2);
    start_time[arg0] = 0;
}


profile:::tick-1sec
{
    system("clear");
    printf("\n%8s %16s %16s %8s %8s\n", "PID", "CMD", "DEVICE", "MAJNO", "MINNO");
    setopt("aggsortpos", "4"); setopt("aggsortrev", "4");
    printa("%8d %16s %16s %8d %8d\n\n%@d\n", @Size);
    printf("\n%16s %8s %8s %10s\n\n", "DEVICE", "MAJNO", "MINNO", "TYPE");
    printa("%16s %8d %8d %10s\n\n%@d\n", @Latency);
}
