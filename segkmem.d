#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option destructive

BEGIN
{
    printf("Tracing...Ctrl-C to exit\nTracking top 20 kernel memory allocs/frees, with size of allocation/free");
}

fbt::segkmem_xalloc:entry
{
	@alloc[pid, execname, args[0]->vm_name, arg2] = count();
}

fbt::segkmem_free_vn:entry
{
	@free[pid, execname, args[0]->vm_name, arg2] = count();
}

profile:::tick-5sec
{
    system("clear");
    trunc(@alloc, 20);
    trunc(@free, 20);
    printf("%8s %16s %8s %8s %8s %8s\n", "PID", "CMD", "VMEM NAME", "SIZE", "ALLOCS", "FREES");
    printa("%8d %16s %8s %8d %@8d %@8d\n", @alloc, @free);
}
