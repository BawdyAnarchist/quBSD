#!/bin/sh

get_msg_qb_ivpn() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _action is optional, and can be used to exit and/or show usage

	local _message
	local _action
	_message="$1"
	_action="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Unable to start jail. Cannot modify IVPN. 
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Script is running inside jail, but kern.securelevel is 
       elevated, and schg is applied to one or more files that
       need to be modified in order to switch VPN servers. 
       Re-run this script from host, in order to modify iVPN.
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: Failed to start $JAIL. Exiting
ENDOFMSG
	;;
	_4) cat << ENDOFMSG

Downloading latest server data from api.ivpn.net , wait a moment.
ENDOFMSG
	;;
	_5) cat << ENDOFMSG

WARNING: Failed to download fresh server stats.
ENDOFMSG
	;;
	_6) cat << ENDOFMSG

Currently connected to the following IVPN server:
ENDOFMSG
	;;
	_7) cat << ENDOFMSG

Will use existing json files for modifying wg0.conf.
ENDOFMSG
	;;
	_8) cat << ENDOFMSG
WARNING: Security level of jail is 3, unable to
         chage pf settings. Restart for new server to take effect.

WARNING: Can't modify wg0.conf due to schg flags
         Recommend running qb-ivpn from host instead
ENDOFMSG
	;;
	_9) cat << ENDOFMSG

WARNING: Can't modify pf.conf due to schg flags
         Recommend running qb-ivpn from host instead
ENDOFMSG
	;;

	esac

	case $_action in 
		usage_0) usage ; exit 0 ;;
		usage_1) usage ; exit 1 ;;
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		*) : ;;
	esac
}

usage(){ cat << ENDOFUSAGE

qb-ivpn: Mange vpn connection for IVPN, specifically.
         Fetches server data and provides guided selection
         for VPN server. Attempts to manage permissions.

Usage: qb-ivpn
Usage: qb-ivpn [-h] [-l] <net-jail>

-h: (h)elp. Shows this message
-j: (j)ail. Use this option if running from inside jail
-l: (l)ist. IVPN server/stats, and exit

ENDOFUSAGE
}


