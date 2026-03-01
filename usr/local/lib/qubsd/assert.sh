#!/bin/sh

################################  SECTION 1: GENERAL FORMAT CHECKS  ################################

assert_args_set() {
    local _fn="assert_args_set"
    local _require="$1" ; shift
    local _count="$#" _i=1

    [ "$_count" -lt "$_require" ] && eval $(THROW 11 $_fn)

    for _arg in "$@" ; do
        [ "$_arg" = "${_arg#*[![:space:]]}" ] && eval $(THROW 11 $_fn)
        [ $_i -ge $_require ] && return 0 || _i=$(( _i + 1 ))
    done

    return 0
}

assert_bool_tf() {
    local _fn="assert_bool_tf"
    echo $1 | tr '[:upper:]' '[:lower:]' \
            | grep -Eqs "^(true|false)\$" || eval $(THROW 12 $_fn)
}

assert_cellname() {
    local _fn="assert_cellname" _val="$1"

    # Trigger words to avoid, just in case.
    case $_val in
        none|qubsd) eval $(THROW 1 _invalid2 cellname $_val "Cannot be 'none' or 'qubsd'") ;;
    esac

    # Jail must start with :alnum: and afterwards, have only _ or - as special chars
    echo "$_val" | grep -E -- '^[[:alnum:]]([-_[:alnum:]])*[[:alnum:]]$' \
        | grep -Eqv '(--|-_|_-|__)' || eval $(THROW 16 $_fn $_val)
}

assert_integer() {
    local _fn="assert_integer"
    echo "$1" | grep -Eqs -- '^(-|[0-9])[0-9]*$' || eval $(THROW 13 $_fn $1)
}

assert_int_comparison() {
    # Checks that _value is integer, and can checks boundaries. [-n] is a descriptive variable name
    # from caller, for error message. Assumes that integers have been provided by the caller.
    local _fn="assert_int_comparison" _opts OPTARG OPTIND _val _g _G _l _L

    while getopts :g:G:l:L: opts ; do case $opts in
        g) assert_integer "$OPTARG" && _g="$OPTARG" || eval $(THROW 13 _internal3 $OPTARG) ;;
        G) assert_integer "$OPTARG" && _G="$OPTARG" || eval $(THROW 13 _internal3 $OPTARG) ;;
        l) assert_integer "$OPTARG" && _l="$OPTARG" || eval $(THROW 13 _internal3 $OPTARG) ;;
        L) assert_integer "$OPTARG" && _L="$OPTARG" || eval $(THROW 13 _internal3 $OPTARG) ;;
        *) eval $(THROW 8 _internal1) ;;  # getopts warning suppressed because we handle it here
    esac  ;  done  ;  shift $(( OPTIND - 1 ))

    assert_integer "$1" && _val="$1" || eval $(THROW 1 _internal3 $1)

    # Check each option one by one. Opts and _val already sanitized as integer format -> no quotes
    [ "$_g" ] && { [ $_val -ge $_g ] || eval $(THROW 11 ${_fn} $_val '<'  $_g) ;}
    [ "$_G" ] && { [ $_val -gt $_G ] || eval $(THROW 11 ${_fn} $_val '<=' $_G) ;}
    [ "$_l" ] && { [ $_val -le $_l ] || eval $(THROW 11 ${_fn} $_val '>'  $_l) ;}
    [ "$_L" ] && { [ $_val -lt $_L ] || eval $(THROW 11 ${_fn} $_val '>=' $_L) ;}

    return 0
}

##################################  SECTION 2: COMMON PARAMETERS  ##################################

assert_class() {
    local _fn="assert_class"
    echo "$CLASSES" | grep -Eqs -- "(^| )$1( |\$)" || eval $(THROW 16 _invalid CLASS $1)
}

assert_ipv4() {
    local _fn="assert_ipv4" _val="$1" _b1 _b2 _b3

    # Not as technically correct as a regex, but it's readable and functional
    # IP represented by the form: a0.a1.a2.a3/a4 ; b-variables are local/ephemeral
    _a0=${_val%%.*.*.*/*}
    _a4=${_val##*.*.*.*/}
        _b1=${_val#*.*}
        _a1=${_b1%%.*.*/*}
            _b2=${_val#*.*.*}
            _a2=${_b2%%.*/*}
                _b3=${_val%/*}
                _a3=${_b3##*.*.*.}

    # Ensures that each number is in the proper range
    echo "$_val" \
        | grep -Eqs "^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+/[[:digit:]]+\$" \
        || eval $(THROW 1 _invalid2 IPV4 "$_val" "Use CIDR notation with subnet")

    # Ensures that each digit is within the proper range
    { [ "$_a0" -ge 0 ] && [ "$_a0" -le 255 ] && [ "$_a1" -ge 0 ] && [ "$_a1" -le 255 ] \
        && [ "$_a2" -ge 0 ] && [ "$_a2" -le 255 ] && [ "$_a3" -ge 0 ] && [ "$_a3" -le 255 ] \
        && [ "$_a4" -ge 0 ] && [ "$_a4" -le 32 ] ;} \
        || eval $(THROW 15 _invalid2 IPV4 "$_val" "Use CIDR notation with subnet")
    return 0
}

assert_bytesize() {
    local _fn="assert_bytesize"
    echo "$1" | grep -Eqs "^[[:digit:]]+(T|t|G|g|M|m|K|k)\$" || eval $(THROW 16 _invalid bytesize $1)
}

normalize_bytesize() {
    local _fn="normalize_bytesize" _val="$1" _raw
    _raw=$(echo $_val | sed -nE "s/.\$//p")
    case $_val in
        *K|*k) echo $(( _raw * 1024 )) ;;
        *M|*m) echo $(( _raw * 1024 * 1024 )) ;;
        *G|*g) echo $(( _raw * 1024 * 1024 * 1024 )) ;;
        *T|*t) echo $(( _raw * 1024 * 1024 * 1024 * 1024 )) ;;
    esac
}


###################################  SECTION 3: JAIL PARAMETERS  ###################################

assert_cpuset() {
    local _fn="assert_cpuset"
    # Test for negative numbers and dashes in the wrong place
    echo "$1" | grep -Eq "(,,+|--+|,-|-,|,[ \t]*-|^[^[:digit:]])" && eval $(THROW 17 $_fn $1)
    return 0
}

assert_schg() {
    local _fn="assert_schg"
    case $1 in
        none|sys|all) return 0 ;;
        *) eval $(THROW 17 _invalid2 SCHG $1 "Must be <none|sys|all>") ;;
    esac
}

assert_seclvl() {
    local _fn="assert_seclvl"
    case $1 in
        none|-1|-0|0|1|2|3) return 0 ;;
        *) eval $(THROW 17 _invalid2 SECLVL $1 "Must be <none|-1|0|1|2|3>") ;;
    esac
}


####################################  SECTION 4: VM PARAMETERS  ####################################

assert_bhyveopts() {
    local _fn="assert_bhyveopts" _val="$1"
    _val=$(echo "$_val" | sed -E 's/^-//')   # Remove the leading dash

    # Only includes bhyve opts with no argument
    echo "$_val" | grep -Eqs -- '^[AaCDeHhPSuWwxY]+$' || eval $(THROW 18 ${_fn}1 BHYVEOPTS $_val)

    # No duplicate characters
    [ "$(echo "$_val" | fold -w1 | sort | uniq -d | wc -l)" -gt 0 ] \
        && eval $(THROW 18 ${_fn}2 BHYVEOPTS $_val)

    return 0
}

assert_taps() {
    local _fn="assert_taps"
    assert_int_comparison -g 0 -- "$1" || eval $(THROW $? _invalid2 TAPS $1 "Require: integer >= 0")
}

assert_vcpus() {
    local _fn="assert_vcpus"
    assert_int_comparison -G 0 -- "$1" || eval $(THROW $? _invalid2 VCPUS $1 "Require: integer > 0")
}

