#!/bin/sh

msg_ephm() {
	while getopts eEm:u _opts ; do case $_opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		u) local _usage="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Must specify a < jail > to clone for ephemeral jail
ENDOFMSG
	;;
	_2) cat << ENDOFMSG

ERROR: < $JAIL > is not properly configured or does not exist
ENDOFMSG
	;;
	esac

	[ $_usage ] && usage
	eval $_exit :
}

usage() { cat << ENDOFUSAGE

qb-ephm: Creates an ephemeral jail from snapshot of existing
         <jail>. Similar to qb-cmd. Run in existing terminal,
         popup a new one, or run a command inside the jail.

         EPHM-jails persist until the initiating terminal and
         all jail windows are closed. Then it's destroyed.

         *Use ephemeral jails for conducting risky operations*

Usage: qb-ephm [-h][-i][-n][-r] <jail> <optional_command>
   -h: (h)elp. Outputs this help message
   -i: (i)3wm. Include commands to float/center new window
   -n: (n)ew_window. Launch a new terminal for EPHM-jail to run.
   -r: (r)oot. Launch as root user inside the EPHM-jail.

ENDOFUSAGE
}

