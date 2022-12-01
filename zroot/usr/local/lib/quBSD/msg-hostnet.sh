#!/bin/sh

get_msg_qb_hostnet() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _if_err is optional, and can be used to exit and/or show usage

	local _message
	local _if_err
	_message="$1"
	_if_err="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Options are mutually exclusive. Chose one. 
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Must specify an action [-d|-u]
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: Tunnel < $JAIL > failed to start. 
       For more info, see: /var/log/quBSD.log
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

qb-hostnet: Connect host to outside internet.

Usage: hostnet [-h] [-d|-u]
   -h: (h)elp. Outputs this help message
   -d: (d)own. Remove connectivity; set pf to block all 
   -u: (u)p. Brings up connectivity as specified in JMAP

   When host is up, qb-stat (if running) prints a large 
   flashing warning message in red letters at the bottom

ENDOFUSAGE
}

