#!/bin/sh
#
# Proprietary and Confidential, Copyright 2008, 2009, 2010 Forsythe Solutions Group, Inc. Do Not Redistribute
# This script is to be used at your own risk with absolutely no warranty implied in its use.
#
# Forsythe data gathering script to determine system and application profile
# Please make sure application is already running and will exhibit a representative
# profile for the next 5 minutes or so that this script collects data.
#
# It is assumed that this script will run as superuser
# If this script cannot be run as root then make sure the following gets setup in /etc/user_attr:
# user-name::::defaultpriv=basic,dtrace_proc,dtrace_user,dtrace_kernel,proc_owner
#
# Usage: ./jgather.sh [-s] [-p pid]
#
# The -s option suppresses static data like /etc/system and ifconfig -a in the data collection
# The -p option should be used if there is a specific process representing the
# application versus many processes are involved such as a database server
# Be careful as the -p option has a higher probe effect on the chosen process

# Check if running as superuser:
if [ -z "`id | grep root`" ] ; then
        echo You are not running as superuser
        if [ -z "`ppriv $$ | grep dtrace`" ] ; then
                echo You are not running with DTrace Privileges
                echo Either run as superuser or add the following line to the /etc/user_attr file:
                echo username::::defaultpriv=basic,dtrace_proc,dtrace_user,dtrace_kernel,proc_owner
                exit 1
        fi
        echo Some of the commands in this script will not work as non-superuser
        PATH=/usr/sbin:/usr/bin:/usr/ccs/bin
        export PATH
fi

TMPDIR=jgather.`hostname`.`date +%b_%d_%y.%H.%M.%S`
mkdir $TMPDIR

if [ $? -ne 0 ] ; then
  echo Could not create $TMPDIR
  exit 1
fi

trap '/bin/rm -fr $TMPDIR' 0 1 2 3 15

echo Script is gathering data
echo "You can generally ignore error messages while the script is running"

if [ "$1" = "-s" -o "$3" = "-s" ]; then
  :
else
  # Add or substract from the list of system files we wish to collect below
  for f in /etc/system /etc/mnttab /etc/dfs/dfstab /etc/release /var/adm/messages
  do
        cp $f  "$TMPDIR/`basename $f`"
  done

  date > $TMPDIR/modinfo.out
  modinfo >> $TMPDIR/modinfo.out

  date > $TMPDIR/prtdiag.out
  prtdiag -v >> $TMPDIR/prtdiag.out

  date > $TMPDIR/ifconfig.out
  ifconfig -a >> $TMPDIR/ifconfig.out

  date > $TMPDIR/showrev.out
  showrev -p >> $TMPDIR/showrev.out

  date > $TMPDIR/projects.out
  projects -l >> $TMPDIR/projects.out

  date > $TMPDIR/zones.out
  zoneadm list -cv >> $TMPDIR/zones.out
  for z in `zoneadm list | tail +2`
  do
    echo "\n$z:"
    zonecfg -z $z info
  done >> $TMPDIR/zones.out

fi

date > $TMPDIR/ps.out
ps -efc >> $TMPDIR/ps.out

date > $TMPDIR/kstat.out
kstat >> $TMPDIR/kstat.out

# Run these commands in parallel
date > $TMPDIR/prstat.out
prstat -Lmn 40 1 60 >> $TMPDIR/prstat.out&

date > $TMPDIR/mpstat.out
mpstat 1 60 >> $TMPDIR/mpstat.out&

date > $TMPDIR/dtrace-kernel.out
dtrace -qn 'profile-505 /arg0 && curthread->t_pri != -1/ {@[stack()] = count()} END {trunc(@, 40)} tick-30s {exit(0)}'  >> $TMPDIR/dtrace-kernel.out

date > $TMPDIR/dtrace-user.out
dtrace -qn 'profile-303 /arg1/ {@[jstack(20, 2048), execname, pid] = count()} END {trunc(@, 40)} tick-30s {exit(0)}' >> $TMPDIR/dtrace-user.out

date > $TMPDIR/dtrace-syscall.out
dtrace -qn 'syscall:::entry {@[probefunc, execname] = count()} tick-10s {exit(0)} END {trunc(@, 50)}' >> $TMPDIR/dtrace-syscall.out

echo Script is about half-way done

# Let's run lockstat alone so it does not report monitoring tool locking
date > $TMPDIR/lockstat.out
lockstat -D 40 -w sleep 10 >> $TMPDIR/lockstat.out
echo "\n\n" >> $TMPDIR/lockstat.out
sleep 10
lockstat -D 40 sleep 10 >> $TMPDIR/lockstat.out

# Run more in parallel
date > $TMPDIR/netstat.out
netstat -s >> $TMPDIR/netstat.out
echo "" >> $TMPDIR/netstat.out
netstat -an >> $TMPDIR/netstat.out
echo "" >> $TMPDIR/netstat.out
netstat -in 1 60 >> $TMPDIR/netstat.out&

date > $TMPDIR/iostat.out
iostat -xncz 1 60 >> $TMPDIR/iostat.out&

date > $TMPDIR/vmstat.out
vmstat -s >> $TMPDIR/vmstat.out
echo "" >> $TMPDIR/vmstat.out
vmstat 1 60 >> $TMPDIR/vmstat.out

if [ $# -ge 2 -a "$1" = "-p" ]; then
  date > $TMPDIR/dtrace-pid.out
  dtrace -qn "profile-303 /pid==$2 && arg1/ {@[jstack(20, 2048)] = count()} END {trunc(@, 40)} tick-30s {exit(0)}" >> $TMPDIR/dtrace-pid.out

  date > $TMPDIR/pidGather.out
  pldd $2 >> $TMPDIR/pidGather.out
  echo "" >> $TMPDIR/pidGather.out
  /usr/ccs/bin/dump -c /proc/$2/path/a.out | grep SUNW >> $TMPDIR/pidGather.out
  echo "" >> $TMPDIR/pidGather.out
  pargs -l $2 >> $TMPDIR/pidGather.out
  echo "" >> $TMPDIR/pidGather.out
  pmap -xs $2 >> $TMPDIR/pidGather.out
fi

if [ $# -eq 3 -a "$2" = "-p" ]; then
  date > $TMPDIR/dtrace-pid.out
  dtrace -qn "profile-303 /pid==$3 && arg1/ {@[jstack(20, 2048)] = count()} END {trunc(@, 40)} tick-30s {exit(0)}" >> $TMPDIR/dtrace-pid.out

  date > $TMPDIR/pidGather.out
  pldd $3 >> $TMPDIR/pidGather.out
  echo "" >> $TMPDIR/pidGather.out
  /usr/ccs/bin/dump -c /proc/$3/path/a.out | grep SUNW >> $TMPDIR/pidGather.out
  echo "" >> $TMPDIR/pidGather.out
  pargs -l $3 >> $TMPDIR/pidGather.out
  echo "" >> $TMPDIR/pidGather.out
  pmap -xs $3 >> $TMPDIR/pidGather.out
fi

tar cvf $TMPDIR.tar $TMPDIR >/dev/null
gzip $TMPDIR.tar
/bin/rm -fr $TMPDIR
echo "\nPlease send $TMPDIR.tar.gz to Forsythe\n"
echo "Generally, you should make multiple runs of this script in order to get a representative profile\n"
