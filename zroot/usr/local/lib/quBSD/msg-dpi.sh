#!/bin/sh

msg_dpi() {
	case "$_message" in
	_e1) cat << ENDOFMSG

ERROR: Proposed DPI is below sanity threshold of 0.3.
ENDOFMSG
	;;
	_e2) cat << ENDOFMSG

ERROR: Proposed DPI is too high for relative (0.5 to 4);
       but too low to be raw (29 to 386).
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG

ERROR: DPI is above sanity threshold of 384.
ENDOFMSG
	;;
	usage) cat << ENDOFUSAGE

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
		;;
	esac
}

