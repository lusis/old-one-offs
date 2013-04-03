#!/bin/bash
# NT Process Count detector plugin for Nagios
# Written by John E. Vincent (nagios-plugs@lusis.org)
# Last Modified: 06-23-2006
#
# Description:
#
# This plugin will use the modified version of check_nt to
# count the instances of a specific process running on a
# Windows server.
#
# This plugin relied on two specific pieces to work properly
# if at all:
# NC_Net (http://http://www.shatterit.com/nc_net/) on the client
# and
# check_nt (http://www.shatterit.com/nc_net/files/check_nt.c)
#
# Both of these are fully compatible replacements for NSClient
# and the default check_nt shipped with nagios plugins
#
# If you wish to keep the original check_nt and compile the 
# ShatterIT version as a different plugin,
# we give the option of defining where to find that plugin.

CHECK_NT_NCNET="/nagios/third-party-plugins/new/check_nt_ncnet"

# Don't change anything below here
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4


PROGNAME=`basename $0`

print_usage() {
	echo "Usage: $PROGNAME -H <hostname> -p <nc_net port> -s <nc_net passkey> -n <process name> -c <count>"
	echo ""
	echo "Notes:"
	echo "-H: Can be a hostname or IP address"
	echo "-n: Process name is case-sensitive"
	echo "-c: The number of times to match the process name specified in -n"
	echo ""
}

print_help() {
	print_usage
	echo ""
	echo "This plugin uses ENUMPROCESS from the version of check_nt from NC_Net to count the number of processes running that match a given string. This is useful for monitoring if the proper number of instances of processes on a Windows Server are running"
	echo ""
	exit 0
}

if [ $# -lt 1 ]; then
	print_usage
	exit $STATE_UNKNOWN
fi

exitstatus=$STATE_WARNING #default

while test -n "$1"; do
	case "$1" in
		--help)
			print_help
			exit $STATE_OK
			;;
		-h)
			print_help
			exit $STATE_OK
			;;
		-H)
			hostname=$2
			shift
			;;
		-p)
			portnumber=$2
			shift
			;;
		-s)
			passkey=$2
			shift
			;;
		-n)	
			procname=$2
			shift
			;;
		-c)	
			proccount=$2
			shift
			;;
	esac
	shift
done

RESULTS=`$CHECK_NT_NCNET -H $hostname -p $portnumber -s $passkey -t 10 -v ENUMPROCESS | grep -o "$procname" | wc -w`

if [ $RESULTS -lt $proccount ]
then
	echo "CRITICAL: Only $RESULTS instances of $procname found. $RESULTS is less than $proccount"
	exitstatus=$STATE_CRITICAL
elif [ $RESULTS -gt $proccount ] 
then
	echo "WARNING: $RESULTS instances of $procname found. $RESULTS is greater than $procname"
	exitstatus=$STATE_WARNING
else
	echo "OK: $RESULTS instances of $procname found."
	exitstatus=$STATE_OK
fi

exit $exitstatus
