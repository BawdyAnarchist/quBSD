#!/bin/sh

msg_() {
	while getopts eEm:quV opts ; do case $opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		q) local _q="true" ;;
		u) local _usage="true" ;;
		V) local _V="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	# Assemble/retreive the message
	_MESSAGE=$([ -z "${_message##_e*}" ] && echo "ERROR:  ${0##*/}" \
		; retreive_msg "$@" ; [ "$GET_MSG" ] && echo "$GET_MSG")

	# If exiting with error, send it to the log
	[ "$_exit" = "exit 1" ] && echo -e "$(date "+%Y-%m-%d_%H:%M")  $0\n$_MESSAGE" >> $QBLOG

	# If -q wasnt specified, print message to the terminal
	[ -z "$_q" ] && echo "$_MESSAGE"

	# Evaluate usage and exit code
	[ $_usage ] && usage
	eval $_exit :
}

retreive_msg() {
	case "$_message" in
	_e1) cat << ENDOFMSG
ENDOFMSG
		;;
	_2) cat << ENDOFMSG
ENDOFMSG
		;;
	_3) cat << ENDOFMSG
ENDOFMSG
		;;
	esac
}

usage() { cat << ENDOFUSAGE

qb-

Usage: qb-
   -h: (h)elp. Outputs this help message.

ENDOFUSAGE
}

