#!/bin/sh

##################################################################################
######################  GENERAL DESCRIPTION OF FUNCTIONS  ########################

# Global variables, jail/quBSD parameters, sanity checks, messages, networking.
# Functions embed many sanity checks, but also call other functions to assist.
# Messages are sourced from a separate script, as a function. They have the form:
#	 get_msg <$_q> <_msg_ident> <_pass_variable1> <_pass_variable2>
#		<$_q> (q)uiet option. Normally getopts, but sometimes as positional param, 
#           when <value> of a positional var might have a leading '-' dash.
#     <_msg_ident> Is used to retreive a particular message from the msg function.
#     <_pass_variable> 1 and 2 are for supplementing message specificity.

# Functions can assign global variables and deliver error messages ; 
# but they almost never make a determination to exit. That is left to the caller.


##################################################################################
##############################  LIST OF FUNCTIONS  ###############################

##################  VARIABLE ASSIGNMENTS and VALUE RETRIEVAL  #################### 
# get_global_variables   - File names/locations ; ZFS datasets 
# get_networking_variables - pf.conf ; wireguard ; endpoints 
# get_user_response  - Simple yes/no y/n checker
# get_jail_parameter - All JMAP entries, along with sanity checks
# get_info           - Info beyond that just for jails or jail parameters 
	# _CLIENTS        - All jails that <jail> serves a network connection
	# _ONJAILS        - All currently running jails
	# _USED_IPS       - All IPs used by currently running jails
	# _XID            - Window ID for the currently active X window
	# _XJAIL          - Jailname (or 'host') for the currently active X window 
	# _XNAME          - Name of the process for the current active X window
	# _XPID           - PID for the currently active X window

###########################  JAIL HANDLING / ACTIONS  ############################
# start_jail         - Performs checks before starting, creates log 
# stop_jail          - Performs checks before starting, creates log 
# restart_jail       - Self explanatory 
# remove_tap         - Removes tap interface from whichever jail it's in. 
# create_epairs      -

###############################  STATUS  CHECKS  #################################
# chk_isblank        - Posix workaround: Variable is [ -z <null> OR [[:blank:]]* ]
# chk_isrunning      - Searches jls -j for the jail 
# chk_valid_zfs      - Checks for presence of zfs dataset. Redirect to null. 

###############################  SANITY  CHECKS  #################################
# chk_valid_jail     - Makes sure the jail has JMAP entries and a ZFS dataset
# chk_valid_class    - JMAP parameter
# chk_valid_rootjail - Only certain jails qualify as rootjails
# chk_valid_gateway  - Checks that jail adhere's to gateway jail norms
# chk_valid_schg     - jail resource control 
# chk_valid_seclvl   - jail resource control 
# chk_valid_maxmem   - jail resource control
# chk_valid_cpuset   - jail resource control
# chk_valid_mtu      - networking option (typically unused) 
# chk_valid_ipv4     - Must adhere to CIDR notation
# chk_isqubsd_ipv4   - Implements quBSD conventions over internal IP addresses 
# chk_valid_template - Somewhat redundant with: chk_valid_jail  
# chk_trueorfalse    - When inputs must be either true or false

#######################  FUNCTIONS RELATED TO NETWORKING #########################
# define_ipv4_convention - Necessary for implementing quBSD IPv4 conventions
# discover_open_ipv4     - Finds an unused IP address from the internal network. 


##################################################################################
##################  VARIABLE ASSIGNMENTS and VALUE RETRIEVAL  #################### 
##################################################################################

# Source error messages for library functions 
. /usr/local/lib/quBSD/msg-quBSD.sh

get_global_variables() {
	# Global config files, mounts, and datasets needed by most scripts 

	# Define variables for files
	JCONF="/etc/jail.conf"
	QBDIR="/usr/local/etc/quBSD"
	QBCONF="${QBDIR}/quBSD.conf"
	JMAP="${QBDIR}/jailmap.conf"
	QBLOG="/var/log/quBSD.log"
	
	# Remove blanks at end of line, to prevent bad variable assignments. 
	sed -i '' -E 's/[[:blank:]]*$//' $QBCONF 
	sed -i '' -E 's/[[:blank:]]*$//' $JMAP  

	# Get datasets, mountpoints; and define files.
   QBROOT_ZFS=$(sed -nE "s:quBSD_root[[:blank:]]+::p" $QBCONF)
	JAILS_ZFS="${QBROOT_ZFS}/jails"
	ZUSR_ZFS=$(sed -En "s/^zusr_dataset[[:blank:]]+//p" $QBCONF)
	M_JAILS=$(zfs get -H mountpoint $JAILS_ZFS | awk '{print $3}')
	M_ZUSR=$(zfs get -H mountpoint $ZUSR_ZFS | awk '{print $3}')

	# Defaults for quBSD.sh functions  
	RTRN="return 1"
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
	 # -d: Function default is to get the <#default> from JMAP, whenever the
	     # retrieved <value> for <jail> <param> is NULL. [-d] prevents this.
	 # -e: echo <value> rather than setting the global variable
	     # Otherwise variable indirection will set <$_PARAM> with <_value> 
	 	 ## NOTE: If using [-e] for variable assignment in caller, best to [-q] 
		 ## quiet any error messages to prevent unpredictable behavior. 
	 # -q: quiet any error/alert messages. Otherwise error messages are shown.
	 # -s: skip checks and return 0. Otherwise, checks will be run.

	# Positional variables:
	 # $1: _param : The parameter to pull from JMAP
	     # _PARAM : <_param> name converted to UPPER. eval statement is used to  
	 	  # to save <value> to the ALL CAPS <param> name stored in: $_PARAM
	 # $2: _jail  : <jail> to reference in JMAP

	# Local options for this function  
	local _d ; local _e ; local _q ; local _s

	while getopts deqs opts ; do
		case $opts in
			d) _d="-d" ;;
			e) _e="-e" ;;
			q) _q="-q" ;; 
			s) _s="return 0" ;;
			*) get_msg "_1" ; return 1 ;;
		esac
	done

	shift $(( OPTIND - 1 ))

	# Positional variables
	local _param="$1"  
	local _PARAM=$(echo "$_param" | tr '[:lower:]' '[:upper:]')
	local _jail="$2"  
	local _value=''

	# Either jail or param weren't provided 
	[ -z "$_jail" ] && get_msg $_q "_0" "jail" && eval $_s $RTRN
	[ -z "$_param" ] && get_msg $_q "_0" "parameter" && eval $_s $RTRN 

	# Get the <_value> from JMAP.
	_value=$(sed -nE "s/^${_jail}[[:blank:]]+${_param}[[:blank:]]+//p" $JMAP)

	# Substitute <#default> values, so long as [-d] was not passed
	if [ -z "$_value" ] && [ -z "$_d" ] ; then
		_value=$(sed -nE "s/^#default[[:blank:]]+${_param}[[:blank:]]+//p" $JMAP)

		# Print warning message. 
		get_msg $_q "_cj17" "$_param" 
	fi

	# Either echo <value> , or assign global variable (as specified by caller).
	[ "$_e" ] && echo "$_value" || eval $_PARAM=\"$_value\"

	# If -s was provided, checks are skipped by this eval 
	eval $_s 

	#NOTE!: Not all functions are used, so they're not included later. 
	# Variable indirection for checks. Escape \" avoids word splitting
	eval "chk_valid_${_param}" $_q \"$_value\" \"$_jail\" \
		&& return 0 || return 1
}

get_info() {
	# Commonly required information that's not limited to jails or jail parameters 
	# Similar to: to get_jail_parameter(). But checks are not default.
	# $1: _info :

	# Local options for this function  
	local _e ; local _q 

	while getopts eq opts ; do
		case $opts in
			e) _e="-e" ;;
			q) _q="-q" ; _e='' ;; 
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
			_value=$(sed -nE "s/[[:blank:]]+gateway[[:blank:]]+${_jail}//p" $JMAP)
		;;
		_ONJAILS)
			# Prints a list of all jails that are currently running
			_value=$(jls | awk '{print $2}' | tail -n +2) 
		;;
		_TAP)
			# If <jail> has VM gateway, the tap interface is returned. Else return 1. 
			_gateway=$(get_jail_parameter -deqs gateway $_jail)
			_value=$(get_jail_parameter -deqs vif $_gateway)
		;;
		_USED_IPS)
			# Assemble list of ifconfig inet addresses for all running jails
			for _onjail in $(get_info -e _ONJAILS) ; do
				_intfs=$(jexec -l -U root "$_onjail" ifconfig -a inet | grep "inet")
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

	# Quiet option implies no further action. Return success 
	[ -n "$_q" ] && return 0

	# Echo option signalled 
	[ -n "$_e" ] && echo "$_value" && return 0
	
	# Assign global if no other option/branch was specified (default action). 
	eval ${_info}=\"${_value}\" 
	return 0
}


##################################################################################
###########################  JAIL HANDLING / ACTIONS  ############################
##################################################################################

start_jail() {
	# Starts jail. Performs sanity checks before starting. Logs results.
	# return 0 on success ; 1 on failure.

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parameter / checks 
	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_q "_0" "jail" && return 1

	# none is an invalid jailname. Never start it. Always return 0. 
	[ "$_jail" = "none" ] && return 0

	# Check to see if _jail is already running 
	if	! chk_isrunning "$_jail" ; then

		# If not, running, perform prelim checks 
		if chk_valid_jail $_q "$_jail" ; then

			# If checks were good, start jail, make a log of it 
			get_msg "_jf1" "$_jail" | tee -a $QBLOG
			jail -vc "$_jail"  >> $QBLOG 2>&1  ||  get_msg $_q "_jf2" "$_jail"

		else
			# Was invalid jail. Error msgs already handled inside chk_valid_jail 
			# NOTE: Temporary exception for VMs during dev/integration
			[ -n "$_isVM" ] && return 0 || return 1	
		fi
	fi

	return 0
}

stop_jail() {
	# If jail is running, remove it. Return 0 on success; return 1 if fail.	

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parameter / check 
	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_q "_0" "jail" && return 1

	# Check if jail is on
	if chk_isrunning "$_jail" ; then	

		# If on, try to remove the jail normally
		get_msg "_jf3" "$_jail" | tee -a $QBLOG
		if ! jail -vr "$_jail"  >> $QBLOG ; then
	
			# If normal removal failed, try forcible removal 
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
				get_msg $_q "_jf5" "$_jail" 
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
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parameters / check 
	local _jail="$1"
	local _hold="$2"
	[ -z "$_jail" ] && get_msg $_q "_0" "jail"  && return 1

	# If the jail was off, and the hold flag was given, don't start it.
	! chk_isrunning "$_jail" && [ "$_hold" = "hold" ] && return 0

	# Otherwise, cycle jail	
	stop_jail $_q "$_jail" && start_jail $_q "$_jail" 
}

remove_tap() {
	# If TAP is not already on host, find it and bring it to host
	# Return 1 on failure, otherwise return 0 (even if tap was already on host)

	# Assign name of tap
	[ -n "$1" ] && _tap="$1" || return 1
	
	# Check if it's already on host
	ifconfig "$_tap" > /dev/null 2>&1  &&  return 0
	
### NOTE: THIS NEEDS REVISED A BIT AND CLEANED UP
### Probably, add a line to pull the $_tap from jmap, and check if it's inside
### the specified jail, and remove it. If not, only *then* run the cycle below.
### All scripts which reference `&& $TAP down`, remove TAP down (done here).
	# First find all jails that are on
	for _jail in $(get_info -e _ONJAILS) ; do
		if jexec -l -U root $_jail ifconfig -l | grep -Eqs "$_tap" ; then
			ifconfig $_tap -vnet $_jail
			ifconfig $_tap down
		fi
	done

	# Bring tap down for host/network safety 
	ifconfig $_tap down 
}

connect_client_gateway() {
	# Implements the client/gateway connection as specified in JMAP 
	# GLOBAL VARIABLES must have been assigned already: $GATEWAY ; $IPV4 ; $MTU 

	# Local options for this function  
	local _e ; local _ipv4 

	while getopts ei: opts ; do
		case $opts in
			e) _e="true" ;;
			i) _ipv4="${OPTARG}" ;;
			*) get_msg "_1" ; return 1 ;;
		esac
	done

	shift $(( OPTIND - 1 ))

	# Positional variables
	local _client="$1"
	local _gateway="$2"

	_gateway="${_gateway:=$GATEWAY}"
	_ipv4="${_ipv4:=$IPV4}"
	_mtu="${MTU:=$(get_jail_parameter -es mtu '#default')}"
	
	# Create virtual interface. Gateway <_intf> can always be sent 
	local _intf=$(ifconfig epair create)
	ifconfig "$_intf" vnet $_gateway 

	# If connecting two jails, send the epair, and assign a command modifier. 
	if ! [ "$_client" = "host" ] ; then 
		ifconfig "${_intf%?}b" vnet $_client
		local _cmdmod='jexec -l -U root $_client'
	fi

	# If there is no IP, skip the assignment	
	if ! [ "$_ipv4" = "none" ] ; then
		# Assign the gateway IP 
		jexec -l -U root "$_gateway" \
				ifconfig "$_intf" inet ${_ipv4%.*/*}.1/${_ipv4#*/} mtu $_mtu up

		# Assign the client IP and default route
		eval "$_cmdmod" ifconfig ${_intf%?}b inet ${_ipv4} mtu $_mtu up
		eval "$_cmdmod" route add default "${_ipv4%.*/*}.1" > /dev/null 2>&1
	fi
	
	# Echo option. Return epair-b ; it's the external interface for the jail. 
	[ -z "$_e" ] && VIF="${_intf%?}b" || echo "${_intf%?}b"
	return 0
}


##################################################################################
################################  STATUS  CHECKS  ################################
##################################################################################

chk_isblank() {
	# Personally I think it's posix dumb that there are only VERBOSE ways of 
	# asking: Is this variable -z or only [[:blanks:]]*. Are you really going
	# to be testing blank variables for the number of spaces/tabs they contain?

	[ "$1" = "${1#*[![:space:]]}" ] && return 0  ||  return 1
}

chk_isrunning() {
	# Return 0 if jail is running; return 1 if not. 

	# Check if jail is running. 
	jls -j "$1" > /dev/null 2>&1  && return 0  ||  return 1 
}

chk_valid_zfs() {
	# Verifies the existence of a zfs dataset, returns 0, or 1 on failure
	# zfs provides no quiet option, and > null redirect takes up real-estate

	# Perform check
	zfs list $1 >> /dev/null 2>&1  &&  return 0  ||  return 1
}



##################################################################################
################################  SANITY  CHECKS  ################################
##################################################################################

chk_valid_jail() {
	# Checks that jail has JCONF, JMAP, and corresponding ZFS dataset 
	# Return 0 for passed all checks, return 1 for any failure

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters and function specific variables. 
	local _value="$1"  
	local _class ; local _rootjail ; local _template ; local _class_of_temp

	# Fail if no jail specified
	[ -z "$_value" ] && get_msg $_q "_0" "jail" && return 1

	# Must have class in JMAP. Used later to find the correct zfs dataset 
	_class=$(sed -nE "s/^${_value}[[:blank:]]+class[[:blank:]]+//p" $JMAP)

	case $_class in 
		VM) 
			# NOTE: This is just a placeholder for VM logic divergence	
			# Integration of commands between jail/VM may be tricky later on.
			_isVM="true" && return 1
		;;	
		"")
			# Empty, no class exists in JMAP
			get_msg $_q "_cj1" "$_value" "class" && return 1 
		;;
		rootjail) 
			# Rootjails require a dataset in zroot 
			! chk_valid_zfs ${JAILS_ZFS}/${_value} \
					&& get_msg $_q "_cj4" "$_value" "$JAILS_ZFS" && return 1
		;;
		appjail)
			# Appjails require a dataset at quBSD/zusr
			! chk_valid_zfs ${ZUSR_ZFS}/${_value} \
					&& get_msg $_q "_cj4" "$_value" "$ZUSR_ZFS" && return 1
		;;
		dispjail)

			# Verify the dataset of the template for dispjail
			_template=$(sed -nE \
					"s/^${_value}[[:blank:]]+template[[:blank:]]+//p" $JMAP)

			# First ensure that it's not blank			
			[ -z "$_template" ] && get_msg $_q "_cj5" "$_value" && return 1

			_class_of_temp=$(sed -nE \
				"s/^${_template}[[:blank:]]+class[[:blank:]]+//p" $JMAP)

			# Dispjails can only reference appjails.
			! [ "$_class_of_temp" = "appjail" ] \
					&& get_msg $_q "_cj5_1" "$_value" "$_template" && return 1

			# Ensure that the template being referenced is valid
			! chk_valid_jail $_q "$_template" \
					&& get_msg $_q "_cj6" "$_value" "$_template" && return 1
		;;
			# Any other class is invalid
		*) get_msg $_q "_cj2" "$_class" "class"  && return 1
		;;
	esac

	# Must have a designated rootjail in JMAP
	! grep -Eqs "^${_value}[[:blank:]]+rootjail[[:blank:]]+" $JMAP \
			&& get_msg $_q "_cj1" "$_value" "rootjail" && return 1

	# Must have an entry in JCONF
	! grep -Eqs "^${_value}[[:blank:]]*\{" $JCONF \
			&& get_msg $_q "_cj3" && return 1

	return 0
}

chk_valid_class() {
	# Return 0 if proposed class is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "jail" && return 1 

	# Valid inputs are: appjail | rootjail | dispjail 
	case $_value in
		appjail|dispjail|rootjail) return 0 ;;
		*) get_msg $_q "_cj2" "$_value" "class" && return 1 ;;
	esac
}

chk_valid_rootjail() {
	# Return 0 if proposed rootjail is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeter / check
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "class" && return 1

	# Must be designated as a rootjail in jailmap.con 
	_rootj=$(sed -nE "s/${_value}[[:blank:]]+class[[:blank:]]+//p" $JMAP) 
	! [ "$_rootj" = "rootjail" ] && get_msg $_q "_cj16" "$_value" && return 1

	# Must have an entry in JCONF 
	! grep -Eqs "^${_value}[[:blank:]]*\{" $JCONF \
			&& get_msg $_q "_cj3" && return 1
	
	# Rootjails require a dataset at zroot/quBSD/jails 
	! chk_valid_zfs ${JAILS_ZFS}/${_value} \
			&& get_msg $_q "_cj4" "$_value" "$JAILS_ZFS" && return 1

	return 0
}

chk_valid_gateway() {
	# Checks against the quBSD conventions.
	# Return 0 if proposed gateway is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. 
	local _value="$1"  
	local _jail="$2"  

	# Tests will depend on the class of the gateway. VMs get special handling
	_class_gw=$(sed -nE "s/^${_value}[[:blank:]]+class[[:blank:]]+//p" $JMAP)

	# Split log for checking a valid VM vs a valid jail 
	if [ "$_class_gw" = "VM" ] ; then 
		### NOTE: Future expansion will include a check for valid VM right here	
		# chk_valid_vm "$_value"
		return 0

	# The case where net-firewall was not assigned a VM as a gateway. 
	elif [ "$_jail" = "net-firewall" ] ; then 

		if [ "$_value" = "none" ] ; then 
			# net-firewall should always have a gatway 
			get_msg "_cj7_2" 
		else	
			# Alert to the fact that net-firewall doesn't have a VM gateway
			get_msg "_cj7_3"
		fi

	else
		# `none' is valid for any other jail 
		[ "$_value" = "none" ] && return 0 

		# Check that gateway is a valid jail. 
 		chk_valid_jail $_q "$_value" || return 1

		# Checks that gateway starts with `net-'
		case $_value in
			net-*) return 0 ;;
			  	 *) get_msg $_q "_cj8" "$_value" "$_jail"  ;  return 1 ;;
		esac
	fi
}

chk_valid_schg() {
	# Return 0 if proposed schg is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeter / check
	local _value="$1"  
	[ -z "$_value" ] && get_msg $_q "_0" "schg" && return 1 

	# None is always a valid schg
	[ "$_value" = "none" ] && return 0 

	# Valid inputs are: none | sys | all
	case $_value in
		none|sys|all) return 0 ;;
		*) get_msg $_q "_cj2" "$_value" "schg"  ;  return 1
	esac
}

chk_valid_seclvl() {
	# Return 0 if proposed seclvl is valid ; return 1 if invalid

	# NOTE: Rare case where [-q] is received as positional, not getopts. 
	# '-1' is a valid seclvl ; which getopts interprets as an option.
	local _q="$1"
	[ "$_q" = '-q' ] && _value="$2" || _value="$_q"
	[ -z "$_value" ] && get_msg $_q "_0" "seclvl" && return 1

	# None is always a valid seclvl 
	[ "$_value" = "none" ] && return 0

	# Security defines levels from lowest = -1 to highest = 3
	[ "$_value" -lt -1 ] && get_msg $_q "_cj2" "$_value" "seclvl" && return 1
	[ "$_value" -gt 3 ]  && get_msg $_q "_cj2" "$_value" "seclvl" && return 1

	return 0
}

chk_valid_maxmem() {
	# Return 0 if proposed maxmem is valid ; return 1 if invalid
	# IMPROVEMENT IDEA - check that proposal isn't greater than system memory

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeter / check
	local _value="$1"  
	[ -z "$_value" ] && get_msg $_q "_0" "maxmem" && return 1

	# None is always a valid maxmem
	[ "$_value" = "none" ] && return 0
	
	# Per man 8 rctl, user can assign units: G|g|M|m|K|k
   ! echo "$_value" | grep -Eqs "^[[:digit:]]+(G|g|M|m|K|k)\$" \
			&& get_msg $_q "_cj2" "$_value" "maxmem" && return 1

	return 0
}

chk_valid_cpuset() {
	# Return 0 if proposed cpuset is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters / check.
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "cpuset" && return 1

	# None is always a valid cpuset 
	[ "$_value" = "none" ] && return 0
	
	# Get the list of CPUs on the system, and edit for searching	
	_validcpuset=$(cpuset -g | sed "s/pid -1 mask: //" | sed "s/pid -1 domain.*//")

	# Test for negative numbers and dashes in the wrong place
	echo "$_value" | grep -Eq "(,-|,[[:blank:]]*-|^[^[:digit:]])" \
			&& get_msg $_q "_cj2" "$_value" "cpuset" && return 1

	# Remove `-' and `,' to check that all numbers are valid CPU numbers
	_cpuset_mod=$(echo $_value | sed -E "s/(,|-)/ /g")

	for _cpu in $_cpuset_mod ; do
		# Every number is followed by a comma except the last one
		! echo $_validcpuset | grep -Eq "${_cpu},|${_cpu}\$" \
			&& get_msg $_q "_cj2" "$_value" "cpuset" && return 1
	done

	return 0
}

chk_valid_mtu() {
	# Return 0 if proposed mtu is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters / check.
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "mtu" && return 1

	# Just push a warning, but don't error for MTU 
	[ "$_value" -lt 1200 ] && get_msg $_q "_cj18" "mtu" 
	[ "$_value" -gt 1600 ] && get_msg $_q "_cj18" "mtu" 

	return 0
}

chk_valid_ipv4() {
	# Tests for validity of IPv4 CIDR notation.
	# return 0 if valid (or none), return 1 if not 
	# Also assigns global variable: _valid_IPv4="true"

	# Variables below are assigned as global variables rather than 
	# local, because they're required for performing other checks. 
	#   $_a0  $_a1  $_a2  $_a3  $_a4  

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeter / check.
	local _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "IPv4" && return 1

	# Temporary variables used for checking ipv4 CIDR
	local _b1 ; local _b2 ; local _b3

	# None is always considered valid.
	[ "$_value" = "none" ] && return 0 

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
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. _
	local _value="$1"
	local _jail="$2"

	# $_a0 - $_a4 vars are needed later. Check that they're all here, or get them. 
	echo "${_a0}#${_a1}#${_a2}#${_a3}#${_a4}" | grep -q "##" \
		&& chk_valid_ipv4 -q "$_value"

	# Assigns global variables that will be used here for checks.
	define_ipv4_convention

	# No value specified 
	[ -z "$_value" ] && get_msg $_q "_0" "IPv4" 

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
		none_*) 
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

	_gateway=$(sed -nE "s/^${_jail}[[:blank:]]+gateway[[:blank:]]+//p" $JMAP)
	
	# Assigning IP to jail that has no gateway 	
	[ "$_gateway" = "none" ] && get_msg $_q "_cj14" "$_value" "$_jail" \
		&& return 1
	
	# Catchall. return 0 if no other checks caused a return 1
	return 0
}

chk_valid_vif() {
	# Return 0 if vif is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. 
	local _value="$1"
	local _jail="$2"

	# Checks that it's a tap interface. Technically, failes after tap99
	case $_value in
		tap[[:digit:]]) 
			return 0 ;;	
		tap[[:digit:]][[:digit:]]) 
			return 0 ;;	
		*) get_msg $_q "_cj7" "$_value" "$_jail" 
			return 1 ;;
	esac
}

chk_valid_template() {
	# Return 0 if proposed template is valid ; return 1 if invalid
	# Exists mostly so that the get_jail_parameters() function works seamlessly

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. 
	local _value="$1"
	local _jail="$2"  

	! chk_valid_jail "$1" "$2" \
			&& get_msg $_q "_cj6" "$_value" "$_template" && return 1

	return 0
}

chk_truefalse() {
	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters / check.
	local _value="$1"
	local _param="$2"
	[ -z "$_value" ] && get_msg $_q "_0" "$_param" && return 1

	# Must be either true or false.
	! [ "$_value" = "true" ] && ! [ "$_value" = "false" ] \
			&& get_msg $_q "_cj19" "$_value" "$_param" && return 1
	
	return 0
}

chk_valid_autostart() {
	# Mostly for standardization/completeness with get_jail_parameter() func.
	chk_truefalse "$1" "$2" "$3"
}

chk_valid_no_destroy() {
	# Mostly for standardization/completeness with get_jail_parameter() func.
	chk_truefalse "$1" "$2" "$3"
}

##################################################################################
#######################  FUNCTIONS RELATED TO NETWORKING #########################
##################################################################################

define_ipv4_convention() {
	# Defines the quBSD internal IP assignment convention.
	# Variables: $ip0.$ip1.$ip2.$ip3/subnet ; are global. They're required 
	# for functions:  discover_open_ipv4()  ;  chk_isqubsd_ipv4() 

	# Returns 0 for any normal IP assignment, returns 1 if 
	# operating on net-firewall (which needs special handling).

	# Global variable indirection is used with `_cycle', in discover_open_ipv4() 
	_cycle=1

	# Combo of function caller and $JAIL determine which IP form to use
	case "$0" in
		*qb-connect)
				# Temporary, adhoc connections have the form: 10.99.x.2/30 
				_ip0=10 ; _ip1=99 ; _ip2="_cycle" ; _ip3=2 ; _subnet=30 ;;

		*qb-usbvm)
				# usbvm connects to usbjail with the address: 10.77.x.2/30 
				_ip0=10 ; _ip1=77 ; _ip2="_cycle" ; _ip3=2 ; _subnet=30 ;;

		*) case $JAIL in
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
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	local _jail="$1"  
	local _temp_ip

	# net-firewall connects to external network. Assign DHCP, and skip checks. 
	[ "$_jail" = "net-firewall" ] && echo "DHCP" && return 0

	# Assigns values for each IP position, and initializes $_cycle
	define_ipv4_convention
	
	# Increment _cycle to find an open IP. 
	while [ $_cycle -le 255 ] ; do

		# $_ip2 uses variable indirection, which subsitutes "cycle"
		eval "_temp_ip=${_ip0}.${_ip1}.\${$_ip2}.${_ip3}"

		# Compare against JMAP, and the IPs already in use
		if grep -qs "$_temp_ip" $JMAP	\
					|| get_info -e _USED_IPS | grep -qs "$_temp_ip" ; then

			# Increment for next cycle
			_cycle=$(( _cycle + 1 ))

			# Failure to find IP in the quBSD conventional range 
			if [ $_cycle -gt 255 ] ; then 
				eval "_pass_var=${_ip0}.${_ip1}.x.${_ip3}"
				get_msg $_q "_jf7" "$_jail" "$_pass_var"
				return 1
			fi
		else
			# Echo the value of the discovered IP and return 0 
			echo "${_temp_ip}/${_subnet}" && return 0
		fi
	done
}


##################################################################################
#######################  FUNCTIONS RELATED TO VM HANDLING ########################
##################################################################################

chk_isrunning_vm() {
	# Return 0 if bhyve VM is a running process; return 1 if not.	
	
	local _VM
	[ -n "$1" ] && _VM="$1" || return 1 

	pgrep -qf "bhyve: $_VM"  >>  /dev/null 2>&1  ||  return 1
}

poweroff_vm() {
	# Tries to gracefully shutdown VM with SIGTERM, as per man bhyve
	# Monitor process for 90 seconds. return 0 if removed, 1 if timeout 
	# Pass option "quiet" if no stdout is desired

	local _vm
	local _count		
	local _quiet

	local _vm
	[ -n "$1" ] && _vm="$1" || get_msg "$_q _0 $2" 
	local _if_err
	# Action to take on failure. Default is return 1 to caller function
	[ -z "$2" ] && _if_err="return 1" || _if_err="return 1"

	# Error if $_jail provided is empty
	[ -z "$_jail" ] && 

	[ -n "$1" ] && _VM="$1" || return 1 
	[ "$2" = "quiet" ] && _quiet="true" 
	
	# pkill default is SIGTERM (-15) 
	pkill -f "bhyve: $_VM"  && get_msg_qb_vm "_3"

	# Monitor for VM shutdown, via process disappearance
	_count=1
	while chk_isrunning_vm "$_VM" ; do
		
		# Prints	a period every second
		[ -z "$quiet" ] && sleep 1 && get_msg_qb_vm "_4"

		_count=$(( _count + 1 ))
		[ "$_count" -gt 30 ] && get_msg_qb_vm "_5" "exit_1"
	done

}


