#!/bin/bash
#
#       Who             When            What
#       Kapilraj(CSI)   02/07/2012      Rename an Oracle 11g database
#
#
#

function set_parms {
    [[ "$debug" = "Yes" ]] && set -x
    export tmpfile01=/var/tmp/tmpfile01$$
    export tmpfile02=/var/tmp/tmpfile02$$
    export tmpfile03=/var/tmp/tmpfile03$$
    export cmdname=$(basename $0)
    export logfile=/var/tmp/logfile.$cmdname.$$
    export thishost=$(uname -n)
    export ORIGINAL_PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/VRTSvcs/bin:/opt/VRTS/bin
    export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/VRTSvcs/bin:/opt/VRTS/bin
    export SOURCE_SID=$1
    export TARGET_SID=$2
    export source_sid=$(echo $SOURCE_SID| tr [A-Z] [a-z])
    export target_sid=$(echo $TARGET_SID| tr [A-Z] [a-z])
    [[ "$(uname)" = "SunOS" ]] && GREP="/usr/xpg4/bin/grep" || GREP="/bin/grep"
    export SQLPLUS="sqlplus -S"
    export SUORACLE="su oracle -c "
    ORATAB="/var/opt/oracle/oratab"
    export ASM_SID=+ASM
    if [ ${#} -lt 2 ]
    then
        print_msg "Syntax Error .. Usage : $cmdname <sid> <new_sid> "
        exit 99
    fi
}

function are_you_root {
    [[ "$debug" = "Yes" ]] && set -x
    id | grep "uid=0" > /dev/null 2>/dev/null
    if [ $? -ne 0 ]
    then
        clean_exit 1 "You have to be root"
    fi
}

function clean_exit {
    [[ "$debug" = "Yes" ]] && set -x
    export rc=$1
    export msg=$2
    print_msg "$msg"
    [[ -f $tmpfile01 ]] && rm $tmpfile01 >/dev/null 2>&1
    [[ -f $tmpfile02 ]] && rm $tmpfile02 >/dev/null 2>&1
    [[ -f $tmpfile03 ]] && rm $tmpfile03 >/dev/null 2>&1
    #[[ -f ${logfile} ]] && rm ${logfile} >/dev/null 2>&1
    exit $rc
}

function print_msg {
    [[ "$debug" = "Yes" ]] && set -x
    echo "$(date +%h:%d:%Y:%H:%M:%S) - $1" >> $logfile
    echo "" >> $logfile
    echo ""
    echo "$(date)  $cmdname :: "$1
    echo ""
}

function send2logger {
    [[ "$debug" = "Yes" ]] && set -x
    LOGGER="logger -p local1.info -t clverify"
    echo "$*" | $LOGGER
}

function proc_rc {
    [[ "$debug" = "Yes" ]] && set -x
    export rc=$1
    shift
    export msg=${*}
    if [ $rc -ne 0 ]
    then
        clean_exit $rc $msg
    fi
}

function set_source_vars {
    [[ "$debug" = "Yes" ]] && set -x
    export ORACLE_SID=$SOURCE_SID
    export ORACLE_HOME=$(grep ^$ORACLE_SID $ORATAB | awk -F: '{print $2}' | head -1)
    export PATH=$ORIGINAL_PATH:$ORACLE_HOME/bin
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib
}

function set_target_vars {
    [[ "$debug" = "Yes" ]] && set -x
    set_source_vars
    export ORACLE_SID=$TARGET_SID
    export ORACLE_HOME=$(echo $ORACLE_HOME | sed "s;$SOURCE_SID;$TARGET_SID;g")
    export PATH=$ORIGINAL_PATH:$ORACLE_HOME/bin
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib
}

function set_asm_vars {
    [[ "$debug" = "Yes" ]] && set -x
    export ORACLE_SID=+ASM
    export ORACLE_HOME=$(grep ^$ORACLE_SID $ORATAB | awk -F: '{print $2}' | head -1)
    export PATH=$ORIGINAL_PATH:$ORACLE_HOME/bin
    export LD_LIBRARY_PATH=$ORACLE_HOME/lib
}

function fn_sarcasm {
    [[ "$debug" = "Yes" ]] && set -x
    print_msg ${*}
}

function cr_pfile_ctrl_file {
    [[ "$debug" = "Yes" ]] && set -x
    rm -f /var/tmp/initSIDora.ora /var/tmp/SIDctl.sql
    if [ ${?} -ne 0 ]
    then
        print_msg "Please remove these files /var/tmp/initSIDora.ora /var/tmp/SIDctl.sql and hit enter to continue ..."
        read
    fi

    sarcasm_count=0
    while [ -f /var/tmp/initSIDora.ora ]
    do
        fn_sarcasm "Didnt you hear what I just said - delete these files /var/tmp/initSIDora.ora /var/tmp/SIDctl.sql and press enter to continue"
        [[ $sarcasm_count -gt 0 ]] && print_msg "I told you $sarcasm_count times ... "
        sarcasm_count=$(echo "$sarcasm_count + 1 " | bc )
        read
    done

    sarcasm_count=0

    while [ -f /var/tmp/SIDctl.sql ]
    do
        fn_sarcasm "Didnt you hear what I just said - delete these files /var/tmp/initSIDora.ora /var/tmp/SIDctl.sql and press enter to continue"
        [[ $sarcasm_count -gt 0 ]] && print_msg "I told you $sarcasm_count times ... "
        sarcasm_count=$(echo "$sarcasm_count + 1 " | bc )
        read
    done

    print_msg "Creating pfile and backup control file from $SOURCE_SID "
    $SUORACLE " $SQLPLUS ' / as sysdba' " <<END
    create pfile='/var/tmp/initSIDora.ora' from spfile ;
    alter database backup controlfile to trace as '/var/tmp/SIDctl.sql' ;
    exit ;
    END
    if [ ! -s /var/tmp/initSIDora.ora ]
    then
        clean_exit 99 "Unable to create init file. Is the databae up ? "
    else
        if [ ! -s /var/tmp/SIDctl.sql ]
        then
            clean_exit 99 "Unable to create backup control file from $ORACLE_SID "
        fi
    fi

    sed "s;$SOURCE_SID;$TARGET_SID;g" /var/tmp/initSIDora.ora > $ORACLE_HOME/dbs/init$TARGET_SID.ora
    chown oracle:dba $ORACLE_HOME/dbs/init$TARGET_SID.ora

    cat /var/tmp/SIDctl.sql \
    | sed -n "/CREATE CONTROLFILE REUSE DATABASE \"$SOURCE_SID\" RESETLOGS/,/End of tempfile additions/p" \
    | sed -n "/Commands to add tempfiles/,/End of tempfile/p" \
    | grep -v ^-- \
    |sed -e "s;$SOURCE_SID;$TARGET_SID;g" -e "s;$source_sid;$target_sid;g" > $ORACLE_HOME/dbs/ctrl$TARGET_SID-temp.sql

    cat /var/tmp/SIDctl.sql\
    | sed -n "/CREATE CONTROLFILE REUSE DATABASE \"$SOURCE_SID\" RESETLOGS/,/^;$/p" \
    | sed "s;REUSE DATABASE \"$SOURCE_SID\";REUSE SET DATABASE \"$TARGET_SID\";g" \
    | sed "s;+$SOURCE_SID;+$TARGET_SID;g" > $ORACLE_HOME/dbs/ctrl$TARGET_SID.sql
}

function shut_src_db {
    [[ "$debug" = "Yes" ]] && set -x
    print_msg "Bringing down the Oracle databse $SOURCE_SID"
    $SUORACLE " $SQLPLUS ' / as sysdba' " <<END
    shutdown immediate ;
    exit ;
    END

    print_msg "Checking if database $SOURCE_SID is completely down "
    ps -ef | grep pmon | grep -v grep | $GREP -q $SOURCE_SID
    if [ $? -eq 0 ]
    then
        clean_exit 1 "Unable to bring down $SOURCE_SID database "
    fi

    print_msg "Database $SOURCE_SID is down "

    $SUORACLE "lsnrctl stop LISTENER_$SOURCE_SID" > /dev/null 2>&1

    sleep 5

    ps -ef | grep tns | grep -v grep | $GREP -q $SOURCE_SID
    if [ $? -eq 0 ]
    then
        print_msg "Unable to bring down LISTENER_$SOURCE_SID please fix and hit enter to continue once done "
        read
    fi
    print_msg "Listener LISTENER_$SOURCE_SID is down "
}

function rename_asm_dgs {
    [[ "$debug" = "Yes" ]] && set -x
    print_msg "Setting environment variables for the ASM instance "
    set_asm_vars
    SOURCE_ASM_DGS=$($SUORACLE "asmcmd lsdg" 2>/dev/null| awk '{print $NF}' |\
    grep -v ^Name | grep $SOURCE_SID | sed "s;/;;g" )
    for ASM_DG in $SOURCE_ASM_DGS
    do
        print_msg "Dismounting ASM diskgroup $ASM_DG ..."
        $SUORACLE "asmcmd umount $ASM_DG"
    done

    ACTIVE_ASM_DGS=$($SUORACLE "asmcmd lsdg" 2>/dev/null| awk '{print $NF}' | grep -v ^Name |\
    grep $SOURCE_SID | sed "s;/;;g" |tr "\n" "")
    if [ "hello"$ACTIVE_ASM_DGS != "hello" ]
    then
        print_msg "Unable to dismount ASM diskgroups for $SOURCE_SID . \
	Please dismount the following ASM diskgroups and hit enter to continue .."
        echo $SOURCE_ASM_DGS
        read
    fi

    print_msg "Dismounted all ASM diskgroups used by $SOURCE_SID "

    TARGET_ASM_DGS=""


    for ASM_DG in $SOURCE_ASM_DGS
    do
        NEW_ASM_DG=$(echo $ASM_DG | sed "s;$SOURCE_SID;$TARGET_SID;g")
        TARGET_ASM_DGS="$TARGET_ASM_DGS $NEW_ASM_DG"
        print_msg "Renaming $ASM_DG to $NEW_ASM_DG ..."
        $SUORACLE "renamedg asm_diskstring='/dev/vx/rdsk/*/*' verbose=false dgname=$ASM_DG newdgname=$NEW_ASM_DG"
    done

    for ASM_DG in $TARGET_ASM_DGS
    do
        print_msg "Mounting ASM diskgroup $ASM_DG ..."
        $SUORACLE "asmcmd mount $ASM_DG"
        if [ ${?} -ne 0 ]
        then
            print_msg "Unable to mount $ASM_DG .... Please fix and hit enter to continue once fixed "
            read
        fi
    done
    $SUORACLE "asmcmd lsdg" | $GREP -q $TARGET_SID
    if [ ${?} -ne 0 ]
    then
        clean_exit 1 "Unable to find mounted ASM diskgroups "
    fi
}

function rename_mount_pnts {
    [[ "$debug" = "Yes" ]] && set -x
    set_source_vars
    export SOURCE_ORACLE_HOME=$ORACLE_HOME
    export TARGET_ORACLE_HOME=$(echo $SOURCE_ORACLE_HOME | sed "s;$SOURCE_SID;$TARGET_SID;g")

    #echo "Now as root Unmount the ${SOURCE_ORACLE_HOME} and mount it as ${TARGET_ORACLE_HOME} on $(uname -n) "
    #echo "If the database is on cooked filesystems please change all filesystem mountpoints to
    #reflect the ORACLE_SID change and hit enter to continue "
    #read
    #echo "Have you mounted ${TARGET_ORACLE_HOME} ? Press enter to continue "
    #read
    #while [ ! -d ${TARGET_ORACLE_HOME}/bin ]
    #do
    #   echo "Please mount ${TARGET_ORACLE_HOME} "
    #   echo "Press enter when done. To break ctrl+c "
    #   read
    #done

    export SOURCE_ORACLE_HOME_FS=$(df -k $SOURCE_ORACLE_HOME | tail -1 | awk '{print $NF}')
    export SOURCE_ORACLE_HOME_DEV=$(mount | grep -w $SOURCE_ORACLE_HOME_FS | awk '{print $3}')
    export TARGET_ORACLE_HOME_FS=$(echo $SOURCE_ORACLE_HOME_FS | sed "s;$SOURCE_SID;$TARGET_SID;g")
    mount | $GREP -q -w $SOURCE_ORACLE_HOME_FS | $GREP -q syspool
    if [ ${?} -eq 0 ]
    then
        FSTYPE=ZFS
    else
        FSTYPE=VXFS
    fi
    case $FSTYPE in
        ZFS)
        zfs set mountpoint=$TARGET_ORACLE_HOME $SOURCE_ORACLE_HOME_DEV
        ;;
        VXFS)
        umount $SOURCE_ORACLE_HOME_FS
        if [ ${?} -ne 0 ]
        then
            print_msg "May be Mount locked by VCS ... Retrying "
            /opt/VRTS/bin/umount -o mntunlock=VCS $SOURCE_ORACLE_HOME_FS
            [[ ${?} -ne 0 ]] &&  clean_exit 1 "Unable to unmount $SOURCE_ORACLE_HOME_FS "
        fi
        mkdir -p $TARGET_ORACLE_HOME_FS
        mount -F vxfs $SOURCE_ORACLE_HOME_DEV $TARGET_ORACLE_HOME_FS
        [[ $? -ne 0 ]] && clean_exit 1 "Unable to mount $TARGET_ORACLE_HOME_FS "
        ;;
    esac
    print_msg "Relinking ORACLE_HOME $SOURCE_ORACLE_HOME "
    set_target_vars
    $SUORACLE "relink all"
}

function rename_database {
    [[ "$debug" = "Yes" ]] && set -x
    print_msg "Setting environment variables for the $TARGET_SID database "

    set_target_vars

    print_msg "Renaming the databae "
    print_msg "Startup no mount the databae "

    $SUORACLE " $SQLPLUS ' / as sysdba' " <<END
    startup pfile=$ORACLE_HOME/dbs/init$TARGET_SID.ora nomount ;
    exit ;
    END

    print_msg "Create control file "
    $SUORACLE "$SQLPLUS ' / as sysdba' " <<END
    @$ORACLE_HOME/dbs/ctrl$TARGET_SID.sql ;
    exit ;
    END

    print_msg "Open database reset logs and create spfile "
    $SUORACLE "$SQLPLUS ' / as sysdba' " <<END
    alter database open resetlogs ;
    create spfile='$ORACLE_HOME/dbs/spfile$TARGET_SID.ora' from pfile ;
    exit ;
    END
}

function rename_tns_listener {
    [[ "$debug" = "Yes" ]] && set -x
    print_msg "Updating tnsnames.ora "
    cp -p $ORACLE_HOME/network/admin/tnsnames.ora $ORACLE_HOME/network/admin/tnsnames.ora.$(date +%m%d%y ).$RANDOM
    cat $ORACLE_HOME/network/admin/tnsnames.ora | sed "s;$SOURCE_SID;$TARGET_SID;g" > $tmpfile01
    cp $tmpfile01 $ORACLE_HOME/network/admin/tnsnames.ora

    print_msg "Updating listener.ora "
    cp -p $ORACLE_HOME/network/admin/listener.ora $ORACLE_HOME/network/admin/listener.ora.$(date +%m%d%y ).$RANDOM
    cat $ORACLE_HOME/network/admin/listener.ora | sed "s;$SOURCE_SID;$TARGET_SID;g" > $tmpfile02
    cp $tmpfile02 $ORACLE_HOME/network/admin/listener.ora

    print_msg "Updating ORATAB "
    cp -p $ORATAB $ORATAB.$(date +%m%d%y ).$RANDOM
    cat $ORATAB | sed "s;$SOURCE_SID;$TARGET_SID;g" > $tmpfile03
    cp $tmpfile03 $ORATAB
}

function open_db {
    [[ "$debug" = "Yes" ]] && set -x
    $SUORACLE "$SQLPLUS ' / as sysdba' " <<END
    alter database open ;
    exit ;
    END
}

function startup_dbmount {
    [[ "$debug" = "Yes" ]] && set -x
    $SUORACLE "$SQLPLUS ' / as sysdba' " <<END
    startup mount ;
    exit ;
    END
}

function open_db_resetlogs {
    [[ "$debug" = "Yes" ]] && set -x
    $SUORACLE "$SQLPLUS ' / as sysdba' " <<END
    alter database open resetlogs ;
    exit ;
    END
}

function change_dbid {
    [[ "$debug" = "Yes" ]] && set -x
    print_msg "Changing the DBID "
    $SUORACLE "$SQLPLUS ' / as sysdba' " <<END
    shutdown immediate ;
    startup mount;
    exit ;
    END
    echo "Y" | $SUORACLE nid target=sys/oracle
    if [ ${?} -ne 0 ]
    then
        print_msg "Unable to change the DBID "
        open_db
    else
        print_msg "Starting the database "
        startup_dbmount
        print_msg "Open database with reset logs this will take a loong time 10 to 15 mins "
        open_db_resetlogs
    fi
}

function cr_temp_tbspcs {
    [[ "$debug" = "Yes" ]] && set -x
    print_msg "Restarting the database "
    $SUORACLE "$SQLPLUS ' / as sysdba' " <<END
    shutdown immediate ;
    startup ;
    exit ;
    END

    print_msg "Creating temp table spaces "
    $SUORACLE "$SQLPLUS ' / as sysdba' " <<END
    @$ORACLE_HOME/dbs/ctrl$TARGET_SID-temp.sql
    exit ;
    END
}

function rename_db {
    [[ "$debug" = "Yes" ]] && set -x
    $GREP -q $SOURCE_SID $ORATAB
    if [ ${?} -ne 0 ]
    then
        clean_exit 99 "Unable to find $SOURCE_SID on $(uname -n) . Check $ORATAB "
    fi

    print_msg "Setting environment variables for $SOURCE_SID "
    set_source_vars
    cr_pfile_ctrl_file
    shut_src_db

    rename_asm_dgs
    rename_mount_pnts
    rename_database
    rename_tns_listener
    change_dbid
    cr_temp_tbspcs

    print_msg "Starting the listener "
    $SUORACLE "lsnrctl start LISTENER_$ORACLE_SID"
}

# Do it now
cd /var/tmp
debug=Yes
verbose=No

[[ "$debug" = "Yes" ]] && set -x

set_parms ${*}
are_you_root
rename_db
clean_exit 0 "All clean "
