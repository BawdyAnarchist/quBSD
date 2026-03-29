#!/bin/sh

###################################### ERROR HANDLING SYSTEM #######################################

# Output redirects for internal library use. Prepend commands with quiet(), hush(), or mute()
quiet() { "$@" > /dev/null 2>&1 ;}  # Suppress all stdout, $ERR still written
hush() { "$@" 2>/dev/null ;}        # Suppress errors from stdout, $ERR still written
mute() {                            # Suppress all stdout, and revert any $ERR writes
    local _return _err=$(cat $ERR 2>/dev/null)
    "$@" > /dev/null 2>&1 ; _return=$?
    [ "$_err" ] && printf '%s' "$_err" > $ERR || rm -f $ERR
    return $_return  # Pass through the return code
}

# Remove the $ERR file
clear_err() { rm -f $ERR ; return 0 ;}

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
    [ "$TRACE" ] && _trace="[$_fn]"

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
        printf "$_trace[$_code]: $_msg\n" "$@" >> $ERR
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
}

# Means of ignoring specific error codes. Simultaneous [-c] clear_err $ERR, if desired.
# Example: my_funct || PASS -c "11 121 242" || eval $(THROW $?)
PASS() {
    RC=$?  # Exit code of function in question must be immediate
    [ -z "$1" ] && return $RC  # In some cases, $1 could be blank. Passthru error code in that case
    [ "$1" = "-c" ] && { _c=true ; shift ;}

    case ",$1," in
        *",$RC,"*) [ "$_c" ] && clear_err ; unset _c ; return 0  ;;
        *) unset _c ; return $RC ;;
    esac # RC intentionally left as a global so that callers retain flexibility.
}

FATAL() {
    local _exit=$?
    [ -f "$ERR" ] && cat $ERR
    exit $_exit
}


################################### AUTOMATED TRAP MANAGEMENT ######################################

# Set $TRAP as a command variable. Now we can operate on the variable instead of `trap` itself
trap_init() { trap 'eval "$TRAP"' $TRAP_SIGS ;}

# Remove the most recent command pushed to $TRAP. Semicolons indicate command separation
trap_pop() { TRAP=${TRAP#*;} ;}

# Push a new command to $TRAP. This is the only truly dangerous aspect of exception.sh.
# Use with caution, sanitize variables inputs. Evaluate them immediately. Do not use indirection.
trap_push() {
    # Minimal sanitization. Args must be present, no semicolons
    if ! assert_args_set 1 "$1" ; then
        echo "Internal Error: < $_fn >. Attempted trap_push without passing any arguments."
        exit 3
    elif echo "$1" | grep -qs ';' ; then
        echo "Internal Error: < $_fn >. trap_push was passed arguments containing a semicolon."
        echo "This is inherently dangerous for trap_pop and the eval embedded in trap management."
        exit 3
    fi
    TRAP="$1 ; $TRAP"
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
    clear_err
    if [ "$_query" = "-r" ] ; then
        printf "\n  Would you like to continue? (Y/n): "
        is_user_response && return 0 || eval $(THROW 2)
    fi
}


############################ DEBUG FUNCTIONS FOR DEEPER ERROR PROBING ##############################

# Command-specific debug tool for viewing what exactly was run for a given command
verbose() { echo ">> $*" >&2; "$@" ;}

# Milliseconds to complete a command. Assuming low system load, should usually be +/- .5ms precision
# FreeBSD /bin/sh `time` builtin only provides centiseconds
elapsed() {
    local _return _date=$(date +%s.%N)
    "$@"
    _return=$?
    # Subtract .0008 to account for (appx) delay of the command itself. Close enough for this tool
    echo "$_fn: Elapsed: $(echo "scale=3 ; (($(date +%s.%N) - $_date - .0008) * 1000) / 1" | bc) ms"
    return $_return
}

# Activate full shell log for debugging. Use `set +x` to deactivate at a later point in a script
debug() {
	 set -x
	 rm $DEBUG > /dev/null 2>&1
	 exec > $DEBUG 2>&1
}
