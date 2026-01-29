#!/bin/sh

## EXCEPTION HANDLING SYSTEM ##

## NOTE: Will later be modularized into separate messaging and exception libraries

rm_errfiles() {
# Catchall cleanup for the error storage mechanism
	rm $ERR1 $ERR2 > /dev/null 2>&1
}

get_msg() {
# qubsd common.sh internal messaging system
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
		_m*) [ -z "$_q" ] && msg_lib_common "$@" ;;
		_w*|_e*) # Append messages to top of $ERR1. Must end with `|| :;}` , for `&& cp -a` to work
			[ -z "$_q" ] && { msg_lib_common "$@" ; [ "$_msg2" ] && _msg1="$_msg2" && msg_lib_common "$@" \
				; [ -s "$ERR1" ] && cat $ERR1 || :;} > $ERR2 && cp -a $ERR2 $ERR1

			# If -V was passed, then print the message immediately
			[ "$_V" ] && msg_lib_common "$@"
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

create_popup() {
	# Handles popus to send messages, receive inputs, and pass commands
	# _h should be as a percentage of the primary screen height (between 0 and 1)
	# _w is a multiplication factor for _h
	local _fn="create_popup" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts c:f:h:im:qVw: opts ; do case $opts in
			c) local _cmd="$OPTARG" ;;
			i) local _input="true" ;;
			f) local _popfile="$OPTARG" ;;
			h) local _h="$OPTARG" ;;
			m) local _popmsg="$OPTARG" ;;
			q) local _qs="-q" ; _quiet='> /dev/null 2>&1' ;;
			V) local _V="-V" ;;
			w) local _w="$OPTARG" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	# Discern if it's i3, and modify with center/floating options
	ps c | grep -qs 'i3' && local _i3mod="i3-msg -q floating enable, move position center"

	# If a file was passed, set the msg equal to the contents of the file
	[ "$_popfile" ] && local _popmsg=$(cat $_popfile)

	# Might've been launched from quick-key or without an environment. Get the host DISPLAY
	[ -z "$DISPLAY" ] && export DISPLAY=$(pgrep -fl Xorg | grep -Eo ":[0-9]+")

	# Equalizes popup size and fonts between systems of different resolution and DPI settings.
	calculate_sizes

	# Execute popup depending on if input is needed or not
	if [ "$_cmd" ] ; then
	echo $DISPLAY >> /root/temp
		xterm -fa Monospace -fs $_fs -e /bin/sh -c "eval \"$_i3mod\" ; eval \"$_cmd\" ; "
	elif [ -z "$_input" ] ; then
		# Simply print a message, and return 0
		xterm -fa Monospace -fs $_fs -e /bin/sh -c \
			"eval \"$_i3mod\" ; echo \"$_popmsg\" ; echo \"{Enter} to close\" ; read _INPUT ;"
		eval $_R0
	else
		# Need to collect a variable, and use a tmp file to pull it from the subshell, to a variable.
		local _poptmp=$(mktemp ${QRUN}/popup.XXXX)
		xterm -fa Monospace -fs $_fs -e /bin/sh -c \
			"eval \"$_i3mod\"; printf \"%b\" \"$_popmsg\"; read _INPUT; echo \"\$_INPUT\" > $_poptmp"

		# Retreive the user input, remove tmp, and echo the value back to the caller
		_input=$(cat $_poptmp)
		rm $_poptmp > /dev/null 2>&1
		echo "$_input"
	fi
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
