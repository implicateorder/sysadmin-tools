#!/bin/ksh
#set -xv
# Author: Gopinath Rao
#         Developer Technical Support
#         Sun Microsystems Inc

#
# Description:
#    adv_analysis() called when the advanced analysis option is chosen 
#    on startup
# Function performs advanced crash dump analysis
# It calls basic_analysis() to do a basic analysis first

adv_analysis()
{

  basic_analysis

mdb -k $g <<EOA

=nn"** /etc/system entries **"
="-------------------------"
::system

=nn"** IPC identifiers **"
="----------------------"
::ipcs -l

=nn"** Callout table **"
="----------------------"
::callout

=nn"** Modinfo output **"
="----------------------"
::modinfo

=nn"** Prtconf output **"
="----------------------"
::prtconf -v

=nn"** Filesystem output **"
="----------------------"
::fsinfo

=nn"** Kmastat output **"
="----------------------"
::kmastat
EOA

}

#
# Description:
#   special_cases() called when advanced analysis option is chosen
# Function checks
#  a) Whether it was a forced crash dump and if so runs the "threadlist"
#     macro and the output is written to the file "threadlist.txt" 
#  b) Whether the kmem_flags is set to greater than 0xf, and runs the
#     "findleaks" macro. Its output is written to the file 
#     "memleaks.txt".
 
special_cases()
{

  kmem_flags=`echo "kmem_flags/D"| mdb -k unix.$g vmcore.$g| cut -f2 -d":"`
  if [ $kmem_flags -ge 15 ]
  then
  echo -n "Do you want to run the findleaks macro(y/n)(default:n)?"
  read s
  if [ "$s" != "n" ]
  then
  echo "Running findleaks Macro"
mdb -k $g <<EOA 1>memleaks.txt
=nn"Findleaks output"
="-----------------"
::findleaks
EOA
  fi
  fi
 
  panicstring=`echo "*panicstr/s" | mdb -k unix.$g vmcore.$g | cut -f2 -d":"`
  if [ "$panicstring" = "zero" ] 
  then
mdb -k $g <<EOA 1>threadlist.txt
=nn"Threadlist output"
="------------------"
\$<threadlist
EOA
  fi

  adv_analysis > outfile.`date |cut -f4 -d" "`

}

#
# Description:
#    basic_analysis() called when the advanced analysis option is chosen 
#    on startup
# Function performs basic crash dump analysis

basic_analysis()
{

  echo "Working....."

cat <<EOC

  ******************************************************************************
  System Crash Dump Analysis Output                     MDeBug Rev 1.0
  `date`                   Files: unix.$g vmcore.$g
  ******************************************************************************

EOC

mdb -k $g <<EOA

  =nn"Time of Boot"
  ="---------------"
  ::eval *boot_time=y
  =nn"Time of Crash"
  ="---------------"
  ::eval *time=y

  =nn"System Information"
  ="--------------------"
  \$<utsname
  =nn"Panic String"
  ="--------------"
  *panicstr/s

  =nn"Stack Backtrace"
  ="-----------------"
  \$c

  =nn"**  Per CPU information  **"
  ="---------------------------"
  ncpus/X
  ncpus_online/X
  =nn

  =nn"** Cpuinfo output **"
  ="------------------ -"
  ::cpuinfo -v
  =nn
  =nn"**  CPU structures  **"
  ="--------------------"
  \$<cpus
  =nn
  =nn"**  Process table  **"
  ="--------------------"
  ::ps -f
  =nn
  ="**  Msgbuf  **"
  ="------------"
  \$<msgbuf
EOA

}

#
# Description:
#    appcore_analysis() called when the application core analysis option is 
#    chosen on startup and the operating system version is Solaris 8 OE or
#    version.
# Function performs basic application core dump analysis

appcore_analysis()
{

cat <<EOC

  ******************************************************************************
  Application core Dump Analysis Output                     MDeBug Rev 1.0
  `date`                   Files: $bin  $cor
  ******************************************************************************

EOC

mdb $bin $cor <<EOA

  =nn"** Core file status **"
  ="------------------------"
  ::status

  =nn"** Thread stack(\$c) **"
  ="----------------------"
  \$c

  =nn"** Shared objects **"
  ="----------------------"
  ::objects

EOA

}

### Main body of the script

# set up the PATH to the commands used inside this script
# /usr/ucb set to get the echo behaviour without carriage return

PATH=/usr/ucb:/usr/bin:$PATH
export PATH

echo "Start of the script"
tput clear

echo "               Welcome to the MDeBug Session                "
echo "               ******************************               "
echo "                                                            "
echo "Select one of the following:"

echo "         1. Run MDeBug against a Kernel Crash dump"
echo "         2. Run MDeBug against an Application core"
echo "         3. Exit                                  "
echo -n "Enter your selection:"


  read sel

case $sel in
1)
  if [ `uname -r | cut -f2 -d"."` -lt 8 ]
  then
  echo "OS release needs to be atleast Solaris 5.8 to use this option, Aborting !"
  exit
  fi

  echo -n "Do you want basic or advanced crash dump analysis[b/a](default:b)?"
  read n

  echo -n "Please enter the suffix digit for your crash dump file:"
  read g

  if [ "$g" = "" ]
  then
  echo "You did not specify the crash dump file suffix, Aborting!"
  exit
  fi

  if [ "$n" = "b" ] || [ "$n" = "" ]
  then
  basic_analysis > outfile.`date |cut -f4 -d" "`
  echo ""
  echo "Done!"
  elif [ "$n" = "a" ]
  then
  special_cases
  echo ""
  echo "Done!"
  fi
;;

2)
  echo -n "Enter the binary name which generated the core:"
  read bin
  echo -n "Enter the core file name:"
  read cor
   
  if [ `uname -r | cut -f2 -d"."` -lt 9 ]
  then
  echo "OS release needs to be Solaris 5.9 to use this option, Aborting !"
  exit
  fi

  appcore_analysis > outfile.appcore

  thr_model=`echo "::status" | mdb $bin $cor | grep thread | cut -f2 -d":"`
  if [ "$thr_model" = " multi-threaded" ]
  then
mdb $bin $cor  <<EOA 1>>outfile.appcore
=nn"Thread stack for MT app"
="------------------------"
  ::walk thread | ::findstack
EOA
  fi
  echo "Done!"
;;

3)
  echo "Bye !"
  exit;;

*)
  echo "Invalid selection - Aborting !"
;;

esac
# End of the script -- 02/21/2002 --grao
