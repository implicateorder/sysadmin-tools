#!/bin/bash

file=$1;
outfile=$2;

for i in `cat ${file}`; do 
    osname=`ssh $i "uname -s"`;
    if [ $osname != "SunOS" ]; then
	echo "Skipping host $i...os type is $osname";
    else
        osver=`ssh $i "uname -r"`; 
        minver=`echo $osver|awk -F\. '{print $2}'`; 
        if [ $minver -ge 10 ]; then
		     memsize=`ssh $i '/usr/sbin/prtconf|egrep -i "Memory size:"'|awk -F\: '{print $2}'|awk '{print $1}'`
        	     size=`ssh $i 'kstat -n arcstats -s size|grep size'|awk '{print $2}'`
		     nsize=`echo $size|perl -ne '$foo = ($_ / 1024 / 1024); printf ("%.2f",$foo);'`
		     pctratio=`echo "$memsize,$nsize"|perl -ne '($msz,$nsz) = split(/,/, $_);$pct = (($nsz/$msz) * 100); printf ("%.2f", $pct);'`
		     echo "$i ZFS ARC size is $nsize MB, $pctratio % of total memory $memsize MB";
        fi; 
    fi
done|tee -a $outfile
