#!/bin/sh

get_msg_cmd() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _pass_cmd is optional, and can be used to exit and/or show usage

   local _message
   local _pass_cmd

	_message="$1"
	_pass_cmd="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Jail failed to start. Preliminary checks looked okay.
       For details, see: /var/log/quBSD.log 
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

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

qb-cmd: Runs command in a jail, or new xterm on host
        If no command is specified, default is /bin/csh

Usage: qb-cmd <jailname>
       qb-cmd [-n][-r][-v] <jailname> <command>

   -h: (h)elp. Outputs this help message
   -n: (n)ew window. Run command in new window. If jail is not
       specified, default environment is the active window
   -r: (r)oot. Run cmd as root. Default is unprivileged user
   -v: (v)erbose. Output of <command> will print to stdio.
       (Default behavior sends output to /dev/null)

ENDOFUSAGE
}

