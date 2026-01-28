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
# configure_ssh_control- SSH keys for control jail are copied over to running env.
# monitor_startstop    - Monitors whether qb-start or qb-stop is still alive
# monitor_vm_stop      - Monitors whether qb-start or qb-stop is still alive
# launch_xephyr        - For qb-cmd, manages the lifecycle of Xephyr windows

#################################  STATUS  CHECKS  #################################
# chk_isblank          - Posix workaround: Variable is [-z <null> OR [ \t]*]
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
# remove_interface     - Removes tap interface from whichever jail it's in
# discover_open_ipv4   - Finds an unused IP address from the internal network
# connect_client_to_gateway - Connects a client jail to its gateway

##################################  VM  FUNCTIONS  #################################
# cleanup_vm           - Cleans up network connections, and dataset after shutdown
# return_ppt           - Set PPT devices back to original state before VM launch.
# prep_bhyve_options   - Retrieves VM variables and handles related functions
# launch_bhyve_vm      - Launches the VM to a background subshell
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
. /usr/local/lib/qubsd/msg-quBSD.sh

# Internal flow variables to handle returns, while reseting _fn and _FN variables with logging
_R0='_FN="$_fn_orig" ; return 0'
_R1='_FN="$_fn_orig" ; return 1'

get_global_variables() {
	# Global config files, mounts, and datasets needed by most scripts

	# Remove any old ERR files (for exec commands)
	[ "$ERR1" ] && [ "$ERR2" ] && rm_errfiles

	# Define variables for files
	export QETC="/usr/local/etc/qubsd"
	export QLIB="/usr/local/lib/qubsd"
	export QRUN="/var/run/qubsd"
	export QSHARE="/usr/local/share/qubsd"
	export QLEXEC="/usr/local/libexec/qubsd"
	export JCONF="$QETC/jail.conf.d/jails"
	export QCONF="$QETC/qubsd.conf"
	export QLOG="/var/log/qubsd/quBSD.log"
	export VMTAPS="$QRUN/vm_taps"

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

	# Using the caller script to generalize message calls. Switch between exec and qb- scripts.
	local _call="${0##*/}"  _msg  _NEEDPOP
	[ -z "${_call##exec.*}" ] && _msg="msg_exec" || _msg="msg_${_call##*-}"

	# Determine if popup should be used or not
	get_info _NEEDPOP

	case $_message in
		_m*|_w*) [ -z "$_q" ] && eval "$_msg" "$@" ;;
		_e*)
			if [ -z "$_force" ] ; then
				# Place final ERROR message into a variable. $ERR1 (tmp) enables func tracing
				_ERROR="$(echo "ERROR: $_call" ; "$_msg" "$@" ; [ -s "$ERR1" ] && cat $ERR1)"
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

exists_then_copy() {
	# Checks if the file exists, then copies it
	local _file="$1"  _dest="$2"
	{ [ -z "$_file" ] || [ -z "$_dest" ] ;} && return 1
	[ -e "$_file" ] && cp "$_file" "$_dest" && return 0
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
	ps c | grep -qs 'i3' && local _i3mod="i3-msg -q floating enable, move position center"

	# If a file was passed, set the msg equal to the contents of the file
	[ "$_popfile" ] && local _popmsg=$(cat $_popfile)

	# Might've been launched from quick-key or without an environment. Get the host DISPLAY
	[ -z "$DISPLAY" ] && export DISPLAY=$(pgrep -fl Xorg | grep -Eo ":[0-9]+")

	# Equalizes popup size and fonts between systems of different resolution and DPI settings.
	calculate_sizes

	# Execute popup depending on if input is needed or not
	if [ "$_cmd" ] ; then
	echo $DISPLAY >> /root/temp
		xterm -fa Monospace -fs $_fs -e /bin/sh -c "eval \"$_i3mod\" ; eval \"$_cmd\" ; "
	elif [ -z "$_input" ] ; then
		# Simply print a message, and return 0
		xterm -fa Monospace -fs $_fs -e /bin/sh -c \
			"eval \"$_i3mod\" ; echo \"$_popmsg\" ; echo \"{Enter} to close\" ; read _INPUT ;"
		eval $_R0
	else
		# Need to collect a variable, and use a tmp file to pull it from the subshell, to a variable.
		local _poptmp=$(mktemp ${QRUN}/popup.XXXX)
		xterm -fa Monospace -fs $_fs -e /bin/sh -c \
			"eval \"$_i3mod\"; printf \"%b\" \"$_popmsg\"; read _INPUT; echo \"\$_INPUT\" > $_poptmp"

		# Retreive the user input, remove tmp, and echo the value back to the caller
		_input=$(cat $_poptmp)
		rm $_poptmp > /dev/null 2>&1
		echo "$_input"
	fi
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

# Assigns global variables that will be used here for checks.
#define_ipv4_convention "$_jail"

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
	_syscpus=$(cpuset -g | head -1 | grep -oE "[^ \t]+\$")
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

connect_client_to_gateway() {

	# Unified function for connecting two jails.
		# [-d] Indicates the need for restarting isc-dhcpd in the gateway. Unused for now.
		# [-i] Provide an exact IPV4 address
		# [-q] Quiet error message
		# [-s] Services restart  -- CURRENTLY UNUSED. Probably remove later
		# [-t] separates SSH (cjail) from EXT_IF (regular gateway). Expandable
	local _fn="connect_client_to_gateway" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts di:qst:V opts ; do case $opts in
		d) local _d='true' ;;
		i) local  ipv4="$OPTARG";;
		q) local _q='-q' ;;
		s) local _s='-s' ;;
		t) local _type="$OPTARG" ;;
		V) local _V="-V" ;;
		*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	# Positional params
	local _client="$1"  _gateway="$2"  _type="${_type:=EXT_IF}"
	local ipv4  _mtu _gw_mod  _cl_mod  _gw_ip  _cl_ip  _groupmod  _cl_root

	# Get gateway if necessary. Decide whether to continue or not.
	: "${_gateway:=$(get_jail_parameter -de GATEWAY $_client)}"
	[ "$_gateway" = "none" ] && eval $_R0
	! chk_isrunning "$_gateway" && get_msg $_q $_V -m _e28 && eval $_R1

	# Reduce verbosity/switches by setting some mods for later commands
	[ "$_gateway" = "host" ] ||   _gw_mod="-j $_gateway"
	[ "$_client"  = "host" ] || { _cl_mod="-j $_client" ; _cl_root="${M_QROOT}/${_client}" ;}

	# Resolve IP addr. Respect [-i] first, otherwise assign based on _type.
	case $_type in
		CJ_SSH) : "${ipv4:=$(get_jail_parameter -de IPV4 $_gateway)}" ;;  # Should only be DHCP or auto
		EXT_IF) : "${ipv4:=$(get_jail_parameter -de IPV4 $_client)}"  ;;
	esac
	case $ipv4 in
		DHCP)
			_groupmod="group DHCPD"  # Later for ifconfig interface groups
			chk_isvm $_gateway || _gw_ip=$(discover_open_ipv4 -g -t "$_type" -- "$_client" "$_gateway")
			;;
		auto)
			_gw_ip=$(discover_open_ipv4 -g -t "$_type" -- "$_client" "$_gateway")
			_cl_ip="${_gw_ip%.*/*}.2/30"
			;;
		*)
			get_msg $_q $_V -m _e2 -- "$_gateway" && eval $_R1      # cjail IP should not be hand jammed
### SELF NOTE: ISNT THIS AN UNREACHABLE COMMAND?? WHAT WAS I DOING HERE?
			_gw_ip="${ipv4%.*/*}.1/${ipv4#*/}"
			_cl_ip="$ipv4"
			;;
	esac

	# Respect jail's QCONF. If no jail-specific MTU, limit to the gw ETX_IF mtu size. Fallback to #default
	_mtu="$(get_jail_parameter -ez MTU $_client)"
	: "${_mtu:=$(ifconfig $_gw_mod -ag EXT_IF 2>/dev/null | sed -En "s/.*mtu ([^ \t]+)/\1/p")}"
	: "${_mtu:=$(get_jail_parameter -de MTU $_client)}"

	# Assign or create interfaces (_vif)
	chk_isvm $_gateway && _vif_cl=$(sed -En "s/${_gateway} ${_type} (.*)/\1/p" $VMTAPS)
	chk_isvm $_client  && _vif_gw=$(sed -En "s/${_client} ${_type} (.*)/\1/p" $VMTAPS)
	if ! chk_isvm $_gateway && ! chk_isvm $_client ; then
		_vif_gw=$(ifconfig epair create)
		_vif_cl="${_vif_gw%?}b"
	fi

	# Transport the interfaces if they belong in a jail
	[ -n "$_vif_gw" ] && [ -n "$_gw_mod" ] && ifconfig $_vif_gw vnet $_gateway
	[ -n "$_vif_cl" ] && [ -n "$_cl_mod" ] && ifconfig $_vif_cl vnet $_client

	# Assign group tags to the interfaces
	[ -n "$_vif_gw" ] && ifconfig $_gw_mod $_vif_gw group ${_client}_ group CLIENTS
	[ -n "$_vif_cl" ] && ifconfig $_cl_mod $_vif_cl group $_type $_groupmod

	# Configure the interfaces with IP addr and route, if not DHCP
	[ ! "$ipv4" = "dhcp" ] && [ -n "$_vif_gw" ] && ifconfig $_gw_mod $_vif_gw inet $_gw_ip mtu $_mtu up
	[ ! "$ipv4" = "dhcp" ] && [ -n "$_vif_cl" ] && ifconfig $_cl_mod $_vif_cl inet $_cl_ip mtu $_mtu up \
		&& route $_cl_mod add default "${_gw_ip%/*}" > /dev/null 2>&1

	# Final configuration for each client depending on type of connection being made
	case $_type in
		EXT_IF) configure_client_network ; reset_gateway_services ;;
#CJAIL BEING DEPRECATED
#CJ_SSH)
#configure_ssh_control "$_client" "$_gateway" ;;
	esac

	eval $_R0
}

reset_gateway_services() {
	local _fn="configure_client_network" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	if sysrc -nqj $_gateway dhcpd_enable 2>/dev/null | grep -q "YES" ; then
		# Only attempt restart if it's already running
		service -qj $_gateway isc-dhcpd status && service -qj $_gateway isc-dhcpd restart
	fi
}

configure_client_network() {
	local _fn="configure_client_network" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Make sure flags dont prevent update inside the jail
	chflags noschg -R ${_cl_root}/etc ${_cl_root}/etc/resolv.conf ${_cl_root}/etc/resolvconf.conf 2>/dev/null

	# DNS and pf management
	if sysrc -nqj $_client dnscrypt_proxy_enable 2>/dev/null | grep -q "YES" ; then
		# Using DoH, presumably for external-router connected (net-firewall) gateway
		rm "${_cl_root}/var/unbound/forward.conf" 2>/dev/null 
		chroot ${_cl_root} /bin/sh -c 'ln -s /var/unbound/forward-doh.conf /var/unbound/forward.conf'

	elif sysrc -nqj $_client wireguard_enable 2>/dev/null | grep -q "YES" ; then
		# Wireguard itself will update resolvconf, and thus, unbound
		rm "${_cl_root}/var/unbound/forward.conf" 2>/dev/null 
		chroot ${_cl_root} /bin/sh -c 'ln -s /var/unbound/forward-resolv.conf /var/unbound/forward.conf'

		# Endpoint IP
		local _ep=$(sed -nE "s/[ \t]*Endpoint[ \t]*=[ \t]*([^[ \t]+):.*/\1/p" \
				${M_ZUSR}/${_client}/rw/usr/local/etc/wireguard/wg0.conf)
		chflags noschg ${_cl_root}/etc/pf-wg_ep.table 2>/dev/null
		echo "$_ep" > ${_cl_root}/etc/pf-wg_ep.table

		# Wireguard restart is required if its upstream gateway restarts. $_CLI comes from exec.created
		[ "$_CLI" = "$_client" ] && service $_cl_mod wireguard restart

	else
		# All other gateways use normal resolvconf mechanism
		if sysrc -nqj $_client local_unbound_enable 2>/dev/null | grep -qs "YES" ; then
			rm "${_cl_root}/var/unbound/forward.conf" 2>/dev/null 
			chroot ${_cl_root} /bin/sh -c 'ln -s /var/unbound/forward-resolv.conf /var/unbound/forward.conf'
		fi
		if [ ! "$ipv4" = "DHCP" ] ; then      # Without DHCP, resolvconf doesnt know the assigned IP
			if [ "$_client" = "host" ] ; then
				echo "nameserver ${_gw_ip%/*}" | resolvconf -a tmpdns0 -m 0 > /dev/null 2>&1
			else
				chroot ${_cl_root} /bin/sh -c \
					"echo \"nameserver ${_gw_ip%/*}\" | resolvconf -a tmpdns0 -m 0 > /dev/null 2>&1"
			fi
		fi
	fi
	eval $_R0
}

configure_ssh_control() {
#CJAIL BEING DEPRECATED - whole function 
	# Ensures that the latest pubkey for the cjail SSH is copied to the controlled jail

	_pubkey=".ssh/cjail_authorized_keys"
	for _dir in $(ls -1 ${_cl_root}/home/) ; do
		_homes="${_cl_root}/home/${_dir}  ${_homes}"   # Mechanism to get root ssh and all the users' ssh
	done

	for _parent in ${_cl_root}/root ${_homes} ; do
		ls -alo $_parent | awk '{print $5}' | grep -qs schg && _schg_H='true'     # Record for later reset
		ls -alo $_parent/.ssh 2>/dev/null | awk '{print $5}' | grep -qs schg && _schg_S='true'
		chflags -R noschg ${_parent} ${_parent}/.ssh 2>/dev/null                  # Lift flags for edits

		[ ! -d "${_parent}/.ssh" ] && mkdir ${_parent}/.ssh \
			&& _owner=$(ls -lnd $_parent | awk '{print $3":"$4}')      # We need the owner:group of parent

		# For root ops in a container, use cjail root ssh. For normal ops, use cjail user
		[ -z "${_parent##*/root}" ] \
			&& cp ${M_ZUSR}/${_gateway}/rw/root/.ssh/id_rsa.pub ${_parent}/${_pubkey} \
			|| cp ${M_ZUSR}/${_gateway}/home/${_gateway}/.ssh/id_rsa.pub ${_parent}/${_pubkey}

		chmod 700 ${_parent}/.ssh
		chmod 600 ${_parent}/.ssh/cjail_authorized_keys

       # Reset flags if necessary, and chown if we created the directory
		[ -n "$_schg_H" ] && chflags schg ${_parent}
		[ -n "$_schg_S" ] && chflags -R schg ${_parent}/.ssh
		[ -n "$_owner" ] && chown -R $_owner ${_parent}/.ssh
	done
	eval $_R0
}

discover_open_ipv4() {
	# Finds an IP address unused by any running jails, or in qubsd.conf.
	# Nonlocal vars: _ip0._ip1._ip2._ip3/_subnet ; Required for chk_isqubsd_ipv4
	# _ip1 designates quBSD usecase ; _ip2 increments per jail ; _ip3 = (1 or 2) for gw vs client
		# qb-connect    (ADHOC):  10.88.X.0/29
		# Gateways     (EXT_IF):  10.99.X.0/30
		# Control jails(CJ_SSH):  10.255.X.0/30
		# Server jails   (serv):  10.128.X.0/30
		# Endpoint client  (EP):  10.1.x.0/30
	local _fn="discover_open_ipv4" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts cgqt:TV opts ; do case $opts in
			g) _ip3="1" ;;  # [-g] Returns the gateway IP ending in .1, instead of client IP of .2
			q) _qi="-q" ;;
			t) local _type="$OPTARG" ;;
			T) # This function is used in IP deconflictin by qb-start. Create TMP file
				_TMP_IP="${_TMP_IP:=${QRUN}/.qb-start_temp_ip}" ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 )) ; [ "$1" = "--" ] && shift

	local _client="$1"  _ip0=10  _ip2=1  _ip3=${_ip3:=2}  _subnet=30

	# The quBSD IP conventions for various use cases.
	case "$_type" in
		ADHOC) _ip1=88  ; _subnet=29 ;;
		CJ_SSH)   _ip1=255 ;;
		EXT_IF|*) # If the jail has clients, go with 99. Otherwise, it's an endpoint or server
				[ -n "$(get_info -e _CLIENTS $_client)" ] && _ip1=99 \
					|| { [ -z "${_client##serv-*}" ] && _ip1=128 || _ip1=1 ;} ;;
	esac

	# Get a list of IPs already in use, then increment $_ip2 until an unused IP is found
	get_info _USED_IPS
	while [ $_ip2 -le 255 ] ; do
		# Compare against QCONF, and the IPs already in use, including the temp file.
		local _ip_test="${_ip0}.${_ip1}.${_ip2}"
		if grep -Fq "$_ip_test" $QCONF || echo "$_USED_IPS" | grep -Fq "$_ip_test" \
				|| grep -Fqs "$_ip_test" "$_TMP_IP" ; then

			# Increment and continue, or return 1 if unable to find an IP in the available range
			_ip2=$(( _ip2 + 1 ))
			[ $_ip2 -gt 255 ] \
				&& get_msg $_qi -m _e30 -- "$_client" "${_ip0}.${_ip1}.X.${_ip3}" && eval $_R1
		else
			# Echo the value of the discovered IP and return 0
			echo "${_ip_test}.${_ip3}/${_subnet}" && eval $_R0
		fi
	done
	eval $_R0
}

remove_interface() {
	# Removes intf's from jails to host. Destroy or put down. Modify tracking files.
	local _fn="remove_interface" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts d opts ; do case $opts in
		d) local _action="destroy" ;;
		*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	# Pos params and _action. taps stay on host but epairs get destroyed
	local _intf="$1"  _jail="$2"  _action="${_action:=down}"

	# First check if it's already on host
	if ifconfig "$_intf" > /dev/null 2>&1 ; then
		ifconfig "$_intf" $_action

	# If a specific jail was passed, check that as the first possibility to find/remove tap
	elif [ -n "$_jail" ] && ifconfig -j $_jail -l | grep -Eqs "$_intf" ; then
		ifconfig "$_intf" -vnet "$_jail"
		ifconfig "$_intf" $_action

	# If the above fails, then check all jails
	else
		for _j in $(get_info -e _ONJAILS) ; do
			if ifconfig -j $_j -l 2>/dev/null | grep -Eqs "${_intf}" ; then
				ifconfig $_intf -vnet $_j
				ifconfig $_intf $_action
			fi
		done
	fi

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
	local _VM="$1"  _rootenv="$2"   _ct  _gw  _jail
	[ -z "$_VM" ] && get_msg $_qcv -m _e0 && eval $_R1

	# Bring all recorded taps back to host, and destroy. Skip checks for speed (non-essential)
	_ct=$(get_jail_parameter -des CONTROL $_VM)
	_gw=$(get_jail_parameter -des GATEWAY $_VM)
	for _tap in $(sed -En "s/^$_VM [^[:blank:]]+ ([^[:blank:]]+)/\1/p" $VMTAPS 2> /dev/null) ; do
		grep -Eqs "CJ_SSH $_tap" $VMTAPS && _jail="$_ct"
		grep -Eqs "EXT_IF $_tap" $VMTAPS && _jail="$_gw"
		remove_interface -d "$_tap" "$_jail"
	done
	sed -i '' -E "/^$_VM /d" $VMTAPS   # Remove any lines in VMTAPS associated to the VM

	# Destroy the VM
	bhyvectl --vm="$_VM" --destroy > /dev/null 2>&1

	# Set the PPT device back to its original state before VM prep/launch
	[ ! "$_ppt" = "none" ] && return_ppt "$_VM"

	# If it was a norun, dont spend time recloning
	[ -n "$_norun" ] && eval $_R0

	# Pull _rootenv in case it wasn't provided, and reclone it
	[ -z "$_rootenv" ] && ! _rootenv=$(get_jail_parameter -e ROOTENV $_VM) && eval $_R1
	reclone_zroot -q "$_VM" "$_rootenv"

	# If it's a dispVM with a template, then make a fresh clone of the template zusr (all children)
	local _template=$(get_jail_parameter -e TEMPLATE $_VM)
	if [ "$_template" ] && [ "$(get_jail_parameter -es CLASS $_VM)" = "dispVM" ] ; then
		reclone_zusr "$_VM" "$_template" || eval $_R1
	fi

	# Remove the /tmp files
	rm "${QRUN}/qb-bhyve_${_VM}" 2> /dev/null
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
	_bhyvecmd=$(tail -1 "${QLOG}_${_VM}" 2>&1)
	while : ; do
		_newppt=$(echo "$_bhyvecmd" | sed -En "s@.*passthru,([0-9/]+[0-9/]+[0-9/]+ ).*@\1@p")
		[ -z "$_newppt" ] && break
		_ppt="$_ppt $_newppt"
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
	_bhyve_custm=$(sed -En "s/${_VM}[ \t]+BHYVE_CUSTM[ \t]+//p" $QCONF \
						| sed -En "s/[ \t]+/ /p")

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
	_zvols=$(zfs list -Hro name -t volume $U_ZFS/$_VM)
	[ -z "$_zvols" ] && _BLK_ZUSR=''    # Set the variable to empty if no volumes are present
	for _vol in $_zvols ; do
		_BLK_ZUSR="-s ${_slot},virtio-blk,/dev/zvol/$_vol"
		_slot=$(( _slot + 1 ))
	done

	# 9p creates a shared directory for file transfer. Directory must exist or bhyve will fail
	mkdir -p "$QRUN/xfer/$_VM" 2>/dev/null
	_BLK_9P="-s ${_slot},virtio-9p,xfer=$QRUN/xfer/$_VM"
	_slot=$(( _slot + 1 ))

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

#CJAIL BEING DEPRECATED
# Default number of taps is 0. Add 1 for the control jail SSH connection
#_taps=$(( _taps + 1 ))
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
		sed -i '' -E "/${_tap}[ \t]*/d" $VMTAPS # Delete any stray lingering taps in the VMTAPS tracker
		ifconfig $_tap group "${_VM}_" down   # Use ifconfig groups to track which VM this tap belongs to
		_VTNET=$(printf "%b" "${_VTNET} -s ${_slot},virtio-net,${_tap}")
		_slot=$(( _slot + 1 )) ; [ "$_slot" -eq 29 ] && _slot=32
		_taps=$(( _taps - 1 ))

		# Tracker file for which taps are related to which VM, and for which purpose (_vif tags)
		case "$_cycle" in
#CJAIL BEING DEPRECATED
#			0) 
#ifconfig $_tap group "CJ_SSH" ; echo "$_VM CJ_SSH $_tap" >> $VMTAPS
#				;;
			0) ifconfig $_tap group "EXT_IF" ; echo "$_VM EXT_IF $_tap" >> $VMTAPS ;;
			1) ifconfig $_tap group "X11"    ; echo "$_VM X11 $_tap"    >> $VMTAPS ;;
			2) ifconfig $_tap group "EXTRA_${_cycle}_" ; echo "$_VM EXTRA_${_cycle}_ $_tap" >> $VMTAPS ;;
		esac
		_cycle=$(( _cycle + 1 ))
	done

	# Define the full bhyve command
	_BHYVE_CMD="$_TMUX1 bhyve $_CPU $_CPUPIN $_RAM $_BHOPTS $_WIRE $_HOSTBRG $_BLK_ROOT $_BLK_ZUSR \
		$_BLK_9P $_BHYVE_CUSTM $_PPT $_VTNET $_FBUF $_TAB $_LPC $_BOOT $_STDIO $_VM $_TMUX2"

	# unset the trap
	trap - INT TERM HUP QUIT EXIT

	eval $_R0
}

rootstrap_bsdvm() {
	# Prepares a new rootVM with qubsd specific files and init
	local _fn="rootstrap_bsdvm" _fn_orig="$_FN" _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Positional and local variables and checks
	local _VM="$1" volsize="$2" vm_zroot zvol distdir bsdvm tmp_zpool alt_mnt
	[ -z "$_VM" ] && get_msg $_q -m _e0 "VM name" && eval $_R1
	chk_avail_jailname "$_VM" && get_msg $_q -m _e1 "$_VM" "VM name" && eval $_R1

	[ -z "$volsize" ] && get_msg $_q -m _e0 "zvol volume size" && eval $_R1
   ! echo "$volsize" | grep -Eqs "^[[:digit:]]+(T|t|G|g|M|m|K|k)\$" \
			&& get_msg $_q -m _e1 -- "$volsize" "zvol size" && eval $_R1

	# Interim variables
	local vm_zroot="zroot/qubsd/$_VM"
	local zvol="/dev/zvol/zroot/qubsd/$_VM"
	local distdir="$QSHARE/freebsd-dist"
	local release=$(freebsd-version -u | cut -d- -f1)
	local arch=$(uname -m)
	local bsdvm="$QSHARE/templates/0bsdvm/rootstrap"
	local tmp_zpool="zrootvm"
	local alt_mnt="/mnt/$tmp_zpool"
	local timeout=5

	# Check network connection, inform if missing, give option to procede or exit
	if ping -ot $timeout freebsd.org > /dev/null 2>&1 ; then
		network=true
	else
		get_msg -Vm _w6 && ! get_user_response && get_msg2 -E
	fi

	# Download the dist files if necessary.
	mkdir -p $distdir
	export DISTRIBUTIONS="GITBRANCH base.txz kernel.txz"
	export BSDINSTALL_DISTSITE="https://download.freebsd.org/ftp/releases/$arch/${release}-RELEASE/"
	export BSDINSTALL_DISTDIR=$distdir
	export BSDINSTALL_CHROOT=$alt_mnt
	[ "$(grep -o "[[:digit:]].*" $distdir/GITBRANCH)" = "$release" ] || bsdinstall distfetch

	# Create the zvol and partitions
	zfs create -V $volsize -o volmode=geom -o qubsd:autosnap=true $vm_zroot
	gpart create -s gpt "$zvol"
	gpart add -t efi -s 200M -l efiboot "$zvol"
	gpart add -t freebsd-zfs -l rootfs "$zvol"
	newfs_msdos -L EFIBOOT "${zvol}p1"

	# zpool -t deconflicts host zroot with the vm's 'zroot'. No cachefile created (not really necessary for VM)
	sysctl vfs.zfs.vol.recursive=1    # zpool create WILL NOT WORK without this
	zpool create -f -o altroot="$alt_mnt" -O mountpoint=/zroot -O atime=off -t ${tmp_zpool} zroot ${zvol}p2
	sysctl vfs.zfs.vol.recursive=0    # recursive is deadlock prone. Set it back to default
	zfs create -o atime=off -o mountpoint=none ${tmp_zpool}/ROOT
	zfs create -o atime=off -o mountpoint=/ ${tmp_zpool}/ROOT/default
	zpool set bootfs=$tmp_zpool/ROOT/default $tmp_zpool

	# Extract the distribution to the VM root
	export DISTRIBUTIONS="base.txz kernel.txz"   # Have to remove GITBRANCH or the extraction will fail
	bsdinstall distextract

	# Create the boot files
	mkdir -p $alt_mnt/boot/efi
	mount -t msdosfs ${zvol}p1 $alt_mnt/boot/efi
	mkdir -p $alt_mnt/boot/efi/EFI/BOOT
	cp $alt_mnt/boot/loader.efi $alt_mnt/boot/efi/EFI/BOOT/BOOTX64.EFI
	umount "$alt_mnt/boot/efi"

	# Files and directories to prepare for a running system
	mkdir -p $alt_mnt/home
	mkdir -p $alt_mnt/usr/local/bin
	mkdir -p $alt_mnt/usr/local/etc/rc.d
	mkdir -p $alt_mnt/xfer && chmod -R 777 $alt_mnt/xfer    # For virtio-9p file sharing between host/VM
	cp -a $bsdvm/fstab       $alt_mnt/etc/fstab
	cp -a $bsdvm/loader.conf $alt_mnt/boot/loader.conf
	cp -a $bsdvm/qubsd-dhcp  $alt_mnt/usr/local/bin/qubsd-dhcp
	cp -a $bsdvm/qubsd-dhcpd $alt_mnt/usr/local/etc/rc.d/qubsd-dhcpd
	cp -a $bsdvm/qubsd-init  $alt_mnt/usr/local/etc/rc.d
	cp -a $bsdvm/rc.conf     $alt_mnt/etc/rc.conf
	cp -a $bsdvm/sysctl.conf $alt_mnt/etc/sysctl.conf
	cp -a /etc/localtime     $alt_mnt/etc/localtime
	sysrc -f $bsdvm/rc.conf hostname="$_VM"
	
	if [ "$network" ] ; then
		# Update the container
		freebsd-update --not-running-from-cron -b $alt_mnt/ -d /var/db/freebsd-update fetch install

		# pkg and installs are more complete/correct with chroot, but requires devfs, resolv, and ldconfig
		mount -t devfs devfs $alt_mnt/dev
		cp /etc/resolv.conf $alt_mnt/etc
		chroot $alt_mnt /etc/rc.d/ldconfig forcerestart
		pkg -c $alt_mnt bootstrap -yf
		pkg -c $alt_mnt install -y vim tmux automount fusefs-exfat fusefs-ext2 fusefs-ifuse fusefs-jmtpfs
		umount $alt_mnt/dev
	fi

	# Unmount, export, and set the volmode correctly
	umount $alt_mnt/zroot
	umount $alt_mnt
	rm -r $alt_mnt
	zpool export $tmp_zpool
	zfs set volmode=dev $vm_zroot

	[ "$network" ] && get_msg -m _m11 "$_VM" || get_msg -m _m12 "$_VM"
}

configure_bsdvm_zusr() {
	# Rough function for VM reconfiguration. Will eventually be made more robust for installer and qb-create 
	# Creates the zusr zvol, and configures it
	local _fn="configure_vm_zusr" _fn_orig="$_FN" _FN="$_FN -> $_fn"
	while getopts d:qV _opts ; do case $_opts in
		d) local _dircopy="$OPTARG" ;;
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Positional and local variables and checks
	local _VM="$1" volsize="$2" vm_zusr zvol tmp_zpool alt_mnt
	[ -z "$_VM" ] && get_msg $_q -m _e0 "VM name" && eval $_R1
	chk_avail_jailname "$_VM" && get_msg $_q -m _e1 "$_VM" "VM name" && eval $_R1

	[ -z "$volsize" ] && get_msg $_q -m _e0 "zvol volume size" && eval $_R1
   ! echo "$volsize" | grep -Eqs "^[[:digit:]]+(T|t|G|g|M|m|K|k)\$" \
			&& get_msg $_q -m _e1 -- "$volsize" "zvol size" && eval $_R1

	# Interim variables
	local vm_zusr="zusr/$_VM/persist"
	local zvol="/dev/zvol/$vm_zusr"
	local mnt="/mnt/$_VM"

	# Create the zvol, filesystem, and mount it
	zfs create -o atime=off -o qubsd:autosnap=true $U_ZFS/$_VM
	zfs create -V $volsize -o volmode=geom -o qubsd:autosnap=true $vm_zusr
	newfs -L zusr $zvol	  # Creates a label used in qubsd-init to identify the primary persistence drive
	mkdir -p $mnt
	mount $zvol $mnt
	
	# Files and directories to prepare for a running system
	if [ "$_dircopy" ] ; then            # Preference user specified directory
		cp -a $_dircopy/ $mnt
	elif [ -e "$QSHARE/templates/$_VM" ] ; then   # Fallback - If VM name matches a template, use it
		cp -a $QSHARE/templates/$_VM/ $mnt
	fi

	umount $mnt
	rm -r $mnt
	zfs set volmode=dev $vm_zusr
}

launch_bhyve_vm() {
	# Need to detach the launch an monitoring of VMs completely from qb-cmd and qb-start

	# Get globals, although errfiles arent needed
	get_global_variables
	rm_errfiles

	# Create trap for post VM exit
	trap "cleanup_vm $_VM $_rootenv ; exit 0" INT TERM HUP QUIT EXIT

	# Log the exact bhyve command being run
	echo "\$(date "+%Y-%m-%d_%H:%M") Starting VM: $_VM" | tee -a $QLOG ${QLOG}_${_VM}
	echo $_BHYVE_CMD >> ${QLOG}_${_VM}

	# Launch the VM to background
	eval $_BHYVE_CMD

	sleep 5   # Allow plent of time for launch. Sometimes weirdness can delay pgrep appearance

	# Monitor the VM, perform cleanup after done
	while pgrep -xfq "bhyve: $_VM" ; do sleep 1 ; done
	echo "\$(date "+%Y-%m-%d_%H:%M") VM: $_VM HAS ENDED." | tee -a $QLOG ${QLOG}_${_VM}
	exit 0
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

	# Connect to control jail and gateway
	connect_client_to_gateway -dt EXT_IF -- "$_VM" "$_gateway" > /dev/null
#CJAIL BEING DEPRECATED
#	connect_client_to_gateway -dt CJ_SSH -- "$_VM" "$_control" > /dev/null

	# Connect VM to all of it's clients (if there are any)
	for _cli in $(get_info -e _CLIENTS "$_VM") ; do
		chk_isrunning "$_cli" && connect_client_to_gateway -t EXT_IF "$_cli" "$_VM"
	done

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
	#start_jail -q $_control
	! start_jail $_gateway && eval $_R1

	# Launch VM sent to background, so connections can be made (network, vnc, tmux)
	get_msg -m _m1 -- "$_jail" | tee -a $QLOG ${QLOG}_${_VM}
	export QLIB _BHYVE_CMD _VM _rootenv QLOG
	daemon -t "bhyve: $_jail" -o /dev/null -- /bin/sh << 'EOF'
		. $QLIB/quBSD.sh
		. $QLIB/msg-quBSD.sh
		launch_bhyve_vm
EOF

	# Monitor to make sure that the bhyve command started running, then return 0
	local _count=0 ; sleep .5

	while ! { pgrep -xfq "bhyve: $_VM" \
				|| pgrep -fl "bhyve" | grep -Eqs "^[[:digit:]]+ .* ${_VM}[ \t]*\$" ;} ; do
	sleep .5 ; _count=$(( _count + 1 ))
	[ "$_count" -ge 10 ] && get_msg -m _e4_1 -- "$_VM" && eval $_R1
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
setlog3() {
	set -x
	rm /root/debug3 > /dev/null 2>&1
	exec > /root/debug3 2>&1
}


