#!/usr/sbin/dtrace -Cs
/*
** socketsnoop.d - snoop TCP network socket traffic by process. 
**              This is intended to identify the process responsible
**              for network traffic. Written in DTrace (Solaris 10 build 63).
**
** THIS SCRIPT HAS BEEN DEPRECATED in favour of the TCP scripts from
** the DTraceToolkit, http://www.opensolaris.org/os/community/dtrace.
**
** This matches most types of TCP traffic, but not all types. It is
**  useful as it shows which processes are causing at least this much 
**  network activity.
**
** 12-Mar-2005, ver 0.65        (check for newer versions)
**
**
** USAGE:       ./socketsnoop.d
**
**      Different styles of output can be selected by changing
**      the "PFORMAT" variable below.
**      
** FIELDS:
**              UID     user ID
**              PID     process ID
**              PPID    parent process ID
**              CMD     command (full arguments)
**              DIR     direction
**              SIZE    size of payload data 
**              TIME    timestamp, us
**
** The size is the data payload size not the packet size.
**
** SEE ALSO: snoop -rS
**           sock_top.d, James Dickens
**
** Standard Disclaimer: This is freeware, use at your own risk.
**
** THANKS: James Dickens
**
** ToDo: UDP, ICMP.
**
** 09-Jul-2004  Brendan Gregg   Created this.
** 12-Mar-2005     "      "	Changed probes, size info now printed.
**
*/

#include <sys/vnode.h>
#include <sys/socket.h>

inline int PFORMAT = 1;
/*                      1 - Default output
**                      2 - Timestamp output (includes TIME)
**                      3 - Everything, space delimited (for spreadsheets)
*/

#pragma D option quiet


/*
**  Print header
*/
dtrace:::BEGIN /PFORMAT == 1/ { 
        printf("%5s %5s %3s %5s %s\n","UID","PID","DIR","SIZE","CMD");
        this->readsize = 0;
}
dtrace:::BEGIN /PFORMAT == 2/ { 
        printf("%-14s %5s %5s %3s %5s %s\n",
         "TIME","UID","PID","DIR","SIZE","CMD");
}
dtrace:::BEGIN /PFORMAT == 3/ { 
        printf("%s %s %s %s %s %s %s\n",
         "TIME","UID","PID","PPID","DIR","SIZE","CMD");
}


/*
**  Store Write Values
*/
fbt:ip:tcp_output:entry
{
        self->dir = "W";
        self->size = msgdsize(args[1]);
	self->ok = 1;
}

/*
**  Store Read Values
*/
fbt:sockfs:sotpi_recvmsg:entry
{
        self->dir = "R";
	/* We track the read request (man uio), */
	self->uiop = (struct uio *) arg2;
	self->residual = self->uiop->uio_resid;
        /* check family */
	this->sonode = (struct sonode *)arg0;
        self->ok = (int)this->sonode->so_family == AF_INET ||
            (int)this->sonode->so_family == AF_INET6 ? 1 : 0;
        /* check type */
        self->ok = (int)this->sonode->so_type == SOCK_STREAM ? self->ok : 0;
}
fbt:sockfs:sotpi_recvmsg:return
/arg0 != 0 && self->ok/
{
	/* calculate successful read size */
	self->size = self->residual - self->uiop->uio_resid;
}

/*
**  Print output
*/
ip:tcp_output:entry, fbt:sockfs:sotpi_recvmsg:return 
/PFORMAT == 1 && self->ok/ 
{
        printf("%5d %5d %3s %5d %s\n",
         uid,pid,self->dir,self->size,curpsinfo->pr_psargs);
}
ip:tcp_output:entry, fbt:sockfs:sotpi_recvmsg:return 
/PFORMAT == 2 && self->ok/ 
{
        printf("%-14d %5d %5d %3s %5d %s\n",
         timestamp/1000,uid,pid,self->dir,self->size,
         curpsinfo->pr_psargs);
}
ip:tcp_output:entry, fbt:sockfs:sotpi_recvmsg:return 
/PFORMAT == 3 && self->ok/ 
{
        printf("%d %d %d %d %s %d %s\n",
         timestamp/1000,uid,pid,ppid,self->dir,
	 self->size,curpsinfo->pr_psargs);
}

/*
**  Cleanup
*/
ip:tcp_output:entry, fbt:sockfs:sotpi_recvmsg:return 
{
	self->ok = 0;
        self->dir = 0;
        self->size = 0;
        self->residual = 0;
        self->uiop = 0;
}
