#!/bin/sh

get_msg_flags() { 

	local _message="$1"
	local _pass_cmd="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Must specify an action: [-d][-u][-r] 
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Actions are mutually exclusive. Chose only one. 
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: Must specify a target jail
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

qb-flags: Toggles schg/noschg for the indicated jail

Usage: qb-flags [-h|-d|-u|-r] <jail>
   -d: (d)own. Recursive noschg flags for <jail>
   -h: (h)elp. Outputs this help message
   -r: (r)eapply jailmap settings for <jail> 
   -u: (u)p. Recursive schg flags for <jail> 

ENDOFUSAGE
}

