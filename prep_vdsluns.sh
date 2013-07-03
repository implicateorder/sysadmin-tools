#!/bin/ksh
id=$1
lunfile=$2
VDS=$3

for lun in `cat $lunfile`
do
    lunid=`/import/admin/unix/ldom/bin/getluninfo.pl --lun=${lun} --getlunid`
    frameid=`/import/admin/unix/ldom/bin/getluninfo.pl --lun=${lun} --getframe`
    typeset -Z2 id
    echo "ldm add-vdsdev /dev/dsk/${lun}s2 vdisk${id}_${frameid}_${lunid}@${VDS}"
    id=$((id + 1))
done

