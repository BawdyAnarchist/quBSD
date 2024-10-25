#!/bin/sh

####################################################################################
#######################  GENERAL DESCRIPTION OF FUNCTIONS  #########################

# Global variables, jail/quBSD parameters, sanity checks, messages, networking.
# Functions embed many sanity checks, but also call other functions to assist.
# Messages are sourced from a separate script, as a function. They have the form:
#   get_msg <$_q> -m <_msg_ident> <_pass_variable1> <_pass_variable2>
#     <$_q> (q)uiet option.
#        -note- /bin/sh passes local vars to new functions called within functions.
#               thus to prevent inadvertently passing [-q], important funcitons
#               have a unique _q identifier.
#     <_msg_ident> Is used to retreive a particular message from the msg function.
#     <_pass_variable> 1 and 2 are for supplementing message specificity.

# Functions can assign global variables and deliver error messages ;
# but they almost never make a determination to exit. That is left to the caller.


####################################################################################
###############################  LIST OF FUNCTIONS  ################################

####################  VARIABLES VALUES and HIGH LEVEL FUNCTIONS  ###################
# get_global_variables - File names/locations ; ZFS datasets
# get_networking_variables - pf.conf ; wireguard ; endpoints
# rm_errfiles          - Removes the coordinated error files for qb-scripts
# get_parameter_lists  - Valid parameters are tracked here, and divided into groups
# get_user_response    - Simple yes/no y/n checker
# get_jail_parameter   - All QCONF entries, along with sanity checks
# get_info             - Info beyond that just for jails or jail parameters
	# _CLIENTS          - All jails that <jail> serves a network connection
	# _ONJAILS          - All currently running jails
	# _USED_IPS         - All IPs used by currently running jails
	# _XID              - Window ID for the currently active X window
	# _XJAIL            - Jailname (or 'host') for the currently active X window
	# _XNAME            - Name of the process for the current active X window
	# _XPID             - PID for the currently active X window
# compile_jlist        - Used for qb-start/stop, to get list of jails to act on
# create_popup         - Generic function used for popups
# calculate_sizes      - Calculate window and font size for message popups

#########################  JAIL/VM  HANDLING and ACTIONS  ##########################
# start_jail           - Performs checks before starting, creates log
# stop_jail            - Performs checks before starting, creates log
# restart_jail         - Self explanatory
# reclone_zroot        - Destroys and reclones jails dependent on ROOTENV
# reclone_zusr         - Destroy and reclones jails with zusr dependency (dispjails)
# select_snapshot      - Find/create ROOTENV snapshot for reclone.
# copy_control_keys    - SSH keys for control jail are copied over to running env.
# monitor_startstop    - Monitors whether qb-start or qb-stop is still alive
# monitor_vm_stop      - Monitors whether qb-start or qb-stop is still alive
# start_xpra           - Determines the status of X11 and starts xpra for GUI envs

#################################  STATUS  CHECKS  #################################
# chk_isblank          - Posix workaround: Variable is [-z <null> OR [[:blank:]]*]
# chk_isrunning        - Searches jls -j for the jail
# chk_truefalse        - When inputs must be either true or false
# chk_integer          - Checks that a value is an integer, within a range
# chk_avail_jailname   - Checks that a proposed jailname is acceptable
# get_jail_shell       - Gets the SHELL for a particular jail

#################################  SANITY  CHECKS  #################################
# chk_valid_zfs        - Checks for presence of zfs dataset. Redirect to null
# chk_valid_jail       - Makes sure the jail has minimum essential elements
# chk_valid_autosnap   - true|false ; Include in qb-autosnap /etc/crontab snapshots
# chk_valid_autostart  - true|false ; Autostart at boot
# chk_valid_bhyveopts  - Checks bhyve options in QCONF for valid or not
# chk_valid_class      - appjail | rootjail | dispjail | appVM | rootVM
# chk_valid_cpuset     - Must be in man 1 cpuset format. Limit jail CPUs
# chk_valid_gateway    - Jail adheres to gateway jail norms
# chk_valid_ipv4       - Adheres to CIDR notation
# chk_isqubsd_ipv4     - Adheres to quBSD conventions for an IP address
# chk_valid_maxmem     - Must be in man 8 rctl format. Max RAM allocated to jail
# chk_valid_memsize    - Check memsize for bhyve (just references _valid_maxmem)
# chk_valid_mtu        - Must be a number, typically between 1000 and 2000
# chk_valid_no_destroy - true|false ; qb-destroy protection mechanism
# chk_valid_ppt        - Checks ppt exists in pciconf and is available to passthru
# chk_valid_rootenv    - Only certain jails/VMs can be used as a ROOTENV
# chk_valid_schg       - none | sys | all ; quBSD convention, schg flags on jail
# chk_valid_seclvl     - -1|0|1|2|3 ; Applied to jail after start
# chk_valid_template   - Somewhat redundant with: chk_valid_jail
# chk_valid_taps       - QCONF designates number of taps to add (must be :digit:)
# chk_valid_tmux       - tmux for terminal access to FreeBSD jails. true/false
# chk_valid_template   - Must be any valid jail
# chk_valid_vcpus      - Must be an integer less than cpuset -g
# chk_valid_vnc        - Must be one of few valid resolutions allowed by bhyve
# chk_valid_vif        - Virtual Intf (vif) is valid
# chk_valid_wiremem    - Must be true/false

##############################  NETWORKING  FUNCTIONS  #############################
# remove_tap           - Removes tap interface from whichever jail it's in
# assign_ipv4_auto     - Handles the ip auto assignments when starting jails
# discover_open_ipv4   - Finds an unused IP address from the internal network
# define_ipv4_convention  - Necessary for implementing quBSD IPv4 conventions
# connect_client_to_ gateway - Connects a client jail to its gateway
# connect_gateway_to_clients - Connects a gateway jail to its clients

##################################  VM  FUNCTIONS  #################################
# cleanup_vm           - Cleans up network connections, and dataset after shutdown
# return_ppt           - Set PPT devices back to original state before VM launch.
# prep_bhyve_options   - Retrieves VM variables and handles related functions
# launch_vm            - Launches the VM to a background subshell
# exec_vm_coordinator  - Coordinates the clean launching and teardown of VMs

##################################  DEBUG LOGGING  #################################
# setlog1              - For turning on debug log to /root/debug1
# setlog2              - For turning on debug log to /root/debug2

#############################  END  OF  FUNCTION  LIST  ############################
####################################################################################



########################################################################################
######################  VARIABLE ASSIGNMENTS and VALUE RETRIEVAL  ######################
########################################################################################

# Source error messages for library functions
. /usr/local/lib/quBSD/msg-quBSD.sh

# Internal flow variables to handle returns, while reseting _fn and _FN variables with logging
_R0='_FN="$_fn_orig" ; return 0'
_R1='_FN="$_fn_orig" ; return 1'

get_global_variables() {
	# Global config files, mounts, and datasets needed by most scripts

	# Define variables for files
	JCONF="/etc/jail.conf"
	QBDIR="/usr/local/etc/quBSD"
	QCONF="${QBDIR}/qubsd.conf"
	QBLOG="/var/log/quBSD/quBSD.log"
	QTMP="/tmp/quBSD"

	# Remove blanks at end of line, to prevent bad variable assignments.
	sed -i '' -E 's/[[:blank:]]*$//' $QCONF
	# Get datasets, mountpoints; and define files.
   R_ZFS=$(sed -nE "s:#NONE[[:blank:]]+jails_zfs[[:blank:]]+::p" $QCONF)
   U_ZFS=$(sed -nE "s:#NONE[[:blank:]]+zusr_zfs[[:blank:]]+::p" $QCONF)
	[ -z "$R_ZFS" ] && get_msg -V -m "_e0_1" "jails_zfs" && exit 1
	[ -z "$U_ZFS" ] && get_msg -V -m "_e0_1" "zusr_zfs" && exit 1
	! chk_valid_zfs "$R_ZFS" && get_msg -V -m _e0_2 -- "jails_zfs" "$R_ZFS" && exit 1
	! chk_valid_zfs "$U_ZFS" && get_msg -V -m _e0_2 -- "zusr_zfs" "$U_ZFS" && exit 1
	M_QROOT=$(zfs get -H mountpoint $R_ZFS | awk '{print $3}')
	M_ZUSR=$(zfs get -H mountpoint $U_ZFS | awk '{print $3}')
	[ "$M_QROOT" = "-" ] && get_msg -V -m _e0_3 "$R_ZFS" && exit 1
	[ "$M_ZUSR" = "-" ]  && get_msg -V -m _e0_3 "$U_ZFS" && exit 1

	# Set the files for error recording, and trap them
	[ -d "$QTMP" ] || mkdir $QTMP
	ERR1=$(mktemp -t quBSD/.${0##*/})
	ERR2=$(mktemp -t quBSD/.${0##*/})
	trap "rm_errfiles" HUP INT TERM QUIT EXIT

	return 0
}

get_networking_variables() {
	WIREGRD="/rw/usr/local/etc/wireguard"
	WG0CONF="${WIREGRD}/wg0.conf"
	PFCONF="/rw/etc/pf.conf"
	JPF="${M_ZUSR}/${JAIL}/${PFCONF}"

	# Get wireguard related variables
   if [ -e "${M_ZUSR}/${JAIL}/${WG0CONF}" ] ; then

		WG_ENDPT=$(sed -nE "s/^Endpoint[[:blank:]]*=[[:blank:]]*([^[:blank:]]+):.*/\1/p" \
				${M_ZUSR}/${JAIL}/${WG0CONF})
		WG_PORTS=$(sed -nE "s/^Endpoint[[:blank:]]*=.*:(.*)[[:blank:]]*/\1/p" \
				${M_ZUSR}/${JAIL}/${WG0CONF})
		WG_MTU=$(sed -nE "s/^MTU[[:blank:]]*=[[:blank:]]*([[:digit:]]+)/\1/p" \
				${M_ZUSR}/${JAIL}/${WG0CONF})
	fi
}

rm_errfiles() {
	rm $ERR1 $ERR2 > /dev/null 2>&1
}

get_msg2() {
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

	# Using the caller script to generalize message calls. Switch between exec- and qb- scripts.
	local _call="${0##*/}"
	[ -z "${_call##exec-*}" ] && local _msg="msg_exec" || _msg="msg_${0##*-}"

	# Determine if popup should be used or not
	get_info _POPUP

	case $_message in
		_m*|_w*) [ -z "$_q" ] && eval "$_msg" "$@" ;;
		_e*)
			if [ -z "$_force" ] ; then
				# Place final ERROR message into a variable.
				_ERROR="$(echo "ERROR: $_call" ; "$_msg" "$@" ; [ -s "$ERR1" ] && cat $ERR1)"
				echo -e "$_ERROR\n" > $ERR2

				# If exiting due to error, log the date and error message to the log file
				[ "$_exit" = "exit 1" ] && echo -e "$(date "+%Y-%m-%d_%H:%M")\n$_ERROR" >> $QBLOG

				# Send the error message
				if [ -z "$_q" ] && [ "$_ERROR" ] ; then
					{ [ "$_popup" ] && [ "$_POPUP" ] && create_popup -f "$ERR2" ;} || echo "$_ERROR"
				fi
			fi ;;
	esac

	# Now that it has been dispositioned, erase the message
	truncate -s 0 $ERR1 ; unset _ERROR

	# Evaluate usage if present
	[ -z "$_q" ] && [ $_usage ] && _message="usage" && eval "$_msg"

	eval $_exit :
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
	local _dp= ; local _ep= ; local _qp= ; local _rp= ; local _sp= ;local _xp= ;local _zp= ;local _V=
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
	local _param="$1"  ; local _low_param=$(echo "$_param" | tr '[:upper:]' '[:lower:]')
	local _jail="$2"   ; local _value=''

	# Either jail or param weren't provided
	[ -z "$_param" ] && get_msg $_qp $_V -m _e0 -- "PARAMETER and jail" && eval "$_sp $_R1"
	[ -z "$_jail" ] && get_msg $_qp $_V -m _e0 -- "jail" && eval "$_sp $_R1"

	# Get the <_value> from QCONF.
	_value=$(sed -nE "s/^${_jail}[[:blank:]]+${_param}[[:blank:]]+//p" $QCONF)

	# Substitute <#default> values, so long as [-d] was not passed
	[ -z "$_value" ] && [ -n "$_dp" ] \
		&& _value=$(sed -nE "s/^#default[[:blank:]]+${_param}[[:blank:]]+//p" $QCONF)

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

	local _info="$1"  ;  local _jail="$2"  ;  local _value=''
	# Either jail or param weren't provided
	[ -z "$_info" ] && get_msg $_qp -m _e0 -- "INFO PARAMETER" && eval "$_sp $_R1"

	case $_info in
		_CLIENTS)  # All _clients listed in QCONF, which depend on _jail as a gateway
			_value=$(sed -nE "s/[[:blank:]]+GATEWAY[[:blank:]]+${_jail}//p" $QCONF)
			;;
		_ONJAILS)  # All jails/VMs that are currently running
			_value=$(jls | sed "1 d" | awk '{print $2}' ; \
						pgrep -fl 'bhyve: ' | sed -E "s/.*[[:blank:]]([^[:blank:]]+)\$/\1/")
			;;
		_POPUP) # Determine if user is in interactive shell, or if popup is possible for inputs
			tty | grep -qS 'ttyv' && pgrep -qx Xorg && _value="true"
			;;
		_USED_IPS) # List of ifconfig inet addresses for all running jails/VMs
			for _onjail in $(jls | sed "1 d" | awk '{print $2}') ; do
				_intfs=$(jexec -l -U root "$_onjail" ifconfig -a inet | grep -Eo "inet [^[:blank:]]+")
				_value=$(printf "%b" "$_value" "\n" "$_intfs")
			done
			;;
		_XID)    # X11 window ID of the current active window
			_value=$(xprop -root _NET_ACTIVE_WINDOW | sed "s/.*window id # //")
			;;
		_XJAIL)  # Gets the jailname of the active window. Converts $HOSTNAME to: "host"
			_xid=$(get_info -e _XID)
			if [ "$_xid" = "0x0" ] || echo $_xid | grep -qs "not found" ; then
				_value=host
			else
				_value=$(xprop -id $(get_info -e _XID) WM_CLIENT_MACHINE \
						| sed "s/WM_CLIENT_MACHINE(STRING) = \"//" | sed "s/.$//" \
						| sed "s/$(hostname)/host/") || _value="host"
			fi
			;;
		_XNAME)  # Gets the name of the active window
			_value=$(xprop -id $(get_info -e _XID) WM_NAME _NET_WM_NAME WM_CLASS)
			;;
		_XPRA_SOCKETS)  # Gets the name of the active window
			_value=$(pgrep -fl "xpra start" | sed -En 's/.*xpra start :([0-9]+) .*/\1/p')
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
			_JLIST=$(grep -E "AUTOSTART[[:blank:]]+true" $QCONF | awk '{print $1}' | uniq)
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
		_JLIST=$(echo "$_JLIST" | grep -Ev "^[[:blank:]]*${_exlist}[[:blank:]]*\$")
	done

	[ -z "$_JLIST" ] && get_msg -m _e31_5 && eval $_R1
	eval $_R0
}

create_popup() {
	# Handles popus to send messages, receive inputs, and pass commands
	# _h should be as a percentage of the primary screen height (between 0 and 1)
	# _w is a multiplication factor for _h
	local _fn="create_popup" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts c:f:h:im:qVw: opts ; do case $opts in
			c) local _cmd="$OPTARG" ;;
			i) local _input="true" ;;
			f) local _popfile="$OPTARG" ;;
			h) local _h="$OPTARG" ;;
			m) local _popmsg="$OPTARG" ;;
			q) local _qs="-q" ; _quiet='> /dev/null 2>&1' ;;
			V) local _V="-V" ;;
			w) local _w="$OPTARG" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	# Discern if it's i3, and modify with center/floating options
	ps c | grep -qs 'i3' && _i3mod="i3-msg -q floating enable, move position center"

	# If a file was passed, set the msg equal to the contents of the file
	[ "$_popfile" ] && _popmsg=$(cat $_popfile)

	# Equalizes popup size and fonts between systems of different resolution and DPI settings.
	calculate_sizes

	# Execute popup depending on if input is needed or not
	if [ "$_cmd" ] ; then
		xterm -fa Monospace -fs $_fs -e /bin/sh -c "$_i3mod ; eval $_cmd"
	elif [ -z "$_input" ] ; then
		# Simply print a message, and return 0
		xterm -fa Monospace -fs $_fs -e /bin/sh -c \
			"eval \"$_i3mod\" ; echo \"$_popmsg\" ; echo \"{Enter} to close\" ; read _INPUT ;"
		eval $_R0
	else
		# Need to collect a variable, and use a tmp file to pull it from the subshell, to a variable.
		local _poptmp=$(mktemp -t quBSD/.popup)
		xterm -fa Monospace -fs $_fs -e /bin/sh -c \
			"eval \"$_i3mod\"; printf \"%b\" \"$_popmsg\"; read _INPUT; echo \"\$_INPUT\" > $_poptmp"

		# Retreive the user input, remove tmp, and echo the value back to the caller
		_input=$(cat $_poptmp)
		rm $_poptmp > /dev/null 2>&1
		echo "$_input"
	fi
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
	_fs=$(appres XTerm xterm | sed -En "s/XTerm.*faceSize:[[:blank:]]+([0-9]+).*/\1/p")
	if [ -z "$_fs" ] ; then
		# If no set fs, then use the ratio of monitor DPI to system DPI to scale font size from 15.
		local _dpi_mon=$(xdpyinfo | sed -En "s/[[:blank:]]+resolution.*x([0-9]+).*/\1/p")
		local _dpi_sys=$(xrdb -query | sed -En "s/.*Xft.dpi:[[:blank:]]+([0-9]+)/\1/p")
		[ -z "$_dpi_sys" ] && _dpi_sys=96

		# 15 is a reference, since it's a sane value when both monitor and logical DPI is 96.
		_fs=$(echo "scale=0 ; ($_dpi_mon / $_dpi_sys) * 15" | bc | cut -d. -f1)
	else
		_fs=$(echo "scale=0 ; $_fs * .75" | bc | cut -d. -f1)
	fi
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
				get_msg -m _m1 -- "$_jail" | tee -a $QBLOG ${QBLOG}_${_jail}
				# Slightly hacky/convoluted err messaging, but it aint easy combining qb-cmd, qb-start
				_jailout=$(jail -vc "$_jail") \
					&& { echo "$_jailout" >> ${QBLOG}_${_jail} ;} \
					|| { echo "$_jailout" > $ERR1 && echo "$_jailout" > ${QBLOG}_${_jail} \
							&& get_msg $_qs -m _e4 -- "$_jail" && eval $_R1 ;}
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
		get_msg -m _m2 -- "$_jail" | tee -a $QBLOG ${QBLOG}_${_jail}

		if chk_isvm "$_jail" ; then
			if [ -z "$_force" ] ; then
				pkill -15 -f "bhyve: $_jail"
			else
				bhyvectl --vm="$_jail" --destroy
			fi
			# If optioned, wait for the VM to stop
			[ "$_wait" ] && ! monitor_vm_stop $_qj $_timeout "$_jail" && eval $_R1

		# Attempt normal removal [-r]. If failure, then remove forcibly [-R].
		elif ! jail -vr "$_jail"  >> ${QBLOG}_${_jail} 2>&1 ; then
			if chk_isrunning "$_jail" ; then
				# -(R)emove jail, rerun exec-release to make sure it's in a clean ending state
				jail -vR "$_jail"  >> ${QBLOG}_${_jail} 2>&1
				/bin/sh ${QBDIR}/exec-release "$_jail"

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
	_tmpsnaps="${QTMP}/.tmpsnaps"

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

	# Jails need to usermod for unique user.
	if ! chk_isvm "$_jail" ; then
		get_jail_shell "$_jail"
		# Drop the flags for etc directory and add the user for the jailname
		chflags -R noschg ${M_QROOT}/${_jail}/etc/
		pw -V ${M_QROOT}/${_jail}/etc/ \
				useradd -n $_jail -u 1001 -d /home/${_jail} -s /bin/csh 2>&1
	fi
	eval $_R0
}

reclone_zusr() {
	# Destroys the existing zusr clone of <_jail>, and replaces it
	# Detects changes since the last snapshot, creates a new snapshot if necessary,
	# and destroys old snapshots when no longer needed.
	local _fn="reclone_zusr" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Variables definitions
	local _jail="$1"
	local _jailzfs="${U_ZFS}/${_jail}"
	local _template="$2"
	local _templzfs="${U_ZFS}/${_template}"
	local _date=$(date +%s)
	local _ttl=$(( _date + 30 ))
	local _newsnap="${_templzfs}@${_date}"
	local _presnap=$(zfs list -t snapshot -Ho name ${_templzfs} | tail -1)

	[ -z "$_jail" ] && get_msg $_qr -m _e0 -- "jail" && eval $_R1
	[ -z "$_template" ] && get_msg $_qr -m _e0 -- "template" && eval $_R1

	# `zfs-diff` from other jails causes a momentary snapshot which the reclone operation
	if chk_valid_zfs "$_presnap" ; then
		while [ -z "${_presnap##*@zfs-diff*}" ] ; do
			# Loop until a proper snapshot is found
			sleep .1
			_presnap=$(zfs list -t snapshot -Ho name ${_templzfs} | tail -1)
		done
	fi

	# If there's a presnap, and no changes since then, use it for the snapshot.
	[ "$_presnap" ] && ! [ "$(zfs diff "$_presnap" "$_templzfs")" ] && _newsnap="$_presnap"

	# If they're equal, then the valid/current snapshot already exists. Otherwise, make one.
	if ! [ "$_newsnap" = "$_presnap" ] ; then
		# Clone and set zfs params so snapshot will get auto deleted later.
		zfs snapshot -o qubsd:destroy-date="$_ttl" \
		 				 -o qubsd:autosnap='-' \
						 -o qubsd:autocreated="yes" "$_newsnap"
	fi

   # Destroy the dataset and reclone it (only if jail is off).
	! chk_isrunning "$_jail" && { zfs destroy -rRf "${_jailzfs}" > /dev/null 2>&1 \
		; zfs clone -o qubsd:autosnap='false' "${_newsnap}" ${_jailzfs} ;}

	if ! chk_isvm ${_jail} ; then
		# Drop the flags for etc directory and add the user for the jailname
		[ -e "${M_ZUSR}/${_jail}/rw" ] && chflags -R noschg ${M_ZUSR}/${_jail}/rw
		[ -e "${M_ZUSR}/${_jail}/home/${_template}" ] \
				&& chflags noschg ${M_ZUSR}/${_jail}/home/${_template}
		# Replace the <template> jailname in fstab with the new <jail>
		sed -i '' -e "s/${_template}/${_jail}/g" ${M_ZUSR}/${_jail}/rw/etc/fstab > /dev/null 2>&1

		# Rename directories and mounts with dispjail name
		mv ${M_ZUSR}/${_jail}/home/${_template} ${M_ZUSR}/${_jail}/home/${_jail} > /dev/null 2>&1
	fi

	eval $_R0
}

select_snapshot() {
	# Generalized function to be shared across qb-start/stop, and reclone_zfs's
	# Returns the best/latest snapshot for a given ROOTENV
	local _fn="select_snapshot" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	local _jlsdate ; local _rootsnaps ; local _snapdate ; local _newsnap
	local _tmpsnaps="${QTMP}/.tmpsnaps"
	local _rootzfs="${R_ZFS}/${_rootenv}"

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
	elif [ -z "${0##*exec-release}" ] || [ -z "${0##*qb-stop}" ] ; then
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

copy_control_keys() {
	# Ensures that the latest ssh pubkey for the control jail is copied to client jail
	# In the case of a restart of the control jail, use [-f] to make sure flags are restored

	getopts f _opts && local _flags="true" && shift
	local _control="$1"
	local _client="$2"

	# Lift flags for edits, create the .ssh directory if not there, and copy the files
	chflags -R noschg ${M_QROOT}/${_client}/root
	[ ! -d "${M_QROOT}/${_client}/root/.ssh" ] && mkdir ${M_QROOT}/${_client}/root/.ssh
	cp ${M_ZUSR}/${_control}/rw/root/.ssh/id_rsa.pub ${M_QROOT}/${_client}/root/.ssh/authorized_keys

	# Change ownership and permissions of all files, then bring up flags
	chmod 700 ${M_QROOT}/${_client}/root/.ssh
	chmod 600 ${M_QROOT}/${_client}/root/.ssh/authorized_keys
	chflags -R schg ${M_QROOT}/${_client}/root/.ssh

	# Repeat all the same steps if there is an unprivileged user
	if [ -d "${M_QROOT}/${_client}/home/${_client}" ] ; then

		chflags -R noschg ${M_QROOT}/${_client}/home/${_client}
		[ ! -d "${M_QROOT}/${_client}/home/${_client}/.ssh" ] \
			&& mkdir ${M_QROOT}/${_client}/home/${_client}/.ssh
		chflags -R noschg ${M_QROOT}/${_client}/home/${_client}/.ssh
		cp ${M_ZUSR}/${_control}/rw/root/.ssh/id_rsa.pub \
			${M_QROOT}/${_client}/home/${_client}/.ssh/authorized_keys

		chmod 700 ${M_QROOT}/${_client}/home/${_client}/.ssh
		chmod 600 ${M_QROOT}/${_client}/home/${_client}/.ssh/authorized_keys
		chown -R 1001:1001 ${M_QROOT}/${_client}/home/${_client}/.ssh
		chflags -R schg ${M_QROOT}/${_client}/home/${_client}/.ssh
	fi

	[ "$_flags" ] && /usr/local/bin/qb-flags -r $_client &
	eval $_R0
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

monitor_vm_stop() {
	# Loops until VM stops, or timeout (20 seconds)
	local _fn="monitor_vm_stop" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _qms='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _jail="$1"
		[ -z "$_jail" ] && eval $_R1
	local _timeout="$2"
		: ${_timeout:=20}
	local _count=1

	# Get message about waiting
	get_msg $_qms -m _m4 -- "$_jail" "$_timeout"

	# Check for when VM shuts down.
	while [ "$_count" -le "$_timeout" ] ; do
		sleep 1

		if ! pgrep -xqf "bhyve: $_jail" ; then
			# If we _count was being shown, put an extra line before returning
			[ -z "$_qms" ] && echo ''
			eval $_R0
		fi

		_count=$(( _count + 1 ))
		[ "$_qms" ] || printf "%b" " .. ${_count}"
	done

	# Fail for timeout
	eval $_R1
}

discover_xpra_socket() {
	# Finds an unused socket for xpra (technically DISPLAY, but socket feels more descriptve)
	local _fn="discover_xpra_socket" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	local _socket
	while getopts qV opts ; do case $opts in
		q) _q='-q' ;;
		V) local _V="-V" ;;
		*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	local _jail="$1"

	# See if the jail/socket combo is already allocated in _TMP_IP. Return if so.
	[ -z "$_TMP_IP" ] && _TMP_IP="${QTMP}/.qb-start_temp_ip"
	[ -e "$_TMP_IP" ] && _socket=$(sed -En "s/^${_jail} XPRA ([0-9]+)/\1/p" $_TMP_IP)
	[ "$_socket" ] && echo "$_socket" && eval $_R0

	# Initialize key variables if not already done
	[ -z "$_XPRA_SOCKETS" ] && get_info _XPRA_SOCKETS
	[ -z "$_socket" ] && _socket="100"

	# If the socket is empty (nothing in _TMP_IP), then find an available socket
	while : ; do
		# Check the TMP_IP, and host ps for an unused xpra socket (DISPLAY) number
		if grep -Eqs "XPRA $_socket" $_TMP_IP || echo "$_XPRA_SOCKETS" | grep -Eqs "$_socket" ; then
			_socket=$(( _socket + 1 ))
			# Error after arbitrary 200 cycles to prevent infinite loop
			[ "$_socket" -gt 300 ] && get_msg $_q $_V -m _e && eval $_R1
		else break
		fi
	done

	echo $_socket
	eval $_R0
}

start_xpra() {
	# Starts the xpra server, then client
	local _fn="start_xpra" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV opts ; do case $opts in
		q) _q='-q' ;;
		V) local _V="-V" ;;
		*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_q -m _e0 -- "JAIL" && eval $_R1

	# Check that Xpra is installed in the ROOTENV before continuing. Return 0 if not present
	_rootenv=$(get_jail_parameter -deqs ROOTENV $_jail)
	[ ! -e "${M_QROOT}/${_rootenv}/usr/local/bin/xpra" ] && eval $_R0

	# Get an available xpra socket (DISPLAY) number
	! _socket=$(discover_xpra_socket "$_jail") && get_msg $_q $_V -m _e && eval $_R1

	if chk_isvm "$_jail" ; then
		:
	else
		# Make sure things start in a clean state
		rm -r ${M_ZUSR}/${_jail}/home/${_jail}/.xpra/* > /dev/null 2>&1

		# Start the server inside the jail
		jexec -l -U "$_jail" "$_jail" xpra start :${_socket} --socket-dir=/tmp/xpra --audio=no \
			--notifications=no --tray=no --system-tray=no --opengl=force \
			--mmap=/tmp/xpra --desktop-scaling=auto --clipboard=yes --clipboard-direction=both \
			> /dev/null 2>&1 &

		# Modify the login environment
		_b='.profile .bash_profile .bashrc .bash_login .kshrc .shrc .zshrc .zshenv .zprofile .zlogin'
		_c='.cshrc .tcshrc .login'
		for _shell in $_b ; do
			if [ -e "${M_ZUSR}/${_jail}/home/${_jail}/${_shell}" ] ; then
				sed -i '' -E "/DISPLAY/d" ${M_ZUSR}/${_jail}/home/${_jail}/${_shell}
				echo "export DISPLAY=:${_socket}" >> ${M_ZUSR}/${_jail}/home/${_jail}/${_shell}
			fi
		done
		for _shell in $_c ; do
			if [ -e "${M_ZUSR}/${_jail}/home/${_jail}/${_shell}" ] ; then
				sed -i '' -E "/DISPLAY/d" ${M_ZUSR}/${_jail}/home/${_jail}/${_shell}
				echo "setenv DISPLAY :${_socket}" >> ${M_ZUSR}/${_jail}/home/${_jail}/${_shell}
			fi
		done

		# If Xorg is installed on host, begin loop (external to start script) to attach xpra.
		pkg query %n Xorg > /dev/null 2>&1 && launch_xpra_loop &
	fi
	eval $_R0
}

launch_xpra_loop() {
	# We dont want to hang the start script merely waiting for the host to attach to xpra.
	# This function is started in a subshell, creates a script, then forks to new process.
	local _fn="launch_xpra_loop" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Send the commands to a temp file
	cat <<-ENDOFCMD > "${QTMP}/.wait_xpra_${_jail}"
		#!/bin/sh
		# New script wont know about caller functions. Need to source them again
		. /usr/local/lib/quBSD/quBSD.sh
		. /usr/local/lib/quBSD/msg-quBSD.sh

		# Get globals, although errfiles arent needed
		get_global_variables
		rm_errfiles

		# Launch the loop that waits for X11 or for the jail's xpra server to stop
		connect_host_to_xpra "$_jail" "$_socket"
ENDOFCMD

	# Make the file executable, and fork to it
	chmod +x "${QTMP}/.wait_xpra_${_jail}"
	exec "${QTMP}/.wait_xpra_${_jail}"
	eval $_R0
}

connect_host_to_xpra() {
	# It takes a moment for xpra server to start; plus, host might not be in an Xorg session yet.
	# /tmp script will manage the loop, waiting for host X11 to start, or jailed xpra server to stop

	# Cleanup the temporary script
	_jail="$1"
	_socket="$2"
	trap "rm ${QTMP}/.wait_xpra_${_jail}" TERM INT HUP QUIT EXIT

	# Wait for the jailed xpra serve to be ready, before continuing to the host X11 wait loop
	while : ; do
		if xpra list --socket-dir="${M_QROOT}/${_jail}/tmp/xpra" 2>&1 \
			| grep -Eqs "LIVE session at :${_socket}"
		then break
		else
			# If xpra fails inside the jail, exit the wait script entirely. Otherwise, loop.
			! pgrep -qflj ${_jail} xpra && exit 0
			sleep .5
		fi
	done

	while : ; do
		# Parallel starts, multiple loops sometimes false positive the `pgreg Xorg`. Filter out pgrep
		#if pgrep -fl '/usr/local/libexec/Xorg' | grep -v pgrep >> /root/tempf ; then
		if ps -ax | grep '/usr/local/libexec/Xorg' | grep -v grep >> /root/tempf ; then
			_display=$(pgrep -fl Xorg | sed -En "s/.*Xorg (:[0-9]+) .*/\1/p")

			DISPLAY="$_display" xpra attach --audio=no --notifications=no \
				--tray=no --system-tray=no --opengl=force --mmap=${Q_ROOT}/${_jail}/tmp/xpra \
				--desktop-scaling=auto --clipboard=yes --clipboard-direction=both \
				--socket-dir=${M_QROOT}/${_jail}/tmp/xpra > /dev/null 2>&1 &
			break
		else
			# Check xpra server is still running inside jail. Otherwise no reason to continue loop.
			! pgrep -flqj ${_jail} 'xpra start :' > /dev/null 2>&1 && break
			sleep 1
		fi
	done
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
		grep -Eq "^${_jail}[[:blank:]]+" $QCONF || \
		grep -Eq "^${_jail}[[:blank:]]*\{" $JCONF ; then
		get_msg $_qa -m _e13_2 -- "$_jail" && eval $_R1
	fi

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


########################################################################################
###################################  SANITY  CHECKS  ###################################
########################################################################################

chk_valid_zfs() {
	# Silently verifies existence of zfs dataset, because zfs has no quiet option
	zfs list -- $1 >> /dev/null 2>&1  &&  return 0  ||  return 1
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
	! grep -Eqs "^${_value}[[:blank:]]+ROOTENV[[:blank:]]+[^[:blank:]]+" $QCONF \
		&& get_msg $_qv $_V -m _e2 -- "$_value" "ROOTENV" \
		&& get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1

	# Jails must have an entry in JCONF
	! chk_isvm -c $_class && ! grep -Eqs "^${_value}[[:blank:]]*\{" $JCONF \
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
			local _templ_class=$(sed -nE "s/^${_template}[[:blank:]]+CLASS[[:blank:]]+//p" $QCONF)
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
		appjail|dispjail|rootjail|cjail|rootVM|appVM|dispVM) eval $_R0 ;;
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
	echo "$_value" | grep -Eq "(,,+|--+|,-|-,|,[[:blank:]]*-|^[^[:digit:]])" \
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

	local _class=$(sed -nE "s/^${_value}[[:blank:]]+CLASS[[:blank:]]+//p" $QCONF)
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
	local _class_gw=$(sed -nE "s/^${_gw}[[:blank:]]+CLASS[[:blank:]]+//p" $QCONF)

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
		auto) [ "$_rp" ] && { _value=$(assign_ipv4_auto -et NET "$_jail") && eval $_R0 ;} || eval $_R1
			;;
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

	# Assigns global variables that will be used here for checks.
	define_ipv4_convention "$_jail"

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

	! chk_integer -v "MTU" -- "$_value" && get_msg $_q -m _e1 -- "$_value" "MTU" && eval $_R1
	chk_integer -g 1200 -l 1600 -v "MTU sanity check:" -- "$_value" && eval $_R0
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
	local _class=$(sed -nE "s/${_value}[[:blank:]]+CLASS[[:blank:]]+//p" $QCONF)
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
	echo "$_value" | ! grep -Eq -- '^(-1|-0|0|1|2|3)$' \
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
		! chk_integer -g 0 -v "Number of TAPS (in QCONF)," -- $_value \
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
	_syscpus=$(cpuset -g | head -1 | grep -oE "[^[:blank:]]+\$")
	_syscpus=$(( _syscpus + 1 ))

	# Ensure that the input is a number
	! chk_integer -G 0 -v "Number of VCPUS" -- $_value \
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



########################################################################################
###########################  FUNCTIONS RELATED TO NETWORKING  ##########################
########################################################################################

remove_tap() {
	# If TAP is not already on host, find it and bring it to host
	# Return 1 on failure, otherwise return 0 (even if tap was already on host)

	# Assign name of tap
	local _tap="$1"  ;  local _jail="$2"

	# Check if it's already on host
	ifconfig "$_tap" > /dev/null 2>&1  && ifconfig "$_tap" down && return 0

	# If a specific jail was passed, check that as the first possibility to find/remove tap
	if [ "$_jail" ] && jexec -l -U root $_jail ifconfig -l | grep -Eqs "$_tap" ; then
		ifconfig "$_tap" -vnet "$_jail" && ifconfig "$_tap" down && return 0
	fi

	# If the above fails, then check all jails
	for _jail in $(get_info -e _ONJAILS) ; do
		if jexec -l -U root $_jail ifconfig -l | grep -Eqs "$_tap" ; then
			ifconfig $_tap -vnet $_jail
			ifconfig $_tap down
			return 0
		fi
	done
	return 1
}

assign_ipv4_auto() {
	# IPV4 assignment during parallel jail starts, has potetial for overlapping IPs. $_TMP_IP
	# file is used for deconfliction during qb-start, and must be referenced by exec-created
	local _fn="assign_ipv4_auto" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts eqt:V opts ; do case $opts in
			e) _echo="true" ;;
			q) local _q='-q' ;;
			t) local _type="$OPTARG" ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 )) ; [ "$1" = "--" ] && shift

	local _client="$1"  ;  _gateway="$2"  ;  local _ipv4=
	_TMP_IP="${_TMP_IP:=${QTMP}/.qb-start_temp_ip}"

	# Pull pre-set IPV4 from the temp file if it exists, based on 0control or normal
	if [ -e "$_TMP_IP" ] ; then
		_ipv4=$(sed -nE "s#^${_client} $_type ##p" $_TMP_IP)
	fi

	# If there was no ipv4 assigned to _client in the temp file, then find an open ip for the jail.
	[ -z "$_ipv4" ] && _ipv4=$(discover_open_ipv4 -t "$_type" "$_client" "$_gateway")

	# Echo option or assign global IPV4
	[ "$_echo" ] && echo "$_ipv4" || IPV4="$_ipv4"

	eval $_R0
}

discover_open_ipv4() {
	# Finds an IP address unused by any running jails, or in qubsd.conf. Requires [-t], to resolve
	# the different types of IPs, like with control jails, net jails, or adhoc connections.
	# Echo open IP on success; Returns 1 if failure to find an available IP.
	local _fn="discover_open_ipv4" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qt:V opts ; do case $opts in
			q) _qi="-q" ;;
			t) local _type="$OPTARG" ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 )) ; [ "$1" = "--" ] && shift

	local _client="$1"  ;  local _ip_test
	_TMP_IP="${_TMP_IP:=${QTMP}/.qb-start_temp_ip}"
	_gateway=${_gateway:="$(get_jail_parameter -deqs GATEWAY $_client)"}

	# If gateway is a VM, then DHCP will be required, regardless
	chk_isvm "$_gateway" && echo "DHCP" && eval $_R0

	# Assigns values for each IP position, and initializes $_cycle
	define_ipv4_convention -t "$_type" "$_client" "$_gateway"

	# Get a list of all IPs in use. Saves to variable $_USED_IPS
	get_info _USED_IPS

	# Increment $_ip2 until an open IP is found
	while [ $_ip2 -le 255 ] ; do

		# Compare against QCONF, and the IPs already in use, including the temp file.
		_ip_test="${_ip0}.${_ip1}.${_ip2}"
		if grep -Fq "$_ip_test" $QCONF || echo "$_USED_IPS" | grep -Fq "$_ip_test" \
				|| grep -Fqs "$_ip_test" "$_TMP_IP" ; then

			# Increment for next cycle
			_ip2=$(( _ip2 + 1 ))

			# Failure to find IP in the quBSD conventional range
			if [ $_ip2 -gt 255 ] ; then
				_passvar="${_ip0}.${_ip1}.X.${_ip3}"
				get_msg $_qi -m _e30 -- "$_client" "$_passvar"
				eval $_R1
			fi
		else
			# Echo the value of the discovered IP and return 0
			echo "${_ip_test}.${_ip3}/${_subnet}" && eval $_R0
		fi
	done
	eval $_R0
}

define_ipv4_convention() {
	# Defines the quBSD internal IP assignment convention.
	# Variables: $ip0.$ip1.$ip2.$ip3/subnet ; are global; required for discover_open_ipv4(),
	# and chk_isqubsd_ipv4(). Not best practice, but they're unique from any others.
	# Return: 0 for normal assignment; 1 for net-firewall. gateway=0control goes first
	local _fn="define_ipv4_convention" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qt:V _opts ; do case $_opts in
		q) local _q='-q' ;;
		t) local _type="$OPTARG" ;;
		V) local _V="-V" ;;
		*) get_msg -m _e9 ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _client="$1"
	# _ip assignments are static, except for $_ip1
	_ip0=10 ; _ip2=1 ; _ip3=2 ; _subnet=30

	# Combo of function caller and JAIL/VM determine which IP form to use
	case $_type in
		ADHOC) # Temporary, adhoc connections have the form: 10.88.x.2/30
			_ip1=88 ; _subnet=29 ;;
		SSH) # Control jails operate on 10.99.x.0/30
			_ip1=99 ; _subnet=30 ;;
		NET|*) case "${_client}" in
				net-firewall*) # firewall IP is not internally assigned, but router dependent.
					_cycle=256 ; eval $_R1 ;;
				net-*) # net jails IP address convention is: 10.255.x.0/30
					_ip1=255 ;;
				serv-*) # Server jails IP address convention is: 10.128.x.0/30
					_ip1=128 ;;
				*) # All other jails should receive convention: 10.1.x.0/30
					_ip1=1 ;;
			esac
	esac
	eval $_R0
}

connect_client_to_gateway() {
	# When a jail/VM is started, this connects to its gateway
	# GLOBAL VARIABLES must have been assigned already: $GATEWAY ; $IPV4 ; $MTU
		# -e (e)cho result  ;  -m (m)tu  ;  -q (q)uiet  ;  -t (t)ype [NET or SSH]
	local _fn="connect_client_to_gateway" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	local _ipv4=  ;  local _type=  ;  local _ec  ;  local _mtu  ;  local _q
	local _dhcpd_restart  ;  local _named_restart
	while getopts cdei:m:nqV opts ; do case $opts in
			c) _type="SSH" ;;
			d) _dhcpd_restart="true" ;;
			e) _ec='true' ;;
			i) _ipv4="$OPTARG"  ;;
			m) _mtu="$OPTARG" ;;
			n) _named_restart="true" ;;
			q) _q='-q' ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	# Pos params, default MTU, and _type
	local _client="$1"  ;  local _gateway="$2"
	_mtu="${MTU:=$(get_jail_parameter -des MTU $_gateway)}"
	local _type="${_type:=NET}"

	# If IP wasnt provided, then find an available one
	[ -z "$_ipv4" ] && local _ipv4=$(assign_ipv4_auto -et "$_type" "$_client" "$_gateway")

	# This function can be called by multiple scripts/functions that dont know which is a VM or jail
	if chk_isvm "$_client" ; then
		# Get tap, send to gateway jail, bring up jail connection
		_vifb=$(sed -En "s/ ${_type}//p" "${QTMP}/vmtaps_${_client}")
		ifconfig "$_vifb" vnet "$_gateway"
		jexec -l -U root $_gateway ifconfig $_vifb inet ${_ipv4%.*/*}.1/${_ipv4#*/} mtu $_mtu up

		# If flagged, restart dhcpd, so the new IP will be included
		if [ "$_dhcpd_restart" ] ; then
			# While loop avoids races/overlaps for potential multiple VM simultaneous starts
			local _count=0
			while jexec -l -U root $_gateway pgrep -fq 'isc-dhcpd restart' > /dev/null 2>&1 ; do
				{ [ "$_count" -le 10 ] && sleep .2 ; _count=$(( _count + 1 )) ;} || eval $_R1
			done
			jexec -l -U root $_gateway service isc-dhcpd restart > /dev/null 2>&1
		fi

		# If flagged, restart dhcpd, so the new IP will be included
		if [ "$_named_restart" ] ; then
			# While loop avoids races/overlaps for potential multiple VM simultaneous starts
			local _count=0
			while jexec -l -U root $_gateway pgrep -fq 'named restart' > /dev/null 2>&1 ; do
				{ [ "$_count" -le 10 ] && sleep .2 ; _count=$(( _count + 1 )) ;} || eval $_R1
			done
			jexec -l -U root $_gateway service named restart > /dev/null 2>&1
		fi

	elif chk_isvm "$_gateway" ; then
		# Get tap and sent to client jail. Should be DHCP, but modify mtu if necessary
		_vifb=$(sed -En "s/ ${_type}//p" "${QTMP}/vmtaps_${_gateway}")

 		ifconfig $_vifb vnet $_client
		[ ! "$_mtu" = "1500" ] && jexec -l -U root $_client ifconfig $_vifb mtu $_mtu up

	else
		# Create epair and assign _vif variables.
		local _vif=$(ifconfig epair create)  ;  local _vifb="${_vif%?}b"
		ifconfig "$_vif" vnet $_gateway

		# If connecting two jails (and not host), send the epair, and assign the command modifier.
		if [ ! "$_client" = "host" ] ; then
			ifconfig "${_vifb}" vnet $_client
			local _cmdmod='jexec -l -U root $_client'
		fi

		# If there's no IP skip the epair assignments
		if [ ! "$_ipv4" = "none" ] ; then
			# Assign the gateway IP
			jexec -l -U root "$_gateway" \
							ifconfig "$_vif" inet ${_ipv4%.*/*}.1/${_ipv4#*/} mtu $_mtu up

			# Assign the client IP and, default route (if not control gateway)
			eval "$_cmdmod" ifconfig $_vifb inet ${_ipv4} mtu $_mtu up
			[ "$_type" = "NET" ] && eval "$_cmdmod" route add default "${_ipv4%.*/*}.1" >/dev/null 2>&1
	fi fi

	# Add the jail and vif to a tracking file
	[ "$_type" = "SSH" ] && echo "$_client $_vifb ${_ipv4%%/*}" >> ${QTMP}/control_netmap

	# Echo option. Return epair-b ; it's the external interface for the jail.
	[ "$_ec" ] && echo "$_vifb"
	eval $_R0
}

connect_gateway_to_clients() {
	# If clients were already started, then the gateway needs to reconnect to its clients
	local _fn="connect_gateway_to_clients" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _gateway="$1"
	[ -z "$_gateway" ] && get_msg $_q -m _e0 -- "Jail/VM" && eval $_R1

	# All onjails connect to 0control
	if [ "$CLASS" = "cjail" ] ; then
		for _client in $(get_info -e _ONJAILS | grep -v "$_gateway") ; do
			if [ "$(get_jail_parameter $_q -de CONTROL $_client)" = "$_gateway" ] ; then
				connect_client_to_gateway -c $_q "$_client" "$_gateway"
				! chk_isvm $_client && copy_control_keys -f $_gateway $_client
			fi
		done
	fi

	# Restore connection to CLIENTS one by one
	for _client in $(get_info -e _CLIENTS "$_gateway") ; do
		if chk_isrunning "$_client" ; then

			# Get client IP, bring up connection, and save the VIF used
			_cIP=$(get_jail_parameter -der IPV4 "$_client")
			_cVIF=$(connect_client_to_gateway -ei "$_cIP" "$_client" "$_gateway")

			# If client is itself a gateway, its pf.conf needs the new epair and IP (cVIF and cIP)
			_cPF="${M_ZUSR}/${_client}/${PFCONF}"
			if [ -e "$_cPF" ] ; then

				# Flags down, modify files
				chflags -R noschg "${M_ZUSR}/${_client}/rw/etc"
				sed -i '' -e "s@^[[:blank:]]*EXT_IF[[:blank:]]*=.*@\tEXT_IF = \"${_cVIF}\"@" $_cPF
				sed -i '' -e "s@^[[:blank:]]*JIP[[:blank:]]*=.*@\tJIP = \"${_cIP}\"@"  $_cPF

				# Restart _client pf service. Restore flags with qb-flags -r (we dont know seclvl here)
				jexec -l -U root "$_client" service pf restart > /dev/null 2>&1
				/usr/local/bin/qb-flags -r $_client > /dev/null 2>&1 &
		fi fi
	done
	eval $_R0
}



########################################################################################
##########################  FUNCTIONS RELATED TO VM HANDLING ###########################
########################################################################################

cleanup_vm() {
	# Cleanup function after VM is stopped or killed in any way
	local _fn="cleanup_vm" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Positional params and func variables.
	while getopts nqV opts ; do case $opts in
			n) local _norun="-n" ;;
			q) local _qcv="-q" ;;
			V) local _V="-V" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	# Positional variables
	local _VM="$1"  ;  local _rootenv="$2"
	[ -z "$_VM" ] && get_msg $_qcv -m _e0 && eval $_R1

	# Bring all recorded taps back to host, and destroy
	for _tap in $(sed -E 's/ .*$//' "${QTMP}/vmtaps_${_VM}" 2> /dev/null) ; do
		if [ -n "$_norun" ] ; then
			ifconfig "$_tap" destroy 2>&1 /dev/null
			sed -i '' -E "/$_tap/d" ${QTMP}/control_netmap
		else
			# Trying to prevent searching in all jails, by guessing where tap is
			_tapjail="$_clients"
			[ -z "$_tapjail" ] && _tapjail=$(get_jail_parameter -deqsz GATEWAY ${_VM})

			# Remove the tap
			remove_tap "$_tap" "$_tapjail" \
				&& ifconfig "$_tap" destroy \
				&& sed -i '' -E "/$_tap/d" ${QTMP}/control_netmap
		fi
	done

	# Remove the taps tracker file
	rm "${QTMP}/vmtaps_${_VM}" > /dev/null 2>&1

	# Destroy the VM
	bhyvectl --vm="$_VM" --destroy > /dev/null 2>&1

	# Set the PPT device back to its original state before VM prep/launch
	[ ! "$_ppt" = "none" ] && return_ppt "$_VM"

	# If it was a norun, dont spend time recloning
	[ -n "$_norun" ] && eval $_R0

	# Pull _rootenv in case it wasn't provided, and reclone it
	[ -z "$_rootenv" ] && ! _rootenv=$(get_jail_parameter -e ROOTENV $_VM) && eval $_R1
	reclone_zroot -q "$_VM" "$_rootenv"

	# If it's a dispVM then get the template, and reclone it
	[ "$(get_jail_parameter -es CLASS $_VM)" = "dispVM" ] && [ -z "$_template" ] \
		&& ! _template=$(get_jail_parameter -e TEMPLATE $_VM) && eval $_R1
	reclone_zusr "$_VM" "$_template"

	# Remove the /tmp files
	rm "${QTMP}/qb-bhyve_${_VM}" 2> /dev/null
	rm_errfiles
	eval $_R0
}

return_ppt() {
	# After VM completion, put PPT devices back to original state (as specified in loader.conf)
	local _fn="return_ppt" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _VM="$1"
	[ -z "$_VM" ] && get_msg $_q -m _e0 -- "VM name" && eval $_R1

	# Get PPT devices from the actual bhyve command that was launched for the VM
	_bhyvecmd=$(tail -1 "${QBLOG}_${_VM}" 2>&1)
	while : ; do
		_newppt=$(echo "$_bhyvecmd" | sed -En "s@.*passthru,([0-9/]+[0-9/]+[0-9/]+ ).*@\1@p")
		[ -z "$_newppt" ] && break
		_ppt=$(echo "$_ppt $_newppt")
		_bhyvecmd=$(echo "$_bhyvecmd" | sed -E "s@$_newppt@@")
	done

	# If there were any _ppt values, reset them to their state before VM launch
	_pciconf=$(pciconf -l | awk '{print $1}')
	for _val in $_ppt ; do
		# convert _val to native pciconf format with :colon: instead of /fwdslash/
		_val2=$(echo "$_val" | sed "s#/#:#g")

		# Search for the individual device and specific device for devctl functions later
		_pciline=$(echo "$_pciconf" | grep -Eo ".*${_val2}")
		_pcidev=$(echo "$_pciline" | grep -Eo "pci.*${_val2}")

		# PCI device doesnt exist on the machine
		[ -z "$_pciline" ] && get_msg $_q -m _e22 -- "$_val" "PPT" \
			&& get_msg -Vpm _e1 -- "$_val" "PPT" && eval $_R1

		# If the device isnt listed in loader.conf, then return it to host
		if ! grep -Eqs "pptdevs=.*${_val}" /boot/loader.conf ; then
			# Detach the PCI device, and examine the error message
			_dtchmsg=$(devctl detach "$_pcidev" 2>&1)
			[ -n "${_dtchmsg##*not configured}" ] && get_msg -m _e22_1 -- "$_pcidev" \
				&& get_msg -Vpm _w5 -- "$_pcidev"

			# Clear the driver returns it back to the host driver (unless it booted as ppt)
			! devctl clear driver $_pcidev && get_msg -Vpm _w5 -- "$_pcidev" && eval $_R1
		fi
	done
	eval $_R0
}

prep_bhyve_options() {
	# Prepares both line options and the host system for the bhyve command
	# CAPS variables are the final line options for the bhyve command
	local _fn="prep_bhyve_options" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _qs='-q' ;;
		V) local _V="-V" ;;
		*) get_msg -m _e9 ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Get simple QCONF variables
	_VM="$1"
	_cpuset=$(get_jail_parameter -de CPUSET "$_VM")        || eval $_R1
	_gateway=$(get_jail_parameter -dez GATEWAY "$_VM")     || eval $_R1
	_clients=$(get_info -e _CLIENTS "$_VM")
	_control=$(get_jail_parameter -de  CONTROL "$_VM")     || eval $_R1
	_ipv4=$(get_jail_parameter -derz IPV4 "$_VM")          || eval $_R1
	_memsize=$(get_jail_parameter -de MEMSIZE "$_VM")      || eval $_R1
	_wiremem=$(get_jail_parameter -de WIREMEM "$_VM")      || eval $_R1
	_bhyveopts=$(get_jail_parameter -de BHYVEOPTS "$_VM")  || eval $_R1
	_rootenv=$(get_jail_parameter -e ROOTENV "$_VM")       || eval $_R1
	_taps=$(get_jail_parameter -de TAPS "$_VM")            || eval $_R1
	_template=$(get_jail_parameter -ez TEMPLATE "$_VM")    || eval $_R1
	_vcpus=$(get_jail_parameter -de VCPUS "$_VM")          || eval $_R1
	_vnc=$(get_jail_parameter -dez VNC "$_VM")             || eval $_R1
	_x11=$(get_jail_parameter -dez X11 "$_VM")             || eval $_R1
	_ppt=$(get_jail_parameter -dexz PPT "$_VM")            || eval $_R1
	_tmux=$(get_jail_parameter -dez TMUX "$_VM")           || eval $_R1
	# UEFI bootrom
	_BOOT="-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd"

	# Add leading '-' to _bhyveopts
	_BHOPTS="-${_bhyveopts}"

	# Get wildcard bhyve option added by user
	_bhyve_custm=$(sed -En "s/${_VM}[[:blank:]]+BHYVE_CUSTM[[:blank:]]+//p" $QCONF \
						| sed -En "s/[[:blank:]]+/ /p")

	# RAM and memory handling
	_RAM="-m $_memsize"
	[ "$_wiremem" = "true" ] && _WIRE='-S' || _WIRE=''

	# Assign hostbridge based on CPU
	grep -Eqs "^CPU.*AMD" /var/run/dmesg.boot \
		&& _HOSTBRG="-s 0,amd_hostbridge" \
		|| _HOSTBRG="-s 0,hostbridge"

	# Handle CPU pinning, or if none, then just assign the number of vcpus
	_vcpu_count=0 ; IFS=','
	for _range in $_cpuset; do
		case "$_range" in
			none) # CPUSET was none, so there is no pinning. Assign the variable and break
				_CPU="-c $_vcpus"
				break
			;;
			*-*) # It's a range; extract the start and end
				_start=$(echo "$_range" | cut -d'-' -f1)
				_end=$(echo "$_range" | cut -d'-' -f2)

				# Loop over the range to append to the _cpupin string
				while [ "$_start" -le "$_end" ]; do
					_CPUPIN="$_CPUPIN -p $_vcpu_count:$_start"
					_vcpu_count=$(( _vcpu_count + 1 ))
					_start=$(( _start + 1 ))
				done
			;;
			*) # It's a single number; directly append to the _CPUPIN string
				_CPUPIN="$_CPUPIN -p $_vcpu_count:$_range"
				_vcpu_count=$(( _vcpu_count + 1 ))
			;;
		esac
	done
	# Output the final _cpupin string
	[ -z "$_CPU" ] && _CPU="-c $_vcpu_count"
	unset IFS

	# BEGIN SLOT ASSIGNMENTS FOR PCI DEVICES
	_slot=1
	_LPC="-s 31,lpc"

	# Assign zroot blk device
	_BLK_ROOT="-s ${_slot},virtio-blk,/dev/zvol/${R_ZFS}/${_VM}"
	_slot=$(( _slot + 1 ))

	# Assign zusr blk device. Must be a volume; or should be blank
	chk_valid_zfs "${U_ZFS}/${_VM}" \
		&& zfs list -Ho type "${U_ZFS}/${_VM}" | grep -qs "volume" \
		&& _BLK_ZUSR="-s ${_slot},virtio-blk,/dev/zvol/${U_ZFS}/${_VM}" \
		&& _slot=$(( _slot + 1 )) || _BLK_ZUSR=''

	# Handling BHYVE_CUST options
	[ "$_bhyve_custm" ] && while IFS= read -r _line ; do

		# User can specify for quBSD to fill in the slot for -s.
		if [ -z "${_line##-s \#*}" ] ; then
			# If a slot was included with a '#', it means to autofill the slot
			_line=$(echo "$_line" | sed -E "s/-s #/-s ${_slot}/")
			_slot=$(( _slot + 1 )) ; [ "$_slot" -eq 29 ] && _slot=32
		fi

		# Make _BHYVE_CUSTM a single line variable for later inclusion with bhyve command
		_BHYVE_CUSTM=$(printf "%b" "${_BHYVE_CUSTM} ${_line}")

	# Personal note: herefile is required; else, `echo $var | while` subshell will lose _BHYVE_CUSTM
	done << EOF
$_bhyve_custm
EOF

	# Assign passthrough variables
	if [ ! "$_ppt" = "none" ] ; then
		for _pci in $_ppt ; do
			_PPT=$(printf "%b" "${_PPT} -s ${_slot},passthru,\"${_pci}\"")
			_WIRE="-S"
			_slot=$(( _slot + 1 )) ; [ "$_slot" -eq 29 ] && _slot=32
		done
	fi

	# Assign VNC FBUF options
	if [ "$_vnc" ] && [ ! "$_vnc" = "false" ] ; then

		# Define height/width from the QCONF entry
		_w=$(echo "$_vnc" | grep -Eo "^[[:digit:]]+")
		_h=$(echo "$_vnc" | grep -Eo "[[:digit:]]+\$")

		# Find all sockets in use, and define starting socket to search
		_socks=$(sockstat -P tcp | awk '{print $6}' | grep -Eo ":[[:digit:]]+")
		_vncport=5900

		# cycle through sockets until an unused one is found
		while : ; do
			echo "$_socks" | grep -qs "$_vncport" && _vncport=$(( _vncport + 1 )) || break
		done

		_FBUF="-s 29,fbuf,tcp=0.0.0.0:${_vncport},w=${_w},h=${_h}"
		_TAB="-s 30,xhci,tablet"
	fi

	# Launch a serial port if tmux is set in QCONF. The \" and TMUX2 closing " are intentional.
	[ "$_tmux" = "true" ] && _STDIO="-l com1,stdio" \
		&& _TMUX1="/usr/local/bin/tmux new-session -d -s $_VM \"" && _TMUX2='"'

	# Invoke the trap function for VM cleanup, in case of any errors after modifying host/trackers
	trap "cleanup_vm -n $_VM ; exit 0" INT TERM HUP QUIT

	# Default number of taps is 0. Add 1 for the control jail SSH connection
	_taps=$(( _taps + 1 ))
	# Also, for every gateway or client the VM touches, it needs another tap
	[ -n "$_gateway" ] && [ ! "$_gateway" = "none" ] && _taps=$(( _taps + 1 ))
	[ -n "$_clients" ] && [ ! "$_clients" = "none" ] \
			&& _taps=$(( _taps + $(echo $_clients | wc -w) ))
	# Add another tap if X11FWD is true
	[ "$_x11" = "true" ] && _taps=$(( _taps + 1 ))

	_cycle=0
	while [ "$_taps" -gt 0 ] ; do

		# Create tap, make sure it's down, increment slot
		_tap=$(ifconfig tap create)
		ifconfig $_tap down
		_VTNET=$(printf "%b" "${_VTNET} -s ${_slot},virtio-net,${_tap}")
		_slot=$(( _slot + 1 )) ; [ "$_slot" -eq 29 ] && _slot=32
		_taps=$(( _taps - 1 ))

		# Tracker file for which taps are related to which VM, and for which purpose (_vif tags)
		case "$_cycle" in
			0) echo "$_tap SSH" >> "${QTMP}/vmtaps_${_VM}"  ;;
			1) echo "$_tap NET" >> "${QTMP}/vmtaps_${_VM}"  ;;
			2) echo "$_tap X11" >> "${QTMP}/vmtaps_${_VM}"  ;;
			3) echo "$_tap EXTRA_${_cycle}" >> "${QTMP}/vmtaps_${_VM}"  ;;
		esac
		_cycle=$(( _cycle + 1 ))
	done

	# Define the full bhyve command
	_BHYVE_CMD="$_TMUX1 bhyve $_CPU $_CPUPIN $_RAM $_BHOPTS $_WIRE $_HOSTBRG $_BLK_ROOT \
			$_BLK_ZUSR $_BHYVE_CUSTM $_PPT $_VTNET $_FBUF $_TAB $_LPC $_BOOT $_STDIO $_VM $_TMUX2"

	# unset the trap
	trap ":" INT TERM HUP QUIT EXIT

	eval $_R0
}

launch_vm() {
	# To ensure VM is completely detached from caller AND trapped after finish, a /tmp script runs
	# the launch and monitoring. qb-start/stop can only have one instance running (for race/safety)
	# but VMs launched by qb-start would otherwise persist in the process list with the VM.

	local _fn="launch_vm" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Send the commands to a temp file
	cat <<-ENDOFCMD > "${QTMP}/qb-bhyve_${_VM}"
		#!/bin/sh

		# New script wont know about caller functions. Need to source them again
		. /usr/local/lib/quBSD/quBSD.sh
		. /usr/local/lib/quBSD/msg-quBSD.sh

		# Get globals, although errfiles arent needed
		get_global_variables
		rm_errfiles

		# Create trap for post VM exit
		trap "cleanup_vm $_VM $_rootenv ; exit 0" INT TERM HUP QUIT EXIT

		# Log the exact bhyve command being run
		echo "\$(date "+%Y-%m-%d_%H:%M") Starting VM: $_VM" | tee -a $QBLOG ${QBLOG}_${_VM}
		echo $_BHYVE_CMD >> ${QBLOG}_${_VM}

		# Launch the VM to background
		eval $_BHYVE_CMD

		sleep 3

		# Monitor the VM, perform cleanup after done
		while pgrep -xfq "bhyve: $_VM" ; do sleep 1 ; done
		echo "\$(date "+%Y-%m-%d_%H:%M") VM: $_VM HAS ENDED." | tee -a $QBLOG ${QBLOG}_${_VM}
ENDOFCMD

	# Make the file executable
	chmod +x "${QTMP}/qb-bhyve_${_VM}"

	# Call the temp file with exec to separate it from the caller script
	exec "${QTMP}/qb-bhyve_${_VM}"

	eval $_R0
}

finish_vm_connections() {
	# While the _BHYVE_CMD appears in ps immediately, emulated devices are not yet attached, and
	# would cause an error. Due to qb-start dynamics/timeouts, we dont want to wait. Instead,
	# return 0 so that launches can continue, and let this function handle the connections later.
	local _fn="finish_vm_connections" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Wait for the actual bhyve VM to appear in ps. If ppt a device is bad, launch can delay 15 secs
	_count=0
	while ! pgrep -xfq "bhyve: $_VM" ; do
		sleep 1 ; _count=$(( _count + 1 ))
		[ "$_count" -ge 15 ] && get_msg -m _e4_2 -- "$_VM" && eval $_R1
	done

	# Connect control jail
	connect_client_to_gateway -cdn -- "$_VM" "$_control" > /dev/null

	# Connect to the upstream gateway
	if chk_isrunning "$_gateway" ; then
		connect_client_to_gateway -di "$_ipv4" "$_VM" "$_gateway" > /dev/null
	fi

	# If VM isnt a gateway, this will return 0
	connect_gateway_to_clients "$_VM"
	eval $_R0
}

exec_vm_coordinator() {
	# Executive management of launching the VM
	local _fn="exec_vm_coordinator" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts nqtV opts ; do case $opts in
			n) local _norun="-n" ;;
			q) local _qs="-q" ; _quiet='/dev/null 2>&1'   ;;
			t) local _tmux="-t"  ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	_VM="$1"

	# Ensure that there's nothing lingering from this VM before trying to start it
	cleanup_vm $_norun $_qs "$_VM"

	# Pulls variables for the VM, and assembles them into bhyve line options
	! prep_bhyve_options $_qs $_tmux "$_VM" && eval $_R1

	# If norun, echo the bhyve start command, cleanup the taps/files, and return 0
	if [ -n "$_norun" ] ; then
		echo $_BHYVE_CMD
		cleanup_vm -n $_VM
		eval $_R0
	fi

	# Start upstream jails/VMs, as well as control jail
	start_jail -q $_control
	! start_jail $_gateway && eval $_R1

	# Launch VM sent to background, so connections can be made (network, vnc, tmux)
	get_msg -m _m1 -- "$_jail" | tee -a $QBLOG ${QBLOG}_${_VM}
	launch_vm $_quiet &

	# Monitor to make sure that the bhyve command started running, then return 0
	local _count=0 ; sleep .5

	while ! { pgrep -xfq "bhyve: $_VM" \
				|| pgrep -fl "bhyve" | grep -Eqs "^[[:digit:]]+ .* ${_VM}[[:blank:]]*\$" ;} ; do
	sleep .5 ; _count=$(( _count + 1 ))
	[ "$_count" -ge 6 ] && get_msg -m _e4_1 -- "$_VM" && eval $_R1
	done

	finish_vm_connections &
	eval $_R0
}



########################################################################################
###################################  DEBUG LOGGING  ####################################
########################################################################################

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



