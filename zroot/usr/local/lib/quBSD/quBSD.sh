#!/bin/sh

##########################  LIST OF FUNCTIONS  ###########################

# get_global_variables 
# get_user_response 
# stop_jail
# restart_jail
# define_ipv4_convention 
# get_used_ips 
# discover_open_ipv4
# check_isvalid_ipv4
# check_isqubsd_ipv4
# check_isvalid_root
# check_isvalid_template
# check_isvalid_tunnel
# check_isvalid_schg
# check_isvalid_seclvl
# check_isvalid_maxmem
# check_isvalid_cpuset

##########################################################################

# Source error messages for library functions
. /usr/local/lib/quBSD/msg-quBSD.sh

get_global_variables() {
	# Global config files, mounts, and datasets needed by most scripts 

	# Define variables for files
	QBDIR="/usr/local/etc/quBSD"
	QBCONF="${QBDIR}/quBSD.conf"
	JMAP="${QBDIR}/jailmap.conf"
	JCONF="/etc/jail.conf"
	QLOG="/var/log/quBSD.log"
	sed -i '' -e 's/[[:blank:]]*$//' $JMAP  #remove blanks at end of lines

	# Get datasets, mountpoints; and define files.
	ZUSR_ZFS=$(sed -En "s/^zusr_dataset[[:blank:]]+//p" $QBCONF)
	M_ZUSR=$(zfs get -H mountpoint $ZUSR_ZFS | awk '{print $3}')
	JAILS_ZFS=$(sed -En "s/^jails_dataset[[:blank:]]+//p" $QBCONF)
	M_JAILS=$(zfs get -H mountpoint $JAILS_ZFS | awk '{print $3}')
} 

get_user_response() {
	# Exits successfully if response is y or yes 
	# Assigns _response=true|false ; available to caller function 
	# Optional $1 input - `severe' ; which requires a user typed `yes'

	read _response
	
	# If flagged with positional parameter `severe' require full `yes' 
	if [ "$1" == "severe" ] ; then
		[ "$_response" == "yes" -o "$_response" == "YES" ] \
												&& return 0 || return 1
	fi
	
	case "$_response" in 
		y|Y|yes|YES) 
			_response=true
			return 0	;;

		# Only return success on positive response. All else fail
		*)	
			_response=false
			return 1 ;;						
	esac
}

check_isrunning_jail() {
	# Return 0 if jail is running; return 1 if not. 

	# Input can be positional variable: $1 ; else use global $JAIL
	local _jail
	[ -n "$1" ] && _jail="$1" || _jail="$JAIL"

	# Check if jail is running 
	jls -j "$_jail" > /dev/null 2>&1 && return 0 || return 1 
}

check_isvalid_jail() {
	# Checks that jail has JCONF, JMAP, and corresponding ZFS dataset 
	
	# Caller may pass positional: $2 , to dictate action on failure.
		# Default, or if no $2 provided, will return 1 silently.
		# If caller desires msg and exit on failure; pass $2 = "exit_1"
	
	local _class
	local _rootjail
	local _template

	# Input can be positional variable: $1 ; else use global $JAIL
	local _jail
	[ -n "$1" ] && _jail="$1" || _jail="$JAIL"

	# Action to take on failure. Default is return 1 to caller function
	local _action
	[ "$2" == "exit_1" ] && _action="get_msg_qubsd" || _action="return 1"

	# Must have class in JMAP. Used later to find the correct zfs dataset 
	_class=$(sed -nE "s/^${_jail}[[:blank:]]+class[[:blank:]]+//p" $JMAP)
			[ "$_class" ] || eval "$_action" "_1" "$2"
	
	# Must also have a designated rootjail in JMAP
	grep -Eqs "^${_jail}[[:blank:]]+rootjail[[:blank:]]+" $JMAP \
			|| eval "$_action" "_2" "$2"

	# Jail must also have an entry in JCONF
	grep -Eqs "^${_jail}[[:blank:]]*\{" $JCONF \
			|| eval "$_action" "_3" "$2"

	# Verify existence of ZFS dataset
	case $_class in
		rootjail) 
			# Rootjails require a dataset at zroot/quBSD/jails 
			zfs list ${JAILS_ZFS}/${_jail} > /dev/null 2>&1 \
				|| eval "$_action" "_4" "$2"
		;;
		appjail)
			# Appjails require a dataset at quBSD/zusr
			zfs list ${ZUSR_ZFS}/${_jail} > /dev/null 2>&1 \
				|| eval "$_action" "_5" "$2"
		;;
		dispjail)

			# Verify the dataset of the template for dispjail
			_template=$(sed -nE "s/^${_jail}[[:blank:]]+template[[:blank:]]+//p" $JMAP)
				[ "$_template" ] || eval "$_action" "_6" "$2"
			
			zfs list ${ZUSR_ZFS}/${_template} > /dev/null 2>&1 \
				|| eval "$_action" "_7" "$2"
		;;
			# Any other class is invalid
		*) eval "$_action" "_8" "$2" 
		;;
	esac
}

start_jail() {
	# Performs required checks on a jail, starts if able, returns 0.

	# Caller may pass positional: $2 , to dictate action on failure.
		# Default, or if no $2 provided, will return 1 silently.
		# If caller desires msg and exit on failure; pass $2 = "exit_1"

	local _jail
	_jail="$1"

	# Check to see if _jail is already running 
	if	check_isrunning_jail "$_jail" ; then

		# No need to error if jail is already running 
		return 0

	else		
		# Start jail if prelim checks pass, and log the startup 
		if check_isvalid_jail "$_jail" "$2" ; then
			echo "Starting < $_jail >"
			jail -c "$_jail"  >> $QLOG  &&  return 0
		fi
	fi
}

stop_jail() {
	# If jail is running, remove it. 

	# Caller may pass positional: $2 , to dictate action on failure.
		# Default, or if no $2 provided, will return 1 silently.
		# If caller desires msg and exit on failure; pass $2 = "exit_1"

	local _jail
	[ -n "$1" ] && _jail="$1" || _jail="$JAIL"

	# Check if jail is on, if so remove it 
	if check_isrunning_jail "$_jail" "$2" ; then	

		# Try to remove jail normally, otherwise manual removal
		if ! jail -r "$_jail"  >> $QLOG ; then
			
			# Forcibly remove jail
			jail -R "$_jail"  >> $QLOG
			get_msg_qubsd "_9" "$2"
			
			# Run exec.poststop, to clean up forcibly stopped jails 
			sh ${QBDIR}/exec.poststop "$_jail"  >> $QLOG 
		fi
	fi
}


restart_jail() {
	# Restarts jail
	local _jail
	_jail="$1"

	if stop_jail "$_jail" "$2"   >> $QLOG ; then 
		start_jail "$_jail" "$2"  >> $QLOG
	fi
}

msg_popup() {
	_cmd="$1"
	xterm -e csh -c "i3-msg -q floating enable, move position center; eval $_cmd"
}

define_ipv4_convention() {
	# Defines the quBSD internal IP assignment convention.
	# Variables: $ip0.$ip1.$ip2.$ip3/subnet ; are global, required 
	# for functions:  discover_open_ipv4() and check_isqubsd_ipv4() 

	# Returns 0 for any normal IP assignment, returns 1 if 
	# operating on net-firewall (which needs special handling).

	# Variable indirection is used with `_cycle', in discover_open_ipv4() 
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

get_used_ips() {
	# Gathers a list of all IP addresses in use by running jails.
	# Assigns variable: $_used_ips for use in main script. This variable
	# is unfiltered, containing superflous info from `ifconfig` command.
	
	# Find jails that are running
	_onjails=$(jls | awk '{print $2}' | tail -n +2)

	# Assemble list of ifconfig inet addresses for all running jails
	for _jail in $_onjails ; do
		_intfs=$(jexec -l -U root $_jail ifconfig -a inet | grep "inet")
		_USED_IPS=$(printf "%b" "$_USED_IPS" "\n" "$_intfs")
	done
}

discover_open_ipv4() {	
	# Finds an IP address unused by any running jails, or in jailmap.conf 
	# Echo open IP on success; Returns 1 if failure to find an available IP

	# Input can be positional variable: $1 ; else use global $_USED_IPS
	local _used_ips 
	[ -n "$1" ] && _used_ips="$1" || _used_ips="$_USED_IPS"

	# Increment _cycle to find an open IP
	while [ $_cycle -le 255 ] ; do
		# $_ip2 uses variable indirection, which subsitutes "cycle"
		eval "_temp_ip=${_ip0}.${_ip1}.\${$_ip2}.${_ip3}"

		# Compare against JMAP, and the IPs already in use
		if grep -qs "$_temp_ip" $JMAP	\
					|| [ $(echo "$_used_ips" | grep -qs "$_temp_ip") ] ; then

			# Increment, until 255, then return failure
			_cycle=$(( _cycle + 1 ))
			if [ $_cycle -gt 254 ] ; then 
				eval "_ip_range=${_ip0}.${_ip1}.x.${_ip3}"
				return 1
			fi

		else
			# Assign Global variable: $OPENIP , and break	
			echo "${_temp_ip}/${_subnet}"
			return 0
		fi
	done
}

check_isvalid_ipv4() {
	# Returns 1 if proposed IP address is not valid CIDR notation.
	# Returns 0 if proposed IP address is valid or `none'
	# Assigns the following variables ; available to caller funciton 
		# $_validIPv4=true 
		# $_a0  $_a1  $_a2  $_a3  $_a4 ; for use in check_isqubsd_ipv4()

	# Input can be positional variable: $1 ; else use global $IP0
	local _ip_addr
	[ -n "$1" ] && _ip_addr="$1" || _ip_addr="$IP0"
	
	local b1
	local b2
	local b3
	
	_validIPv4=''
	
	# Exit and return success if value is none
	[ "$_ip_addr" == "none" ]  && _validIPv4="true"  &&  return 0
	
	# Not as technically correct as a regex, but it's readable and functional 
	# IP represented by the form: a0.a1.a2.a3/a4 ; b-variables are transitory
	_a0=${_ip_addr%%.*.*.*/*}
	_a4=${_ip_addr##*.*.*.*/}
		b1=${_ip_addr#*.*}
		_a1=${b1%%.*.*/*}
			b2=${_ip_addr#*.*.*}
			_a2=${b2%%.*/*}
				b3=${_ip_addr%/*}
				_a3=${b3##*.*.*.}

	# Ensures that each number is in the proper range
	if   [ "$_a0" -ge 0 -a "$_a0" -le 255 -a "$_a1" -ge 0 -a "$_a1" -le 255 \
		 -a "$_a2" -ge 0 -a "$_a2" -le 255 -a "$_a3" -ge 0 -a "$_a3" -le 255 \
		 -a "$_a4" -ge 0 -a "$_a4" -le 32 ] >> /dev/null 2>&1

	then
		# Ensures that each number is a digit

		if echo "$_ip_addr" | grep -Eqs \
			"[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+/[[:digit:]]+"
		then
			_validIPv4="true"
			return 0
		else
			return 1
		fi
	else
		return 1
	fi
}

check_isqubsd_ipv4() {
	# Checks for IP overlaps and/or mismatch in quBSD convention. 
	# Assigns the following, available to caller function:
		# $_isoverlap=true
		# $_ismismatch=true

	# Input can be positional variable: $1 ; else use global $IP0
	local _ip_addr
	[ -n "$1" ] && _ip_addr="$1" || _ip_addr="$IP0"

	# Input can be positional variable: $1 ; else use global $_USED_IPS
	local _used_ips 
	[ -n "$2" ] && _used_ips="$2" || _used_ips="$_USED_IPS"

	local _is_overlap
	_is_overlap=''
	
	# IP addr of "none" is never a mismatch or overlap	
	[ "$_ip_addr" == "none" ]  &&  return 0 

	# Compare against JMAP, and _USED_IPS 
	grep -qs "$_ip_addr" $JMAP	\
			|| [ $(echo "$_used_ips" | grep -qs "${_ip_addr%/*}") ] \
																&& _isoverlap="true"

	# Note that $a2 and $ip2 are missing, because that is the _cycle 
	# Any change to quBSD naming convention will require manual change.
	[ "$_a0.$_a1.$_a3/$_a4" == "$_ip0.$_ip1.$_ip3/$_subnet" ] \
																|| _ismismatch="true"
}

check_isvalid_root() {
	# Return 0 if proposed rootjail is valid ; return 1 if invalid
	# Assigns _validRoot=true|false ; available to caller function 

	local _rootjail
	_rootjail="$1"

	# Checks that the jail has a zroot dataset, and in jailmap.conf as rootjail
	if zfs list ${JAILS_ZFS}/${_rootjail} > /dev/null 2>&1 \
					&& grep -Eqs "^${_rootjail}[[:blank:]]+rootjail" $JMAP ; then 
		_validRoot=true
		return 0
	else
		_validRoot=false
		return 1
	fi
}

check_isvalid_template() {
	# Return 0 if proposed template is valid ; return 1 if invalid
	# Assigns _validTemplate=true|false ; available to caller function 

	local template
	_template="$1"

	# Checks that the jail has a zusr dataset, and in jailmap.conf as appjail
	if zfs list ${ZUSR_ZFS}/${_template} > /dev/null 2>&1 \
		&& grep -Eqs "^${_template}[[:blank:]]+class[[:blank:]]+appjail" $JMAP ; then 

		_validTemplate=true
		return 0
	else
		_validTemplate=false
		return 1
	fi
}

check_isvalid_tunnel() {
	# Return 0 if proposed tunnel is valid ; return 1 if invalid
	# Assigns _validTemplate=none|true|alert|false ; available to caller func 

	# Input can be positional variable: $1 ; else use global $TUNNEL
	local _tunnel
	[ -n "$1" ] && _tunnel="$1" || _tunnel="$TUNNEL"

	# Input can be positional variable: $2 ; else use global $JAIL
	local _jail
	[ -n "$2" ] && _jail="$2" || _jail="$JAIL"

	# net-firewall has special requirements for tunnel. Must be tap interface
	if [ "$_jail" == "net-firewall" ] ; then
			# NOTE: This isn't robust. It fails after tap0 to tap9
		if [ -z "${_tunnel##tap[[:digit:]]}" ]  ; then
			return 0
		else
			_validTunnel="firewall" ; return 1
		fi
	fi
	
	# `none' is a valid tunnel for all other jails
	if	[ "$_tunnel" == "none" ]  
		then _validTunnel="none" ; return 0

	# Jail is missing zusr dataset
	elif ! zfs list ${ZUSR_ZFS}/${_tunnel} > /dev/null 2>&1
		then _validTunnel="zusr" ; return 1

	# Jail is missing JMAP entries
	elif ! grep -Eqs "^${_tunnel}[[:blank:]]+class[[:blank:]]+appjail" $JMAP 
		then _validTunnel="jmap" ; return 1

	# Checks that tunnel starts with `net-'
	elif [ -n "${_tunnel##net-*}" ] 
		then _validTunnel="net" ; return 0
	else
		return 0
	fi
}

check_isvalid_schg() {
	# Return 0 if proposed schg is valid ; return 1 if invalid
	local _schg
	_schg="$1"
	
	# Valid inputs are: none | sys | all
	[ "$_schg" = "none" -o "$_schg" = "sys" -o "$_schg" = "all" ] \
															&& return 0 || return 1 
}

check_isvalid_seclvl() {
	# Return 0 if proposed schg is valid ; return 1 if invalid
	local _seclvl
	_seclvl="$1"

	# Security defines levels from lowest == -1 to highest == 3
	[ "$_seclvl" -ge -1 -a "$_seclvl" -le 3 ] && return 0 || return 1
}

check_isvalid_maxmem() {
	# Return 0 if proposed schg is valid ; return 1 if invalid

	local _maxmem
	local g
	local G
	local m
	local M
	local k
	local K
	_maxmem="$1"

	[ -z ${_maxmem##none} ] && return 0
	
	# Per man 8 rctl, user can assign units: G|g|M|m|K|k
   echo "$_maxmem" | grep -Eqs "^[[:digit:]]+(G|g|M|m|K|k)\$" \
															&& return 0 || return 1
	# IMPROVEMENT IDEA - check that proposal isn't greater than system memory
}

check_isvalid_cpuset() {
	# Return 0 if proposed schg is valid ; return 1 if invalid
	local _cpuset
	_cpuset="$1"

	[ -z ${_cpuset##none} ] && return 0
	
	# Get the list of CPUs on the system, and edit for searching	
	_validcpuset=$(cpuset -g | sed "s/pid -1 mask: //" | sed "s/pid -1 domain.*//")
	_cpuset_mod=$(echo $_cpuset | sed -E "s/(,|-)/ /g")

	for _cpu in $_cpuset_mod ; do
		# Every number is followed by a comma except the last one
		echo $_validcpuset | grep -Eq "${_cpu},|${_cpu}\$" || return 1
	done
}






