#!/bin/sh

################################  SECTION 1: GENERAL FORMAT CHECKS  ################################ 

chk_args_set() {
    local _fn="chk_args_set"
    local _require="$1" ; shift
    local _count="$#" _i=1 

    [ "$_count" -lt "$_require" ] && eval $(THROW 1 $_fn)

    for _arg in "$@" ; do
        [ "$_arg" = "${_arg#*[![:space:]]}" ] && eval $(THROW 1 $_fn)
        [ $_i -ge $_require ] && return 0 || _i=$(( _i + 1 ))
    done

    return 0
}

chk_bool_tf() {
    local _fn="chk_bool_tf"
    echo $1 | tr '[:upper:]' '[:lower:]' | grep -Eqs "true|false" || eval $(THROW 1 $_fn)
}

chk_integer() {
    local _fn="chk_integer"
    echo "$1" | grep -Eqs -- '^-*[0-9]+$' || eval $(THROW 1 $_fn $1)
}

chk_cellname() {
    local _fn="chk_cellname" _val="$1" 

    # Trigger words to avoid, just in case.
    case $_val in 
        none|qubsd) eval $(THROW 1 _invalid2 cellname $_val "Cannot be 'none' or 'qubsd'") ;;
    esac

    # Jail must start with :alnum: and afterwards, have only _ or - as special chars
    echo "$_val" | grep -E -- '^[[:alnum:]]([-_[:alnum:]])*[[:alnum:]]$' \
        | grep -Eqv '(--|-_|_-|__)' || eval $(THROW 1 $_fn $_val)
}

compare_integer() {
    # Checks that _value is integer, and can checks boundaries. [-n] is a descriptive variable name
    # from caller, for error message. Assumes that integers have been provided by the caller.
    local _fn="compare_integer" _val

    while getopts :g:G:l:L: opts ; do case $opts in
        g) local _g="$OPTARG" ;;
        G) local _G="$OPTARG" ;;
        l) local _l="$OPTARG" ;;
        L) local _L="$OPTARG" ;;
        *) eval $(THROW 1 internal) ;;   # getopts warning suppressed because we handle it here
    esac  ;  done  ;  shift $(( OPTIND - 1 ))
    _val="$1"

    # Check each option one by one
    [ "$_g" ] && { [ "$_val" -ge "$_g" ] || eval $(THROW 1 ${_fn} $_val '<'  $_g) ;}
    [ "$_G" ] && { [ "$_val" -gt "$_G" ] || eval $(THROW 1 ${_fn} $_val '<=' $_G) ;}
    [ "$_l" ] && { [ "$_val" -le "$_l" ] || eval $(THROW 1 ${_fn} $_val '>'  $_l) ;}
    [ "$_L" ] && { [ "$_val" -lt "$_L" ] || eval $(THROW 1 ${_fn} $_val '>=' $_L) ;} 

    return 0
}

##################################  SECTION 2: COMMON PARAMETERS  ##################################

chk_class() {
    local _fn="chk_class"
    echo "$CLASSES" | grep -Eqs -- "$1" || eval $(THROW 1 _invalid CLASS $1)
}

chk_ipv4() {
    local _fn="chk_ipv4" _val="$1" _b1 _b2 _b3

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
    echo "$_val" | grep -Eqs "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+/[[:digit:]]+" \
        || eval $(THROW 1 _invalid2 IPV4 "$_val" "Use CIDR notation with subnet")

    # Ensures that each digit is within the proper range
    { [ "$_a0" -ge 0 ] && [ "$_a0" -le 255 ] && [ "$_a1" -ge 0 ] && [ "$_a1" -le 255 ] \
        && [ "$_a2" -ge 0 ] && [ "$_a2" -le 255 ] && [ "$_a3" -ge 0 ] && [ "$_a3" -le 255 ] \
        && [ "$_a4" -ge 0 ] && [ "$_a4" -le 32 ] ;} \
        || eval $(THROW 1 _invalid2 IPV4 "$_val" "Use CIDR notation with subnet")

    # Reserve a.b.c.1 (ending in .1) for the gateway
    [ "$_a3" = "1" ] && eval $(THROW 1 ${_fn}2 $_val) || return 0
}

chk_bytesize() {
    local _fn="chk_bytesize"
    echo "$1" | grep -Eqs "^[[:digit:]]+(T|t|G|g|M|m|K|k)\$" || eval $(THROW 1 _invalid bytesize $1)
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

chk_cpuset() {
    local _fn="chk_cpuset"
    # Test for negative numbers and dashes in the wrong place
    echo "$1" | grep -Eq "(,,+|--+|,-|-,|,[ \t]*-|^[^[:digit:]])" && eval $(THROW 1 $_fn $1)
    return 0
}

chk_schg() {
    local _fn="chk_valid_schg"
    case $1 in
        none|sys|all) return 0 ;; 
        *) eval $(THROW 1 _invalid2 $1 "Must be <none|sys|all>") ;;
    esac
}

chk_valid_seclvl() {
    local _fn="chk_valid_seclvl"
    case $1 in
        none|-1|-0|0|1|2|3) return 0 ;;   
        *) eval $(THROW 1 _invalid2 $1 "Must be <none|-1|0|1|2|3>") ;; 
    esac
}


####################################  SECTION 4: VM PARAMETERS  ####################################

chk_bhyveopts() {
    local _fn="chk_bhyveopts" _val="$1"
    _val=$(echo "$_val" | sed -E 's/^-//')   # Remove the leading dash

    # Only includes bhyve opts with no argument
    echo "$_val" | grep -Eqs -- '^[AaCDeHhPSuWwxY]+$' || eval $(THROW 1 ${_fn}1 BHYVEOPTS $_val)
 
    # No duplicate characters
    [ "$(echo "$_val" | fold -w1 | sort | uniq -d | wc -l)" -gt 0 ] \
        && eval $(THROW 1 ${_fn}2 BHYVEOPTS $_val)

    return 0
}

chk_taps() {
    local _fn="chk_taps"
    compare_integer -g 0 -- "$1" || eval $(THROW 1 _invalid2 TAPS $1 "Must be an integer >= 0")
}

chk_vcpus() {
    local _fn="chk_vcpus"
    compare_integer -G 0 -- "$1" || eval $(THROW 1 _invalid2 VCPUS $1 "Must be an integer > 0")
}

normalize_ppt() {
    local _fn="normalize_ppt"
    echo "$1" | sed "s#/#:#g"
}

chk_ppt() {
    local _fn="chk_valid_ppt" _val
    
    [ "$_value" = "none" ] && eval $_R0

    # Get list of pci devices on the machine
    _pciconf=$(pciconf -l | awk '{print $1}')

    # Check all listed PPT devices from QCONF
    for _val in $_value ; do

        # convert _val to native pciconf format with :colon: instead of /fwdslash/
        _val2=$(echo "$_val" | sed "s#/#:#g")

        # Search for the individual device and specific device for devctl functions later
        _pciline=$(echo "$_pciconf" | grep -Eo ".*${_val2}")
        _pcidev=$(echo "$_pciline" | grep -Eo "pci.*${_val2}")

        # PCI device doesnt exist on the machine
        [ -z "$_pciline" ] && get_msg $_q -m _e22_0 -- "$_val" "PPT" \
            && get_msg $_q -m _e1 -- "$_val" "PPT" && eval $_R1
    done
}

pci_extra() {
	for _val in $_value ; do
		# Extra set of checks for the PCI device, if it's about to be attached to a VM
		if [ "$_xtra" ] ; then
			# First detach the PCI device, and examine the error message
			_dtchmsg=$(devctl detach "$_pcidev" 2>&1)
			[ -n "${_dtchmsg##*not configured}" ] && get_msg $_q -m _e22_1 -- "$_pcidev" \
					&& get_msg $_q -m _e22 -- "$_pcidev" "$_VM" && eval $_R1

			# Switch based on status of the device after being detached
			if pciconf -l $_pcidev | grep -Eqs "^none" ; then
				# If the device is 'none' then set the driver to ppt (it attaches automatically).
				! devctl set driver "$_pcidev" ppt && get_msg $_q -m _e22_2 -- "$_pcidev" \
					&& get_msg $_q -m _e22 -- "$_pcidev" "$_VM" && eval $_R1
			else
				# Else the devie was already ppt. Attach it, or error if unable
				! devctl attach "$_pcidev" && get_msg $_q -m _e22_3 -- "$_pcidev" \
					&& get_msg $_q -m _e22 -- "$_pcidev" "$_VM" && eval $_R1
			fi
		fi
	done
}


##################################################################################################
####################################  OLD  FUNCTIONS  ############################################
##################################################################################################


chk_truefalse() {
   local _fn="chk_truefalse" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

   while getopts qV _opts ; do case $_opts in
      q) local _qf='-q' ;;
      V) local _V="-V" ;;
   esac ; done ; shift $(( OPTIND - 1))

   local _value="$1"  ;  local _param="$2"
   [ -z "$_value" ] && get_msg $_qf -m _e0 -- "$_param" && eval $_R1

   # Must be either true or false.
   [ ! "$_value" = "true" ] && [ ! "$_value" = "false" ] \
         && get_msg $_qf -m _e10 -- "$_param" && eval $_R1
   eval $_R0
}

chk_integer2() {
   # Checks that _value is integer, and can checks boundaries. [-n] is a descriptive variable name
   # from caller, for error message. Assumes that integers have been provided by the caller.
   local _fn="chk_integer2" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

   while getopts g:G:l:L:qv:V opts ; do case $opts in
         g) local _g="$OPTARG" ; local _c="greater-than or equal to"
            ! echo "${_g}" | grep -Eq -- '^-*[0-9]+$' && get_msg $_q -m _e11 -- "$_g" && eval $_R1;;
         G) local _G="$OPTARG" ; local _c="greater-than"
            ! echo "${_G}" | grep -Eq -- '^-*[0-9]+$' && get_msg $_q -m _e11 -- "$_G" && eval $_R1;;
         l) local _l="$OPTARG" ; local _c="less-than or equal to"
            ! echo "${_l}" | grep -Eq -- '^-*[0-9]+$' && get_msg $_q -m _e11 -- "$_l" && eval $_R1;;
         L) local _L="$OPTARG" ; local _c="less-than"
            ! echo "${_L}" | grep -Eq -- '^-*[0-9]+$' && get_msg $_q -m _e11 -- "$_L" && eval $_R1;;
         v) local _p="$OPTARG" ;;
         V) local _V="-V" ;;
         q) local _q='-q' ;;
         *) get_msg -m _e9 ; eval $_R1 ;;
   esac  ;  done  ;  shift $(( OPTIND - 1 ))
   _val="$1"

   # Check that it's an integer
   ! echo "$_val" | grep -Eq -- '^-*[0-9]+$' && get_msg $_q -m _e11 -- "$_val" && eval $_R1

   # Check each option one by one
   [ "$_g" ] && [ ! "$_val" -ge "$_g" ] \
      && get_msg $_q -m _e12 -- "$_p" "$_val" "$_c" "$_g" && eval $_R1
   [ "$_G" ] && [ ! "$_val" -gt "$_G" ] \
      && get_msg $_q -m _e12 -- "$_p" "$_val" "$_c" "$_G" && eval $_R1
   [ "$_l" ] && [ ! "$_val" -le "$_l" ] \
      && get_msg $_q -m _e12 -- "$_p" "$_val" "$_c" "$_l" && eval $_R1
   [ "$_L" ] && [ ! "$_val" -lt "$_L" ] \
      && get_msg $_q -m _e12 -- "$_p" "$_val" "$_c" "$_L" && eval $_R1
   eval $_R0
}

##############################  JAIL/VM  PARAMETER CHECKS  ##############################
# These functions are often called programmatically in relation to PARAMETERS
# Return 1 on failure; otherwise, return 0

chk_valid_autostart() {
	local _fn="chk_valid_autostart" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	chk_truefalse $_q -- "$1" "AUTOSTART" && eval $_R0
	get_msg $_q -m _e1 -- "$1" "AUTOSTART" && eval $_R1
}

chk_valid_autosnap() {
	local _fn="chk_valid_autosnap" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	chk_truefalse $_q -- "$1" "AUTOSNAP" && eval $_R0
	get_msg $_q -m _e1 -- "$1" "AUTOSNAP" && eval $_R1
}

chk_valid_backup() {
	local _fn="chk_valid_backup" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	chk_truefalse $_q -- "$1" "BACKUP" && eval $_R0
	get_msg $_q -m _e1 -- "$1" "BACKUP" && eval $_R1
}

chk_valid_bhyveopts() {
	# Only options that have no additional OPTARG required, are allowed here
	local _fn="chk_valid_bhyveopts" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	_value="$1"

	# Only bhyve opts with no argument
	! echo "$_value" | grep -Eqs '^[AaCDeHhPSuWwxY]+$' \
			&& get_msg $_q -m _e14 -- "$_value" \
			&& get_msg $_q -m _e1 -- "$_value" "BHYVEOPTS" && eval $_R1

	# No duplicate characters
	[ "$(echo "$_value" | fold -w1 | sort | uniq -d | wc -l)" -gt 0 ] \
			&& get_msg $_q -m _e14_1 -- "$_value" \
			&& get_msg $_q -m _e1 -- "$_value" "BHYVEOPTS" && eval $_R1
	eval $_R0
}

chk_valid_class() {
	local _fn="chk_valid_class" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	local _value="$1"

	# Valid inputs are: appjail | rootjail | cjail | dispjail | appVM | rootVM
	case $_value in
		'') get_msg $_q -m _e0 -- "CLASS" && eval $_R1 ;;
		host|appjail|dispjail|rootjail|cjail|rootVM|appVM|dispVM) eval $_R0 ;;
		*) get_msg $_q -m _e15 && get_msg $_q -m _e1 -- "$_value" "CLASS" && eval $_R1 ;;
	esac
}

chk_valid_cpuset() {
	local _fn="chk_valid_cpuset" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	while getopts qV opts ; do case $opts in
			q) local _q="-q" ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	local _value="$1"
	[ -z "$_value" ] && get_msg $_q -m _e0 -- "CPUSET" && eval $_R1
	[ "$_value" = "none" ] && eval $_R0

	# Get the list of CPUs on the system, and edit for searching
	_validcpuset=$(cpuset -g | sed "s/pid -1 mask: //" | sed "s/pid -1 domain.*//")

	# Test for negative numbers and dashes in the wrong place
	echo "$_value" | grep -Eq "(,,+|--+|,-|-,|,[ \t]*-|^[^[:digit:]])" \
			&& get_msg $_q -m _e16 && get_msg $_q -m _e1 -- "$_value" "CPUSET" && eval $_R1

	# Remove `-' and `,' to check that all numbers are valid CPU numbers
	_cpuset_mod=$(echo $_value | sed -E "s/(,|-)/ /g")

	for _cpu in $_cpuset_mod ; do
		# Every number is followed by a comma except the last one
		! echo $_validcpuset | grep -Eq "${_cpu},|${_cpu}\$" \
			&& get_msg $_q -m _e16_1 -- "$_cpu" "${_validcpuset##*, }" \
			&& get_msg $_q -m _e1 -- "$_value" "CPUSET" && eval $_R1
	done
	eval $_R0
}

chk_valid_control() {
	local _fn="chk_valid_control" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _qt='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	local _value="$1"

	# 'none' is valid for control jail
	[ "$_value" = "none" ] && eval $_R0

	local _class=$(sed -nE "s/^${_value}[ \t]+CLASS[ \t]+//p" $QCONF)
	chk_valid_jail $_qt -c "$_class" -- "$_value" && eval $_R0
	get_msg $_qt -m _e1 -- "$_value" "CONTROL" && eval $_R1
}

chk_valid_devfs_rule() {
	local _fn="chk_valid_devfs_rule" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	local _value="$1"

	[ -z "$_value" ] && get_msg $_q -m _e0 -- "devfs_ruleset" && eval $_R1

	grep -Eqs -- "=${_value}\]\$|\[devfsrules.*${_value}\]\$" /etc/devfs.rules && eval $_R0
	get_msg $_q -m _e17 && get_msg $_q -m _e1 -- "$_value" "DEVFS_RULE" && eval $_R1
}

chk_valid_gateway() {
	local _fn="chk_valid_gateway" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _gw="$1"
	[ "$_gw" = "none" ] && eval $_R0

	# Nonlocal var, class of the gateway is important for jail startups
	local _class_gw=$(sed -nE "s/^${_gw}[ \t]+CLASS[ \t]+//p" $QCONF)

	# Class of gateway should never be a ROOTENV
	{ [ "$_class_gw" = "rootjail" ] || [ "$_class_gw" = "rootVM" ] ;} \
		&& get_msg $_q -m _e8 -- "$_gw" && get_msg $_q -m _e1 -- "$_gw" "GATEWAY" && eval $_R1

	# Check that gateway is a valid jail.
 	chk_valid_jail $_q -c "$_class_gw" -- "$_gw" && eval $_R0
	get_msg $_q $_V -m _e1 -- "$_value" "GATEWAY" && eval $_R1
}

chk_valid_ipv4() {
	# Tests for validity of IPv4 CIDR notation.
	# Variables below are globally assigned because they're required for performing other checks.
		# $_a0  $_a1  $_a2  $_a3  $_a4
	# -(q)uiet  ;  -(r)esolve _value  ;  -(x)tra check
	local _fn="chk_valid_ipv4" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qrVx opts ; do case $opts in
		q) local _q="-q" ;;
		r) local _rp="-r" ;;
		V) local _V="-V" ;;
		x) local _xp="-x" ;;
		*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	# !! _value is not local here, it might get reassigned !!
	_value="$1"  ;  local _jail="$2"

	case $_value in
		'') get_msg $_q -m _e0 -- "IPV4" && eval $_R1 ;;
		none|DHCP) eval $_R0 ;;
		auto) eval $_R0 ;;
	esac

	# Temporary variables used for checking ipv4 CIDR
	local _b1 ; local _b2 ; local _b3

	# Not as technically correct as a regex, but it's readable and functional
	# IP represented by the form: a0.a1.a2.a3/a4 ; b-variables are local/ephemeral
	_a0=${_value%%.*.*.*/*}
	_a4=${_value##*.*.*.*/}
		_b1=${_value#*.*}
		_a1=${_b1%%.*.*/*}
			_b2=${_value#*.*.*}
			_a2=${_b2%%.*/*}
				_b3=${_value%/*}
				_a3=${_b3##*.*.*.}

	# Ensures that each number is in the proper range
	! echo "$_value" \
		| grep -Eqs "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+/[[:digit:]]+" \
		&& get_msg $_q -m _e18 && get_msg $_q -m _e1 -- "$_value" "IPV4" && eval $_R1

	# Ensures that each digit is within the proper range
	! { [ "$_a0" -ge 0 ] && [ "$_a0" -le 255 ] && [ "$_a1" -ge 0 ] && [ "$_a1" -le 255 ] \
	 && [ "$_a2" -ge 0 ] && [ "$_a2" -le 255 ] && [ "$_a3" -ge 0 ] && [ "$_a3" -le 255 ] \
	 && [ "$_a4" -ge 0 ] && [ "$_a4" -le 32 ] ;} \
	 && get_msg $_q -m _e18 && get_msg $_q -m _e1 -- "$_value" "IPV4" && eval $_R1

	[ -n "$_xp" ] && chk_isqubsd_ipv4 $_q "$_value" "$_jail"
	eval $_R0
}

chk_isqubsd_ipv4() {
	# Checks for IP overlaps and/or mismatch in quBSD convention.
	local _fn="chk_isqubsd_ipv4" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _value="$1"  ;  local _jail="$2"
	[ -z "$_value" ] && get_msg $_q -m _e0 -- "IPV4"

	# $_a0 - $_a4 vars are needed later. Check that they're all here, or get them.
	echo "${_a0}#${_a1}#${_a2}#${_a3}#${_a4}" | grep -q "##" && chk_valid_ipv4 -q -- "$_value"

	# Assigning an IP of 'none' to a jail with clients, should throw a warning.
	[ "$_value" = "none" ] && [ -n "$(get_info -e CLIENTS $_jail)" ] \
		&& get_msg $_q -m _w3 -- "$_value" "$_jail" && eval $_R1

	# Otherwise, a value of none, auto, or DHCP are fine
	{ [ "$_value" = "none" ] || [ "$_value" = "auto" ] || [ "$_value" = "DHCP" ] ;} && eval $_R0

	# Compare against QCONF, and _USED_IPS.
	{ grep -v "^$_jail" $QCONF | grep -qs "$_value" \
		|| get_info -e _USED_IPS | grep -qs "${_value%/*}" ;} \
			&& get_msg $_q -m _w4 -- "$_value" "$_jail" && eval $_R1

	# NOTE:  $a2 and $ip2 are missing, because these are the variable positions
	! [ "$_a0.$_a1.$_a3/$_a4" = "$_ip0.$_ip1.$_ip3/$_subnet" ] \
			&& get_msg $_q -m _m9 -- "$_value" "$_jail" && eval $_R1

	# Assigning IP to jail that has no gateway
	[ "$(get_jail_parameter -deqs GATEWAY "$_jail")" = "none" ] \
			&& get_msg $_q -m _m7 -- "$_value" "$_jail" && eval $_R1

	eval $_R0
}

chk_valid_maxmem() {
	local _fn="chk_valid_maxmem" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _value="$1"
	[ -z "$_value" ] && get_msg $_q -m _e0 -- "MAXMEM" && eval $_R1
	[ "$_value" = "none" ] && eval $_R0

	# Per man 8 rctl, user can assign units: G|g|M|m|K|k
   ! echo "$_value" | grep -Eqs "^[[:digit:]]+(T|t|G|g|M|m|K|k)\$" \
			&& get_msg $_q -m _e19 -- "$_value" "MAXMEM" \
			&& get_msg $_q -m _e1 -- "$_value" "MAXMEM" && eval $_R1

	# Set values as numbers without units
	_bytes=$(echo $_value | sed -nE "s/.\$//p")
	_sysmem=$(grep "avail memory" /var/run/dmesg.boot | sed "s/.* = //" | sed "s/ (.*//" | tail -1)

	# Unit conversion to bytes
	case $_value in
		*T|*t) _bytes=$(( _bytes * 1000000000000 )) ;;
		*G|*g) _bytes=$(( _bytes * 1000000000 )) ;;
		*M|*m) _bytes=$(( _bytes * 1000000 ))    ;;
		*K|*k) _bytes=$(( _bytes * 1000 ))       ;;
	esac

	# Compare values, error if user input exceeds available RAM
	[ "$_bytes" -lt "$_sysmem" ] && eval $_R0
	get_msg $_q -m _e20 -- "$_value" "$_sysmem"
	get_msg $_q -m _e1 -- "$_value" "MAXMEM" && eval $_R1
}

chk_valid_memsize() {
	local _fn="chk_valid_memsize" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _value="$1"
	[ "$_value" = "none" ] && get_msg -m _e21 \
		&& get_msg $_q -m _e1 -- "$_value" "MEMSIZE" && eval $_R1

	# It's the exact same program/routine. Different QCONF params to be technically specific.
	chk_valid_maxmem $_q -- "$1" && eval $_R0 || eval $_R1
}

chk_valid_mtu() {
	local _fn="chk_valid_mtu" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	_value="$1"

	! chk_integer2 -v "MTU" -- "$_value" && get_msg $_q -m _e1 -- "$_value" "MTU" && eval $_R1
	chk_integer2 -g 1200 -l 1600 -v "MTU sanity check:" -- "$_value" && eval $_R0
	get_msg $_q -m _e1 -- "$_value" "MTU" && eval $_R1
}

chk_valid_no_destroy() {
	local _fn="chk_valid_no_destroy" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	chk_truefalse $_q -- "$1" "NO_DESTROY" && eval $_R0
	get_msg $_q -m _e1 -- "$1" "NO_DESTROY" && eval $_R1
}

chk_valid_ppt() {
	local _fn="chk_valid_ppt" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qVx opts ; do case $opts in
			q) local _q="-q" ;;
			V) local _V="-V" ;;
			x) local _xtra="true" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	_value="$1"
	[ -z "$_value" ] && get_msg $_q -m _e0 -- "PPT (passthru) device" && eval $_R1
	[ "$_value" = "none" ] && eval $_R0

	# Get list of pci devices on the machine
	_pciconf=$(pciconf -l | awk '{print $1}')

	# Check all listed PPT devices from QCONF
	for _val in $_value ; do

		# convert _val to native pciconf format with :colon: instead of /fwdslash/
		_val2=$(echo "$_val" | sed "s#/#:#g")

		# Search for the individual device and specific device for devctl functions later
		_pciline=$(echo "$_pciconf" | grep -Eo ".*${_val2}")
		_pcidev=$(echo "$_pciline" | grep -Eo "pci.*${_val2}")

		# PCI device doesnt exist on the machine
		[ -z "$_pciline" ] && get_msg $_q -m _e22_0 -- "$_val" "PPT" \
			&& get_msg $_q -m _e1 -- "$_val" "PPT" && eval $_R1

		# Extra set of checks for the PCI device, if it's about to be attached to a VM
		if [ "$_xtra" ] ; then
			# First detach the PCI device, and examine the error message
			_dtchmsg=$(devctl detach "$_pcidev" 2>&1)
			[ -n "${_dtchmsg##*not configured}" ] && get_msg $_q -m _e22_1 -- "$_pcidev" \
					&& get_msg $_q -m _e22 -- "$_pcidev" "$_VM" && eval $_R1

			# Switch based on status of the device after being detached
			if pciconf -l $_pcidev | grep -Eqs "^none" ; then
				# If the device is 'none' then set the driver to ppt (it attaches automatically).
				! devctl set driver "$_pcidev" ppt && get_msg $_q -m _e22_2 -- "$_pcidev" \
					&& get_msg $_q -m _e22 -- "$_pcidev" "$_VM" && eval $_R1
			else
				# Else the devie was already ppt. Attach it, or error if unable
				! devctl attach "$_pcidev" && get_msg $_q -m _e22_3 -- "$_pcidev" \
					&& get_msg $_q -m _e22 -- "$_pcidev" "$_VM" && eval $_R1
			fi
		fi
	done
	eval $_R0
}

chk_valid_rootenv() {
	local _fn="chk_valid_rootenv" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _value="$1"
	[ -z "$_value" ] && get_msg $_q -m _e0 -- "CLASS" && eval $_R1

	# Must be designated as a ROOTENV in QCONF
	local _class=$(sed -nE "s/${_value}[ \t]+CLASS[ \t]+//p" $QCONF)
	case $_class in
		'') get_msg $_q -m _e2 -- "$_value" "CLASS"
			 get_msg $_q -m _e1 -- "$_value" "ROOTENV" && eval $_R1
			;;
		rootjail|rootVM) : ;;
		*) get_msg $_q -m _e23 -- "$_class" "CLASS"
			get_msg $_q -m _e1 -- "$_value" "ROOTENV" && eval $_R1
			;;
	esac

	# Perform all other checks for valid jail.
	chk_valid_jail $_q $_V -c "$_class" -- "$_value"
}

chk_valid_seclvl() {
	local _fn="chk_valid_seclvl" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _value="$1"
	[ -z "$_value" ] && get_msg $_q -m _e0 -- "SECLVL" && eval $_R1
	[ "$_value" = "none" ] && eval $_R0

	# If SECLVL is not a number
	! echo "$_value" | grep -Eq -- '^(-1|-0|0|1|2|3)$' \
			&& get_msg $_q -m _e24 -- "$_value" "SECLVL" && eval $_R1

	eval $_R0
}

chk_valid_taps() {
	# Taps in QCONF just lists how many are wanted
	local _fn="chk_valid_taps" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q -m _e0 -- "TAPS" && eval $_R1

	# Make sure that it's an integer
	for _val in $_value ; do
		! chk_integer2 -g 0 -v "Number of TAPS (in QCONF)," -- $_value \
			 && get_msg $_q -m _e1 -- "$_value" "TAPS" && eval $_R1
	done

	eval $_R0
}

chk_valid_tmux() {
	local _fn="chk_valid_tmux" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	chk_truefalse $_q -- "$1" "TMUX" && eval $_R0
	get_msg $_q -m _e1 -- "$1" "TMUX" && eval $_R1
}

chk_valid_schg() {
	local _fn="chk_valid_schg" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	local _value="$1"

	# Valid inputs are: none | sys | all
	case $_value in
		'') get_msg $_q -m _e0 -- "SCHG" && eval $_R1 ;;
		none|sys|all) eval $_R0 ;;
		*) get_msg $_q -m _e25 -- "$_value" "SCHG" && eval $_R1 ;;
	esac
	eval $_R0
}

chk_valid_template() {
	local _fn="chk_valid_template" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _qt='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	local _value="$1"

	chk_valid_jail $_qt -- "$_value" && eval $_R0
	eval $_R0
}

chk_valid_vcpus() {
	# Make sure the formatting is correct, and the CPUs exist on the system
	local _fn="chk_valid_vcpus" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _value="$1"
	[ -z "$_value" ] && get_msg $_q -m _e0 -- "VCPUS" && eval $_R1

	# Get the number of CPUs on the system
	_syscpus=$(cpuset -g | head -1 | grep -oE "[^ \t]+\$")
	_syscpus=$(( _syscpus + 1 ))

	# Ensure that the input is a number
	! chk_integer2 -G 0 -v "Number of VCPUS" -- $_value \
		&& get_msg $_q -m _e1 -- "$_value" "VCPUS" && eval $_R1

	# Ensure that vpcus doesnt exceed the number of system cpus or bhyve limits
	if [ "$_value" -gt "$_syscpus" ] || [ "$_value" -gt 16 ] ; then
		get_msg $_q -m _e27 -- "$_value" "$_syscpus"
		get_msg $_q -m _e1 -- "$_value" "VCPUS" && eval $_R1
	fi

	eval $_R0
}

chk_valid_vnc() {
	# Make sure that the resolution is supported by bhyve
	local _fn="chk_valid_vnc" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	_value="$1"

	case $_value in
		# If value was provided as "true" then assign the default resolution.
		true) _value=1920x1080 ; eval $_R0 ;;
		none|false|640x480|800x600|1024x768|1920x1080) eval $_R0 ;;
		'') get_msg $_q -m _e0 -- "VNC" && eval $_R1 ;;
		*) get_msg $_q -m _e27 -- "VNC" && eval $_R1 ;;
	esac
}

chk_valid_wiremem() {
	local _fn="chk_valid_wiremem" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	chk_truefalse $_q -- "$1" "WIREMEM" && eval $_R0
	get_msg $_q -m _e1 -- "$1" "WIREMEM" && eval $_R1
}

chk_valid_x11() {
	local _fn="chk_valid_x11" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))
	chk_truefalse $_q -- "$1" "X11FWD" && eval $_R0
	get_msg $_q -m _e1 -- "$1" "X11FWD" && eval $_R1
}

chk_valid_jail() {
   # Checks that jail has JCONF, QCONF, and corresponding ZFS dataset
   # Return 0 for passed all checks, return 1 for any failure
   local _fn="chk_valid_jail" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

   local _class= ; local _template= ; local _class_of_temp=
   while getopts c:qV opts ; do case $opts in
         c) _class="$OPTARG" ;;
         q) local _qv='-q' ;;
         V) local _V="-V" ;;
         *) get_msg -m _e9 ;;
   esac  ;  done  ;  shift $(( OPTIND - 1 )) ; [ "$1" = "--" ] && shift

   # Positional parmeters and function specific variables.
   local _value="$1"
   [ -z "$_value" ] && get_msg $_qv -m _e0 -- "jail" && eval $_R1

   # _class is a necessary element of all jails. Use it for pulling datasets
   [ -z "$_class" ] && _class=$(get_jail_parameter -eqs CLASS $_value)

   # Must have a ROOTENV in QCONF.
   ! grep -Eqs "^${_value}[ \t]+ROOTENV[ \t]+[^ \t]+" $QCONF \
      && get_msg $_qv $_V -m _e2 -- "$_value" "ROOTENV" \
      && get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1

   # Jails must have an entry in JCONF
   ! chk_isvm -c $_class "$_value" && [ ! -e "${JCONF}/${_value}" ] \
         && get_msg $_qv -m _e7 -- "$_value" && get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1
    
   case $_class in
      "") # Empty, no class exists in QCONF
         get_msg $_qv $_V -m _e2 -- "jail" "$_value" \  
         get_msg $_qv $_V -m _e1 -- "$_value" "class" && eval $_R1
         ;;
      rootjail) # Rootjail's zroot dataset should have no origin (not a clone)
         ! zfs get -H origin ${R_ZFS}/${_value} 2> /dev/null | awk '{print $3}' | grep -Eq '^-$' \
             && get_msg $_qv -m _e5 -- "$_value" "$R_ZFS" \
             && get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1
         ;;
      appjail|cjail) # Appjails require a dataset at quBSD/zusr
         ! chk_valid_zfs ${U_ZFS}/${_value} \
            && get_msg $_qv -m _e5 -- "${_value}" "${U_ZFS}" \
            && get_msg $_qv -m _e1 -- "${U_ZFS}/${_value}" "ZFS dataset" && eval $_R1
         ;;
      dispjail) # Verify the dataset of the template for dispjail
         # Template cant be blank
         local _template=$(get_jail_parameter -deqs TEMPLATE $_value)
         [ -z "$_template" ] && get_msg $_qv -m _e2 -- "$_value" "TEMPLATE" \
            && get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1
    
         # Dispjails can't reference other dispjails
         local _templ_class=$(sed -nE "s/^${_template}[ \t]+CLASS[ \t]+//p" $QCONF)
         [ "$_templ_class" = "dispjail" ] \
            && get_msg $_qv -m _e6_1 -- "$_value" "$_template" && eval $_R1

         # Ensure that the template being referenced is valid
         ! chk_valid_jail $_qv -c "$_templ_class" -- "$_template" \
            && get_msg $_qv -m _e6_2 -- "$_value" "$_template" \
            && get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1
         ;;
      rootVM) # VM zroot dataset should have no origin (not a clone)
         ! zfs get -H origin ${R_ZFS}/${_value} 2> /dev/null | awk '{print $3}' \
            | grep -Eq '^-$'  && get_msg $_qv -m _e5 -- "$_value" "$R_ZFS" && eval $_R1
         ;;
      *VM) :
         ;;
      *) # Any other class is invalid
         get_msg $_qv -m _e1 -- "$_class" "CLASS" \
         get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1
         ;;
   esac

   # One more case statement for VMs vs jails
   case $_class in
      *jail)
   esac

   eval $_R0
}

