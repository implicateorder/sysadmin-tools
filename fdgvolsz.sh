#!/usr/bin/ksh
#set -x
# -------------------------------------------------------------------------------------------------------------#
# $Id: fdgvolsz.sh,v 1.1 2012/08/06 21:43:33 i08129r Exp i08129r $
# $Log: fdgvolsz.sh,v $
# Revision 1.1  2012/08/06 21:43:33  i08129r
# Initial revision
#
# -------------------------------------------------------------------------------------------------------------#

# build a list of dgs on the host
 if [ -f /var/tmp/dgnames.txt ]; then
     sudo mv /var/tmp/dgnames.txt /var/tmp/dgnames.txt.$$
 fi
 sudo vxdg list|grep -v NAME|awk '{print $1}' > /var/tmp/dgnames.txt

# for each DG, generate a vxprint and save to file

 for dg in `cat /var/tmp/dgnames.txt`
 do
     if [ -f /var/tmp/${i}_vxprint.txt ]; then 
         sudo mv /var/tmp/${dg}_vxprint.txt /var/tmp/${dg}_vxprint.txt.$$
     fi
     sudo vxprint -g $dg > /var/tmp/${dg}_vxprint.txt
 done
host=`hostname`
# get the dgname corresponding to each LUN's hexid. Populate /var/tmp/thick_luns.txt with hexids
#
    if [ -f /var/tmp/${host}-ldvslist.txt ]; then
	sudo mv /var/tmp/${host}-ldvslist.txt /var/tmp/${host}-ldvslist.txt.$$ && touch /var/tmp/${host}-ldvslist.txt.$$
    fi
    for dg in `cat /var/tmp/dgnames.txt`
    do
        for lun in `cat /var/tmp/thick_luns.txt`
        do
            grep _${lun} ${dg}_vxprint.txt|grep "^sd" 
            if [ $? -eq 0 ]; then
                for volname in `grep _${lun} ${dg}_vxprint.txt|grep "^sd" | awk '{print $3}' | awk -F\- '{print $1}'`
                do
                    size=`grep -w $volname ${dg}_vxprint.txt |grep "^v" |awk '{print $5}'`
                    gsize=$(printf "%s\n" "$size*512/1024/1024"|bc)
		    for plexname in `grep -w $volname ${dg}_vxprint.txt |grep "^pl"|awk '{print $2}'` 
do
		    	for dmname in `grep -w $plexname ${dg}_vxprint.txt | grep "^sd" |awk '{print $2}'|awk -F\- '{print $1}'`
			do
			    devname=`grep -w $dmname ${dg}_vxprint.txt |grep "^dm"|awk '{print $3}'`
			    #dmname=`grep -w $plexname ${dg}_vxprint.txt |grep "^sd"|awk '{print $2}'|awk -F\- '{print $1}'`
			    devflags=`sudo vxdisk list ${devname}|grep "^flags"|grep "thin"`
			    if [ ! -z $devflags ]; then
			        devtype="thin"
			    else
			        devtype="thick"
			    fi
			    devsize=`grep -w $devname ${dg}_vxprint.txt|grep "^dm"|awk '{print $5}'`
			    mdevsize=$(printf "%s\n" "$devsize*512/1024/1024"|bc)
                    	    echo "$host,$lun,$dg,$volname,${gsize}MB,$plexname,$devname,$dmname,$devtype,${mdevsize}MB" |tee -a /var/tmp/${host}-ldvslist.txt
			done
		    done
                done
            fi
        done
    done
