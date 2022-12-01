#!/bin/sh

get_msg_qb_() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _if_err is optional, and can be used to exit and/or show usage

	local _message
	local _if_err
	_message="$1"
	_if_err="$2"

	case "$_message" in
	_1) cat << ENDOFMSG


ENDOFMSG
	;;	
	_2) cat << ENDOFMSG


ENDOFMSG
	;;	
	_3) cat << ENDOFMSG


ENDOFMSG
	;;
	_4) cat << ENDOFMSG


ENDOFMSG
	;;
	_5) cat << ENDOFMSG


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

qb-

Usage: qb-
   -h: outputs this usage message

ENDOFUSAGE
}

