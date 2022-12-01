#!/bin/sh

get_msg_qb_floatcmd() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _if_err is optional, and can be used to exit and/or show usage

	local _message
	local _if_err
	_message="$1"
	_if_err="$2"

	case "$_message" in
	_1) cat << ENDOFMSG
#[[Unused msg. Keeping for consistency/standardization]]
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

qb-floatcmd: Causes a popup window which receives a user command
             and then executes inside of the the selected jail.

Usage: qb-float-cmd [-h ] [-r] [-x] <jail>
   -h: shows this usage message
   -r: run command in jail as root
   -x: DO NOT USE!! special option internal to script. 

ENDOFUSAGE
}

