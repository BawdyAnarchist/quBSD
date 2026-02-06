#!/bin/sh

###################################  BOOLEAN RESPONSE QUERIES  #####################################

is_path_exist() {
    local _fn="is_path_exist"
    chk_args_set 2 $1 $2 || eval $(THROW 1)
    [ $1 $2 ] && return 0 || eval $(THROW 1 $_fn $2)
}

is_zfs_exist() {
    local _fn="is_zfs_exist"
    chk_args_set 1 $1 || eval $(THROW 1)
    quiet zfs list -- $1 || eval $(THROW 1 $_fn $1) 
}

is_cell_running() {
    local _fn="is_zfs_exist" _cell="$1"
    chk_args_set 1 $_cell || eval $(THROW 1)

    [ "$_cell" = "host" ] && return 0
    quiet jls -j "$_cell" && return 0
    quiet pgrep -xqf "bhyve: $_jail" && return 0
    eval $(THROW 1 $_fn $_cell)
}

# Determine if process is detached, but Xorg is running (needs a popup). Failure THROW unnecessary
is_needpop() {
    ! ps -p $$ -o state | grep -qs -- '+' && pgrep -fq Xorg && return 0 || return 1
}

# return 0 for "Y/y". Optional $1=`severe` for a hard-typed `yes` required from the user 
query_user_response() {
    local _fn="query_user_response" _response

    read _response
    _response=$(echo $_response | tr '[:upper:]' '[:lower:]')

    # If flagged with positional parameter `severe' require full `yes'
    case "$1:$_response" in
        severe:yes) return 0 ;;
        :y|:yes) return 0 ;;
        *) eval $(THROW 1 $_fn) ;;
    esac
}

########################################  GET CELL CONFIG  #########################################

# Return [JAIL|VM] based on $1 CLASS. Bootstraps parameter sourcing
query_cell_type() {
    local _fn="resolve_cell_type" _cell _type
    chk_args_set 1 $1 && _cell="$1" || eval $(THROW 1)
    is_path_exist -f $D_CELLS/$_cell || eval $(THROW 1)

    # This function is used for bootstrap. Do not rely on external functions. Hardcode CLASS
    _type=$(sed -En "s/CLASS=\"(.*)\"/\1/p" $D_CELLS/$_cell)
    case $_type in
        *jail) echo "JAIL" ;;
        *VM) echo "VM" ;;
        *) eval $(THROW 1 $_fn $_cell $_type) ;;
    esac

    return 0
}

# Single parameter extraction from cell config
query_cell_param() {
    local _fn="query_cell_param" _cell="$1" _param="$2" _val _type _def_type
    chk_args_set 2 $_cell $_param || eval $(THROW 1)

    # Happy path -> parameter found immediately in the cell conf
    _val=$(sed -En "s/^[ \t]*$_param=\"(.*)\"[ \t]*/\1/p" $D_CELLS/$_cell)
    [ "$_val" ] && echo "$_val" && return 0

    # Backup path -> check the defaults
    _type=$(query_cell_type $_cell) || eval $(THROW 1)
    eval _def_type=\${DEF_${_type}}

    # _type defaults are prioritized over base defaults
    _val=$(sed -En "s/^[ \t]*$_param=\"(.*)\"[ \t]*/\1/p" $_def_type)
    [ "$_val" ] && echo "$_val" && return 0

    _val=$(sed -En "s/^[ \t]*$_param=\"(.*)\"[ \t]*/\1/p" $DEF_BASE)
    [ "$_val" ] && echo "$_val" && return 0

    # Failed to find a value for the parameter
    eval $(THROW 1 ${_fn} $_param $_cell)
}

# All clients that a gateway serves
query_cell_clients() {
    local _fn="query_clients" _val
    chk_args_set 1 $1 || eval $(THROW 1)

    _val=$(grep -Eo "GATEWAY=\"$1\"" $D_CELLS/* \
          | sed -En "s|$D_CELLS/(.*):.*|\1|p") || eval $(THROW 1 $_fn $1)

    [ -z "$_val" ] && eval $(THROW 1 $_fn $1)
    echo $_val   # Intentionally not quoted so items present as a single-line list
}

# Provide either the explicit cell shell from /overlay, or use the 0zusr default
query_cell_shell() {
    local _fn="query_cell_shell" _cell="$1" _user="$2" _val
    chk_args_set 2 $_cell $_user || eval $(THROW 1)

    # First check $_user at the source
    if [ "$_user" = "root" ] ; then
        _val=$(pw -V $R_MNT/$_cell/etc usershow -n root | awk -F':' '{print $10}')
    else
        _val=$(awk -F':' '{print $10}' $U_MNT/$_cell/$PW_LOC)
    fi

    # Fallback to the 0zusr default if not found 
    [ -z "$_val" ] && _val=$(awk -F':' '{print $10}' $U_MNT/0zusr/$PW_LOC)

    [ -z "$_val" ] && eval $(THROW 1 $_fn $_cell)
    echo "$_val"
}

#####################################  SYSTEM STATE QUERIES  #######################################

query_onjails() {
    local _fn="query_onjails" _val
    _val=$(jls | sed "1 d" | awk '{print $2}')
    [ -z "$_val" ] && return 1
    echo $_val   # Intentionally not quoted, so items present as a single-line list
}

# With $1 < cell>, all active IPaddr of a running jail. Without $1, active IPs of all running jails
query_running_ips() {
    local _fn="query_used_ips" _cell="$1" _val _onjails _jail_ips

    if [ "$_cell" ] ; then
        _val=$(ifconfig -j $_cell -a inet | awk '/inet / {print $2}')
    else
        _onjails=$(query_onjails)
        for _jail in $_onjails ; do 
            _jail_ips=$(ifconfig -j $_jail -a inet | awk '/inet / {print $2}') 
            _val=$(printf "%b" "$_val" "\n" "$_jail_ips")
        done
    fi

    [ -z "$_val" ] && return 1
    echo $_val   # Intentionally not quoted, so items present as a single-line list
}

query_sysmem() {
    local _fn="query_sysmem" _val
    _val=$(grep -s "avail memory" /var/run/dmesg.boot | sed "s/.* = //" | sed "s/ (.*//" | tail -1) \
        || eval $(THROW 1 $_fn)
    [ "$_val" ] || eval $(THROW 1 $_fn)
    echo "$_val"
}


##########################################  X11 QUERIES  ###########################################

query_net_active_xid() {
    local _fn="query_net_active_xid" _val
    _val=$(xprop -root _NET_ACTIVE_WINDOW | sed "s/.*window id # //") \
        || eval $(THROW 1 xfail XID)
    [ "$_val" ] || eval $(THROW 1 xfail XID)
    echo "$_val"
}

query_xwin_name() {
    local _fn="query_xwin_name" _xid _val
    _xid=$(query_net_active_xid) || eval $(THROW 1)
    _val=$(xprop -id "$_xid" WM_NAME _NET_WM_NAME WM_CLASS) \
        || eval $(THROW 1 xfail _NAME $_xid)
    [ -z "$_val" ] && eval $(THROW 1 xfail _NAME $_xid)
    echo "$_val"
}

query_xwin_socket() {
    local _fn="query_xwin_socket" _xid _val
    _xid=$(query_net_active_xid) || eval $(THROW 1)
    _val=$(xprop -id $_xid | sed -En "s/^WM_NAME.*:([0-9]+)\..*/\1/p") \
        || eval $(THROW 1 fail socket $_xid)
    [ -z "$_val" ] && eval $(THROW 1 xfail socket $_xid)
    echo "$_val"
}

query_xwin_pid() {
    local _fn="query_xwin_pid" _xid _val
    _xid=$(query_net_active_xid) || eval $(THROW 1)
    _val=$(xprop -id $_xid _NET_WM_PID | grep -Eo "[[:alnum:]]+$") \
        || eval $(THROW 1 $_fn PID $_xid)
    [ -z "$_val" ] && eval $(THROW 1 xfail PID $_xid)
    echo "$_val"
}

query_xwin_cellname() {
    local _fn="query_xwin_cellname" _xid _xsock _val

    _xid=$(query_net_active_xid) || eval $(THROW 1)
    if [ "$_xid" = "0x0" ] || echo "$_xid" | grep -Eq "not found" \
                           || xprop -id $_xid WM_CLIENT_MACHINE | grep -Eq $(hostname) ; then
        _val=host
    else
        _xsock=$(xprop -id $_xid | sed -En "s/^WM_NAME.*:([0-9]+)\..*/\1/p")
        _val=$(pgrep -fl "X11-unix/X${_xsock}" | head -1 | sed -En \
              "s@.*var/run/qubsd/X11/(.*)/.X11-unix/X${_xsock},.*@\1@p")
    fi
    
    [ "$_val" ] || eval $(THROW 1 $_fn $_xid)
    echo "$_val"
}

# Use vertical res to derive popup dimensions.
_resolve_popup_dimensions() {
    local _fn="_resolve_popup_dimensions" _h=.25 _w=2.5 _res

    # Adjust _res that based on inputs from the caller
    local _res=$(xrandr | sed -En "s/.*connected primary.*x([0-9]+).*/\1/p") || eval $(THROW 1 $_fn)
    [ "$_res" ] || eval $(THROW 1 $_fn)

    _h=$(echo "scale=0 ; $_res * $_h" | bc | cut -d. -f1) || eval $(THROW 1 $_fn)
    _w=$(echo "scale=0 ; $_h * $_w" | bc | cut -d. -f1)   || eval $(THROW 1 $_fn)
    [ "${_h}${_w}" ] || eval $(THROW 1 $_fn) 

    echo "$_h $_w"
}

# Intelligently calculate fontsize for popups based on monitor vs system DPI
_resolve_popup_fontsize() {
    local _fn="_resolve_popup_fontsize" _val _dpi_mon _dpi_sys

    # If there's a system font size set, use that at .75 size factor.
    _fs=$(appres XTerm xterm | sed -En "s/XTerm.*faceSize:[ \t]+([0-9]+).*/\1/p")

    if [ -z "$_fs" ] ; then
        # If no fs, use the ratio of monitor DPI to system DPI to scale font size
        local _dpi_mon=$(xdpyinfo | sed -En "s/[ \t]+resolution.*x([0-9]+).*/\1/p")
        local _dpi_sys=$(xrdb -query | sed -En "s/.*Xft.dpi:[ \t]+([0-9]+)/\1/p")
        [ -z "$_dpi_sys" ] && _dpi_sys=96  # Fallback default
        # fs of 15 is a sane value when both monitor and system DPI is at default of 96
        _val=$(echo "scale=0 ; ($_dpi_mon / $_dpi_sys) * 15" | bc | cut -d. -f1)
    else
        _val=$(echo "scale=0 ; $_fs * .75" | bc | cut -d. -f1)
    fi

    [ -z "$_val" ] && return 1
    echo "$_val"
}

##################################################################################################
####################################  OLD  FUNCTIONS  ############################################
##################################################################################################

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

calculate_sizes() {
	# Get vertical resolution of primary display for calculating popup dimensions
	local _res=$(xrandr | sed -En "s/.*connected primary.*x([0-9]+).*/\1/p")

	# Adjust that based on inputs from the caller
	[ -z "$_h" ] && _h=".25"
	[ -z "$_w" ] && _w="2.5"
	_h=$(echo "scale=0 ; $_res * $_h" | bc | cut -d. -f1)
	_w=$(echo "scale=0 ; $_h * $_w" | bc | cut -d. -f1)
	_i3mod="${_i3mod}, resize set $_w $_h"

	# If there's a system font size set, use that at .75 size factor.
	_fs=$(appres XTerm xterm | sed -En "s/XTerm.*faceSize:[ \t]+([0-9]+).*/\1/p")
	if [ -z "$_fs" ] ; then
		# If no set fs, then use the ratio of monitor DPI to system DPI to scale font size from 15.
		local _dpi_mon=$(xdpyinfo | sed -En "s/[ \t]+resolution.*x([0-9]+).*/\1/p")
		local _dpi_sys=$(xrdb -query | sed -En "s/.*Xft.dpi:[ \t]+([0-9]+)/\1/p")
		[ -z "$_dpi_sys" ] && _dpi_sys=96

		# 15 is a reference, since it's a sane value when both monitor and logical DPI is 96.
		_fs=$(echo "scale=0 ; ($_dpi_mon / $_dpi_sys) * 15" | bc | cut -d. -f1)
	else
		_fs=$(echo "scale=0 ; $_fs * .75" | bc | cut -d. -f1)
	fi
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

