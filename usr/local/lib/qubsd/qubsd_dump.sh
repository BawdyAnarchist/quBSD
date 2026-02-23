#!/bin/sh

chk_valid_zfs() {
   # Silently verifies existence of zfs dataset, because zfs has no quiet option
   zfs list -- $1 >> /dev/null 2>&1  &&  return 0  ||  return 1
}

get_global_variables() {
	# Global config files, mounts, and datasets needed by most scripts

	# Remove any old ERR files (for exec commands)
	[ "$ERR1" ] && [ "$ERR2" ] && rm_errfiles

	# Remove blanks at end of line, to prevent bad variable assignments.
	sed -i '' -E 's/[ \t]*$//' $QCONF
	# Get datasets, mountpoints; and define files.
   export R_ZFS=$(sed -nE "s:#NONE[ \t]+jails_zfs[ \t]+::p" $QCONF)
   export U_ZFS=$(sed -nE "s:#NONE[ \t]+zusr_zfs[ \t]+::p" $QCONF)
	[ -z "$R_ZFS" ] && get_msg -V -m "_e0_1" "jails_zfs" && exit 1
	[ -z "$U_ZFS" ] && get_msg -V -m "_e0_1" "zusr_zfs" && exit 1
	! chk_valid_zfs "$R_ZFS" && get_msg -V -m _e0_2 -- "jails_zfs" "$R_ZFS" && exit 1
	! chk_valid_zfs "$U_ZFS" && get_msg -V -m _e0_2 -- "zusr_zfs" "$U_ZFS" && exit 1
	export M_QROOT=$(zfs get -H mountpoint $R_ZFS | awk '{print $3}')
	export M_ZUSR=$(zfs get -H mountpoint $U_ZFS | awk '{print $3}')
	[ "$M_QROOT" = "-" ] && get_msg -V -m _e0_3 "$R_ZFS" && exit 1
	[ "$M_ZUSR" = "-" ]  && get_msg -V -m _e0_3 "$U_ZFS" && exit 1

	# Set the files for error recording, and trap them
	[ -d "$QRUN" ] || mkdir $QRUN
	export ERR1=$(mktemp ${QRUN}/err1_${0##*/}.XXXX)
	export ERR2=$(mktemp ${QRUN}/err2_${0##*/}.XXXX)
	trap "rm_errfiles" HUP INT TERM QUIT EXIT

	return 0
}

get_parameter_lists() {
	# Primarily returns global varibles: CLASS ; ALL_PARAMS ; but also a few others
	local _fn="get_parameter_lists" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# [-n] suppresses separation of parameters into groups by CLASS (we dont always have CLASS yet)
	while getopts nqV _opts ; do case $_opts in
		n) local _nc="true" ;;
		q) local _q="-q" ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	# List out normal parameters which can be checked (vs BHYVE_CUSTM)
	COMN_PARAMS="AUTOSTART AUTOSNAP BACKUP CLASS CONTROL CPUSET GATEWAY IPV4 MTU NO_DESTROY ROOTENV"
	JAIL_PARAMS="MAXMEM SCHG SECLVL"
	VM_PARAMS="BHYVEOPTS MEMSIZE TAPS TMUX VCPUS VNC WIREMEM X11"
	MULT_LN_PARAMS="BHYVE_CUSTM PPT"
	ALL_PARAMS="$COMN_PARAMS $JAIL_PARAMS TEMPLATE $VM_PARAMS $MULT_LN_PARAMS"
	NON_QCONF="DEVFS_RULE"

	# Unless suppressed with [-n], group by CLASS
	if [ -z "$_nc" ] ; then
		[ -z "$CLASS" ] && get_jail_parameter -qs CLASS "$JAIL"

		case $CLASS in
			appVM|rootVM) FILT_PARAMS="$COMN_PARAMS $VM_PARAMS $MULT_LN_PARAMS" ;;
			dispVM) FILT_PARAMS="$COMN_PARAMS $VM_PARAMS $MULT_LN_PARAMS TEMPLATE" ;;
			dispjail) FILT_PARAMS="$COMN_PARAMS $JAIL_PARAMS TEMPLATE" ;;
			appjail|rootjail|cjail) FILT_PARAMS="$COMN_PARAMS $JAIL_PARAMS" ;;
			host) FILT_PARAMS="GATEWAY IPV4 MTU AUTOSNAP" ;;
		esac
	fi
	eval $_R0
}

get_user_response() {
	# Exits successfully if response is y or yes
	# Optional $1 input - `severe' ; which requires a user typed `yes'
	read _response

	# If flagged with positional parameter `severe' require full `yes'
	if [ "$1" = "severe" ] ; then
		case "$_response" in
			yes|YES) return 0	;;
			*) return 1 ;;
		esac
	fi

	case "$_response" in
		y|Y|yes|YES) return 0	;;
		exit|quit) get_msg -m _m3 && exit 0 ;;
		# Only return success on positive response. All else fail
		*)	return 1 ;;
	esac
}

get_jail_parameter() {
	# Get corresponding <value> for <jail> <param> from QCONF.
	# Assigns global variable of ALL CAPS <param> name, with <value>
	 # -dp: If _value is null, retreive #default from QCONF
	 # -ep: echo _value rather than setting global variable. If using inside $(command_substitution),
	 	  ## best to use [-q] with it to prevent unpredictable behavior
	 # -qp: quiet any error/alert messages. Otherwise error messages are shown.
	 # -rp: resolve value. Some values are "auto" and need further resolution.
	 # -sp: skip checks, and return 0 regardless of failures, errors, or blanks
	 # -xp: extra checks. Some cases benefit from an extra check only invoked at certain moments
	 # -zp: don't error on zero/null values, just return
	local _fn="get_jail_parameter" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Ensure all options variables are reset
	local _dp=  _ep=  _qp=  _rp=  _sp=  _xp=  _zp=  _V=
	while getopts deqrsVxz opts ; do case $opts in
			d) _dp="-d" ;;
			e) _ep="-e" ;;
			q) _qp="-q" ;;
			r) _rp="-r" ;;
			s) _sp="$_R0" ;;
			V) _V="-V" ;;
			x) _xp="-x" ;;
			z) _zp="true" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	# Positional and function variables
	local _param="$1"  _jail="$2"  _value=''
	local _low_param=$(echo "$_param" | tr '[:upper:]' '[:lower:]')

	# Either jail or param weren't provided
	[ -z "$_param" ] && get_msg $_qp $_V -m _e0 -- "PARAMETER and jail" && eval "$_sp $_R1"
	[ -z "$_jail" ]  && get_msg $_qp $_V -m _e0 -- "jail" && eval "$_sp $_R1"

	# Get the <_value> from QCONF.
	_value=$(sed -nE "s/^${_jail}[ \t]+${_param}[ \t]+//p" $QCONF)

	# Substitute <#default> values, so long as [-d] was not passed
	[ -z "$_value" ] && [ -n "$_dp" ] \
		&& _value=$(sed -nE "s/^#default[ \t]+${_param}[ \t]+//p" $QCONF)

	# If still blank, check for -z or -s options. Otherwise err message and return 1
	if [ -z "$_value" ] ; then
		[ "$_zp" ] && eval $_R0
		[ "$_sp" ] && eval $_R0
		get_msg $_qp $_V -m _e2 -- "$_jail" "$_param" && eval $_R1
	fi

	# If -s was provided, checks are skipped by this eval
	if ! [ "$_sp" ] ; then
		# Variable indirection for checks. Escape \" avoids word splitting
		! eval "chk_valid_${_low_param}" $_qp $_rp $_xp '--' \"$_value\" \"$_jail\" \
			&& get_msg $_qp $_V -m _e3 -- "$_jail" "$_param" && eval $_R1
	fi

	# Either echo <value> , or assign global variable (as specified by caller).
	[ "$_ep" ] && echo "$_value" || eval $_param=\"$_value\"

	eval $_R0
}

get_info() {
	# Commonly required information that's not limited to jails or jail parameters
	# Use $1 to indicate the _info desired from case statement
	local _fn="get_info" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	local _sp=

	while getopts eqsV _opts ; do case $_opts in
		e) local _ei="-e" ;;
		q) local _q="-q" ;;
		s) local _sp="$R0" ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _info="$1"  _jail="$2"  _value=''

	# Either jail or param weren't provided
	[ -z "$_info" ] && get_msg $_qp -m _e0 -- "INFO PARAMETER" && eval "$_sp $_R1"

	case $_info in
		_CLIENTS)  # All _clients listed in QCONF, which depend on _jail as a gateway
			_value=$(sed -nE "s/[ \t]+GATEWAY[ \t]+${_jail}//p" $QCONF)
			;;
		_ONJAILS)  # All jails/VMs that are currently running
			_value=$(jls | sed "1 d" | awk '{print $2}' ; \
						pgrep -fl 'bhyve: ' | sed -E "s/.*[ \t]([^ \t]+)\$/\1/")
			;;
		_NEEDPOP) # Determine if process is detached, but Xorg is running (needs a popup)
			! ps -p $$ -o state | grep -qs -- '+' && pgrep -fq Xorg && _value="true"
			;;
		_USED_IPS) # List of ifconfig inet addresses for all running jails/VMs
			for _onjail in $(jls | sed "1 d" | awk '{print $2}') ; do
				_intfs=$(jexec -l -U root "$_onjail" ifconfig -a inet | grep -Eo "inet [^ \t]+")
				_value=$(printf "%b" "$_value" "\n" "$_intfs")
			done
			;;
		_XID)    # X11 window ID of the current active window
			_value=$(xprop -root _NET_ACTIVE_WINDOW | sed "s/.*window id # //")
			;;
		_XJAIL)  # Gets the jailname of the active window. Converts $HOSTNAME to: "host"
			_xid=$(get_info -e _XID)
			if [ "$_xid" = "0x0" ] || echo "$_xid" | grep -Eq "not found" \
					|| xprop -id $_xid WM_CLIENT_MACHINE | grep -Eq $(hostname) ; then
				_value=host
			else
				_xsock=$(xprop -id $_xid | sed -En "s/^WM_NAME.*:([0-9]+)\..*/\1/p")
				_value=$(pgrep -fl "X11-unix/X${_xsock}" | head -1 | sed -En \
								"s@.*var/run/qubsd/X11/(.*)/.X11-unix/X${_xsock},.*@\1@p")
			fi
			;;
		_XNAME)  # Gets the name of the active window
			_value=$(xprop -id $(get_info -e _XID) WM_NAME _NET_WM_NAME WM_CLASS)
			;;
		_XSOCK)  # Gets the socket number of the active window
			_xid=$(get_info -e _XID)
			_value=$(xprop -id $_xid | sed -En "s/^WM_NAME.*:([0-9]+)\..*/\1/p")
			;;
		_XPID)   # Gets the PID of the active window.
			_value=$(xprop -id $(get_info -e _XID) _NET_WM_PID | grep -Eo "[[:alnum:]]+$")
			;;
	esac

	# If null, return failure immediately
	[ -z "$_value" ] && [ -z "$_sp" ] && eval $_R1

	# Sort values
	_value=$(echo "$_value" | sort)

	# Echo option signalled
	[ "$_ei" ] && echo "$_value" && eval $_R0

	# Assign global if no other option/branch was specified (default action).
	eval ${_info}=\"${_value}\"
	eval $_R0
}

get_jail_shell() {
	local _fn="get_jail_shell" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts eqr:V opts ; do case $opts in
			e) local _ec='true' ;;
			q) local _qv='-q' ;;
			r) local _rootenv="$OPTARG" ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 )) ; [ "$1" = "--" ] && shift

	# Positional parmeters and function specific variables.
	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_qv -m _e0 -- "jail" && eval $_R1

	# First check jail/rw/etc/ directory
	_shell=$(pw -V ${M_ZUSR}/${_jail}/rw/etc usershow -n ${_jail} 2>&1 \
			| sed -En "s@.*${_jail}:(/bin/[a-z]+)@\1@p")

	# If that didn't work, then use the ROOTENV user
	if [ -z "$_shell" ] ; then
		[ -z "$_rootenv" ] && _rootenv=$(get_jail_parameter -eqs ROOTENV $_jail)
		_shell=$(pw -V ${M_QROOT}/${_rootenv}/etc usershow -n ${_rootenv} 2>&1 \
			| sed -En "s@.*${_rootenv}:(/bin/[a-z]+)@\1@p") \

		# If there is no ROOTENV user, then use the root shell of the ROOTENV
		[ -z "$_shell" ] &&_shell=$(pw -V ${M_QROOT}/${_rootenv}/etc usershow -n root 2>&1 \
				| sed -En "s@.*root:(/bin/[a-z]+)@\1@p")
	fi

	# Either echo the value, or globalize it to the SHELL variable
	[ -n "$_ec" ] && echo $_shell || SHELL=${_shell}
	eval $_R0
}

compile_jlist() {
	# Called only by qb-start and qb-stop. Uses global variables, which isn't best practice,
	# but they should be unique, and not found in other programs.
	local _fn="compile_jlist" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	case "${_SOURCE}" in
		'')
			# If both SOURCE and POSPARAMS are empty, there is no JLIST.
			[ -z "$_POSPARAMS" ] && get_msg -m _e31 && eval $_R1
			_JLIST="$_POSPARAMS"

			# If there was no SOURCE, then [-e] makes the positional params ambiguous
			[ "$_EXCLUDE" ] && get_msg -m _e31_1 && eval $_R1
		;;

		auto)
			# Find jails tagged with autostart in QCONF.
			_JLIST=$(grep -E "AUTOSTART[ \t]+true" $QCONF | awk '{print $1}' | uniq)
		;;

		all)
			# ALL jails from QCONF, except commented lines
			_JLIST=$(awk '{print $1}' $QCONF | uniq | sed "/^#/d")
		;;

		?*)
			# Only possibility remaining is [-f]. Check it exists, and assign JLIST
			[ -e "$_SOURCE" ] && _JLIST=$(tr -s '[:space:]' '\n' < "$_SOURCE" | uniq) \
					|| { get_msg -m _e31_2 && eval $_R1 ;}
		;;
	esac

	# If [-e], then the exclude list is just the JLIST, but error if null.
	[ "$_EXCLUDE" ] && _EXLIST="$_POSPARAMS" && [ -z "$_EXLIST" ] && get_msg -m _e31_3 && eval $_R1

	# If [-E], make sure the file exists, and if so, make it the exclude list
	if [ "$_EXFILE" ] ; then
		[ -e "$_EXFILE" ] && _EXLIST=$(tr -s '[:space:]' '\n' < "$_EXFILE")	\
			|| { get_msg -m _e31_4 && eval $_R1 ;}
	fi

	# Remove any jail on EXLIST, from the JLIST
	for _exlist in $_EXLIST ; do
		_JLIST=$(echo "$_JLIST" | grep -Ev "^[ \t]*${_exlist}[ \t]*\$")
	done

	[ -z "$_JLIST" ] && get_msg -m _e31_5 && eval $_R1
	eval $_R0
}

chk_isblank() {
	# Seems there are only verbose POSIX ways to test a variable is either null contains spaces.
	[ "$1" = "${1#*[![:space:]]}" ] && return 0  ||  return 1
}

chk_isrunning() {
	# Return 0 if jail/VM is running; return 1 if not.
	local _jail="$1"
	[ -z "$_jail" ] && return 1
   [ "$_jail" = "host" ] && return 0
	jls -j "$1" > /dev/null 2>&1  && return 0
	pgrep -xqf "bhyve: $_jail" > /dev/null 2>&1  && return 0

	# Neither jail nor bhyve were found. Return error
	return 1
}

chk_isvm() {
	# Checks if the positional variable is the name of a VM, return 0 if true 1 of not
	local _fn="chk_isvm" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	getopts c _opts && local _class='true' && shift
	local _value="$1"

	# If -c was passed, then use the $1 as a class, not as a jailname
	[ "$_class" ] && [ "$_value" ] && [ -z "${_value##*VM}" ] && eval $_R0

	get_jail_parameter -eqs CLASS $_value | grep -qs "VM" && eval $_R0
	eval $_R1
}


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

