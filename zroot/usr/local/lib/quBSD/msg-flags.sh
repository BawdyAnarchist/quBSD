#!/bin/sh

get_msg_qb_flags() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _if_err is optional, and can be used to exit and/or show usage

	local _message
	local _if_err
	_message="$1"
	_if_err="$2"

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

	case $_if_err in 
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

