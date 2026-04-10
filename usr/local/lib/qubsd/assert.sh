#!/bin/sh

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

assert_bhyveopts() {
    local _fn="assert_bhyveopts" _val="$1"
    _val=$(echo "$_val" | sed -E 's/^-//')   # Remove the leading dash

    # Only includes bhyve opts with no argument
    echo "$_val" | grep -Eqs -- '^[AaCDeHhPSuWwxY]+$' || eval $(THROW 32 ${_fn}_1)

    # No duplicate characters
    [ "$(echo "$_val" | fold -w1 | sort | uniq -d | wc -l)" -gt 0 ] && eval $(THROW 33 ${_fn}_2)

    return 0
}

# Impossible to fully assert bhyve_custm parameter user inputs. But some guarantees can be provided
assert_bhyve_custm() {
    local _fn="assert_bhyve_custm" _val="$1"
    echo "$_val" | grep -Eqs "^[a-zA-Z0-9 \-/_:,.=+]*$" || eval $(THROW 31 $_fn)
}

assert_bool_tf() {
    local _fn="assert_bool_tf"
    echo "$1" | grep -Eqs "^(true|TRUE|FALSE|false)\$" || eval $(THROW 12 $_fn)
}

assert_bytesize() {
    local _fn="assert_bytesize"
    echo "$1" | grep -Eqs "^[[:digit:]]+(T|t|G|g|M|m|K|k)\$" || eval $(THROW 19 $_fn)
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

assert_cellname() {
    local _fn="assert_cellname" _val="$1"
    # Jail must start with :alnum: and afterwards, have only _ or - as special chars
    echo "$_val" | grep -E -- '^[[:alnum:]]([-_[:alnum:]])*[[:alnum:]]$' \
        | grep -Eqv '(--|-_|_-|__)' || eval $(THROW 16 $_fn)

    case $_val in
        none|qubsd|host) eval $(THROW 16 ${_fn}_2) ;;
    esac
}

assert_cellname_new() {
    local _fn="assert_cellname_new" _val="$1"

    # Trigger words that shouldn't be used
    case $_val in
        none|qubsd|host) eval $(THROW 16 assert_cellname_2)
    esac

    # Jail must start with :alnum: and afterwards, have only _ or - as special chars
    echo "$_val" | grep -E -- '^[[:alnum:]]([-_[:alnum:]])*[[:alnum:]]$' \
        | grep -Eqv '(--|-_|_-|__)' || eval $(THROW 16 assert_cellname)
}

assert_class() {
    local _fn="assert_class"
    echo_grep -qd , "$CLASSES" "$1" || eval $(THROW 18 $_fn "$CLASSES")
}

assert_cpuset() {
    local _fn="assert_cpuset"
    # Test for negative numbers and dashes in the wrong place
    echo "$1" | grep -Eq "(,,+|--+|,-|-,|,[ \t]*-|^[^[:digit:]])" && eval $(THROW 21 $_fn)
    return 0
}

assert_dataset_name() {
    local _fn="assert_dataset_name" _val="$1"

    echo "$_val" | grep -Eq "^[a-zA-Z][a-zA-Z0-9_.:-]*(/[a-zA-Z0-9_.:-]+)*$" \
        || eval $(THROW 17 $_fn)
    return 0
}

assert_devfs_rule() {
    local _fn="assert_devfs_rule"
    assert_int_comparison -g 0 "$1" || eval $(THROW 26 $_fn)
}

assert_integer() {
    local _fn="assert_integer"
    echo "$1" | grep -Eqs -- '^(-|[0-9])[0-9]*$' || eval $(THROW 13 $_fn)
}

# Checks that $1 is integer, and comparison boundaries are valid
# Prefer this implementation because error reporting is vastly better than [ x -gt y ] inbuilt
assert_int_comparison() {
    local _fn="assert_int_comparison" _opts OPTARG OPTIND _val _g _G _l _L

    while getopts :g:G:l:L: opts ; do case $opts in
        g) assert_integer "$OPTARG" && _g="$OPTARG" || eval $(THROW 13 _internal3 "$OPTARG") ;;
        G) assert_integer "$OPTARG" && _G="$OPTARG" || eval $(THROW 13 _internal3 "$OPTARG") ;;
        l) assert_integer "$OPTARG" && _l="$OPTARG" || eval $(THROW 13 _internal3 "$OPTARG") ;;
        L) assert_integer "$OPTARG" && _L="$OPTARG" || eval $(THROW 13 _internal3 "$OPTARG") ;;
        *) eval $(THROW 8 _internal1) ;;  # getopts warning suppressed because we handle it here
    esac  ;  done  ;  shift $(( OPTIND - 1 ))

    assert_integer "$1" && _val="$1" || eval $(THROW 13 _internal3 "$1")

    # Check each option one by one. Opts and _val already sanitized as integer format -> no quotes
    [ "$_g" ] && { [ $_val -ge $_g ] || eval $(THROW 14 ${_fn} "$_val" '<'  "$_g") ;}
    [ "$_G" ] && { [ $_val -gt $_G ] || eval $(THROW 14 ${_fn} "$_val" '<=' "$_G") ;}
    [ "$_l" ] && { [ $_val -le $_l ] || eval $(THROW 14 ${_fn} "$_val" '>'  "$_l") ;}
    [ "$_L" ] && { [ $_val -lt $_L ] || eval $(THROW 14 ${_fn} "$_val" '>=' "$_L") ;}

    return 0
}

# Optional $2: (_extra), to ensure that the last bit in the IP is not '1'.  It's required for the
# automated gateway/client management. But some assert_ipv4() calls might not care about this.
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
        || eval $(THROW 15 $_fn)

    # Ensures that each digit is within the proper range
    { [ "$_a0" -ge 0 ] && [ "$_a0" -le 255 ] && [ "$_a1" -ge 0 ] && [ "$_a1" -le 255 ] \
        && [ "$_a2" -ge 0 ] && [ "$_a2" -le 255 ] && [ "$_a3" -ge 0 ] && [ "$_a3" -le 255 ] \
        && [ "$_a4" -ge 0 ] && [ "$_a4" -le 32 ] ;} \
        || eval $(THROW 15 _fail2 IPV4 "$_val" "Use CIDR notation (with subnet)")

    # With the $_extra flag, reserve a.b.c.1 (ending in .1) for the gateway
    [ "$_a3" = "1" ] && eval $(THROW 15 ${_fn}_2)
    return 0
}

# Guarantee that $OPTARG is actually present (and not just another dash-option)
assert_optarg() {
    local _fn="assert_optarg"
    [ -z "$OPTARG" ] && eval $(THROW 25 $_fn)
    echo "$OPTARG" | grep -Eqs -- "^-" && eval $(THROW 25 $_fn)
    unset OPTARG  # Must unset, or stale value lingers (coz it's local-scoped)
}

# Ensures that $1 is part of the static PARAMS_ALL list
assert_param() {
    local _fn="assert_param"
    echo_grep -qd , "$PARAMS_ALL" "$1" || eval $(THROW 10 $_fn)
}

assert_params() {
    local _fn="assert_param" IFS=,
    for _param in $1 ; do
        assert_param $_param || eval $(THROW $?)
    done
}

assert_pass() {
    local _fn="assert_pass" _val="$1"
    echo "$_val" | grep -Eqs -- '^[0-9][0-9,]*$' || eval $(THROW 27 $_fn)
}

assert_pfx() {
    local _fn="assert_pfx" _val="$1"
    [ -z "$_val" ] && return 0  # _pfx can be null
    echo "$_val" | grep -Eqs -- "^[a-zA-Z0-9_]+\$" || eval $(THROW 28 $_fn)
}

assert_ppt() {
    local _fn="assert_ppt"
    echo "$1" | grep -Eqs -- '^[ 0-9]+/[0-9]+/[0-9]+([[:blank:]]+[0-9]+/[0-9]+/[0-9]+)*[[:blank:]]*$' \
        || eval $(THROW 33 $_fn "$1")
}

assert_ptype() {
    local _fn="assert_ptype" _val="$1"
    echo_grep -q "base BASE jail JAIL vm VM" "$_val" || eval $(THROW 24 $_fn)
}

assert_schg() {
    local _fn="assert_schg"
    case $1 in
        none|sys|all) return 0 ;;
        *) eval $(THROW 22 $_fn) ;;
    esac
}

assert_seclvl() {
    local _fn="assert_seclvl"
    case $1 in
        none|-1|-0|0|1|2|3) return 0 ;;
        *) eval $(THROW 23 $_fn) ;;
    esac
}

assert_taps() {
    local _fn="assert_taps"
    assert_int_comparison -g 0 -- "$1" || eval $(THROW 34 $_fn)
}
assert_time_format() {
    local _fn="assert_time_format" _val="$1"
    echo "$_val" | grep -Eqs "^[1-9]+[0-9]*(s|m|H|D|W|Y)\$" || eval $(THROW 20 $_fn)
}

assert_vcpus() {
    local _fn="assert_vcpus"
    assert_int_comparison -G 0 -- "$1" || eval $(THROW 35 $_fn)
}

