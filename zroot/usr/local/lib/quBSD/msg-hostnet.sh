#!/bin/sh

msg_hostnet() {
	case "$_message" in
	_e1) cat << ENDOFMSG

ERROR: Options are mutually exclusive. Chose one.
ENDOFMSG
	;;
	_e2) cat << ENDOFMSG

ERROR: Must specify an action [-d|-u]
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG

ERROR: Tunnel < $JAIL > failed to start.
       For more info, see: $QBLOG
ENDOFMSG
	;;
	_e6) cat << ENDOFMSG
ENDOFMSG
	;;
	_e7) cat << ENDOFMSG

WARNING: User opted to remove the network timeout. Host
         will keep this network connection indefintely.
ENDOFMSG
	;;
	usage) cat << ENDOFUSAGE

qb-hostnet: Connect host to outside internet.

Usage: hostnet [-h][-d|-u][-t <time_in_seconds>]
   -h: (h)elp. Outputs this help message
   -d: (d)own. Remove connectivity; set pf to block all
   -u: (u)p. Brings up connectivity as specified in QMAP

   -t: (t)ime before connection is automatically removed.
       Default is 300 secs (5 min). Two exceptions where
       where connection will persist beyond <timeout>:
          1) If freebsd-update is running, or
          2) pkg is running
          # After completion, connection is removed.
       To disable default timeout and maintain indefinite
       host connection, use qb-hostnet -u -t 0

   When host is connected, qb-stat will print a large
   flashing warning message in red letters.

ENDOFUSAGE
		;;
	esac
}

