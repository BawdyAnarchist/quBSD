#!/bin/sh

msg_launch() { 
	while getopts eEm:u _opts ; do case $_opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		u) local _usage="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: < $FILE > does not exist.
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: [-t <timeout>] must be integer from 5 to 600. Caution, 
       choose a timeout appropriate for number of starts,
       longer if starting multiple gateways/clients in a row
ENDOFMSG
	;;
	_3) cat << ENDOFMSG

ERROR: qb-start failed to launch all jails before timeout
ENDOFMSG
	;;
	esac

	[ $_usage ] && usage
	eval $_exit :
}

usage() { cat << ENDOFUSAGE

qb-i3-launch: Launch programs as indicated by config file

Usage: qb-i3-launch [-h][-f <conf_file>][-s]  
   -h: (h)elp. Outputs this usage message.
   -f: (f)ile. Run an alternate configuration file. 
       Default file is: < ${HOME}/.config/i3/i3gen.conf >
   -F: (F)orce. Program checks that there isn't already a
       window with the same jail/program in the workspace.
       Default behavior would skip, but you can (F)orce. 
   -s: (s)start jails; but do not launch programs.
   -t: (t)timeout before giving up on waiting for jail
       starts and exiting. Default 30sec. 
   
If no options are given, default conf is fully run.

NOTE: The results can sometimes be finicky, especially if
a particular program takes longer than 6 sec to launch.
After that built-in delay, i3-launch moves to next window. 

ENDOFUSAGE
}

