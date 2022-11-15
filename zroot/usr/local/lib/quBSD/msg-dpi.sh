#!/bin/sh

get_msg_qb_dpi() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _action is optional, and can be used to exit and/or show usage

	local _message
	local _action
	_message="$1"
	_action="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Proposed DPI is below sanity threshold of 0.5. 
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Proposed DPI is too high for relative (0.5 to 4); 
       but too low to be raw (48 to 386).
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: DPI is above sanity threshold of 386.
ENDOFMSG
	;;
	_4) cat << ENDOFMSG
ENDOFMSG
	;;
	_5) cat << ENDOFMSG
ENDOFMSG
	;;
	esac

	case $_action in 
		usage_0) usage ; exit 0 ;;
		usage_1) usage ; exit 1 ;;
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		*) : ;;
	esac
}

usage() { cat << ENDOFUSAGE

qb-dpi: Quickly change dpi on the fly; revert automatically.

Converts from 
        raw DPI to a scaling constant, referenced at 96.
        For example:  1=96 ; 0.5=48 ; 2=192

Usage: qb-dpi [-r] <new_dpi>
   -h: (h)elp. Outputs this usage message
	-r: (r)evert. Seconds to keep new DPI before reverting
       to the system default from \`xrdb -query\` 

   <new_dpi> can be expressed either as a raw value, or with
   a simple integer acting as a relative scaling constant, 
   centered at 96. For example:  1=96 ; 2=192 ; 0.5=48   

ENDOFUSAGE
}

