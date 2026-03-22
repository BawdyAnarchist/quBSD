#!/bin/sh

################################### AUTOMATED TRAP MANAGEMENT ######################################

rm_err() { rm -f $ERR ;}

trap_init() { trap 'eval "$TRAP"' $TRAP_SIGS ;}

# This is the only truly dangerous aspect of exception.sh. Use with caution. 
trap_push() {
    # Minimal sanitization. Args must be present, no semicolons
    if ! assert_args_set 1 "$1" ; then
        echo "Internal Error: < $_fn >. Attempted trap_push without passing any arguments."
        exit 3
    elif echo_grep "$1" ';' ; then
        echo "Internal Error: < $_fn >. trap_push was passed arguments containing a semicolon." 
        echo "This is inherently dangerous for trap_pop and the eval embedded in trap management."
        exit 3
    fi

    TRAP="$1 ; $TRAP"
}

trap_pop()  { TRAP=${TRAP#*;} ;}

##################################### ERROR TRACING SYSTEM #########################################

# Output redirects for internal library use
quiet() { "$@" > /dev/null 2>&1 ;}     # Pure silence
hush() { "$@" 2>/dev/null ;}           # Hush errors
verbose() { echo ">> $*" >&2; "$@" ;}  # Command-specific debug tool

# Silence all throws, remove $ERR file, but still return a failure
MUTE() { "$@" || { rm -f $ERR ; return 1 ;};}

# Remove the $ERR file
CLEAR() { WARN_CNT=0 ; rm -f $ERR ; return 0 ;}

# Means of ignoring specific error codes. Simultaneous [-C] CLEAR $ERR, if desired.
# Example: my_funct || PASS -C "11 121 242" || eval $(THROW $?)
PASS() {
    RC=$?  # Exit code of function in question must be immediate
    [ -z "$1" ] && return $RC  # In some cases, $1 could be blank. Passthru error code in that case
    [ "$1" = "-C" ] && { _C=true ; shift ;}

    case " $1 " in
        *" $RC "*) [ "$_C" ] && CLEAR ; unset _C ; return 0  ;;
        *) unset _C ; return $RC ;;
    esac # RC intentionally left as a global so that callers retain flexibility.
}

# Primary error, message, and tracing system
THROW() {
    local _code="$1" _msg_code="$2" _trace _msg _args _internal_err

    # Return code must always have a positive integer value
    if echo $_code | grep -Eqs '^[ \t]*[0-9]+[ \t]*$' ; then
        shift
    else
        _internal_err="Internal error: THROW called without return code"
        _code=9
    fi

    # Activate stack trace
    [ "$TRACE" ] && _trace="[ $_fn ]"

    # Code in *.msg library must have the form:   :_msg_code:
    if [ "$_msg_code" ] && [ ! "$_code" = 9 ]; then
        _msg=$(awk -v code=":$_msg_code:" '
            $1 == code { found=1; next }
            found && /^\/END\// { exit }
            found { print }' $D_QMSG/lib*.msg $D_QMSG/$BASENAME.msg 2>/dev/null)
        shift
        # If _msg_code is misformatted and _msg not found, printf errors. Send warning.
        [ "$_msg" ] || _internal_err="Internal error: Message not found. Check lib_*.msg formatting"
    fi

    # Record the trace and/or error message to the global ERR file
    if [ "$_internal_err" ] ; then
        printf "$_internal_err\n" >> $ERR
    elif [ "$_trace" ] || [ "$_msg" ] ; then
        printf "$_trace [$_code] $_msg\n" "$@" >> $ERR
    fi

    # This echo gets `eval` on return to caller. $_code was sanitized, so this is safe.
    echo "return $_code"
}

# Warning system writes to the same $ERR file as THROW
WARN() {
    local _msg_code="$1" _msg _trace

    # Activate stack trace
    [ "$TRACE" ] && _trace="[ $_fn ]"

    # Warning code in *.msg libs must have the form:  :w:_msg_code:
    if [ "$_msg_code" ] ; then
        _msg=$(awk -v code=":w:$_msg_code:" '
            $1 == code { found=1; next }
            found && /^\/END\// { exit }
            found { print }' $D_QMSG/lib*.msg $D_QMSG/$BASENAME.msg 2>/dev/null)
        shift
        # If _msg_code is misformatted and _msg not found, printf errors. Send warning.
        [ "$_msg" ] || _msg="Warn message not found. Check lib_*.msg formatting"
    fi

    if [ "$_trace" ] || [ "$_msg" ] ; then
        printf "$_trace $_msg\n" "$@" >> $ERR
    fi
    echo ': $(( WARN_CNT += 1 ))'   # Increment warn counter must be done by parent
}

############### CONVENIENCE FUNCTIONS FOR FLOW MANAGEMENT AND GLOBAL HOUSEKEEPING ##################

# mktemp standardization
make_tmp() {
    local _fn="make_tmp" _name
    assert_args_set 1 "$1" && _name="$1"
    eval $_name=$(mktemp $D_QTMP/${0##*/}.XXX)
    eval trap_push \"rm -f \${$_name}\"
}

# User-Interactive response subroutine
response_subr() {
    local _fn="response_subr" _query="$1"
    cat $ERR
    CLEAR
    if [ "$_query" = "-r" ] ; then
        printf "\n  Would you like to continue? (Y/n): "
        is_user_response && return 0 || eval $(THROW 1)
    fi
}

############################ DEBUG FUNCTIONS FOR DEEPER ERROR PROBING ##############################

debug1() {
	set -x
	rm $DEBUG1 > /dev/null 2>&1
	exec > $DEBUG1 2>&1
}
debug2() {
	set -x
	rm $DEBUG2 > /dev/null 2>&1
	exec > $DEBUG2 2>&1
}

