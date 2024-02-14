#!/bin/sh

msg_record() {
	case "$_message" in
	_e1) cat << ENDOFMSG
   Invalid option
ENDOFMSG
	;;
	_e2) cat << ENDOFMSG
   [-v] volume must be an integer 0 to 100.
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG
   < $JAIL > is not running.
ENDOFMSG
	;;
	usage) cat << ENDOFUSAGE

qb-record: Toggles webcamd and/or virtual_oss services

Usage: qb-record [-h][-m][-p][-v <mic_vol>][-w <jail>]
   -h: (h)elp. Outputs this help message.
   -m: (m)icrophone toggle. /dev/dsp* is already exposed
       to all GUI jails, so <jail> is not required.
   -p: (p)urge mic/webcam (stop services, hide webcam).
       Overrides [-m][-w], and stops the services.
   -v: (v)olume on microphone. If not specified, it will
       be set to 100, whenever mic is toggled on.
   -w: (w)ebcam. Toggle <jail> access to webcam.
       Jail must be specified.

ENDOFUSAGE
		;;
	esac
}

