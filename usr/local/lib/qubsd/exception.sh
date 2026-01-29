#!/bin/sh

rm_errfiles() {
# Catchall cleanup for the error storage mechanism
	rm $ERR1 $ERR2 > /dev/null 2>&1
}

get_msg() {
# qubsd.sh internal messaging system
# THIS WILL BE OVERHAULED INTO A UNIFIED SYSTEM WITH get_msg2()
	local _msg1= ; local _msg2= ; local _error

   # Quiet option finally resolves.
	while getopts m:M:pqV opts ; do case $opts in
		m) _msg1="$OPTARG" ;;
		M) _msg2="$OPTARG" ;;
		q) local _q="true" ;;
		p) local _popup="true" ;;
		V) local _V="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 )) ; [ "$1" = "--" ] && shift

	# DEBUG helps to see what the chain of functions was for an error.
	[ "$DEBUG" = "1" ] && echo "$(date "+%Y-%m-%d_%H:%M")  $0  ${_FN}" >> $QLOG

	case $_msg1 in
		_m*) [ -z "$_q" ] && msg_qubsd "$@" ;;
		_w*|_e*) # Append messages to top of $ERR1. Must end with `|| :;}` , for `&& cp -a` to work
			[ -z "$_q" ] && { msg_qubsd "$@" ; [ "$_msg2" ] && _msg1="$_msg2" && msg_qubsd "$@" \
				; [ -s "$ERR1" ] && cat $ERR1 || :;} > $ERR2 && cp -a $ERR2 $ERR1

			# If -V was passed, then print the message immediately
			[ "$_V" ] && msg_qubsd "$@"
			;;
	esac

	unset _msg1 _msg2
	return 0
}

get_msg2() {
# Exception and message handling for the libexec scripts

	# Unified messaging function. Makes standard calls to individual script messages.
	# NOTE: The reality is that the error message files could experience race conditions.

	while getopts eEFm:pquV opts ; do case $opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		F) local _force="true" ; unset _exit= ;;
		m) local _message="$OPTARG" ;;
		p) local _popup="true" ;;
		q) local _q="true" ;;
		u) local _usage="true" ;;
		V) local _V="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	# Using the caller script to generalize message calls. Switch between exec and qb- scripts.
	local _caller="${0##*/}"  _msg  _NEEDPOP
	[ -z "${_caller##exec.*}" ] && _msg="msg_exec" || _msg="msg_${_caller##*-}"
# NOTE: When generalizing, you want lib_exec and lib_networking. Right now exec.sh (for exec.scripts) could
# hypothetically collide with some new scripted named qb-exec.

	# Source the correct message file
	. "$QLIB/messages/${_msg#msg_}.sh"

	# Determine if popup should be used or not
	get_info _NEEDPOP

	case $_message in
		_m*|_w*) [ -z "$_q" ] && eval "$_msg" "$@" ;;
		_e*)
			if [ -z "$_force" ] ; then
				# Place final ERROR message into a variable. $ERR1 (tmp) enables func tracing
				_ERROR="$(echo "ERROR: $_caller" ; "$_msg" "$@" ; [ -s "$ERR1" ] && cat $ERR1)"
				echo -e "$_ERROR\n" > $ERR2

				# If exiting due to error, log the date and error message to the log file
				[ "$_exit" = "exit 1" ] && echo -e "$(date "+%Y-%m-%d_%H:%M")\n$_ERROR" >> $QLOG

				# Send the error message
				if [ -z "$_q" ] && [ "$_ERROR" ] ; then
					{ [ "$_popup" ] && [ "$_NEEDPOP" ] && create_popup -f "$ERR2" ;} || echo "$_ERROR"
				fi
			fi ;;
	esac

	# Now that it has been dispositioned, erase the message
	truncate -s 0 $ERR1 ; unset _ERROR

	# Evaluate usage if present
	[ -z "$_q" ] && [ $_usage ] && _message="usage" && eval "$_msg"

	[ -n "$_exit" ] && rm_errfiles  # Had problems with lingering $ERR in QRUN. Make it unequivocal
	eval $_exit :
	return 0
}


# DEBUG FUNCTIONS FOR DEEPER ERROR PROBING

setlog1() {
	set -x
	rm /root/debug1 > /dev/null 2>&1
	exec > /root/debug1 2>&1
}

setlog2() {
	set -x
	rm /root/debug2 > /dev/null 2>&1
	exec > /root/debug2 2>&1
}

setlog3() {
	set -x
	rm /root/debug3 > /dev/null 2>&1
	exec > /root/debug3 2>&1
}

