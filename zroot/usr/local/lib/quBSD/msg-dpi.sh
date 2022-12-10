#!/bin/sh

get_msg_dpi() { 

	local _message="$1"
	local _pass_cmd="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Proposed DPI is below sanity threshold of 0.3. 
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Proposed DPI is too high for relative (0.5 to 4); 
       but too low to be raw (29 to 386).
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: DPI is above sanity threshold of 384.
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

qb-dpi: Quickly change dpi on the fly; revert automatically.

Converts from 
        raw DPI to a scaling constant, referenced at 96.
        For example:  1=96 ; 0.5=48 ; 2=192

Usage: qb-dpi [-r] <new_dpi>
   -h: (h)elp. Outputs this usage message
	-r: (r)evert. Revert back to system DPI and exit. 
	-t: (t)time. Seconds to keep new DPI before reverting
       to the system default from .Xresources 

   <new_dpi> can be expressed either as a raw value, or with
   a simple integer acting as a relative scaling constant, 
   centered at 96. For example:  1=96 ; 2=192 ; 0.5=48   

ENDOFUSAGE
}

