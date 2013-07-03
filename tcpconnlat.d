#!/usr/sbin/dtrace -s

#pragma D option quiet 
#pragma D option destructive
/* #pragma D option bufsize=16m */

tcp:::connect-request {
	start[args[1]->cs_cid] = timestamp;
}
tcp:::connect-established /start[args[1]->cs_cid]/ {
	this->timestamp = (timestamp - start[args[1]->cs_cid])/1000;
	@latency[pid, curpsinfo->pr_psargs, args[2]->ip_saddr, args[4]->tcp_sport, args[2]->ip_daddr, args[4]->tcp_dport] = avg(this->timestamp); 
	start[args[1]->cs_cid] = 0;
}

profile:::tick-5sec {
	system("clear");
	trunc(@latency,20);
	printf("%3s %-26s %-26s %-s %-26s %-s %8s\n", "PID", "CMD", "LADDR","LPORT", "DADDR","DPORT", "Latency us"); 
	printa("%d %-26s %-26I %-P %-26I %-P %8@d us\n", @latency);
}
