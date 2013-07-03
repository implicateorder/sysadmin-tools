#!/usr/bin/ksh

OS=`uname -s`

if [ $OS = "SunOS" ]; then

    sudo vxdmpadm -v getdmpnode|egrep -v "Disk|ENCLR-NAME"|awk '{print $7}'|sort -u > /var/tmp/vxdmp_enclosures.txt

    while true
    do
        for i in `cat /var/tmp/vxdmp_enclosures.txt`
        do
            sudo vxdmpadm -v getdmpnode enclosure=$i
        done
        sleep 5
    done
else
    print "No Veritas DMP on $OS \n"
fi
