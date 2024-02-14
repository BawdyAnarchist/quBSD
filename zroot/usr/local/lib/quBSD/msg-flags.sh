#!/bin/sh

msg_flags() {
	case "$_message" in
	_e1) cat << ENDOFMSG
Must specify an action: [-d][-u][-r]
ENDOFMSG
	;;
	_e2) cat << ENDOFMSG
Actions are mutually exclusive. Chose only one.
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG
Must specify a target jail
ENDOFMSG
	;;
	usage) cat << ENDOFUSAGE

qb-flags: Toggles schg/noschg for the indicated jail

Usage: qb-flags [-h|-d|-u|-r] <jail>
   -d: (d)own. Recursive noschg flags for <jail>
   -h: (h)elp. Outputs this help message
   -r: (r)estore qmap settings for <jail>
   -u: (u)p. Recursive schg flags for <jail>

ENDOFUSAGE
		;;
	esac
}

