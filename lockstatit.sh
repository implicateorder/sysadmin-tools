#!/bin/ksh

DATE=$(date '+%y%d%m%H%M')
/usr/sbin/lockstat -CcwP -n 100000 -x aggrate=10hz -D 20 -s 40 sleep 2 > lockstat-C.out.${DATE}
/usr/sbin/lockstat -kgIW -i 977 -D 20 sleep 2 > lockstat-kgiW.out.${DATE}
