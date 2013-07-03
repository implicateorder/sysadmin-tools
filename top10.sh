#!/bin/ksh

function printUsage {

    echo "Usage: $0 [-t <count> | -h ]
	   -h 	- print this message
	   -t 	- pass count of top consumers of cpu and memory you want to see
	"
}

ostype=$(uname -s)
osver=$(uname -r)

while getopts ht: switch
do
    case $switch in
        t) count=$OPTARG;;
        h|?) printUsage && exit;;
    esac
done
shift $(( $OPTIND - 1 ))

if [ -z $count ]; then
	count=10
fi

if [ $ostype = "Linux" ]; then
    date
    echo "Top $count CPU Hogs"
    /bin/ps auxww|sort -r -k 3|head -$count
    echo "Top $count Memory Hogs"
    /bin/ps auxww|sort -r -k 4|head -$count
fi

if [ $ostype = "SunOS" ]; then
    majver=$(echo $osver | awk -F\. '{print $1}')
    minver=$(echo $osver | awk -F\. '{print $2}')
    if [ $minver -ge 11 ]; then
        date
        echo "Top $count CPU hogs"
        /usr/bin/ps auxww|sort -r -k 3|head -$count
	echo "Top $count Memory Hogs"
	/usr/bin/ps auxww|sort -r -k 4|head -$count
    else
	date
        echo "Top $count CPU hogs"
	/usr/ucb/ps auxww|sort -r -k 3|head -$count
	echo "Top $count Memory Hogs"
	/usr/ucb/ps auxww|sort -r -k 4|head -$count
    fi
fi



