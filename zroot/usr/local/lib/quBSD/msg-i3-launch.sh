#!/bin/sh

msg_launch() {
	case "$_message" in
	_e1) cat << ENDOFMSG
< $FILE > does not exist.
ENDOFMSG
	;;
	_e2) cat << ENDOFMSG
[-t <timeout>] must be an integer from 5 to 600.
(Choose longer timeouts if starting multiple gateways in a row)
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG
qb-start failed to launch all jails before timeout
ENDOFMSG
	;;
	usage) cat << ENDOFUSAGE

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
		;;
	esac
}

