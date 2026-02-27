#!/bin/sh

# OUTPUT REDIRECTS FOR INTERNAL LIBRARY USE
quiet() { "$@" > /dev/null 2>&1 ;}     # Pure silence
hush() { "$@" 2>/dev/null ;}           # Hush errors
verbose() { echo ">> $*" >&2; "$@" ;}  # Command-specific debug tool

# TRAP MANAGAMENT
rm_err() { rm -f $ERR ;}
rm_rt_ctx() { rm -f $RT_CTX ;}
trap_init() { trap 'eval "$TRAP"' $TRAP_SIGS ;}
trap_push() { TRAP="$1 ; $TRAP" ;}
trap_pop()  { TRAP=${TRAP#*;} ;}   # WARNING: Do not use semicolons in trap_push args

# mktemp STANDARDIZATION
make_tmp() {
    local _fn="make_tmp" _name
    assert_args_set 1 "$1" && _name="$1"
    eval $_name=$(mktemp $D_QTMP/${0##*/}.XXX)
    eval trap_push \"rm -f \${$_name}\"
}

# WARNING SUBR
warning_subr() {
    local _fn="warning_subr" _query="$1"
    cat $ERR
    CLEAR
    if [ "$_query" = "-r" ] ; then
        printf "\n  Would you like to continue? (Y/n): "
        is_user_response && return 0 || eval $(THROW 1)
    fi
}

# ERROR/TRACING SYSTEM
MUTE() { "$@" || { rm -f $ERR ; return 1 ;};}

CLEAR() { WARN_CNT=0 ; rm -f $ERR ; return 0 ;}

# MEANS OF IGNORING SPECIFIC ERROR CODES. SIMULTANEOUS -C CLEAR of ERR, IF DESIRED
# RC INTENTIONALLY LEFT AS A GLOBAL SO THAT CALLERS RETAIN FLEXIBILITY
PASS() {
    RC=$?  # Exit code of function in question must be immediate
    [ "$1" = "-C" ] && { _C=true ; shift ;}

    case " $1 " in
    *" $RC "*) [ "$_C" ] && CLEAR ; unset _C ; return 0  ;;
    *) unset _C ; return 1 ;;
    esac
}

THROW() {
    local _code="$1" _msg_code="$2" _trace _msg _args _internal_err

    # Return code must always have a positive integer value
    if echo $_code | grep -Eqs '^[ \t]*[1-9]+[ \t]*$' ; then
        shift
    else
        _internal_err="Internal error: THROW called without return code"
        _code=99
    fi

    # Activate stack trace
    [ "$TRACE" ] && _trace="[ $_fn ]"

    # Code in *.msg library must have the form:   :_msg_code:
    if [ "$_msg_code" ] && [ ! "$_code" = 99 ]; then
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
        printf "$_trace $_msg\n" "$@" >> $ERR
    fi

    # This echo gets `eval` on return to caller. $_code was sanitized, so this is safe.
    echo "return $_code"
}

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

# DEBUG FUNCTIONS FOR DEEPER ERROR PROBING
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

