#!/bin/sh

get_msg_qb_connect() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _if_err is optional, and can be used to exit and/or show usage

	local _message
	local _if_err
	_message="$1"
	_if_err="$2"

	case "$_message" in
	_0) cat << ENDOFMSG

ERROR: Missing option. Must specify an action to perform
ENDOFMSG
	;;	
	_1) cat << ENDOFMSG

ERROR: Mutually exclusive options: [-c|-d|-l]

ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: < $JAIL > isn't running. 

ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: < $TUNNEL > isn't running.

ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ERROR: < $JAIL > or < $TUNNEL > or both, have securelevel=3,
       and pf applied. It will be impossible to modify pf to 
       to pass packets between the jails, without modifying
       and restarting the jail(s). Moreover, such an elevated
       setting, indicates this is a security critical jail,
       and probably shoudn't participate in adhoc connections 
       such as this. If you still wish to prevent this error, 
       modify seclvl in jailmap.conf and restart the jail(s).
ENDOFMSG
	;;
	_5) cat << ENDOFMSG

INTERFACES FOR < $JAIL >
$_jail_intfs

< $JAIL > IS CONNECTED TO THESE JAILS: 
ENDOFMSG
	;;
	_6) cat << ENDOFMSG
$_tunnel_pairs

ENDOFMSG
	;;
	_7) cat << ENDOFMSG

INTERFACES FOR ALL RUNNING JAILS:
$_ALL_INTF

ENDOFMSG
	;;
	esac

	case $_if_err in 
		usage_0) usage ; exit 0 ;;
		usage_1) usage ; exit 1 ;;
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		*) : ;;
	esac
}

usage() { cat << ENDOFUSAGE
qb-connect: Create adhoc network connection between two jails.
            Attempts to auto configure as much as possible. 

Usage: qb-connect [-i <IP>] [-c|-d] <target-jail> <tunnel-jail>
       qb-connect [-l] <target-jail>

   -c: (c)create new connection between <target > and < tunnel >
       IP address is auto-assigned unless [-i] is selected.
   -d: (d)estroy all epairs for < target >. If < tunnel > jail 
       is specified, only epairs common to both are destroyed. 
   -h: (h)elp. Outputs this help message
   -i: (i)p. Override auto IP assignment. Must be valid IPv4 in 
       CIDR notation. Include the subnet:  IP.IP.IP.IP/subnet
   -l: (l)ist all interfaces and IPs for all running jails. If
       <jail> is specified, only those interfaces are listed.

ENDOFUSAGE
}

