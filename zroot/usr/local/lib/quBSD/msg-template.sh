#!/bin/sh

usage_qb_() { 
	cat << ENDOFUSAGE 

qb-:  Modify 

Usage: qb-
qb-edit [-f][-h]

   -f: (f)orce: Ignore potential errors and modify anyways
   -h: (h)elp:  Outputs this help message

ENDOFUSAGE
}

get_msg_() { 
	_message="$1"
	_action="$2"
	case "$_message" in
	_1) cat << ENDOFMSG
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG
ENDOFMSG
	;;
	_4) cat << ENDOFMSG
ENDOFMSG
	;;
	_5) cat << ENDOFMSG
ENDOFMSG
	;;
	_6) cat << ENDOFMSG
ENDOFMSG
	;;
	_7) cat << ENDOFMSG
ENDOFMSG
	;;
	_8) cat << ENDOFMSG
ENDOFMSG
	;;
	_9) cat << ENDOFMSG
ENDOFMSG
	;;
	_10) cat << ENDOFMSG
ENDOFMSG
	;;
	_11) cat << ENDOFMSG
ENDOFMSG
	;;
	_12) cat << ENDOFMSG
ENDOFMSG
	;;
	_13) cat << ENDOFMSG
ENDOFMSG
	;;
	_14) cat << ENDOFMSG
ENDOFMSG
	;;
	_15) cat << ENDOFMSG
ENDOFMSG
	;;
	_16) cat << ENDOFMSG
ENDOFMSG
	;;
	_18) cat << ENDOFMSG
ENDOFMSG
	;;
	_19) cat << ENDOFMSG
ENDOFMSG
	;;
	_20) cat << ENDOFMSG
ENDOFMSG
	;;
	esac

	case $_action in 
		usage_0) usage_qb_edit ; exit 0 ;;
		usage_1) usage_qb_edit ; exit 1 ;;
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		*) : ;;
	esac
}
