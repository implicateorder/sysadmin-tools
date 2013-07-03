#!/bin/ksh

# Abandon hope, all ye who enter here.

PATH=${PATH}:/sbin:/usr/sbin:/bin:/usr/bin

UNAME_S=`uname -s 2>/dev/null`
UNAME_I=`uname -i 2>/dev/null`
UNAME_R=`uname -r 2>/dev/null`
UNAME_V=`uname -v 2>/dev/null`
UNAME_M=`uname -m 2>/dev/null`

case ${UNAME_S} in

SunOS)

	case ${UNAME_I} in

	SUNW,Sun-Fire)	
		PRTDIAGSC=`/usr/platform/sun4u/sbin/prtdiag | egrep "^System Configuration"`
		case ${PRTDIAGSC} in
			*6800)
				UNAME_I="SUNW,Sun-Fire-6800"
			;;
			*4800)	
				UNAME_I="SUNW,Sun-Fire-4800"
			;;
		esac
		;;

	SUNW,Sun-Fire-15000)
		PRTDIAGSC=`/usr/platform/sun4u/sbin/prtdiag | egrep "^System Configuration"`
		case ${PRTDIAGSC} in
			*E25K)
				UNAME_I="SUNW,Sun-Fire-E25K"
			;;
		esac
		;;

	SUNW,Netra-T12)
		UNAME_I="SUNW,Sun-Fire-V1280"
		;;

	SUNW,SPARC-Enterprise)
		BOXNAME=`/usr/platform/${UNAME_M}/sbin/prtdiag | egrep "^System Configuration" | awk '{print $(NF-1)}'`
		UNAME_I="SUNW,SPARC-Enterprise-${BOXNAME}"
		;;

	sun4v)

		OSMINVER=$(echo ${UNAME_R}|awk -F\. '{print $2}')
		if [ $OSMINVER -ge 10 ]; then
		      if [ -x /usr/sbin/virtinfo ]; then
			SERIALNO=$(/usr/sbin/virtinfo -s|awk -F\: '{print $2}'|/usr/bin/sed -e"s/ //g")
			DOMAINTYPE=$(/usr/sbin/virtinfo -t|awk -F\: '{print $2}'|/usr/bin/sed -e"s/ //g")
			if [ $DOMAINTYPE = "LDomsguest" ]; then
			     SYSTEM_LOCATION=$(/usr/sbin/virtinfo -c|awk -F\: '{print $2}'|/usr/bin/sed -e"s/ //g")
			fi
		      fi
		fi
		if [ -x /usr/sbin/prtdiag ]; then
		     BOXNAME=`/usr/sbin/prtdiag | egrep "^System Configuration" | awk '{print $(NF)}'`
		     UNAME_I="SUNW,SPARC-Enterprise-${BOXNAME}"
		else
		      BOXNAME=`/usr/platform/${UNAME_M}/sbin/prtdiag | egrep "^System Configuration" | awk '{print $(NF)}'`
		      UNAME_I="SUNW,SPARC-Enterprise-${BOXNAME}"
		fi
		;;
	esac

			

	HOSTID=`hostid`

	# `iostat -En` outputs like this:
	#
	# c1t1d0          Soft Errors: 0 Hard Errors: 0 Transport Errors: 0
	# Vendor: HITACHI  Product: DK32EJ72FSUN72G  Revision: 2Q09 Serial No: 0311W0VYX3
	# Size: 73.40GB <73400057856 bytes>
	# Media Error: 0 Device Not Ready: 0 No Device: 0 Recoverable: 0
	# Illegal Request: 0 Predictive Failure Analysis: 0
	#

	# Assume non-EMC are internal disks.  See where that gets us.

	iostat -En | awk '$1 ~ /^c[0-9]+t.*d[0-9]+/ { 
		DISK = $1;
		getline;
		VENDOR = $2;
		PRODUCT = $4;
   	 	getline;
		SIZE = substr( $2, 1, length($2)-2 );
		if ( ( SIZE != "18446744073.71" ) \
		&& ( SIZE != "0.00" ) \
		&& ( VENDOR != "EMC" ) \
		&& ( VENDOR != "DGC" ) ) { 
			printf( "%dGB\n", SIZE );
		} 
	}' > /var/tmp/inventory_intdisks.$$

	INTDISKSNUM=`cat /var/tmp/inventory_intdisks.$$ | wc -l | sed 's/^ *//'`
	INTDISKSSZS=`cat /var/tmp/inventory_intdisks.$$ | perl -e '
		while( <STDIN> ) {
			chomp;
			$disks{$_}++
		};
		foreach $disk ( keys( %disks ) ) {
			push( @diskslist, $disks{$disk} . "@" . $disk )
		};
		print( sort( join( ",", @diskslist ) ) );
		'`

	rm /var/tmp/inventory_intdisks.$$

	case ${UNAME_R} in

		5.8)
			# Solaris 8 doesn't run on any multicore machines...
			CPUSSOCKETS=`psrinfo | wc -l | sed 's/^ *//'`
			CPUSTHREADS=${CPUSSOCKETS}
			CPUSCORES=${CPUSSOCKETS}
			;;
		5.9)
			# Solaris 9 doesn't run on any multithread machines...
			CPUSSOCKETS=`psrinfo -p`
			CPUSCORES=`kstat -p cpu_info | awk '$0 ~ /chip_id/ { print $2 }' | wc -l | sed 's/^ *//'`
			CPUSTHREADS=${CPUSCORES}
			;;
		*) 
			CPUSSOCKETS=`psrinfo -p`
        	CPUSTHREADS=`kstat -p cpu_info | awk '$0 ~ /core_id/ { print $2 }' | wc -l | sed 's/^ *//'`
			CPUSCORES=`kstat -p cpu_info | awk '$0 ~ /core_id/ { print $2 }' | sort | uniq | wc -l | sed 's/^ *//'`
			;;
	esac

	CPUSPDZ=`kstat -p cpu_info | awk '$0 ~ /clock_MHz/ { print $2 }' | perl -e '
                while( <STDIN> ) {
                        chomp;
                        $cpus{$_}++
                };
                foreach $cpu ( keys( %cpus ) ) {
                        push( @cpuslist, $cpus{$cpu} . "@" . $cpu . "MHz" )
                };
                print( sort( join( ",", @cpuslist ) ) );
                '`

	MEMSIZE=`prtconf 2>/dev/null | grep -i "Memory size" | awk '{printf( "%.1d\n", ( $3 ) ) }'`

	/opt/vpms2/lib/sunOS_5x/kstat_netstat | awk '{print $2 / 1000000}' > /var/tmp/inventory_netspeeds.$$
	
        NETSNUM=`cat /var/tmp/inventory_netspeeds.$$ | wc -l | sed 's/^ *//'`
        NETSPDZ=`cat /var/tmp/inventory_netspeeds.$$ | perl -e '
                while( <STDIN> ) {
                        chomp;
                        $netspeeds{$_}++
                };
                foreach $netspeed ( keys( %netspeeds ) ) {
                        push( @netspeedslist, $netspeeds{$netspeed} . "@" . $netspeed . "Mbit" )
                };
                print( sort( join( ",", @netspeedslist ) ) );
                '`

        rm /var/tmp/inventory_netspeeds.$$

	HBASNUM=`sudo luxadm -e port 2>/dev/null | awk '$2 == "CONNECTED" {print $0}' | wc -l | sed 's/^ *//'`

        case ${UNAME_I} in

		SUNW,Sun-Fire-280R) 	HBASNUM=$((HBASNUM - 1)) ;;
		SUNW,Sun-Fire-480R)	HBASNUM=$((HBASNUM - 1)) ;;
		SUNW,Sun-Fire-V490)	HBASNUM=$((HBASNUM - 1)) ;;
		SUNW,Sun-Fire-880)	HBASNUM=$((HBASNUM - 1)) ;;
		SUNW,Sun-Blade-1000)	HBASNUM=$((HBASNUM - 1)) ;;
	esac



	;;

Linux)

	if grep cciss/ /proc/partitions > /dev/null 2>&1
	then
		
		# cciss is used, so all cciss and only cciss are internal disks
		
		awk '$4 ~ /cciss\/c[0-9]d[0-9]$/ { 
			SIZE = $3 / ( 1024 * 1024 );
			printf( "%iGB\n", SIZE );
		 }' /proc/partitions > /var/tmp/inventory_intdisks.$$

	elif grep ida/ /proc/partitions > /dev/null 2>&1
	then

              	# ida (precursor to cciss) is used, so all cciss and only cciss are internal disks

                awk '$4 ~ /ida\/c[0-9]d[0-9]$/ {
                        SIZE = $3 / ( 1024 * 1024 );
                        printf( "%iGB\n", SIZE );
                 }' /proc/partitions > /var/tmp/inventory_intdisks.$$

	else

		# no cciss, so look in dmesg for sd[0-9] 

		dmesg | awk '$1 == "Vendor:" {
			VENDOR = $2
			getline;
			getline;
			if ( ( VENDOR != "ENC" ) \
			&& ( VENDOR != "DGC" ) \
			&& ( $0 ~ /^SCSI device/ ) ) {
				SIZE = substr( $8, 2);
				SIZE = SIZE / 1024;
				printf( "%iGB\n", SIZE );
			}
		}' > /var/tmp/inventory_intdisks.$$

	fi

        INTDISKSNUM=`cat /var/tmp/inventory_intdisks.$$ | wc -l | sed 's/^ *//'`
        INTDISKSSZS=`cat /var/tmp/inventory_intdisks.$$ | perl -e '
                while( <STDIN> ) {
                        chomp;
                        $disks{$_}++
                };
                foreach $disk ( keys( %disks ) ) {
                        push( @diskslist, $disks{$disk} . "@" . $disk )
                };
                print( sort( join( ",", @diskslist ) ) );
                '`

        rm /var/tmp/inventory_intdisks.$$

		CPUSSOCKETS=`cat /proc/cpuinfo | egrep "^physical id" | sort | uniq | wc -l | sed 's/^ *//'`
		CPUSCORES=`cat /proc/cpuinfo | egrep "^(physical id|core id)" | awk '{printf $0; getline; print $0}' | sort | uniq | wc -l | sed 's/^ *//'`
		CPUSTHREADS=`cat /proc/cpuinfo | egrep "^processor" | wc -l | sed 's/^ *//'`

        CPUSPDZ=`cat /proc/cpuinfo | egrep -i 'cpu MHz' | awk -F": " '{printf( "%i\n", $2 )}' | perl -e '
                while( <STDIN> ) {
                        chomp;
                        $cpus{$_}++
                };
                foreach $cpu ( keys( %cpus ) ) {
                        push( @cpuslist, $cpus{$cpu} . "@" . $cpu . "MHz" )
                };
                print( sort( join( ",", @cpuslist ) ) );
                '`

	MEMSIZE=`awk '$1 == "MemTotal:" { printf( "%.1d\n", $2 / ( 1024 ) ) }' /proc/meminfo`

	ifconfig | awk ' $1 ~ /^eth[0-9]+$/ { print $1 }' | xargs -i sudo ethtool {} | awk '
	
	$1 ~ /Speed:/ { 
		if ( $2 != "Unknown!" ) {
			print $2 
		}
	}

	' | sed 's/Mb\/s//' > /var/tmp/inventory_netspeeds.$$

        NETSNUM=`cat /var/tmp/inventory_netspeeds.$$ | wc -l | sed 's/^ *//'`
        NETSPDZ=`cat /var/tmp/inventory_netspeeds.$$ | perl -e '
                while( <STDIN> ) {
                        chomp;
                        $netspeeds{$_}++
                };
                foreach $netspeed ( keys( %netspeeds ) ) {
                        push( @netspeedslist, $netspeeds{$netspeed} . "@" . $netspeed . "Mbit" )
                };
                print( sort( join( ",", @netspeedslist ) ) );
                '`

        rm /var/tmp/inventory_netspeeds.$$

	if [[ -f /usr/sbin/dmidecode ]]
	then
		UNAME_I=`sudo /usr/sbin/dmidecode | awk -F": " '
			$0 ~ "System Information" {
				getline;
				while ( $0 ~ "^\t" ) {
					if ( $0 ~ "Product Name" ) {
						print $2;
					}
					getline;
				}
			} '`

        SERIALNO=`sudo /usr/sbin/dmidecode | awk -F": " '
			$0 ~ "System Information" {
				getline;
				while ( $0 ~ "^\t" ) {
					if ( $0 ~ "Serial Number" ) {
						print $2;
					}
					getline;
				}
			} ' | sed 's/ //g'`

		# This works (probably) for HP c-class blades
		SYSTEM_LOCATION=`sudo /usr/sbin/dmidecode | awk -F: '
			$0 ~ "HP ProLiant System/Rack Locator" {
				getline;	
				while ( $0 ~ "^\t" ) {
					if ( $1 ~ "\tEnclosure Name" ) {
						chassis = $2;
					}
					if ( $1 ~ "\tServer Bay" ) {
						slot = $2;
 					}
					getline;
				}
				print chassis "-" slot;
			} ' | sed 's/ //g'` 


	fi

	;;

esac

	if [[ -x /opt/quest/bin/vastool ]]
   then
      DOMAIN=$(/opt/quest/bin/vastool info domain 2>/dev/null)
   fi
  
echo "${UNAME_I}:${UNAME_S}:${UNAME_R}:${HOSTID}:${CPUSSOCKETS}:${CPUSCORES}:${CPUSTHREADS}:${CPUSPDZ}:${INTDISKSNUM}:${INTDISKSSZS}:${MEMSIZE}:${NETSNUM}:${NETSPDZ}:${HBASNUM}:${SERIALNO}:${SYSTEM_LOCATION}:${DOMAIN}"

