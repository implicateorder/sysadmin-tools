#!/bin/bash

# Get the process which listens on port

# $1 is the port we are looking for

if [ $# -lt 1 ]; then
     echo "Please provide a port number parameter for this script"
     echo "e.g. $0 22"
     exit
fi

echo "Greping for your port, please be patient (CTRL+C breaks) ... "

for i in `ls /proc`
do
    pfiles $i | grep AF_INET | grep -w $1 
    if [ $? -eq 0 ]
        then
	pname=$(ps -o args -p $i|grep -v COMMAND)
        echo "$1 is owned by pid $i - $pname \n";
    fi
done
