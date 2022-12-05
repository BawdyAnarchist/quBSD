#!/bin/sh

get_msg_off() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _pass_cmd is optional, and can be used to exit and/or show usage

	local _message
	local _pass_cmd
	_message="$1"
	_pass_cmd="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Must specify an action to perform. 
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Mutually exclusive options [-a|-e] 
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: < $_jail > failed to start. 
       For more info, see: /var/log/quBSD.log
ENDOFMSG
	;;
	esac

	case $_pass_cmd in 
		usage_0) usage ; exit 0 ;;
		usage_1) usage ; exit 1 ;;
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		*) : ;;
	esac
}

usage() { cat << ENDOFUSAGE

qb-off: Shut down multiple jails at once

Usage: qb-off <jail_name>
Usage: qb-off [-h] [-a|-e] <jail_name> <jail_name> ... <jail_name>
   -a: (a)ll. Shutdown all jails
   -e: (e)xcept. Shutdown all jails except for those listed
   -h: (h)elp. Outputs this help message
   -r: (r)estart. Removes and restarts the listed jails

ENDOFUSAGE
}

