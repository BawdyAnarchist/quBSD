#!/bin/sh

get_msg_() { 
	while getopts eEm:u opts ; do case $opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		u) local _usage="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

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
	esac

	[ $_usage ] && usage
	eval $_exit :
}

usage() { cat << ENDOFUSAGE

qb-

Usage: qb-
   -h: (h)elp. Outputs this help message.

ENDOFUSAGE
}

