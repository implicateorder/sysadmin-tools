#!/usr/bin/ksh

ostype=$(uname -s);
osver=$(uname -v|awk -F\. '{print $1}');

if [ $ostype = "SunOS" ]; then
     if [ $osver -ge 11 ]; then
	     # Set up the super role
	     /usr/sbin/roleadd -s /usr/bin/pfbash -K profiles="System Administrator" -d /export/home/super super
	     /usr/bin/passwd -r files super
	     # set up the ocgmr user id
	     /usr/sbin/useradd -g 14 -d /export/home/ocmgr -s /usr/bin/pfbash -R+super -m ocmgr
	     /usr/bin/passwd -r files ocmgr
     fi
else
     echo "$ostype is unknown ostype..." && exit 1;
fi
