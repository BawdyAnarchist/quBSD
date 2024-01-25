#!/bin/sh

msg_cmd() {
	while getopts eEm:u _opts ; do case $_opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		u) local _usage="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: < $JAIL > Failed to start.
       For details, see: /var/log/quBSD.log
ENDOFMSG
	;;
	_2) cat << ENDOFMSG

ERROR: No TMUX or valid vncviewer configuration was found for
       < $JAIL >. Check VM parameters with:  qb-list $JAIL
ENDOFMSG
	;;
	_3) cat << ENDOFMSG
ALERT: The command below is run with /bin/sh. If the current
       SHELL is different, there will likely be ERRORS if you
       simply copy/paste the command. Current shell is $SHELL

ENDOFMSG
	;;
	_4) cat << ENDOFMSG
ALERT: < $JAIL > is tagged with VNCRES, but the FBUF device
       hasnt been detected yet. Waiting 15 seconds before quitting
ENDOFMSG
	;;
	_5) cat << ENDOFMSG
ERROR: Timeout waiting for vnc FBUF device to appear in sockstat
ENDOFMSG
	;;
	esac

	[ $_usage ] && usage
	eval $_exit :
}

usage() { cat << ENDOFUSAGE

qb-cmd: Runs command in a jail, or connects to VM.
        Jail default is /bin/csh ; VM defaults to
        both tmux and VNC if no option specified.

Usage: qb-cmd <jail/VM>
       qb-cmd [-n][-r|-u <user>][-v] <jail> <command>
       qb-cmd [-N|-v] <VM>

   -h: (h)elp. Outputs this help message
   -n: (n)ew window. Run command in new window. If jail is not
       specified, default environment is the active window
   -N: (N)orun. Print the bhyve command that would be run,
       but do not launch. Only applies to VMs.
   -r: (r)oot. Run cmd as root. Default is unprivileged user
   -u: (u)ser. Run cmd as <user>. Default is unpriveleged
       user, which is the same name as the jail.
   -v: (v)erbose. Output of <command> will print to stdio.
       (Default behavior sends output to /dev/null).For VM,
       this will print the bhyve command, and launch the VM.

ENDOFUSAGE
}

