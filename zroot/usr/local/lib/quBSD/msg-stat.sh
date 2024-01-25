#!/bin/sh

msg_stat() { 
	while getopts eEm:u _opts ; do case $_opts in
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
	esac

	[ $_usage ] && usage
	eval $_exit :
}

usage() { cat << ENDOFUSAGE

qb-stat: List status of all jails 

Usage: qb-stat [-c <column>] [-h]

   -c: (c)olumn to sort by
   -h: (h)elp: Outputs this help message

ENDOFUSAGE
}

