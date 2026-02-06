#!/bin/sh

# OUTPUT REDIRECTS FOR INTERNAL LIBRARY USE
quiet() { "$@" > /dev/null 2>&1 ;}     # Pure silence
hush() { "$@" 2>/dev/null ;}           # Hush errors
verbose() { echo ">> $*" >&2; "$@" ;}  # Command-specific debug tool

# ERROR/TRACING SYSTEM
rm_errfile() { rm -f $ERR ;}

MUTE() { "$@" || { rm -f $ERR ; return 1 ;};}

CLEAR() { WARN_CNT=0 ; rm -f $ERR ; return 0 ;}

THROW() {
    local _code="$1" _msg_code="$2" _trace _msg _args

    # Return code must always have a non-zero integer value
    echo $_code | grep -Eqs '[1-9]+' && shift \
        || { echo "Internal error: THROW called without return code" && exit 0 ;}

    # Activate stack trace
    [ "$TRACE" ] && _trace="[ $_fn ]"

    # Code in *.msg library must have the form:   :_msg_code: 
    if [ "$_msg_code" ] ; then
        _msg=$(awk -v code=":$_msg_code:" '
            $1 == code { found=1; next }
            found && /^\/END\// { exit }
            found { print }' $D_QMSG/lib*.msg $D_QMSG/$BASENAME.msg)
        shift
        # If _msg_code is misformatted and _msg not found, printf errors. Send warning.
        [ "$_msg" ] || _msg="Error message not found. Check lib_*.msg formatting"
    fi

    # Record the trace and/or error message to the global ERR file
    if [ "$_trace" ] || [ "$_msg" ] ; then
        printf "$_trace $_msg\n" "$@" >> $ERR
    fi

    # This echo gets `eval` on return to caller. $_code was sanitized, so this is safe.
    echo "return $_code"
}

WARN() {
    local _msg_code="$1" _msg
    : $(( WARN_CNT += 1 ))   # Increment warn count

    # Warning code in *.msg libs must have the form:  :w:_msg_code: 
    if [ "$_msg_code" ] ; then
        _msg=$(awk -v code=":w:$_msg_code:" '
            $1 == code { found=1; next }
            found && /^\/END\// { exit }
            found { print }' $D_QMSG/lib*.msg $D_QMSG/$BASENAME.msg)
        shift
        # If _msg_code is misformatted and _msg not found, printf errors. Send warning.
        [ "$_msg" ] || _msg="Warn message not found. Check lib_*.msg formatting"
    fi

    [ "$_msg" ] && printf "[ WARN ] $_msg\n" "$@" >> $ERR
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



########################################################################################
########################################## OLD #########################################
########################################################################################


rm_errfiles() { rm -f $ERR ;}    # Baseline trap

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

