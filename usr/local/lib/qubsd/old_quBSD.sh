#!/bin/sh

########################################################################################
######################  VARIABLE ASSIGNMENTS and VALUE RETRIEVAL  ######################
########################################################################################

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


########################################################################################
############################  JAIL/VM  HANDLING / ACTIONS  #############################
########################################################################################

start_jail() {
	# Starts jail. Performs sanity checks before starting. Logs results.
	# return 0 on success ; 1 on failure.
	local _fn="start_jail" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts nqV opts ; do case $opts in
			n) local _norun="-n" ;;
			q) local _qs="-q" ; _quiet='> /dev/null 2>&1' ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	local _jail="$1"
	[ "$_jail" = "none" ] && eval $_R0
	[ -z "$_jail" ] && get_msg $_qs -m _e0 -- "jail" && eval $_R1

	# Check to see if _jail is already running
	if	! chk_isrunning "$_jail" ; then
		# If not, running, perform prelim checks
		if chk_valid_jail $_qs -- "$_jail" ; then

			# Jail or VM
			if chk_isvm "$_jail" ; then
				! exec_vm_coordinator $_norun $_qs $_jail $_quiet \
					&& get_msg $_qs -m _e4 -- "$_jail" && eval $_R1
			else
				[ "$_norun" ] && return 0

				# Have to use tmpfile to grab the error message while still allowing for user zfs -l
				get_msg -m _m1 -- "$_jail" | tee -a $QLOG ${QLOG}_${_jail}
				_jailout=$(mktemp ${QRUN}/start_jail${0##*/}.XXXX)

				if jail -vc "$_jail" | tee -a $_jailout ; then
					cat $_jailout >> ${QLOG}_${_jail}
					rm $_jailout 2>/dev/null
				else
					cat $_jailout > $ERR1
					cat $_jailout > ${QLOG}_${_jail}
					rm $_jailout 2>/dev/null
					get_msg $_qs -m _e4 -- "$_jail" && eval $_R1
				fi
			fi
		else # Jail was invalid
			return 1
		fi
	fi
	eval $_R0
}

stop_jail() {
	# If jail is running, remove it. Return 0 on success; return 1 if fail.
	local _fn="stop_jail" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts fqt:Vw opts ; do case $opts in
			f) local _force="true" ;;
			q) local _qj="-q" ;;
			V) local _V="-V" ;;
			t) local _timeout="-t $OPTARG" ;;
			w) local _wait="true" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_qj -m _e0 -- "jail" && eval $_R1

	# Check that the jail is on
	if chk_isrunning "$_jail" ; then
		# Log stop attempt, then switch by VM or jail
		get_msg -m _m2 -- "$_jail" | tee -a $QLOG ${QLOG}_${_jail}

		if chk_isvm "$_jail" ; then
			if [ -z "$_force" ] ; then
				pkill -15 -f "bhyve: $_jail"
			else
				bhyvectl --vm="$_jail" --destroy
			fi
			# If optioned, wait for the VM to stop
			[ "$_wait" ] && ! monitor_vm_stop $_qj $_timeout "$_jail" && eval $_R1

		# Attempt normal removal [-r]. If failure, then remove forcibly [-R].
		elif ! jail -vr "$_jail"  >> ${QLOG}_${_jail} 2>&1 ; then
			if chk_isrunning "$_jail" ; then
				# Manually run exec.prestop, then forcibly remove jail, and run exec.release
				/bin/sh ${QLEXEC}/exec.prestop "$_jail" > /dev/null 2>&1
				jail -vR "$_jail"  >> ${QLOG}_${_jail} 2>&1
				/bin/sh ${QLEXEC}/exec.release "$_jail" > /dev/null 2>&1

				if chk_isrunning "$_jail" ; then
					# Warning about failure to forcibly remove jail
					get_msg $_qj -m _w2 -- "$_jail" && eval $_R1
				else
					# Notify about failure to remove normally
					get_msg -m _w1 -- "$_jail"
				fi
			fi
	fi fi
	eval $_R0
}

restart_jail() {
	# Restarts jail. If a jail is off, this will start it. However, passing
	# [-h] will override this default, so that an off jail stays off.
	local _fn="restart_jail" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts hqV opts ; do case $opts in
			h) local _hold="true" ;;
			q) local _qr="-q" ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	# Positional parameters / check
	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_qr -m _e0 -- "jail" && eval $_R1

	# If the jail was off, and the hold flag was given, don't start it.
	! chk_isrunning "$_jail" && [ "$_hold" ] && eval $_R0

	# Otherwise, cycle jail
	stop_jail $_qr "$_jail" && start_jail $_qr "$_jail"
	eval $_R0
}

reclone_zroot() {
	# Destroys the existing _rootenv clone of <_jail>, and replaces it
	# Detects changes since the last snapshot, creates a new snapshot if necessary,
	local _fn="reclone_zroot" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	_tmpsnaps="${QRUN}/.tmpsnaps"

	while getopts qV _opts ; do case $_opts in
		q) local _qz='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Variables definitions
	local _jail="$1"
		[ -z "${_jail}" ] && get_msg $_qz -m _e0 -- "Jail" && eval $_R1
	local _rootenv="$2"
		[ -z "${_rootenv}" ] && get_msg $_qz -m _e0 -- "ROOTENV" && eval $_R1
	local _jailzfs="${R_ZFS}/${_jail}"

	# Check that the _jail being destroyed/cloned has an origin (is a clone).
	chk_valid_zfs "$_jailzfs" && [ "$(zfs list -Ho origin $_jailzfs)" = "-" ] \
		&& get_msg $_qz -m _e32 -- "$_jail" && eval $_R1

	# Parallel starts create race conditions for zfs snapshot access/comparison. This deconflicts it.
	# Use _tmpsnaps if avail. Else, find/create latest rootenv snapshot.
	[ -e "$_tmpsnaps" ] \
		&& _rootsnap=$(grep -Eo "^${R_ZFS}/${_rootenv}@.*" $_tmpsnaps) \
		|| { ! _rootsnap=$(select_snapshot) && get_msg $_qz $_V -m '' && eval $_R1 ;}

   # Destroy the dataset and reclone it
	zfs destroy -rRf "${_jailzfs}" > /dev/null 2>&1
	zfs clone -o qubsd:autosnap='false' "${_rootsnap}" ${_jailzfs}

	eval $_R0
}

reclone_zusr() {
	# Destroys the existing zusr clone of <_jail>, and replaces it
	# Detects changes since the last snapshot, creates a new snapshot if necessary,
	# and destroys old snapshots when no longer needed.
	local _fn="reclone_zusr" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Variables definitions
	local _jail="$1"
	local _jailzfs="$U_ZFS/$_jail"
	local _template="$2"
	local _date=$(date +%s)
	local _ttl=$(( _date + 30 ))

	# Basic checks, and do not attempt this on a running container
	[ -z "$_jail" ] && get_msg $_qr -m _e0 -- "jail" && eval $_R1
	[ -z "$_template" ] && get_msg $_qr -m _e0 -- "template" && eval $_R1
	! chk_valid_zfs "$U_ZFS/$_template" && get_msg $_qr -m _e0 -- "template" && eval $_R1
	chk_isrunning "$_jail" && get_msg $_qr -m _e35 && -- "$_jail" eval $_R1

	# Destroy the existing zusr dataset. Suppress error in case the dataset doesnt exist
	zfs destroy -rRf "${_jailzfs}" > /dev/null 2>&1

	# There is no `clone recursive`. Must find all the children and clone them one by one
	local _datasets=$(zfs list -Hro name "$U_ZFS/$_template")
	for _templzfs in $_datasets ; do
		_newsnap="${_templzfs}@${_date}"                                  # Potential temporary snapshot
		_presnap=$(zfs list -t snapshot -Ho name ${_templzfs} | tail -1)  # Latest snapshot

		# Use "written" to detect any changes to the dataset since last snapshot
		if [ $(zfs list -Ho written "$_templzfs") -eq 0 ] ; then
			_source_snap="$_presnap"          # No changes, use the old snapshot
		else
			# Changes detected, create a new, short-lived snapshot
			_source_snap="$_newsnap"
			zfs snapshot -o qubsd:destroy-date="$_ttl"
				-o qubsd:autosnap='-' -o qubsd:autocreated="yes" "$_newsnap"
		fi

		# Substitute the jail/vm name for the template name
		_newclone=$(echo $_templzfs | sed -E "s|/${_template}|/${_jail}|")
		zfs clone -o qubsd:autosnap="false" $_source_snap $_newclone
	done

	# Dispjails need to adjust pw after cloning the template
	if chk_isvm ${_jail} ; then
		set_dispvm_pw
	else
		local prefix="${M_ZUSR}/${_jail}/rw"
		set_freebsd_pw
	fi

	eval $_R0
}

set_dispvm_pw() {
	local persist="$_jailzfs/persist"
	local zvol="/dev/zvol/$persist"
	local volmnt="/mnt/$persist"

	zfs set volmode=geom $persist
	fs_type=$(fstyp $zvol)
	case "$fs_type" in
		ufs)
			mkdir -p $volmnt
			mount -o rw $zvol $volmnt
			local prefix="$volmnt/overlay"
			set_freebsd_pw
			;;
		ext*)
			kldstat -qn ext2fs || kldload -n ext2fs
			mount -t ext2fs -o rw $zvol $volmnt
			set_linux_pw
			;;
		*) # INSERT ERROR MESSAGE SYSTEM HERE
			;;
	esac

	umount $volmnt
	rm -r /mnt/$U_ZFS
	zfs set volmode=dev $zvol
}

set_freebsd_pw() {
	local jailhome="${prefix%/*}/home"   # Must remove /rw or /overlay to access /home
	local etc_local="$prefix/etc"
	local pwd_local="$prefix/etc/master.passwd.local"
	local grp_local="$prefix/etc/group.local"

	# Drop the flags for the home directory and rename it from template to dispjail name
	[ -e "$jailhome/$_template" ] \
		&& chflags noschg $jailhome/$_template \
		&& mv $jailhome/$_template $jailhome/$_jail > /dev/null 2>&1

	# Change the local pwd from template name to dispjail name
	[ -e "$etc_local" ] && chflags -R noschg $etc_local
	[ -e "$pwd_local" ] && sed -i '' -E "s|^$_template:|$_jail:|g" $pwd_local
	[ -e "$grp_local" ] && sed -i '' -E "s/(:|,)$_template(,|[[:blank:]]|\$)/\1$_jail\2/g" $grp_local
}

set_linux_pw() {
	# EMPTY FOR NOW. WILL FILL LATER WHEN THE LINUS OVERLAYFS IS A KNOWN ENTITY
	return 0
}

set_xauthority() {
	_jail="$1"
	_file="${M_ZUSR}/${_jail}/home/${_jail}/.Xauthority"
	_xauth=$(xauth list | grep -Eo ":0.*")
	[ -e "$_file" ] && rm $_file
	touch $_file && chown 1001:1001 $_file
	eval "jexec -l -U $_jail $_jail /usr/local/bin/xauth add $_xauth"
	chmod 400 $_file
}  

select_snapshot() {
	# Generalized function to be shared across qb-start/stop, and reclone_zfs's
	# Returns the best/latest snapshot for a given ROOTENV
	local _fn="select_snapshot" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	local _jlsdate  _rootsnaps  _snapdate  _newsnap
	local _tmpsnaps="${QRUN}/.tmpsnaps"  _rootzfs="${R_ZFS}/${_rootenv}"

	# For safety, running ROOTENV snapshot should be taken from before it was started
	if chk_isrunning ${_rootenv} ; then
		# Get epoch date of ROOTENV pid, and ROOTENV snapshots
		if chk_isvm ${_rootenv} ; then
			_jlsdate=$(ps -o lstart -p $(pgrep -f "bhyve: $_rootenv") | tail -1 \
								| xargs -I@ date -j -f "%a %b %d %T %Y" @ +"%s")
		else
			_jlsdate=$(ps -o lstart -J $(jls -j $_rootenv jid) | tail -1 \
								| xargs -I@ date -j -f "%a %b %d %T %Y" @ +"%s")
		fi
		_rootsnaps=$(zfs list -t snapshot -Ho name $_rootzfs)
		_snapdate=$(echo "$_rootsnaps" | tail -1 | xargs -I@ zfs list -Ho creation @ \
											| xargs -I@ date -j -f "%a %b %d %H:%M %Y" @ +"%s")

		# Cycle from most-to-least recent until a snapshot older-than running ROOTENV pid, is found
		while chk_integer -q -g $_jlsdate $(( _snapdate + 59 )) ; do
			_rootsnaps=$(echo "$_rootsnaps" | sed '$ d')
			[ -n "$_rootsnaps" ] \
				&& _snapdate=$(echo "$_rootsnaps" | tail -1 | xargs -I@ zfs list -Ho creation @ \
					| xargs -I@ date -j -f "%a %b %d %H:%M %Y" @ +"%s")
		done

		# If no _rootsnap older than the rootenv pid was found, return error
		_rootsnap=$(echo "$_rootsnaps" | tail -1)
		[ -z "$_rootsnap" ] && get_msg $_qz -m _e32_1 -- "$_jail" "$_rootenv" && eval $_R1

	# Latest ROOTENV snapshot unimportant for stops, and prefer not to clutter ROOTENV snaps.
	elif [ -z "${0##*exec.release}" ] || [ -z "${0##*qb-stop}" ] ; then
		# The jail is running, meaning there's a ROOTENV snapshot available (no error/chks needed)
		local _rootsnap=$(zfs list -t snapshot -Ho name $_rootzfs | tail -1)

	# If ROOTENV is off, and jail is starting, make sure it has the absolute latest ROOTENV state
	else
		local _date=$(date +%s)
		local _newsnap="${_rootzfs}@${_date}"
		local _rootsnap=$(zfs list -t snapshot -Ho name $_rootzfs | tail -1)

		# Perform the snapshot
		zfs snapshot -o qubsd:destroy-date=$(( _date + 30 )) -o qubsd:autosnap='-' \
			-o qubsd:autocreated="yes" "${_newsnap}"

		# Use zfsprop 'written' to detect any new data. Destroy _newsnap if it has no new data.
		if [ ! "$(zfs list -Ho written $_newsnap)" = "0" ] || [ -z "$_rootsnap" ] ; then
			_rootsnap="$_newsnap"
		else
			zfs destroy $_newsnap
		fi
	fi

	# Echo the final value and return 0
	echo "$_rootsnap" && eval $_R0
}

monitor_startstop() {
	# PING: There's legit cases where consecutive calls to qb-start/stop could happen. [-p] handles
	# potential races via _tmp_lock; puts the 2nd call into a timeout queue; and any calls after
	# the 2nd one, are dropped. Not perfectly user friendly, but it's unclear if allowing a long
	# queue is desirable. Better to error, and let the user try again.
	# NON-PING: Give qb-start/stop until $_timeout for jails/VMs to start/stop before intervention
	local _fn="monitor_startstop" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts pqV _opts ; do case $_opts in
		p) local _ping="true" ;;
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Monitoring loop is predicated on main script killing this one after successful starts/stops
	if [ -z "$_ping" ] ; then
		local _timeout="$1"
		while [ "$_timeout" -ge 0 ] ; do
			echo "$_timeout" > $_TMP_TIME
			_timeout=$(( _timeout - 1 )) ; sleep 1
		done

		# Last check before kill. If self PID was removed, then main has already completed.
		if [ -e "$_TMP_LOCK" ] && [ ! "$(sed -n 1p $_TMP_LOCK)" = "$$" ] ; then
			eval $_R0
		fi

		# Timeout has passed, kill qb-start/stop
		[ -e "$_TMP_LOCK" ] && for _pid in $(cat $_TMP_LOCK) ; do
			kill -15 $_pid > /dev/null 2>&1
			# Removing the PID is how we communicate to qb-start/stop to issue a failure message
			sed -i '' -E "/^$$\$/ d" $_TMP_LOCK
		done

		eval $_R1
	fi

	# Handle the [-p] ping case
	if [ "$_ping" ] ; then
		# Resolve any races. 1st line on lock file wins. 2nd line queues up. All others fail.
		echo "$$" >> $_TMP_LOCK && sleep .1
		[ "$(sed -n 1p $_TMP_LOCK)" = "$$" ] && eval $_R0
		[ ! "$(sed -n 2p $_TMP_LOCK)" = "$$" ] && sed -i '' -E "/^$$\$/ d" && eval $_R0

		# Timeout loop, wait for _TMP_TIME to be set with a _timeout
		local _cycle=0
		while ! _timeout=$(cat $_TMP_TIME 2>&1) ; do
			# Limit to 5 secs before returning error, so that one hang doesnt cause another
			sleep .5  ;  _cycle=$(( _cycle + 1 ))
			[ "$_cycle" -gt 10 ] && eval $_R1

			# Check if self PID was promoted to the #1 spot while waiting
			[ "$(sed -n 1p $_TMP_LOCK)" = "$$" ] && eval $_R0
		done

		# Inform the user of the new _timeout, waiting for jails/VMs to start/stop before proceding
		get_msg -m _m5 -- "$_timeout"

		# Wait for primary qb-start/stop to either complete, or timeout
		while [ "$(cat $_TMP_TIME 2>&1)" -gt 0 ] 2>&1 ; do
			[ "$(sed -n 1p $_TMP_LOCK)" = "$$" ] && eval $_R0
			sleep 0.5
		done
	fi
	eval $_R0
}

launch_xephyr() {
	# sysvshm cannot share Xephyr here. Some apps will fail if we dont disable it. XVideo prevents non-existent
	# GPU overlay. We MUST stop GLX entirely (even iglx), as A) Xephyr implementation sucks (<1.4), and B) even
	# if it didnt, Xephyr is launched from *host*, and the jail only sees an X socket, not the Xephyr process.
	Xephyr -extension MIT-SHM -extension XVideo -extension XVideo-MotionCompensation -extension GLX \
		-resizeable -terminate -no-host-grab :$display > /dev/null 2>&1 &

	xephyr_pid=$!  &&  sleep 0.1       # Give a moment for Xephyr session to launch, trap it
	trap "kill -15 $xephyr_pid" INT TERM HUP QUIT EXIT
	! ps -p "$xephyr_pid" > /dev/null 2>&1 && get_msg2 -Em _e8

	# The Xephyr window_id is needed for monitoring/cleanup
	winlist=$(xprop -root _NET_CLIENT_LIST | sed 's/.*# //' | tr ',' '\n' | tail -r)
	for wid in $winlist; do
		xprop -id "$wid" | grep -Eqs "WM_NAME.*Xephyr.*:$display" \
		&& window_id="$wid" && break
	done

	# Launch a simple window manager for scaling/resizing to the full Xephyr size
	jexec -l -U $_USER $_JAIL env DISPLAY=:$display bspwm -c /usr/local/etc/X11/bspwmrc &
	bspwm_pid="$!"

	# Link the sockets together
	socat \
		UNIX-LISTEN:${QRUN}/X11/${_JAIL}/.X11-unix/X${display},fork,unlink-close,mode=0666 \
		UNIX-CONNECT:/tmp/.X11-unix/X${display} &
	socat_pid="$!"
	trap "kill -15 $bspwm_pid $socat_pid $xephyr_pid" INT TERM HUP QUIT EXIT

	# Push the Xresources and DPI to the Xephyr instance
	[ -n "$_xresources" ] && env DISPLAY=:$display xrdb -merge $_xresources
	[ -n "$_DPI" ] && echo "Xft.dpi: $_DPI" | env DISPLAY=:$display xrdb -merge

	# Monitor both the window, and the existence of the jail,
	while sleep 1 ; do
		xprop -id "$window_id" | grep -Eqs ".*Xephyr.*:$display" || exit 0
		jls | grep -Eqs "[ \t]${_JAIL}[ \t]" || exit 0
	done
	exit 0
}

monitor_ephmjail() {
	# X11 windows can take a moment launch. Ineligant solution, but wait 3 secs before check-loop
	sleep 5
	
	# ps -o tt tty -> is associated with terminals/windows. Keepalive until all are gone
	while sleep 1 ; do
		ps -axJ ${_JAIL} -o tt -o command | tail -n +2 | grep -v 'dbus' | grep -qv ' -' || break
	done
	
	# Destroy sequence
	stop_jail "$_JAIL" > /dev/null 2>&1
	zfs destroy -rRf ${R_ZFS}/$_JAIL > /dev/null 2>&1
	zfs destroy -rRf ${U_ZFS}/$_JAIL > /dev/null 2>&1
	sed -i '' -E "/^${_JAIL}[[:blank:]]/d" $QCONF
	rm ${JCONF}/${_JAIL}
	rm_errfiles
	exit 0
}



########################################################################################
###################################  STATUS  CHECKS  ###################################
########################################################################################

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

chk_integer() {
	# Checks that _value is integer, and can checks boundaries. [-n] is a descriptive variable name
	# from caller, for error message. Assumes that integers have been provided by the caller.
	local _fn="chk_integer" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

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

chk_avail_jailname() {
	# Checks that the proposed new jailname does not have any entries or partial entries
	# in JCONF, QCONF, and ZFS datasets
	# Return 0 jailname available, return 1 for any failure
	local _fn="chk_avail_jailname" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _qa='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Positional parmeters
	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_qa -m _e0 -- "new jail name" && eval $_R1

	# Checks that proposed jailname isn't 'none' or 'qubsd' or starts with '#'
	echo "$_jail" | grep -Eqi "^(none|qubsd)\$" \
			&& get_msg $_qa -m _e13 -- "$_jail" && eval $_R1

	# Jail must start with :alnum: and afterwards, have only _ or - as special chars
	! echo "$_jail" | grep -E -- '^[[:alnum:]]([-_[:alnum:]])*[[:alnum:]]$' \
			| grep -Eqv '(--|-_|_-|__)' && get_msg $_qa -m _e13_1 -- "$_jail" && eval $_R1

   # Checks that proposed jailname doesn't exist or partially exist
	if chk_valid_zfs "${R_ZFS}/$_jail" || \
		chk_valid_zfs "${U_ZFS}/$_jail"  || \
		grep -Eq "^${_jail}[ \t]+" $QCONF || \
		[ -e "${JCONF}/${_jail}" ] ; then
		get_msg $_qa -m _e13_2 -- "$_jail" && eval $_R1
	fi

	eval $_R0
}

