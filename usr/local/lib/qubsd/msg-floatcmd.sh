#!/bin/sh

msg_floatcmd() {
	case $_message in
	usage) cat << ENDOFUSAGE

qb-floatcmd: Causes a popup window which receives a user command
             and then executes inside of the the selected jail.

Usage: qb-float-cmd [-h ] [-r] [-x] <jail>
   -h: shows this usage message
   -r: run command in jail as root
   -x: DO NOT USE!! special option internal to script.

ENDOFUSAGE
		;;
	esac
}

