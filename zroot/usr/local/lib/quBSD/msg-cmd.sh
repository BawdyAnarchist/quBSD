#!/bin/sh

get_msg_cmd() { 

   local _message="$1"
   local _pass_cmd="$2"

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

qb-cmd: Runs command in a jail, or connects to VM.
        Jail default is /bin/csh ; VM defaults to
        both tmux and VNC if no option specified.

Usage: qb-cmd <jailname>
       qb-cmd [-n][-r|-u <user>][-t][-v][-V] <jailname> <command>

   -h: (h)elp. Outputs this help message
   -n: (n)ew window. Run command in new window. If jail is not
       specified, default environment is the active window
   -r: (r)oot. Run cmd as root. Default is unprivileged user
   -t: (t)mux (terminal connection) will be made to VM, if present
       Note: Press ctrl-b and then "d" to disconnect.
   -u: (u)ser. Run cmd as <user>. Default is unpriveleged
       user, which is the same name as the jail.
   -v: (v)erbose. Output of <command> will print to stdio.
       (Default behavior sends output to /dev/null)
	-V: (V)NC connection to VM will be attempted, based on info
       found in /tmp/quBSD/qb-vnc_<jail>

ENDOFUSAGE
}

