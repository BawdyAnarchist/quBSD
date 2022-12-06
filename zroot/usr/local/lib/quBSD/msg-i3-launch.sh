#!/bin/sh

get_msg_i3_launch() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _pass_cmd is optional, and can be used to exit and/or show usage

	local _message
	local _pass_cmd
	_message="$1"
	_pass_cmd="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: < $FILE > does not exist.
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

qb-i3-launch: Launch programs as indicated by config file

Usage: qb-i3-launch [-h][-f <conf_file>][-s]  
   -h: (h)elp. Outputs this usage message.
   -f: (f)ile. Run an alternate configuration file. 
       Default launch.conf file is: < $CONF >
   -F: (F)orce. Program checks that there isn't already a
       window with the same jail/program in the workspace.
       Default behavior would skip, but you can (F)orce. 
   -s: (s)start jails; but do not launch programs.
   
If no options are given, default conf is fully run.

ENDOFUSAGE
}

