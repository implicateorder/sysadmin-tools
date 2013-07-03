#!/usr/sbin/dtrace -s

#pragma D option quiet 
#pragma D option destructive


sched:::off-cpu
/ arg1 != 0 && pid == $1 && curlwpsinfo->pr_state == SSLEEP/
{
	/*
	 * We're sleeping.  Track our sobj type.
	 */
	self->sobj = curlwpsinfo->pr_stype;
	self->bedtime = timestamp;
}

sched:::off-cpu
/ arg1 != 0 && pid == $1 && curlwpsinfo->pr_state == SRUN/
{
	self->bedtime = timestamp;
}

sched:::on-cpu
/self->bedtime && !self->sobj /
{
	this->delta = (timestamp - self->bedtime) / 1000;
	@b[execname,pid,"preempted"] = sum(this->delta);
	self->bedtime = 0;
}


sched:::on-cpu
/self->sobj /
{
	this->delta = (timestamp - self->bedtime) / 100000;
	@c[execname,pid,self->sobj == SOBJ_MUTEX ? "kernel-level lock" :
	    self->sobj == SOBJ_RWLOCK ? "rwlock" :
	    self->sobj == SOBJ_CV ? "condition variable" :
	    self->sobj == SOBJ_SEMA ? "semaphore" :
	    self->sobj == SOBJ_USER ? "user-level lock" :
	    self->sobj == SOBJ_USER_PI ? "user-level prio-inheriting lock" : 
	    self->sobj == SOBJ_SHUTTLE ? "shuttle" : 
	    "unknown"] = quantize(this->delta);
	self->sobj = 0;
	self->bedtime = 0;
}

tick-10sec
{
    system("clear");
    printf("%-16s %8s %16s\n", "EXECNAME", "PID", "RUN TIME(us)");
    printa("%-16s %8d %16@d\n\n", @b);
    printf("%-16s %8s %32s %32s\n", "EXECNAME", "PID", "LOCK TYPE", "LOCK TIME(ms)");
    printa("%-16s %8d %32s %32@d\n", @c);
}
