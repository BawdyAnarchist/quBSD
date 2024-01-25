#!/bin/sh

msg_connect() { 
	while getopts eEm:u _opts ; do case $_opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		u) local _usage="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

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

ERROR: < $GATEWAY > isn't running.

ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ERROR: < $JAIL > or < $GATEWAY > or both, have securelevel=3,
       and pf applied. It will be impossible to modify pf to 
       to pass packets between the jails, without modifying
       and restarting the jail(s). Moreover, such an elevated
       setting, indicates this is a security critical jail,
       and probably shoudn't participate in adhoc connections 
       such as this. If you still wish to prevent this error, 
       modify seclvl in qubsdmap.conf and restart the jail(s).
ENDOFMSG
	;;
	_5) cat << ENDOFMSG

INTERFACES FOR < $JAIL >
$_jail_intfs

< $JAIL > IS CONNECTED TO THESE JAILS: 
ENDOFMSG
	;;
	_6) cat << ENDOFMSG
$_gateway_pairs

ENDOFMSG
	;;
	_7) cat << ENDOFMSG

INTERFACES FOR ALL RUNNING JAILS:
$_ALL_INTF

ENDOFMSG
	;;
	esac

	[ $_usage ] && usage
	eval $_exit :
}

usage() { cat << ENDOFUSAGE
qb-connect: Create adhoc network connection between two jails.

Usage: qb-connect [-i <IP>] [-c|-d] <client-jail> <gateway-jail>
       qb-connect [-l] <target-jail>

   -c: (c)create new connection between <client> and <gateway>.
       IP=auto unless [-i]. Default route set only for client. 
   -d: (d)estroy all epairs for < target >. If < gateway > jail 
       is specified, only epairs common to both are destroyed. 
   -h: (h)elp. Outputs this help message
   -i: (i)p. Manual IP, CIDR. Only for jail-to-jail connection
   -l: (l)ist epairs/IPs of <jail> if specified; otherwise, all. 

ENDOFUSAGE
}

