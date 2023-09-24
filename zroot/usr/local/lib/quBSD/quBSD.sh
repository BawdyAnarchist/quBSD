#!/bin/sh

####################################################################################
#######################  GENERAL DESCRIPTION OF FUNCTIONS  #########################

# Global variables, jail/quBSD parameters, sanity checks, messages, networking.
# Functions embed many sanity checks, but also call other functions to assist.
# Messages are sourced from a separate script, as a function. They have the form:
#   get_msg <$_q> <_msg_ident> <_pass_variable1> <_pass_variable2>
#     <$_q> (q)uiet option. Normally getopts, but sometimes as positional param,
#            when <value> of a positional var might have a leading '-' dash.
#            -note- csh passes local vars to new functions called within functions.
#                   thus to prevent inadvertently passing [-q], important funcitons
#                   have a unique _q identifier.
#     <_msg_ident> Is used to retreive a particular message from the msg function.
#     <_pass_variable> 1 and 2 are for supplementing message specificity.

# Functions can assign global variables and deliver error messages ;
# but they almost never make a determination to exit. That is left to the caller.


####################################################################################
###############################  LIST OF FUNCTIONS  ################################

###################  VARIABLE ASSIGNMENTS and VALUE RETRIEVAL  #####################
# get_global_variables  - File names/locations ; ZFS datasets
# get_networking_variables - pf.conf ; wireguard ; endpoints
# get_user_response   - Simple yes/no y/n checker
# get_jail_parameter  - All JMAP entries, along with sanity checks
# get_info            - Info beyond that just for jails or jail parameters
	# _CLIENTS         - All jails that <jail> serves a network connection
	# _ONJAILS         - All currently running jails
	# _USED_IPS        - All IPs used by currently running jails
	# _XID             - Window ID for the currently active X window
	# _XJAIL           - Jailname (or 'host') for the currently active X window
	# _XNAME           - Name of the process for the current active X window
	# _XPID            - PID for the currently active X window
# compile_jlist       - Used for qb-start/stop, to get list of jails to act on

############################  JAIL HANDLING / ACTIONS  #############################
# start_jail          - Performs checks before starting, creates log
# stop_jail           - Performs checks before starting, creates log
# restart_jail        - Self explanatory
# remove_tap          - Removes tap interface from whichever jail it's in
# connect_client_to_ gateway - Connects a client jail to its gateway
# connect_gateway_to_clients - Connects a gateway jail to its clients
# reclone_zroot       - Destroys and reclones jails dependent on rootjail
# reclone_zusr        - Destroy and reclones jails with zusr dependency (dispjails)
# cleanup_oldsnaps    - Destroys old snapshots beyond their time-to-live 
# monitor_startstop   - Monitors whether qb-start or qb-stop is still alive

#################################  STATUS  CHECKS  #################################
# chk_isblank          - Posix workaround: Variable is [-z <null> OR [[:blank:]]*]
# chk_isrunning        - Searches jls -j for the jail
# chk_truefalse        - When inputs must be either true or false
# chk_avail_jailname   - Checks that a proposed jailname is acceptable

#################################  SANITY  CHECKS  #################################
# chk_valid_zfs        - Checks for presence of zfs dataset. Redirect to null
# chk_valid_jail       - Makes sure the jail has minimum essential elements
# chk_valid_autosnap   - true|false ; Include in qb-autosnap /etc/crontab snapshots
# chk_valid_autostart  - true|false ; Autostart at boot
# chk_valid_bhyveopts  - Checks bhyve options in jailmap for valid or not
# chk_valid_class      - appjail | rootjail | dispjail
# chk_valid_cpuset     - Must be in man 1 cpuset format. Limit jail CPUs
# chk_valid_gateway    - Jail adheres to gateway jail norms
# chk_valid_ipv4       - Adheres to CIDR notation
# chk_isqubsd_ipv4     - Adheres to quBSD conventions for an IP address
# chk_valid_maxmem     - Must be in man 8 rctl format. Max RAM allocated to jail
# chk_valid_memsize    - Check memsize for bhyve (just references _valid_maxmem)
# chk_valid_mtu        - Must be a number, typically between 1000 and 2000
# chk_valid_no_destroy - true|false ; qb-destroy protection mechanism
# chk_valid_ppt        - Checks ppt exists in pciconf and is available to passthru
# chk_valid_rootjail   - Only certain jails qualify as rootjails
# chk_valid_rootvm     - Only certain VMs qualify as rootVMs 
# chk_valid_schg       - none | sys | all ; quBSD convention, schg flags on jail
# chk_valid_seclvl     - -1|0|1|2|3 ; Applied to jail after start
# chk_valid_template   - Somewhat redundant with: chk_valid_jail
# chk_valid_taps       - jmap designates number of taps to add (must be :digit:)
# chk_valid_tmux       - tmux for terminal access to FreeBSD jails. true/false
# chk_valid_template   - Must be any valid jail 
# chk_valid_vcpus      - Must be an integer less than cpuset -g 
# chk_valid_vncres     - Must be one of few valid resolutions allowed by bhyve
# chk_valid_vif        - Virtual Intf (vif) is valid
# chk_valid_wiremem    - Must be true/false

##############################  NETWORKING  FUNCTIONS  #############################
# define_ipv4_convention - Necessary for implementing quBSD IPv4 conventions
# discover_open_ipv4     - Finds an unused IP address from the internal network
# assign_ipv4_auto       - Handles the ip auto assignments when starting jails

##################################  VM  FUNCTIONS  #################################
# cleanup_vm           - Cleans up network connections, and dataset after shutdown
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

get_global_variables() {
	# Global config files, mounts, and datasets needed by most scripts

	# Define variables for files
	JCONF="/etc/jail.conf"
	QBDIR="/usr/local/etc/quBSD"
	JMAP="${QBDIR}/jailmap.conf"
	QBLOG="/var/log/quBSD.log"
	QTMP="/tmp/quBSD/"

	# Remove blanks at end of line, to prevent bad variable assignments.
	sed -i '' -E 's/[[:blank:]]*$//' $JMAP

	# Get datasets, mountpoints; and define files.
   JAILS_ZFS=$(sed -nE "s:#NONE[[:blank:]]+jails_zfs[[:blank:]]+::p" $JMAP)
   ZUSR_ZFS=$(sed -nE "s:#NONE[[:blank:]]+zusr_zfs[[:blank:]]+::p" $JMAP)
	M_JAILS=$(zfs get -H mountpoint $JAILS_ZFS | awk '{print $3}')
	M_ZUSR=$(zfs get -H mountpoint $ZUSR_ZFS | awk '{print $3}')
}

get_networking_variables() {
	WIREGRD="/rw/usr/local/etc/wireguard"
	WG0CONF="${WIREGRD}/wg0.conf"
	PFCONF="/rw/etc/pf.conf"
	JPF="${M_ZUSR}/${JAIL}/${PFCONF}"

	# Get wireguard related variables
   if [ -e "${M_ZUSR}/${JAIL}/${WG0CONF}" ] ; then

		ENDPOINT=$(sed -nE "s/^Endpoint[[:blank:]]*=[[:blank:]]*//p" \
				${M_ZUSR}/${JAIL}/${WG0CONF} | sed -n "s/:[[:digit:]]*.*//p")
		WGPORTS=$(sed -nE "s/^Endpoint[[:blank:]]*=[[:blank:]]*.*://p" \
				${M_ZUSR}/${JAIL}/${WG0CONF})
	fi
}

get_parameter_lists() {
	# Primarily returns global varibles: CLASS ; ALL_PARAMS ; but also a few others
	
	# Need the CLASS to determine which parameters are valid
	get_jail_parameter -dqs CLASS "$JAIL"

	# List out normal parameters which can be checked (vs BHYVE_CUSTM)
	COMN_PARAMS="AUTOSTART AUTOSNAP CLASS GATEWAY IPV4 MTU NO_DESTROY"
	JAIL_PARAMS="CPUSET MAXMEM ROOTJAIL SCHG SECLVL"
	VM_PARAMS="BHYVEOPTS BHYVE_CUSTM MEMSIZE PPT ROOTVM TAPS TMUX VCPUS VNCRES WIREMEM"
	MULT_LN_PARAMS="BHYVE_CUSTM PPT"

	case $CLASS in
		*VM) FILT_PARAMS="$COMN_PARAMS $VM_PARAMS" ;;
		dispjail) FILT_PARAMS="$COMN_PARAMS $JAIL_PARAMS TEMPLATE" ;;
		appjail|rootjail) FILT_PARAMS="$COMN_PARAMS $JAIL_PARAMS" ;;
	esac

	return 0
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

		# Only return success on positive response. All else fail
		*)	return 1 ;;
	esac
}

get_jail_parameter() {
	# Get corresponding <value> for <jail> <param> from JMAP.
	# Assigns global variable of ALL CAPS <param> name, with <value>
	 # -dp: Function default is to get the <#default> from JMAP, whenever the
	     # retrieved <value> for <jail> <param> is NULL. [-d] prevents this.
	 # -ep: echo <value> rather than setting the global variable
	     # Otherwise variable indirection will set <$_PARAM> with <_value>
	 	 ## NOTE: If using [-e] in $(command_substitution), best to [-q]
		 ## quiet any error messages to prevent unpredictable behavior.
	 # -qp: quiet any error/alert messages. Otherwise error messages are shown.
	 # -sp: Skip checks, and return 0 regardless of any failures 
	 # -zp: don't error on zero/null values, just return 

	# Positional variables:
	 # $1: _param : The parameter to pull from JMAP
	 # $2: _jail  : <jail> to reference in JMAP

	# Ensure all options variables are reset
	local _dp='' ; local _ep='' ; local _qp='' ; local _sp='' ; local _zp=''

	while getopts deqsz opts ; do
		case $opts in
			d) _dp="-d" ;;
			e) _ep="-e" ;;
			q) _qp="-q" ;;
			s) _sp="true" ;;
			z) _zp="true" ;;
			*) get_msg "_1" ; return 1 ;;
		esac
	done

	shift $(( OPTIND - 1 ))

	# Positional and function variables 
	local _param="$1"  ; local _low_param=$(echo "$_param" | tr '[:upper:]' '[:lower:]')
	local _jail="$2"   ; local _value=''

	# Either jail or param weren't provided
	[ -z "$_jail" ] && get_msg $_qp "_0" "jail" && eval $_sp return 1 
	[ -z "$_param" ] && get_msg $_qp "_0" "parameter" && eval $_sp return 1 

	# Get the <_value> from JMAP.
	_value=$(sed -nE "s/^${_jail}[[:blank:]]+${_param}[[:blank:]]+//p" $JMAP)

	# Substitute <#default> values, so long as [-d] was not passed
	if [ -z "$_value" ] && [ -z "$_dp" ] ; then
		_value=$(sed -nE "s/^#default[[:blank:]]+${_param}[[:blank:]]+//p" $JMAP)
	fi

	# If still blank, check for -z or -s options. Otherwise err message and return 1 
	if [ -z "$_value" ] ; then 
		[ "$_zp" ] && return 0
		[ "$_sp" ] && return 0
		get_msg $_qp "$_cj17_1" "$_param" "$_value" && return 1 
	fi

	# If -s was provided, checks are skipped by this eval
	if ! [ $_sp ] ; then

		# Variable indirection for checks. Escape \" avoids word splitting
		eval "chk_valid_${_low_param}" $_qp \"$_value\" \"$_jail\" || return 1
	fi

	# Either echo <value> , or assign global variable (as specified by caller).
	[ "$_ep" ] && echo "$_value" || eval $_param=\"$_value\"

	return 0
}

get_info() {
	# Commonly required information that's not limited to jails or jail parameters
	# Similar to: to get_jail_parameter(). But checks are not default.
	# $1: _info :

	# Local options for this function
	while getopts e opts ; do
		case $opts in
			e) _ei="-e" ;;
			*) get_msg "_1" ; return 1 ;;
		esac
	done

	shift $(( OPTIND - 1 ))

	# Positional variables
	local _info="$1"
	local _jail="$2"
	local _value=''

	case $_info in
		_CLIENTS)
			_value=$(sed -nE "s/[[:blank:]]+GATEWAY[[:blank:]]+${_jail}//p" $JMAP)
		;;
		_ONJAILS)
			# Prints a list of all jails that are currently running
			_value=$(jls | sed "1 d" | awk '{print $2}') 
		;;
		_TAP)
			# If <jail> has VM gateway, the tap interface is returned. Else return 1.
			_gateway=$(get_jail_parameter -deqs GATEWAY $_jail)
			_value=$(get_jail_parameter -deqs VIF $_gateway)
		;;
		_USED_IPS)
			# Assemble list of ifconfig inet addresses for all running jails
			for _onjail in $(get_info -e _ONJAILS) ; do 
				_intfs=$(jexec -l -U root "$_onjail" ifconfig -a inet | grep -Eo "inet [^[:blank:]]+")
				_value=$(printf "%b" "$_value" "\n" "$_intfs")
			done
		;;
		_XID)
			_value=$(xprop -root _NET_ACTIVE_WINDOW | sed "s/.*window id # //")
		;;
		_XJAIL)
			# Gets the jailname of the active window. Converts $HOSTNAME to: "host"
			_value=$(xprop -id $(get_info -e _XID) WM_CLIENT_MACHINE \
					| sed "s/WM_CLIENT_MACHINE(STRING) = \"//" | sed "s/.$//" \
					| sed "s/$(hostname)/host/g")
		;;
		_XNAME)
			# Gets the name of the active window
			_value=$(xprop -id $(get_info -e _XID) WM_NAME _NET_WM_NAME WM_CLASS)
		;;
		_XPID)
			# Gets the PID of the active window.
			_value=$(xprop -id $(get_info -e _XID) _NET_WM_PID \
					| grep -Eo "[[:alnum:]]+$")
		;;
	esac

	# If null, return failure immediately
	[ -z "$_value" ] && return 1

	# Echo option signalled
	[ "$_ei" ] && echo "$_value" && return 0

	# Assign global if no other option/branch was specified (default action).
	eval ${_info}=\"${_value}\"
	return 0
}

compile_jlist() {
	# Called only by qb-start and qb-stop. Uses global variables, which isn't best practice,
	# but they should be unique, and not found in other programs. 

	case "${_SOURCE}" in
		'')
			# If both SOURCE and POSPARAMS are empty, there is no JLIST. 
			[ -z "$_POSPARAMS" ] && get_msg_start "_je1" "usage_1" || _JLIST="$_POSPARAMS"

			# If there was no SOURCE, then [-e] makes the positional params ambiguous 
			[ "$_EXCLUDE" ] && get_msg_start "_je2" "usage_1" 	
		;;  

		auto)	
			# Find jails tagged with autostart in jmap. 
			_JLIST=$(grep -E "AUTOSTART[[:blank:]]+true" $JMAP | awk '{print $1}' | uniq)
		;;

		all)	
			# ALL jails from jailmap, except commented lines
			_JLIST=$(awk '{print $1}' $JMAP | uniq | sed "/^#/d")
		;;
	
		?*)
			# Only possibility remaining is [-f]. Check it exists, and assign JLIST
			[ -e "$_SOURCE" ] && _JLIST=$(tr -s '[:space:]' '\n' < "$_SOURCE" | uniq) \
					|| get_msg_start "_je3" "usage_1"
		;;
	esac

	# If [-e], then the exclude list is just the JLIST, but error if null. 
	[ "$_EXCLUDE" ] && _EXLIST="$_POSPARAMS" && [ -z "$_EXLIST" ] && get_msg_start "_je4" "usage_1" 

	# If [-E], make sure the file exists, and if so, make it the exclude list 
	if [ "$_EXFILE" ] ; then

		[ -e "$_EXFILE" ] && _EXLIST=$(tr -s '[:space:]' '\n' < "$_EXFILE")	\
			|| get_msg_start "_je5" "usage_1"
	fi	

	# Remove any jail on EXLIST, from the JLIST
	for _exlist in $_EXLIST ; do
		_JLIST=$(echo "$_JLIST" | grep -Ev "^[[:blank:]]*${_exlist}[[:blank:]]*\$")
	done
}



########################################################################################
##############################  JAIL HANDLING / ACTIONS  ###############################
########################################################################################

start_jail() {
	# Starts jail. Performs sanity checks before starting. Logs results.
	# return 0 on success ; 1 on failure.

   # Options 
	while getopts nqt opts ; do
		case $opts in
			n) _norun="-n" ;;
			q) _qs="-q" ;;
			t) _tmux="-t" ;;
			*) return 1 ;;
		esac
	done

	shift $(( OPTIND - 1 ))

	# Positional parameter / checks
	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_qs "_0" "jail" && return 1

	# none is an invalid jailname. Never start it. Always return 0.
	[ "$_jail" = "none" ] && return 0

	# Check to see if _jail is already running
	if	! chk_isrunning "$_jail" ; then

		# If not, running, perform prelim checks
		if chk_valid_jail $_qs "$_jail" ; then

			# If checks were good, start jail, make a log of it
			get_msg "_jf1" "$_jail" | tee -a $QBLOG
			
			if chk_isvm "$_jail" ; then
				exec_vm_coordinator $_norun $_tmux $_qs "$_jail"
			else
				jail -vc "$_jail"  >> $QBLOG 2>&1  ||  get_msg $_qs "_jf2" "$_jail"
			fi
		fi
	fi

	return 0
}

stop_jail() {
	# If jail is running, remove it. Return 0 on success; return 1 if fail.

	# Quiet option
	getopts q _opts && _qj='-q'
	shift $(( OPTIND - 1 ))

	# Positional parameter / check
	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_qj "_0" "jail" && return 1

	# Check that the jail is on
	if chk_isrunning "$_jail" ; then
		# Print message to log
		get_msg "_jf3" "$_jail" | tee -a $QBLOG

		if chk_isvm "$_jail" ; then
			# Kill the process gracefully; or if not, then forcefully
			pkill -15 -fx "bhyve: $_jail" || pkill -9 -fx "bhyve: $_jail"

		elif ! jail -vr "$_jail"  >> $QBLOG ; then

			# If normal removal failed, forcibly remove
			get_msg "_jf4" "$_jail" | tee -a $QBLOG
			if jail -vR "$_jail"  >> $QBLOG  ; then

				# Forcible removal likely missed mounts. Clean them up.
				sh ${QBDIR}/exec.release "$_jail"
				[ -e "${M_ZUSR}/${JAIL}/rw/etc/fstab" ] \
					&& umount -aF "${M_ZUSR}/${JAIL}/rw/etc/fstab" > /dev/null 2>&1

				# Notify about failure to remove normally
				get_msg "_jf6" "$_jail" | tee -a $QBLOG

			else
				# Print warning about failure to forcibly remove jail
				get_msg $_qj "_jf5" "$_jail"
				return 1
			fi
		fi
	fi

	# Catch all. Either the jail was already off, or was succesfully removed
	return 0
}

restart_jail() {
	# Restarts jail. If a jail is off, this will start it. However, passing
	# $2="hold" will override this default, so that an off jail stays off.

	# Quiet option
	getopts q _opts && _qr='-q'
	shift $(( OPTIND - 1 ))

	# Positional parameters / check
	local _jail="$1"
	local _hold="$2"
	[ -z "$_jail" ] && get_msg $_qr "_0" "jail"  && return 1

	# If the jail was off, and the hold flag was given, don't start it.
	! chk_isrunning "$_jail" && [ "$_hold" = "hold" ] && return 0

	# Otherwise, cycle jail
	stop_jail $_qr "$_jail" && start_jail $_qr "$_jail"
}

remove_tap() {
	# If TAP is not already on host, find it and bring it to host
	# Return 1 on failure, otherwise return 0 (even if tap was already on host)

	# Assign name of tap 
	local _tap="$1"
	local _jail="$2"

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

connect_client_to_gateway() {
	# When a jail/VM is started, this connects to its gateway 
	# GLOBAL VARIABLES must have been assigned already: $GATEWAY ; $IPV4 ; $MTU

	while getopts e opts ; do
		case $opts in
			e) local _ec="true" ;;
			*) get_msg "_1" ; return 1 ;;
		esac
	done

	shift $(( OPTIND - 1 ))

	# Positional variables
	local _client="$1" ; local _gateway="$2" ; local _ipv4="$3"
	local _mtu="${MTU:=$(get_jail_parameter -es MTU '#default')}"

	# VM client uses pre-determined tap interfaces and DHCP on the gateway jail
	if chk_isvm "$_client" ; then

		# Connect the tap to the gateway
		ifconfig "$_vif" vnet "$_gateway"
		jexec -l -U root $_gateway ifconfig $_vif inet ${_ipv4%.*/*}.1/${_ipv4#*/} mtu $_mtu up
		jexec -l -U root $_gateway service isc-dhcpd restart

		return 0

	elif chk_isvm "$_gateway" ; then
		# This is called by exec scripts, which dont yet have the _vif (tap
		_vif=$(head -1 "${QTMP}/qb-taps_${_gateway}" 2> /dev/null)

		# Send tap to client
 		ifconfig $_vif vnet $_client

		# If there's any mtu setting other than 1500, apply it 
		[ ! "$_mtu" = "1500" ] && jexec -l -U root $_client ifconfig $_vif mtu $_mtu up

# Run DHCP, or manuall add IP address 
#if [ "$_ipv4" = "DHCP" ] ; then
# First remove any running instances of dhclient
# jexec -l -U root $_client pkill -f dhclient > /dev/null 2>&1
#	jexec -l -U root $_client dhclient $_vif > /dev/null 2>&1

#else
#	jexec -l -U root $_client ifconfig $_vif inet ${_ipv4} mtu $_mtu up 
#	jexec -l -U root $_client route add default "${_ipv4%.*/*}.1" > /dev/null 2>&1
#fi

		[ "$_ec" ] && echo "$_vif"	

		return 0
	fi

	# Create virtual interface. Gateway <_intf> can always be sent
	local _intf=$(ifconfig epair create)
	ifconfig "$_intf" vnet $_gateway

	# If connecting two jails, send the epair, and assign a command modifier.
	if [ ! "$_client" = "host" ] ; then
		ifconfig "${_intf%?}b" vnet $_client
		local _cmdmod='jexec -l -U root $_client'
	fi

	# If there is no IP or it's DHCP, skip the assignment
	if [ ! "$_ipv4" = "none" ] ; then
		# Assign the gateway IP
		jexec -l -U root "$_gateway" \
				ifconfig "$_intf" inet ${_ipv4%.*/*}.1/${_ipv4#*/} mtu $_mtu up

		# Assign the client IP and default route
		eval "$_cmdmod" ifconfig ${_intf%?}b inet ${_ipv4} mtu $_mtu up
		eval "$_cmdmod" route add default "${_ipv4%.*/*}.1" > /dev/null 2>&1
	fi

	# Echo option. Return epair-b ; it's the external interface for the jail.
	[ "$_ec" ] && echo "${_intf%?}b" || VIF="${_intf%?}b" 

	return 0
}

connect_gateway_to_clients() {
	# When a jail/VM is started, this manages the connection to its downstream clients 
	
	# Quiet option
	getopts q _opts && _qz='-q'
	shift $(( OPTIND - 1 ))

	_jail="$1"
	[ -z "$_jail" ] && get_msg $_q "_0" "Jail/VM" && return 1

	for _client in $(get_info -e _CLIENTS "$_jail") ; do
		
		if chk_isrunning "$_client" ; then 
	
			# Get client IP
			_cIP=$(get_jail_parameter -deq IPV4 "$_client") 
			[ "$_cIP" = "auto" ] && _cIP=$(assign_ipv4_auto -e "$_client")

			# Bring up connection, and return the VIF used for the client
			_cVIF=$(connect_client_to_gateway -e "$_client" "$_jail" "$_cIP")

			# Need to modify the client pf.conf with the epair
			_cPF="${M_ZUSR}/${_client}/${PFCONF}"

			if [ -e "$_cPF" ] ; then 
				# Make sure flags are down
				chflags -R noschg "${M_ZUSR}/${_client}/rw/etc" 

				# pf needs the external interface and jIP for filtering variables
				sed -i '' -e "s@^ext_if[[:blank:]]*=.*@ext_if = \"${_cVIF}\"@" $_cPF
				sed -i '' -e "s@^jIP[[:blank:]]*=.*@jIP = \"${_cIP}\"@"  $_cPF

				# Restart _client pf service
				jexec -l -U root "$_client" service pf restart > /dev/null 2>&1

				# Reapply jail flags from jmap 
				qb-flags -r $_client > /dev/null 2>&1 &
			fi
		fi
	done
	return 0
}

reclone_zroot() {
	# Destroys the existing rootjail clone of <_jail>, and replaces it
	# Detects changes since the last snapshot, creates a new snapshot if necessary,
	# and destroys old snapshots when no longer needed.

	# Quiet option
	getopts q _opts && _qz='-q'
	shift $(( OPTIND - 1 ))

	# Variables definitions
	_jail="$1"
	_jailzfs="${JAILS_ZFS}/${_jail}"
	_rootjail="$2"
	_rootzfs="${JAILS_ZFS}/${_rootjail}"

	_date=$(date +%s)
	_ttl=$(($_date + 30))
	_newsnap="${_rootzfs}@${_date}"

	_presnap=$(zfs list -t snapshot -Ho name ${_rootzfs} | tail -1)

	# Check that the _jail being destroyed/cloned has an origin (is a clone).
	chk_valid_zfs "$_jailzfs" && [ "$(zfs list -Ho origin "${JAILS_ZFS}/${_jail}")" = "-" ] \
		&& get_msg $_qz "_jo0" "$_jail" && return 1 

	# `zfs diff` from simultaneous jail start, create momentary snapshot. Errors reclone 
	while [ -z "${_presnap##*@zfs-diff*}" ] ; do

		# Loop until a proper snapshot is found
		sleep .1
		_presnap=$(zfs list -t snapshot -Ho name ${_rootzfs} | tail -1)
	done

	# Determine if there are any updates or pkg installations taking place inside the jail
	if pgrep -qf "/usr/sbin/freebsd-update -b ${M_JAILS}/${_rootjail}" \
		|| pgrep -qj "$_rootjail" -qf '/usr/sbin/freebsd-update' > /dev/null 2>&1 \
		|| pgrep -qj "$_rootjail" 'pkg' > /dev/null 2>&1 
#I'm not sure if taking a snapshot of a running rootVM is maybe a bad idea
#||pgrep -qf "bhyve: $_jail" > /dev/null 2>&1
	then
		local _busy="true"
	fi

	# If there's a pre existing snapshot, there's always a fallback for the reclone operation
	# Exclude vm, coz zfs volmode=dev cant be analyzed with zfs diff
	if ! chk_isvm "$_jail" && [ "$_presnap" ] ; then

		# Check for differences between pre existing snapshot, and current state of jail
		if [ "$(zfs diff "$_presnap" "$_rootzfs")" ] ; then

			# There are differences and the jail is busy. Fallback on pre-existing snapshot
			[ "$_busy" ] && _newsnap="$_presnap"
		else
			# There have been no updates since the last snapshot. Use the pre existing snapshot
			_newsnap="$_presnap"
		fi

	else
		# There is no pre existing snapshot, and the rootjail is busy. Must error.
		[ "$_busy" ] && get_msg "_jo1" "$_jail" "$_rootjail" && return 1
	fi

	# If they're equal, then the valid/current snapshot already exists. Otherwise, make one.
	if [ ! "$_newsnap" = "$_presnap" ] ; then
		# Clone and set zfs params so snapshot will get auto deleted later.
		zfs snapshot -o qubsd:destroy-date="$_ttl" \
	 					 -o qubsd:autosnap='-' \
						 -o qubsd:autocreated="yes" "${_newsnap}" 
	fi

   # Destroy the dataset and reclone it
	zfs destroy -rRf "${_jailzfs}" > /dev/null 2>&1
	zfs clone -o qubsd:autosnap='false' "${_newsnap}" ${_jailzfs}

	if ! chk_isvm "$_jail" ; then
		# Drop the flags for etc directory and add the user for the jailname
		chflags -R noschg ${M_JAILS}/${_jail}/etc/
		pw -V ${M_JAILS}/${_jail}/etc/ \
				useradd -n $_jail -u 1001 -d /usr/home/${_jail} -s /bin/csh 2>&1
	fi

	# Remove old snapshots past their ttl and no longer being used.
#cleanup_oldsnaps "$_rootzfs" &

	return 0
}

reclone_zusr() {
	# Destroys the existing rootjail clone of <_jail>, and replaces it
	# Detects changes since the last snapshot, creates a new snapshot if necessary,
	# and destroys old snapshots when no longer needed.

	# Variables definitions
	local _jail="$1"
	local _jailzfs="${ZUSR_ZFS}/${_jail}"
	local _template="$2"
	local _templzfs="${ZUSR_ZFS}/${_template}"

	local _date=$(date +%s)
	local _ttl=$(($_date + 30))
	local _newsnap="${_templzfs}@${_date}"
	local _presnap=$(zfs list -t snapshot -Ho name ${_templzfs} | tail -1)

	# `zfs-diff` from other jails causes a momentary snapshot which the reclone operation 
	while [ -z "${_presnap##*@zfs-diff*}" ] ; do

		# Loop until a proper snapshot is found
		sleep .1
		_presnap=$(zfs list -t snapshot -Ho name ${_templzfs} | tail -1)
	done

	# If there's a presnap, and no changes since then, use it for the snapshot.
	[ "$_presnap" ] && ! [ "$(zfs diff "$_presnap" "$_templzfs")" ] && _newsnap="$_presnap"

	# If they're equal, then the valid/current snapshot already exists. Otherwise, make one.
	if ! [ "$_newsnap" = "$_presnap" ] ; then
		# Clone and set zfs params so snapshot will get auto deleted later.
		zfs snapshot -o qubsd:destroy-date="$_ttl" \
		 				 -o qubsd:autosnap='-' \
						 -o qubsd:autocreated="yes" "$_newsnap"
	fi

   # Destroy the dataset and reclone it
	zfs destroy -rRf "${_jailzfs}" > /dev/null 2>&1
	zfs clone -o qubsd:autosnap='false' "${_newsnap}" ${_jailzfs}

	# Drop the flags for etc directory and add the user for the jailname
	chflags -R noschg ${M_ZUSR}/${_jail}/rw
	chflags noschg ${M_ZUSR}/${_jail}/usr/home/${_template}

	# Replace the <template> jailname in fstab with the new <jail>
	sed -i '' -e "s/${_template}/${_jail}/g" ${M_ZUSR}/${_jail}/rw/etc/fstab > /dev/null 2>&1

	# Rename directories and mounts with dispjail name
	mv ${M_ZUSR}/${_jail}/usr/home/${_template} ${M_ZUSR}/${_jail}/usr/home/${_jail} > /dev/null 2>&1

	# Remove old snapshots past their ttl and no longer being used.
	cleanup_oldsnaps "$_templzfs" &
	return 0
}

cleanup_oldsnaps() {

	# Option for clearning up "zero bytes" (_zb) snapshots 
	getopts z _opts && _zb='true'
	shift $(( OPTIND - 1 ))

	# Removes old snapshots for the given jail. Routine cleanup, necessary due to autosnapping.
	local _dataset="$1"
	local _date=$(date +%s)

	# Assemple list of datasets in zroot, tagged ttl. Note that empty $1 , pulls all datasets
	local _snaplist=$(zfs list -Hr -t snapshot -o name,qubsd:destroy-date $_dataset \
		| grep -E "[[:blank:]]+[[:digit:]]+\$" | awk '{print $1}')

	for _snap in $_snaplist ; do

		# Get the destroy-date for each snap, and destroy if past their date
		chk_valid_zfs "$_snap" && _snap_dd=$(zfs list -Ho qubsd:destroy-date $_snap)
		[ "$_snap_dd" -lt "$_date" ] && zfs destroy $_snap > /dev/null 2>&1

		# Only remove 0B datasets if instructed to with [-z]	
		if [ "$_zb" ] ; then
			# Get data used by snap, destroy if 0B. Check exists first, b/c above might've deleted it.
			chk_valid_zfs "$_snap" && _snap_used=$(zfs list -Ho used $_snap)
			[ "$_snap_used" = "0B" ] && zfs destroy $_snap > /dev/null 2>&1 
		fi
	done
}

monitor_startstop() {
	# Need a way of monitoring qb-start, from outside of the process, to remove _TMP

	_timeout="$1"
	_TMP_IP="${_TMP_IP:=${QTMP}/qb-start_temp_ip}"
	_cycle=0

	# Assign a default value if not assigned.
	_timeout="${_timeout:="1"}"

	while [ "$_cycle" -lt "$_timeout" ] ; do
		# -Note- this only works because /bin/sh doesnt include self/caller in pgrep output
		if ! pgrep -fl '/bin/sh /usr/local/bin/qb-start' > /dev/null 2>&1 \
			 && ! pgrep -fl '/bin/sh /usr/local/bin/qb-stop' > /dev/null 2>&1
		then
			# The tmp file used for IP tracking can be discarded. 
			[ "$_TMP_IP" ] && rm "$_TMP_IP" >> /dev/null 2>&1

			# Long timeout means it's at the end of the script (rather than beginning).
			[ "$_timeout" -gt 10 ] && get_msg "_jo2" "$0"
			return 0
		fi
		
		_cycle=$(( _cycle + 1 ))
		sleep .5
	done

	# Send error message that gave up waiting, return error
	get_msg "_jo3" "$0"
	return 1	
}



########################################################################################
###################################  STATUS  CHECKS  ###################################
########################################################################################

chk_isblank() {
	# Personally I think it's posix dumb that there are only VERBOSE ways of
	# asking: Is this variable -z or only [[:blanks:]]*. Are you really going
	# to be testing blank variables for the number of spaces/tabs they contain?

	[ "$1" = "${1#*[![:space:]]}" ] && return 0  ||  return 1
}

chk_isrunning() {
	# Return 0 if jail/VM is running; return 1 if not.

	local _jail="$1"	

	if $(get_jail_parameter -eqs CLASS "$_jail" | grep -qs "VM") ; then
		pgrep -qf "bhyve: $_jail" > /dev/null 2>&1  && return 0 ||  return 1
	else
		jls -j "$1" > /dev/null 2>&1  && return 0  ||  return 1
	fi
}

chk_truefalse() {
	# Quiet option
	getopts q _opts && _qf='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters / check.
	local _value="$1"
	local _param="$2"

	[ -z "$_value" ] && get_msg $_qf "_0" "$_param" && return 1

	# Must be either true or false.
	[ ! "$_value" = "true" ] && [ ! "$_value" = "false" ] \
			&& get_msg $_qf "_cj19" "$_param" && return 1

	return 0
}

chk_isvm() {
	# Checks if the positional variable is the name of a VM, return 0 if true 1 of not
	_jail="$1"

	$(get_jail_parameter -qsde CLASS $_jail | grep -qs "VM") && return 0 || return 1
}

chk_avail_jailname() {
	# Checks that the proposed new jailname does not have any entries or partial entries
	# in JCONF, JMAP, and ZFS datasets
	# Return 0 jailname available, return 1 for any failure

	# Quiet option
	getopts q _opts && _qa='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters and function specific variables.
	local _jail="$1"

	# Fail if no jail specified
	[ -z "$_jail" ] && get_msg $_qa "_0" "new jail name" && return 1

	# Checks that proposed jailname isn't 'none' or 'qubsd' or starts with '#'
	echo "$_jail" | grep -Eqi "^(none|qubsd)\$" \
			&& get_msg $_qa "_cj15" "$_jail" && return 1

	# Jail must start with :alnum: and afterwards, have only _ or - as special chars 
	echo ! "$_jail" | grep -Eq '^[[:alnum:]][[:alnum:]_-]*$' \
			&& get_msg $_qa "_cj15_2" "$_jail" && return 1

   # Checks that proposed jailname doesn't exist or partially exist
	if chk_valid_zfs "${JAILS_ZFS}/$_jail" || \
		chk_valid_zfs "${ZUSR_ZFS}/$_jail"  || \
		grep -Eq "^${_jail}[[:blank:]]+" $JMAP || \
		grep -Eq "^${_jail}[[:blank:]]*\{" $JCONF ; then
		get_msg $_qa "_cj15_1" "$_jail" && return 1
	fi
}



########################################################################################
###################################  SANITY  CHECKS  ###################################
########################################################################################

chk_valid_zfs() {
	# Verifies the existence of a zfs dataset, returns 0, or 1 on failure
	# zfs provides no quiet option, and > null redirect takes up real-estate

	# Perform check
	zfs list $1 >> /dev/null 2>&1  &&  return 0  ||  return 1
}

chk_valid_jail() {
	# Checks that jail has JCONF, JMAP, and corresponding ZFS dataset
	# Return 0 for passed all checks, return 1 for any failure

	# Quiet option
	getopts q _opts && _qv='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters and function specific variables.
	local _value="$1"
	local _class ; local _rootjail ; local _template ; local _class_of_temp

	# Fail if no jail specified
	[ -z "$_value" ] && get_msg $_qv "_0" "jail" && return 1

	# Must have class in JMAP. Used later to find the correct zfs dataset
	_class=$(sed -nE "s/^${_value}[[:blank:]]+CLASS[[:blank:]]+//p" $JMAP)
	chk_valid_class $_qv $_class || return 1

	case $_class in
		"")
			# Empty, no class exists in JMAP
			get_msg $_qv "_cj1" "$_value" "class" && return 1
		;;
		rootjail)
			# Rootjail's zroot dataset should have no origin (not a clone) 
			! zfs get -H origin ${JAILS_ZFS}/${_value} 2> /dev/null | awk '{print $3}' \
					| grep -Eq '^-$'  && get_msg $_qv "_cj4" "$_value" "$JAILS_ZFS" && return 1
		;;
		appjail)
			# Appjails require a dataset at quBSD/zusr
			! chk_valid_zfs ${ZUSR_ZFS}/${_value}\
					&& get_msg $_qv "_cj4" "$_value" "$ZUSR_ZFS" && return 1
		;;
		dispjail)

			# Verify the dataset of the template for dispjail
			local _template=$(sed -nE \
					"s/^${_value}[[:blank:]]+TEMPLATE[[:blank:]]+//p" $JMAP)

			# First ensure that it's not blank
			[ -z "$_template" ] && get_msg $_qv "_cj5" "$_value" && return 1

			local _class_of_temp=$(sed -nE \
				"s/^${_template}[[:blank:]]+CLASS[[:blank:]]+//p" $JMAP)

			# Dispjails can only reference appjails.
			[ "$_class_of_temp" = "dispjail" ] \
					&& get_msg $_qv "_cj5_1" "$_value" "$_template" && return 1

			# Ensure that the template being referenced is valid
			! chk_valid_jail $_qv "$_template" \
					&& get_msg $_qv "_cj6" "$_value" "$_template" && return 1
		;;
		ephemeral) # There are no checks for now. These are special types of dispjails
					# But I might want to add the temporary cloned datasets. We'll see. Prob not.
		;;
		rootVM)
			# VM zroot dataset should have no origin (not a clone) 
			! zfs get -H origin ${JAILS_ZFS}/${_value} 2> /dev/null | awk '{print $3}' \
					| grep -Eq '^-$'  && get_msg $_qv "_cj4" "$_value" "$JAILS_ZFS" && return 1
		;;
		*VM)
		;;
		# Any other class is invalid
		*) get_msg $_qv "_cj2" "$_class" "CLASS"  && return 1
		;;
	esac

	# One more case statement for VMs vs jails
	case $_class in
		*jail)
			# Must have a designated rootjail in JMAP
			! grep -Eqs "^${_value}[[:blank:]]+ROOTJAIL[[:blank:]]+[^[:blank:]]+" $JMAP \
					&& get_msg $_qv "_cj1" "$_value" "ROOTJAIL" && return 1

			# Must have an entry in JCONF
			! grep -Eqs "^${_value}[[:blank:]]*\{" $JCONF \
					&& get_msg $_qv "_cj3" && return 1
		;;
		*VM)
			# Must have a designated rootVM in JMAP
			! grep -Eqs "^${_value}[[:blank:]]+ROOTVM[[:blank:]]+[^[:blank:]]+" $JMAP \
					&& get_msg $_qv "_cj1" "$_value" "ROOTVM" && return 1
		;;
	esac

	return 0
}


###############################  JAIL  PARAMETER CHECKS  ###############################

chk_valid_autostart() {
	# Standardization/consistency with get_jail_parameter() func.

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	chk_truefalse $_q "$1" "AUTOSTART"
}

chk_valid_autosnap() {
	# Mostly for standardization/completeness with get_jail_parameter() func.

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	chk_truefalse $_q "$1" "AUTOSNAP"
}

chk_valid_bhyveopts() {
	# Checks that only non arg based bhyve options were provided 

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	_value="$1"

	# Only bhyve opts with no argument
	! echo "$_value" | grep -Eqs '^[AaCDeHhPSuWwxY]+$' \
			&& get_msg $_q "_cj29" "$_value" && return 1

	# No duplicate characters
	[ "$(echo "$myvar" | fold -w1 | sort | uniq -d | wc -l)" -gt 0 ] \
			&& get_msg $_q "_cj30" "$_value" && return 1

	return 0	
}

chk_valid_class() {
	# Return 0 if proposed class is valid ; return 1 if invalid

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "CLASS" && return 1

	# Valid inputs are: appjail | rootjail | dispjail
	case $_value in
		appjail|dispjail|ephemeral|rootjail|rootVM|appVM|VM) return 0 ;;
		*) get_msg $_q "_cj2" "$_value" "CLASS" && return 1 ;;
	esac
}

chk_valid_cpuset() {
	# Return 0 if proposed cpuset is valid ; return 1 if invalid

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters / check.
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "CPUSET" && return 1

	# None is always a valid cpuset
	[ "$_value" = "none" ] && return 0

	# Get the list of CPUs on the system, and edit for searching
	_validcpuset=$(cpuset -g | sed "s/pid -1 mask: //" | sed "s/pid -1 domain.*//")

	# Test for negative numbers and dashes in the wrong place
	echo "$_value" | grep -Eq "(,,+|--+|,-|-,|,[[:blank:]]*-|^[^[:digit:]])" \
			&& get_msg $_q "_cj2" "$_value" "CPUSET" && return 1

	# Remove `-' and `,' to check that all numbers are valid CPU numbers
	_cpuset_mod=$(echo $_value | sed -E "s/(,|-)/ /g")

	for _cpu in $_cpuset_mod ; do
		# Every number is followed by a comma except the last one
		! echo $_validcpuset | grep -Eq "${_cpu},|${_cpu}\$" \
			&& get_msg $_q "_cj2" "$_value" "CPUSET" && return 1
	done

	return 0
}

chk_valid_gateway() {
	# Checks against the quBSD conventions.
	# Return 0 if proposed gateway is valid ; return 1 if invalid

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters.
	local _gw="$1"
	local _jail="$2"

	# Nonlocal var, class of the gateway is important for jail startups
	local _class_gw=$(sed -nE "s/^${_gw}[[:blank:]]+CLASS[[:blank:]]+//p" $JMAP)

	# Class of gateway should never be a rootjail
	if [ "$_class_gw" = "rootjail" ] || [ "$_class_gw" = "rootVM" ] ; then
		get_msg $_q "_cj7_1" "$_gw" "$_jail" && return 1

	else
		# `none' is always a valid gateway 
		[ "$_gw" = "none" ] && return 0

		# Check that gateway is a valid jail.
 		chk_valid_jail $_q "$_gw" || return 1

# UPGRADES: TYPE

	fi
}

chk_valid_ipv4() {
	# Tests for validity of IPv4 CIDR notation.
	# return 0 if valid (or none), return 1 if not
	# Also assigns global variable: _valid_IPv4="true"

	# Variables below are assigned as global variables rather than
	# local, because they're required for performing other checks.
	#   $_a0  $_a1  $_a2  $_a3  $_a4

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeter / check.
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "IPV4" && return 1

	# Temporary variables used for checking ipv4 CIDR
	local _b1 ; local _b2 ; local _b3

	# None, auto, and DHCP are always considered valid.
	[ "$_value" = "none" -o "$_value" = "auto" -o "$_value" = "DHCP" ] && return 0

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
	if echo "$_value" | grep -Eqs \
		"[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+/[[:digit:]]+"\
			 >> /dev/null 2>&1 ; then

		# Ensures that each digit is within the proper range
		if    [ "$_a0" -ge 0 ] && [ "$_a0" -le 255 ] \
			&& [ "$_a1" -ge 0 ] && [ "$_a1" -le 255 ] \
			&& [ "$_a2" -ge 0 ] && [ "$_a2" -le 255 ] \
			&& [ "$_a3" -ge 0 ] && [ "$_a3" -le 255 ] \
			&& [ "$_a4" -ge 0 ] && [ "$_a4" -le 32 ]  >> /dev/null 2>&1
		then
			_valid_IPv4="true"
			return 0
		else
			# Error message, is invalid IPv4
			get_msg $_q "_cj10" "$_value" && return 1
		fi

	else
		# Error message, is invalid IPv4
		get_msg $_q "_cj10" "$_value" && return 1
	fi
}

chk_isqubsd_ipv4() {
	# Checks for IP overlaps and/or mismatch in quBSD convention.
	# Returns 0 for IPv4 within convention ; return 1 if not.

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. _
	local _value="$1"
	local _jail="$2"

	# $_a0 - $_a4 vars are needed later. Check that they're all here, or get them.
	echo "${_a0}#${_a1}#${_a2}#${_a3}#${_a4}" | grep -q "##" \
		&& chk_valid_ipv4 -q "$_value"

	# Assigns global variables that will be used here for checks.
	define_ipv4_convention "$_jail"

	# No value specified
	[ -z "$_value" ] && get_msg $_q "_0" "IPV4"

	# Check the net-jails for IP values of none
	case ${_value}_${_jail} in

		none_net-firewall)
			# IPV4 `none' with net-firewall shouldn't really happen
			get_msg $_q "_cj9" "$_value" "$_jail" && return 1
		;;
		*_net-firewall)
			# net-firewall has external connection. No convention to judge
			return 0
		;;
		none_net-*)
			# `none' shouldn't really happen with net-jails either
			get_msg $_q "_cj13" "$_value" "$_jail" && return 1
		;;
		none_*|auto_*)
			# All other jails, `none' is fine. No checks required
			return 0
		;;
	esac

	# Compare against JMAP, and _USED_IPS.
	if grep -v "^$_jail" $JMAP | grep -qs "$_value" \
			|| $(get_info -e _USED_IPS | grep -qs "${_value%/*}") ; then
		get_msg $_q "_cj11" "$_value" "$_jail" && return 1
	fi

# NOTE:  $a2 and $ip2 are missing, because that is the _cycle
# Any change to quBSD naming convention will require manual change.
	! [ "$_a0.$_a1.$_a3/$_a4" = "$_ip0.$_ip1.$_ip3/$_subnet" ] \
			&& get_msg $_q "_cj12" "$_value" "$_jail" && return 1

	_gateway=$(sed -nE "s/^${_jail}[[:blank:]]+GATEWAY[[:blank:]]+//p" $JMAP)

	# Assigning IP to jail that has no gateway
	[ "$_gateway" = "none" ] && get_msg $_q "_cj14" "$_value" "$_jail" \
		&& return 1

	# Catchall. return 0 if no other checks caused a return 1
	return 0
}

chk_valid_maxmem() {
	# Return 0 if proposed maxmem is valid ; return 1 if invalid
	# IMPROVEMENT IDEA - check that proposal isn't greater than system memory

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeter / check
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "MAXMEM" && return 1

	# None is always a valid maxmem
	[ "$_value" = "none" ] && return 0

	# Per man 8 rctl, user can assign units: G|g|M|m|K|k
   ! echo "$_value" | grep -Eqs "^[[:digit:]]+(G|g|M|m|K|k)\$" \
			&& get_msg $_q "_cj2" "$_value" "MAXMEM" && return 1

	# Set values as numbers without units 
	_bytes=$(echo $_value | sed -nE "s/.\$//p")
	_sysmem=$(grep "avail memory" /var/run/dmesg.boot | sed "s/.* = //" | sed "s/ (.*//" | tail -1)

	# Unit conversion to bytes
	case $_value in 
		*G|*g) _bytes=$(( $_bytes * 1000000000 )) ;;
		*M|*m) _bytes=$(( $_bytes * 1000000 ))    ;;
		*K|*k) _bytes=$(( $_bytes * 1000 ))       ;;
	esac

	# Compare values, error if user input exceeds availabl RAM
	[ "$_bytes" -ge "$_sysmem" ] && get_msg $_q "_cj21" "$_value" "$_sysmem" && return 1 

	return 0
}

chk_valid_memsize() {
	# Return 0 if proposed memsize is valid ; return 1 if invalid

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# It's the exact same program/routine. Different jmap params to be technically specific.
	chk_valid_maxmem $_q "$1" || return 1

	return 0
}

chk_valid_mtu() {
	# Return 0 if proposed mtu is valid ; return 1 if invalid

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters / check.
	local _value="$1"
	local _jail="$2"

	# If MTU is not a number
	echo "$_value" | ! grep -Eq '^[0-9]*$' && get_msg $_q "_cj18_1" "$_value" "MTU" && return 1

	# Just push a warning, but don't error for MTU
	[ "$_value" -lt 1200 ] > /dev/null 2>&1 && get_msg $_q "_cj18" "MTU"
	[ "$_value" -gt 1600 ] > /dev/null 2>&1 && get_msg $_q "_cj18" "MTU"

	return 0
}

chk_valid_no_destroy() {
	# Mostly for standardization/completeness with get_jail_parameter() func.

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	chk_truefalse $_q "$1" "NO_DESTROY"
}

chk_valid_ppt() {
	# Mostly for standardization/completeness with get_jail_parameter() func.

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	_value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "PPT (passthru)" && return 1

	# Get list of pci devices on the machine
	_pciconf=$(pciconf -l | awk '{print $1}')

	# Check all listed PPT devices from jmap 
	for _val in $_value ; do

		# convert _val to native pciconf format with :colon: instead of /fwdslash/
		_val2=$(echo "$_val" | sed "s#/#:#g")

		# Search for the individual device and specific device for devctl functions later
		_pciline=$(echo "$_pciconf" | grep -Eo ".*${_val2}")
		_pcidev=$(echo "$_pciline" | grep -Eo "pci.*${_val2}")

		# PCI device doesnt exist on the machine
		[ -z "$_pciline" ] && get_msg $_q "_cj22" "$_val" "PPT" && return 1 

		# Extra set of checks for the PCI device, if it's about to be attached to a VM 
		if [ "$_ppt_launch" = "true" ] ; then

			# If the pci device is detached, try to attach it.
			[ -z "${_pciline##none*}" ] && ! $(devctl attach "$_pcidev") && _attached="true" \
					&& get_msg "_cj26" "$_pciline" && return 1

			# Make sure the PCI device is designated for passthrough 
			[ -n "${_pciline##ppt*}" ] && get_msg $_q "_cj23" "$_val" "$_passvar" && return 1 

			# If the device was attached and is ppt, there's no need for dettach/attach test 
			if [ -z "$_attached" ] ; then

				# Check if the PCI device is busy, and would thus cause an error
				! devctl detach "$_pcidev" && get_msg $_q "_cj24" "$_val" && return 1

				# Re-attach PCI, or error if unable
				! devctl attach "$_pcidev" && get_msg $_q "_cj25" && return 1
			fi
		fi
	done

	return 0
}

chk_valid_rootjail() {
	# Return 0 if proposed rootjail is valid ; return 1 if invalid

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeter / check
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "CLASS" && return 1

	# Must be designated as a rootjail in jailmap.con
	_rootj=$(sed -nE "s/${_value}[[:blank:]]+CLASS[[:blank:]]+//p" $JMAP)
	! [ "$_rootj" = "rootjail" ] && get_msg $_q "_cj16" "$_value" "rootjail" && return 1

	# Must have an entry in JCONF
	! grep -Eqs "^${_value}[[:blank:]]*\{" $JCONF \
			&& get_msg $_q "_cj3" && return 1

	# Rootjails require a dataset at zroot/quBSD/jails
	! chk_valid_zfs ${JAILS_ZFS}/${_value} \
			&& get_msg $_q "_cj4" "$_value" "$JAILS_ZFS" && return 1

	return 0
}

chk_valid_rootvm() {
	# Return 0 if proposed rootVM is valid ; return 1 if invalid

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeter / check
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "CLASS" && return 1

	# Must be designated as a rootjail in jailmap.con
	_rootvm=$(sed -nE "s/${_value}[[:blank:]]+CLASS[[:blank:]]+//p" $JMAP)
	! [ "$_rootvm" = "rootVM" ] && get_msg $_q "_cj16" "$_value" "rootVM" && return 1

	# Rootjails require a dataset at zroot/quBSD/jails
	! chk_valid_zfs ${JAILS_ZFS}/${_value} \
			&& get_msg $_q "_cj4" "$_value" "$JAILS_ZFS" && return 1

	return 0
}

chk_valid_seclvl() {
	# Return 0 if proposed seclvl is valid ; return 1 if invalid

	# NOTE: Rare case where [-q] is received as positional, not getopts.
	# '-1' is a valid seclvl ; which getopts interprets as an option.
	local _opt="$1"

	if [ "$_opt" = '-q' ] ; then
		_value="$2" ; _q='-q'
	else
		_value="$_opt"
	fi

	[ -z "$_value" ] && get_msg $_q "_0" "SECLVL" && return 1

	# None is always a valid seclvl
	[ "$_value" = "none" ] && return 0

	# If SECLVL is not a number
	echo "$_value" | ! grep -Eq '^(-1|-0|0|1|2|3)$' \
			&& get_msg $_q "_cj2" "$_value" "SECLVL" && return 1

	return 0
}

chk_valid_taps() {
	# Return 0 if vif is valid ; return 1 if invalid

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters.
	local _value="$1"

	[ -z "$_value" ] && get_msg $_q "_0" "VIF" && return 1

	for _val in $_value ; do
		! echo "$_val" | grep -qE "^[[:digit:]]\$" \
				&& get_msg $_q "_cj7" "$_val" && return 1
	done

	return 0
}

chk_valid_tmux() {
	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	chk_truefalse $_q "$1" "TMUX"
}

chk_valid_schg() {
	# Return 0 if proposed schg is valid ; return 1 if invalid

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeter / check
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "SCHG" && return 1

	# None is always a valid schg
	[ "$_value" = "none" ] && return 0

	# Valid inputs are: none | sys | all
	case $_value in
		none|sys|all) return 0 ;;
		*) get_msg $_q "_cj2" "$_value" "SCHG"  ;  return 1
	esac
}

chk_valid_template() {
	# Return 0 if proposed template is valid ; return 1 if invalid
	# Exists mostly so that the get_jail_parameters() function works seamlessly

	# Quiet option
	getopts q _opts && _qt='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters.
	local _value="$1"

	! chk_valid_jail $_qt "$_value" && return 1

	return 0
}

chk_valid_vcpus() {
	# Return 0 if proposed vcpus are valid; false if not. 

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters / check.
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "VCPUS" && return 1

	# Get the number of CPUs on the system 
	_syscpus=$(cpuset -g | head -1 | grep -oE "[^[:blank:]]+\$")
	_syscpus=$(( _syscpus + 1 ))

	# Ensure that the input is a number
 	! echo "$_value" | grep -qE "^[[:digit:]]+\$" \
			&& get_msg $_q "_cj2" "$_value" "VCPUS" && return 1

	# Ensure that vpcus doesnt exceed the number of system cpus or bhyve limits
	if [ "$_value" -gt "$_syscpus" ] || [ "$_value" -gt 16 ] ; then
		get_msg $_q "_cj20" "$_value" "$_syscpus" && return 1
	fi

	return 0
}

chk_valid_vncres() {
	# Make sure that the resolution is supported by bhyve

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	_value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "vnc viewer resolution" && return 1

	case $_value in 
		640x480|800x600|1024x768|1920x1080) return 0 ;;
		*) get_msg $_q "_je6" "VNC viewer resolution" && return 1 ;;
	esac
}

chk_valid_wiremem() {
	# Standardization/consistency with get_jail_parameter() func.

	# Quiet option
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	chk_truefalse $_q "$1" "WIREMEM"
}



########################################################################################
###########################  FUNCTIONS RELATED TO NETWORKING  ##########################
########################################################################################

define_ipv4_convention() {
	# Defines the quBSD internal IP assignment convention.
	# Variables: $ip0.$ip1.$ip2.$ip3/subnet ; are global. They're required
	# for functions:  discover_open_ipv4()  ;  chk_isqubsd_ipv4()

	# Returns 0 for any normal IP assignment, returns 1 if
	# operating on net-firewall (which needs special handling).

	local _jail="$1"

	# Global variable indirection is used with `_cycle', in discover_open_ipv4()
	_cycle=1

	# Combo of function caller and $JAIL determine which IP form to use
	case "$0" in
		*qb-connect)
				# Temporary, adhoc connections have the form: 10.99.x.2/30
				_ip0=10 ; _ip1=99 ; _ip2="_cycle" ; _ip3=2 ; _subnet=30 ;;

		*) case $_jail in
				net-firewall)
					# firewall IP is not internally assigned, but router dependent.
					_cycle=256 ; return 1 ;;

				net-*)
					# net jails IP address convention is: 10.255.x.2/30
					_ip0=10 ; _ip1=255 ; _ip2="_cycle" ; _ip3=2 ; _subnet=30 ;;

				serv-*)
					# Server jails IP address convention is: 10.128.x.2/30
					_ip0=10 ; _ip1=128 ; _ip2="_cycle" ; _ip3=2 ; _subnet=30 ;;

				*)
					# All other jails should receive convention: 10.1.x.2/30
					_ip0=10 ; _ip1=1 ; _ip2="_cycle" ; _ip3=2 ; _subnet=30 ;;
			esac
	esac
}

discover_open_ipv4() {
	# Finds an IP address unused by any running jails, or in jailmap.conf
	# Echo open IP on success; Returns 1 if failure to find an available IP

	# Positional params and func variables.
	getopts q _opts && local _qi='-q'
	shift $(( OPTIND - 1 ))

	local _jail="$1"
	local _ipv4
	_TMP_IP="${_TMP_IP:=${QTMP}/qb-start_temp_ip}"

	# net-firewall connects to external network. Assign DHCP, and skip checks.
	[ "$_jail" = "net-firewall" ] && echo "DHCP" && return 0

	# Assigns values for each IP position, and initializes $_cycle
	define_ipv4_convention "$_jail"

	# Get a list of all IPs in use. Saves to variable $_USED_IPS
	get_info _USED_IPS 

	# Increment _cycle to find an open IP.
	while [ $_cycle -le 255 ] ; do

		# $_ip2 uses variable indirection, which subsitutes "cycle"
		eval "_ipv4=${_ip0}.${_ip1}.\${$_ip2}.${_ip3}"

		# Compare against JMAP, and the IPs already in use, including the temp file.
		if grep -Fq "$_ipv4" $JMAP || echo "$_USED_IPS" | grep -Fq "$_ipv4" \
				|| grep -Fqs "$_ipv4" "$_TMP_IP" ; then

			# Increment for next cycle
			_cycle=$(( _cycle + 1 ))

			# Failure to find IP in the quBSD conventional range
			if [ $_cycle -gt 255 ] ; then
				eval "_pass_var=${_ip0}.${_ip1}.x.${_ip3}"
				get_msg $_qi "_jf7" "$_jail" 
				return 1
			fi
		else
			# Echo the value of the discovered IP and return 0
			echo "${_ipv4}/${_subnet}" && return 0
		fi
	done
}

assign_ipv4_auto() {
	# IPV4 assignment during parallel jail starts, has potetial for overlapping IPs. $_TMP_IP
	# file is used for deconfliction during qb-start, and must be referenced by exec.created
	
	# Positional params and func variables.
	getopts e _opts && _echo="true"
	shift $(( OPTIND - 1 ))

	_jail="$1"
	_ipv4=''
	_TMP_IP="${_TMP_IP:=${QTMP}/qb-start_temp_ip}"

	# Try to pull pre-set IPV4 from the temp file if it exists.
	[ -e "$_TMP_IP" ] && local _ipv4=$(sed -nE "s#^[[:blank:]]*${_jail}[[:blank:]]+##p" $_TMP_IP) 

	# If there was no ipv4 assigned to _jail in the temp file, then find an open ip for the jail.
	[ -z "$_ipv4" ] && _ipv4=$(discover_open_ipv4 "$_jail")

	# Echo option or assign global IPV4
	[ "$_echo" ] && echo "$_ipv4" || IPV4="$_ipv4"
	
	return 0
}



########################################################################################
##########################  FUNCTIONS RELATED TO VM HANDLING ###########################
########################################################################################

cleanup_vm() {
	# Cleanup function after VM is stopped or killed in any way 

	# Positional params and func variables.
	while getopts nqx opts ; do
		case $opts in
			n) _norun="-n" ;;
			q) _qcv="-q" ;;
			x) _exit="true" ;;
		esac
	done

	shift $(( OPTIND - 1 ))

	# Positional variables
	_VM="$1"
	_rootvm="$2"

	# Make sure a VM was provided, or return 
	[ -z "$_VM" ] && get_msg $_qcv "_0" && return 1

	# Bring all recorded taps back to host, and destroy 
	for _tap in $(cat "${QTMP}/qb-taps_${_VM}" 2> /dev/null) ; do
		
		if [ -n "$_norun" ] ; then
			ifconfig "$_tap" destroy 2> /dev/null
		else
			# Trying to prevent searching in all jails, by guessing where tap is 
			_tapjail=$(get_info -e _CLIENTS "$_VM")
			[ -z "$_tapjail" ] && _tapjail=$(get_jail_parameter -esqz GATEWAY ${_VM})

			# Remove the tap
			remove_tap "$_tap" "$_tapjail" && ifconfig "$_tap" destroy 2> /dev/null
		fi
	done	

	# Remove the tracker files
	rm "${QTMP}/qb-vnc_${_VM}"  > /dev/null 2>&1
	rm "${QTMP}/qb-taps_${_VM}" > /dev/null 2>&1

	# Destroy the VM
	bhyvectl --vm="$_VM" --destroy > /dev/null 2>&1

	# If it was a norun, dont spend time recloning
	[ -n "$_norun" ] && return 0
	
	# Pull rootvm in case it wasn't provided 
	[ -z "$_rootvm" ] && ! _rootvm=$(get_jail_parameter -ed ROOTVM $_VM) \
		&& get_msg "$_cj32" "$_VM" && return 1

	# Destroy the dataset
	reclone_zroot -q "$_VM" "$_rootvm"	

	# Remove the /tmp file
	rm "${QTMP}/qb-bhyve_${_VM}" 2> /dev/null

	# If called with [-x] send an exit message and run exit 0	
	[ -n "$_exit" ] && get_msg "_cj32" "$_VM" && exit 0

	return 0
}

prep_bhyve_options() {
	# Starts VM. ALLCAPS variables are each a full line option for bhyve. Returns 1 if any errors. 

   # Options 
	while getopts qt opts ; do
		case $opts in
			q) _qs="-q" ;;
			t) _tmux="-t" ;;
		esac
	done

	shift $(( OPTIND - 1 ))

	# Assign _vm variable
	_VM="$1"

	# Get simple jmap variables
	_gateway=$(get_jail_parameter -edz GATEWAY "$_VM")    || return 1 
	_ipv4=$(get_jail_parameter -ez IPV4 "$_VM")           || return 1 
	_memsize=$(get_jail_parameter -e MEMSIZE "$_VM")      || return 1 
	_wiremem=$(get_jail_parameter -e WIREMEM "$_VM")      || return 1 
	_bhyveopts=$(get_jail_parameter -e BHYVEOPTS "$_VM")  || return 1 
	_rootvm=$(get_jail_parameter -ed ROOTVM "$_VM")       || return 1 
	_taps=$(get_jail_parameter -e TAPS "$_VM")            || return 1 
	_vcpus=$(get_jail_parameter -e VCPUS "$_VM")          || return 1 
	_vncres=$(get_jail_parameter -edz VNCRES "$_VM")      || return 1 
	[ -z "$_tmux" ] && _tmux=$(get_jail_parameter -edz TMUX "$_VM") || return 1 

	# _ppt_launch is a dirty hack to flag extra checks for passthru devices 
	_ppt_launch="true"
	_ppt=$(get_jail_parameter -edz PPT "$_VM")            || return 1

	# For VMs that are clients, their tap still needs an IPV4 inside the gateway 
	[ "$_ipv4" = "auto" ] && _ipv4=$(assign_ipv4_auto -e "$_VM")

	# Add leading '-' to _bhyveopts
	_BHOPTS="-${_bhyveopts}"

	# Get wildcard bhyve option added by user 
	_BHYVE_CUST=$(sed -En "s/${_VM}[[:blank:]]+BHYVE_CUST[[:blank:]]+//p" $JMAP \
						| sed -En "s/[[:blank:]]+/ /p")

	# Assign CPU, memory, and wire variable
	_CPU="-c $_vcpus"
	_RAM="-m $_memsize"
	[ "$_wiremem" = "true" ] && _WIRE='-S' || _WIRE=''
	
	# Assign hostbridge based on CPU 
	grep -Eqs "^CPU.*AMD" /var/run/dmesg.boot \
		&& _HOSTBRG="-s 0:0,amd_hostbridge" \
		|| _HOSTBRG="-s 0:0,hostbridge"

	# assign lpc, then start slot count for bhyve command construction
	_LPC="-s 31:0,lpc"
	_slot=1

	# Assign zroot blk device 
	_BLK_ROOT="-s ${_slot}:0,virtio-blk,/dev/zvol/${JAILS_ZFS}/${_VM}"
	_slot=$(( _slot + 1 ))	

	# Assign zusr blk device. Must be a volume; or should be blank
	chk_valid_zfs "${ZUSR_ZFS}/${_VM}" \
		&& zfs list -Ho type "${ZUSR_ZFS}/${_VM}" | grep -qs "volume" \
		&& _BLK_ZUSR="-s ${_slot}:0,virtio-blk,/dev/zvol/${ZUSR_ZFS}/${_VM}" \
		&& _slot=$(( _slot + 1 ))	\
		|| _BLK_ZUSR='' \

	# Assign passthrough variable
	for _pci in $_ppt ; do		
		_PPT=$(printf "%b" "${_PPT} -s ${_slot}:0,passthru,\"${_pci}\"")
		_WIRE="-S"
		_slot=$(( _slot + 1 ))	
	done

	# UEFI bootrom
	_BOOT="-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd"

	# Assign VNC FBUF options 
	if [ "$_vncres" ] ; then

		# Define height/width from the jmap entry
		_w=$(echo "$_vncres" | grep -Eo "^[[:digit:]]+")
		_h=$(echo "$_vncres" | grep -Eo "[[:digit:]]+\$")
		
		# Find all sockets in use, and define starting socket to search 
		_socks=$(sockstat -P tcp | awk '{print $6}' | grep -Eo ":[[:digit:]]+")
		_vncport=5900

		# cycle through sockets until an unused one is found
		while : ; do
			echo "$_socks" | grep -qs "$_vncport" && _vncport=$(( _vncport + 1 )) || break 
		done

		_FBUF="-s 29,fbuf,tcp=0.0.0.0:${_vncport},w=${_w},h=${_h}"
		_slot=$(( _slot + 1 ))	

		_TAB="-s 30,xhci,tablet"
		_slot=$(( _slot + 1 ))	

	fi

	# Launch a serial port if variable was passed	
	[ "$_tmux" ] && _STDIO="-l com1,stdio" && _TMUX1="tmux new-session -d -s $_VM \"" \
		&& _TMUX2='"'

	# Tap virtio lines still need to be created. Slots 29-31 are reserved fbuf, tablet, lpc
	[ "$(( _slot + _taps ))" -gt 28 ] && get_msg "_cj28" "$_VM" && return 1

	# Invoke the trap function for VM cleanup, in case of any errors after modifying host/trackers
	trap "cleanup_vm -n $_VM" INT TERM HUP EXIT

	# Assign all taps to slots _VTNET. VM can have taps, even without gateway
	while [ "$_taps" -gt 0 ] ; do		

		# Use ifconfig to keep track of available taps. 
		_tap=$(ifconfig tap create)
		_VTNET=$(printf "%b" "${_VTNET} -s ${_slot}:0,virtio-net,${_tap}")
		_taps=$(( _taps - 1 ))

		# Tracker file for which taps are related to which VM
		echo "$_tap" >> "${QTMP}/qb-taps_${_VM}"
	done

	# First tap created is used for networking
	_vif=$(head -1 "${QTMP}/qb-taps_${_VM}" 2> /dev/null)

	# Wait till last moment to create tracker file for the vncview port
	[ "$_vncport" ] && echo "${_vncport}" > "${QTMP}/qb-vnc_${_VM}"

	# Define the full bhyve command
	_BHYVE_CMD=$(echo $_TMUX1 bhyve $_CPU $_RAM $_BHOPTS $_WIRE $_HOSTBRG $_BLK_ROOT $_BLK_ZUSR \
			$_VTNET $_PPT $_FBUF $_TAB $_LPC $_BOOT $_BHYVE_CUST $_STDIO $_VM $_TMUX2)
	
	# unset the trap
	trap ":" INT TERM HUP EXIT

	return 0
}

launch_vm() {
	# To ensure VM is completely detached from caller AND trapped after finish, a /tmp script runs
	# the launch and monitoring. qb-start/stop can only have one instance running (for race/safety)
	# but VMs launched by qb-start would otherwise persist in the process list with the VM.

	# Send the commands to a temp file
	cat << ENDOFCMD > "${QTMP}/qb-bhyve_${_VM}"
		
		# New script wont know about caller functions. Need to source them again 
		. /usr/local/lib/quBSD/quBSD.sh
		
		get_global_variables

		# Create trap for post VM exit 
		trap "cleanup_vm -x $_VM $_rootvm" INT TERM HUP EXIT

		# Launch the VM to background
		eval $_BHYVE_CMD

		sleep 2

		# Monitor the VM, perform cleanup after done	
		while pgrep -fq "bhyve: $_VM" ; do sleep 1 ; done 

		# Positively exiting the script prevents hanging at terminal
		exit 0
ENDOFCMD

	# Make the file executabel
	chmod +x "${QTMP}/qb-bhyve_${_VM}"

	# Call the temp file with exec to separate it from the caller script
	exec "${QTMP}/qb-bhyve_${_VM}" &
	
	return 0
}

exec_vm_coordinator() {
	# Oversees the launching of a VM

   # Options 
	while getopts nqt opts ; do
		case $opts in
			n) _norun="-n" ;;
			q) _qs="-q" ;;
			t) _tmux="-t" ;;
		esac
	done

	shift $(( OPTIND - 1 ))

	# Assign _vm variable
	_VM="$1"

	# Ensure that there's nothing lingering from this VM before trying to start it 
	cleanup_vm $_norun $_qs "$_VM"

	# Pulls variables for the VM, and assembles them into bhyve line options
	prep_bhyve_options $_qs $_tmux "$_VM"

	# If norun, echo the bhyve start command, cleanup the taps/files, and return 0 
	if [ -n "$_norun" ] ; then

		echo $_BHYVE_CMD 
		cleanup_vm -n $_VM 
		return 0
	fi

	# Launch VM sent to background, so connections can be made (network, vnc, tmux)
	launch_vm & 

	# Monitor for VM start, before attempting connections. 3 secs to start
	_count=1
	while : ; do
		sleep .5
		pgrep -fq "bhyve: $_VM" && break

		[ "$_count" -ge 6 ] && get_msg get_msg "_cj31" "$_VM" && return 1
		_count=$(( _count + 1 ))
	done

	# The VM should be up and running, or function would've already returned 1 
	if [ -n "$_vif" ] ; then

		# Connect to the upstream gateway
		[ -n "$_gateway" ] && [ ! "$_gateway" = "none" ] && chk_isrunning "$_gateway" \
			&& connect_client_to_gateway "$_VM" "$_gateway" "$_ipv4" > /dev/null 
	
		# Reconnect the downstream client. Will immediately return if there are no clients
		connect_gateway_to_clients "$_VM"	
	fi

	[ -n "$_vncres" ] && vncviewer "0.0.0.0:$_vncport" &

	return 0
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
