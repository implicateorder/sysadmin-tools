#!/bin/ksh

host=$1

ostype=`ssh $host 'uname -s'`
osver=`ssh $host 'uname -r'`
osminver=`echo $osver|awk -F\. '{print $2}'`
if [ $ostype = "SunOS" ]; then
    if [ $osminver -ge 10 ]; then
	ssh $host 'sudo egrep -i "pg_contig_disable" /etc/system' \
	|| echo "pg_contig_disable not set on $host"
	ssh $host 'sudo egrep -i "mpss_coalesce" /etc/system' \
	||echo "mpss_coalesce_disable not set on $host"
	ssh $host 'sudo egrep -i "zfs:zfs_arc_max" /etc/system' \
	|| echo "zfs_arc_max is not set on $host"
    fi
fi
