#!/usr/sbin/dtrace -s
#pragma D option quiet

dtrace:::BEGIN
{
   printf("Tracing...Hit Ctrl-C to end\n");
}

io:::start {
    this->size = args[0]->b_bcount;
    this->device = args[1]->dev_statname;
    this->major = args[1]->dev_major;
    this->minor = args[1]->dev_minor;
    @Size[pid, curpsinfo->pr_psargs, this->device, this->major, this->minor] = quantize(this->size);
}

dtrace:::END
{
    printf("\n%8s %16s %16s %8s %8s\n", "PID", "CMD", "DEVICE", "MAJNO", "MINNO");
    printa("%8d %16s %16s %8d %8d\n\n%@d\n", @Size);
}
