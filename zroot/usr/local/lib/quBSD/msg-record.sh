#!/bin/sh

get_msg_record() { 

	local _message="$1"
	local _pass_cmd="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Invalid option

ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: [-v] volume must be an integer 0 to 100.  

ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: < $JAIL > is not running. 

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
}

