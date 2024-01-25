#!/bin/sh

msg_flags() {
	while getopts eEm:u _opts ; do case $_opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		u) local _usage="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Must specify an action: [-d][-u][-r]
ENDOFMSG
	;;
	_2) cat << ENDOFMSG

ERROR: Actions are mutually exclusive. Chose only one.
ENDOFMSG
	;;
	_3) cat << ENDOFMSG

ERROR: Must specify a target jail
ENDOFMSG
	;;
	esac

	[ $_usage ] && usage
	eval $_exit :
}

usage() { cat << ENDOFUSAGE

qb-flags: Toggles schg/noschg for the indicated jail

Usage: qb-flags [-h|-d|-u|-r] <jail>
   -d: (d)own. Recursive noschg flags for <jail>
   -h: (h)elp. Outputs this help message
   -r: (r)estore qmap settings for <jail>
   -u: (u)p. Recursive schg flags for <jail>

ENDOFUSAGE
}

