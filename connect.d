#!/usr/sbin/dtrace -s

#pragma D option quiet
#pragma D option destructive
#pragma D option switchrate=10hz

/* if AF_INTE and AF_INET6 are "Unknown" to DTrace, replace with numbers */
inline int af_inet = 2;
inline int af_inet6 = 26;

dtrace:::BEGIN {
	err[0] = "Success";
	err[EINTR] = "Interrupted syscall";
	err[EIO] = "I/O Error";
	err[EACCES] = "permission denied";
	err[ENETDOWN] = "network is down";
	err[ENETUNREACH] = "network is unreachable";
	err[ECONNREFUSED] = "Connection refused";
	err[ECONNRESET] = "connection reset";
	err[ETIMEDOUT] = "Timed out";
	err[EHOSTDOWN] = "Host down";
	err[EHOSTUNREACH] = "No route to host";
	err[EINPROGRESS] = "In progress";

}
syscall::connect*:entry {
	/* assume this is sockaddr_in until we can examine family */
	this->s = (struct sockaddr_in *)copyin(arg1,sizeof (struct sockaddr));
	this->f = this->s->sin_family;
}

syscall::connect*:entry 
/this->f == af_inet/
{
	self->family = this->f;
	/* self->port = ntohs(this->s->sin_port);
	 * self->address = inet_ntop(self->family, (void *)&this->s->sin_addr);
	 * self->start = timestamp;
	 */
	self->port = (this->s->sin_port & 0xFF00) >> 8;
	self->port |= (this->s->sin_port & 0xFF) << 8;
	this->a = (uint8_t *)&this->s->sin_addr;
	this->addr1 = strjoin(lltostr(this->a[0] + 0ULL), strjoin(".", strjoin(lltostr(this->a[1] + 0ULL), ".")));
	this->addr2 = strjoin(lltostr(this->a[2] + 0ULL), strjoin(".", lltostr(this->a[3] + 0ULL)));
	self->address = strjoin(this->addr1, this->addr2);
	self->start = timestamp;

}

/* syscall::connect*:entry
 * /this->f == af_inet6/
 *{
*	this->s6 = (struct sockaddr_in6 *)copyin(arg1,sizeof (struct sockaddr_in6));
*	self->family = this->f;
*	self->port = ntohs(this->s6->sin6_port);
*	self->address = inet_ntoa6((in6_addr_t *)&this->s6->sin6_addr);
*	self->start = timestamp;
*}
*/
syscall::connect*:return
/self->start/
{
	this->delta = (timestamp - self->start) / 1000;
	this->errstr = err[errno] != NULL ? err[errno] : lltostr(errno);
	/* @lat[pid,curpsinfo->pr_psargs,self->family,self->address,self->port, this->errstr] = avg(this->delta); */
	/* comment subsequent line and uncomment preceding line to see full cmdline argument instead of execname */
	@lat[pid,execname,self->family,self->address,self->port, this->errstr] = avg(this->delta); 

	self->family = 0;
	self->address = 0;
	self->port = 0;
	self->start = 0;
}

profile:::tick-5sec {
	system("clear");
	trunc(@lat,50);
	printf("Tracing for Top 50 Network IO Latencies...Ctrl-C to exit\nFAM 2 is ipv4 26 is ipv6\n");
	printf("%-6s %-30s %-3s %-16s %-5s %-16s %8s\n", "PID", "PROCESS", "FAM", "ADDRESS", "PORT", "RESULT", "LAT(us)");
	printa("%-6d %-30s %-3d %-16s %-5d %-16s %8@d\n", @lat);
}


