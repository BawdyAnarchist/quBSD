#!/bin/sh

get_msg_() { 

	local _message="$1"
	local _pass_cmd="$2"

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

	case $_pass_cmd in 
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
   -h: (h)elp. Outputs this help message.

ENDOFUSAGE
}

