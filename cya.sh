#!/usr/bin/ksh

# ---------------------------------------------------------------------------
# $Author$
# $Log$
# $Id$
# NOTE: This script ought to be run everytime a system maintenance activity
# is performed. This will take a snapshot of the system and save critical
# information under /var/tmp/cya which could be used to recover vital system
# functionality in case of a misconfiguration without having to roll back from 
# tape.
# Also, collect critical system information so we can compare system state 
# before and after a major change
# ---------------------------------------------------------------------------

CYA_DIR=/var/tmp/cya
SUDO=/usr/local/bin/sudo
DATE=`date '+%m%d%y'`
if [ ! -d $CYA_DIR ]; then
    mkdir -p $CYA_DIR
fi

function get_suncluster_info {
if [ -x /usr/cluster/bin/scstat ]; then
    /usr/cluster/bin/scstat > $CYA_DIR/scstat.$DATE
    /usr/cluster/bin/scrgadm -pvv > $CYA_DIR/scrgadm-pvv.$DATE
fi
}

function get_vcs_info {

if [ -x /opt/VRTSvcs/bin/hastatus ]; then
    $SUDO /opt/VRTSvcs/bin/hastatus -sum > $CYA_DIR/hastatus-sum.$DATE
    for grp in `$SUDO /opt/VRTSvcs/bin/hastatus -sum|grep "^B"|awk '{print $2}'|sort -u`
    do
	$SUDO /opt/VRTSvcs/bin/hagrp -display $grp >> $CYA_DIR/hagrp-display-${grp}.$DATE
    done
    for res in `$SUDO /opt/VRTSvcs/bin/hares -list|awk '{print $1}'|sort -u`
    do
	$SUDO /opt/VRTSvcs/bin/hares -display $res >> $CYA_DIR/hares-display-${res}.$DATE
    done
fi
}

# Save some vital system related information

df -h > $CYA_DIR/df-h.$DATE
cp -pr /etc/system $CYA_DIR/system.$DATE
cp -pr /etc/vfstab $CYA_DIR/vfstab.$DATE
cp -pr /kernel/drv/scsi-vhci.conf $CYA_DIR/scsi_vhci.$DATE
cp -pr /kernel/drv/sd.conf $CYA_DIR/sd_conf.$DATE
cp -pr /kernel/drv/st.conf $CYA_DIR/st_conf.$DATE
cp -pr /kernel/drv/ssd.conf $CYA_DIR/ssd_conf.$DATE
cp -pr /kernel/drv/jnic.conf $CYA_DIR/jnic_conf.$DATE
cp -pr /kernel/drv/ql*.conf $CYA_DIR
$SUDO cp -pr /etc/system $CYA_DIR/system.$DATE
$SUDO cp -pr /etc/project $CYA_DIR/project.$DATE
$SUDO cp -pr /etc/passwd $CYA_DIR/passwd.$DATE
$SUDO cp -pr /etc/shadow $CYA_DIR/shadow.$DATE
$SUDO /usr/platform/`uname -i`/sbin/prtdiag -v > $CYA_DIR/prtdiag-v.$DATE
$SUDO /usr/sbin/ifconfig -a > $CYA_DIR/ifconfig-a.$DATE
$SUDO /usr/bin/netstat -rn > $CYA_DIR/netstat-rn.$DATE
$SUDO /usr/sbin/cfgadm -al > $CYA_DIR/cfgadm-al.$DATE
$SUDO /usr/sbin/modinfo > $CYA_DIR/modinfo.$DATE
$SUDO /usr/sbin/kstat > $CYA_DIR/kstat.$DATE
#
# VxVM stuff
#
$SUDO /usr/sbin/vxdisk -eo alldgs list > $CYA_DIR/vxdisk-eo-alldgslist.$DATE
$SUDO /usr/sbin/vxprint -hrt > $CYA_DIR/vxprint-hrt.$DATE
$SUDO /usr/bin/iostat -nE > $CYA_DIR/iostat-nE.$DATE

# Collect multipathing information

/usr/sbin/modinfo|/usr/xpg4/bin/grep -q dmp && \
$SUDO /usr/sbin/vxmdpadm listenclosure >> $CYA_DIR/vxdmpadm-listenclosure.$DATE && \
$SUDO /usr/sbin/vxdmpadm getctlr >> $CYA_DIR/vxdmpadm-getctlr.$DATE && \
$SUDO /usr/sbin/vxdmpadm getsubpaths all >> $CYA_DIR/vxdmpadm-getsubpaths-all.$DATE

# Check for MPxIO multipathing as well

$SUDO /usr/sbin/mpathadm list lu >> $CYA_DIR/mpathadm-list-lu.$DATE

# Check for powerpath

if [ -x /etc/powermt ]; then
     $SUDO /etc/powermt display dev=all >> $CYA_DIR/powermt-display-all.$DATE
fi
# 

# Check if had/hashadow processes are running and if so, collect VCS data

/usr/bin/pgrep had && get_vcs_info;

# Don't run sun cluster gather here @ OMX (yet)
