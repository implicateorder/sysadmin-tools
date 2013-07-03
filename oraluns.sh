#!/usr/bin/ksh

for i in `cat /var/tmp/safe/$1`;do
j=${i}s6
rdev=/dev/rdsk/$j
cdev=/dev/dsk/$j
device=`ls -l $rdev |awk '{print $11}' |sed -e "s!\.\.\/\.\.!!g"`
device2=`ls -l $cdev |awk '{print $11}' |sed -e "s!\.\.\/\.\.!!g"`
echo "chown oracle:dba $device"
sleep 1
chown oracle:dba $device
echo "chown oracle:dba $device2"
sleep 1
chown oracle:dba $device2
echo "chown -h oracle:dba $rdev"
sleep 1
chown -h oracle:dba $rdev
echo "chown -h oracle:dba $cdev"
sleep 1
chown -h oracle:dba $cdev
done
