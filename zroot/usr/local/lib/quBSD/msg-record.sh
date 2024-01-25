#!/bin/sh

msg_record() { 
	while getopts eEm:u _opts ; do case $_opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		u) local _usage="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

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

	[ $_usage ] && usage
	eval $_exit :
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

