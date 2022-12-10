#!/bin/sh

get_msg_i3_launch() { 

	local _message="$1"
	local _pass_cmd="$2"

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
       Default file is: < ${HOME}/.config/i3/i3gen.conf >
   -F: (F)orce. Program checks that there isn't already a
       window with the same jail/program in the workspace.
       Default behavior would skip, but you can (F)orce. 
   -s: (s)start jails; but do not launch programs.
   
If no options are given, default conf is fully run.

NOTE: This script can be finicky, and windows can pop up
in the wrong places sometimes. For example, if your browser 
tries to restore multiple windows from its last session. 
The script tries to account for that with a short delay
after detecting the window; but it's not perfect. 

If a window fails to launch within 6 sec, it's skipped. 

ENDOFUSAGE
}

