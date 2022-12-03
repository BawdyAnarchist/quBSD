#!/bin/sh

##########################  LIST OF FUNCTIONS  ###########################


##################################################################################
########################  VARIABLES ASSIGNMENT FUNCTIONS  ########################
##################################################################################

# Source error messages for library functions (jails) 
. /usr/local/lib/quBSD/msg-quBSD-j.sh

# Source error messages for library functions (VMs) 
. /usr/local/lib/quBSD/msg-quBSD-vm.sh

# Just a placeholder to reduce number of operations for [-q] 
empty() {
}

get_global_variables() {
	# Global config files, mounts, and datasets needed by most scripts 

	# Define variables for files
	JCONF="/etc/jail.conf"
	QBDIR="/usr/local/etc/quBSD"
	QBCONF="${QBDIR}/quBSD.conf"
	JMAP="${QBDIR}/jailmap.conf"
	QBLOG="/var/log/quBSD.log"
	
	# Remove blanks at end of line, to prevent bad variable assignments. 
	sed -i '' -e 's/[[:blank:]]*$//' $QBCONF 
	sed -i '' -e 's/[[:blank:]]*$//' $JMAP  

	# Get datasets, mountpoints; and define files.
   QBROOT_ZFS=$(sed -nE "s:quBSD_root[[:blank:]]+::p" $QBCONF)
	JAILS_ZFS="${QBROOT_ZFS}/jails"
	ZUSR_ZFS=$(sed -En "s/^zusr_dataset[[:blank:]]+//p" $QBCONF)
	M_JAILS=$(zfs get -H mountpoint $JAILS_ZFS | awk '{print $3}')
	M_ZUSR=$(zfs get -H mountpoint $ZUSR_ZFS | awk '{print $3}')

	# Defaults for quBSD.sh functions  
	RTRN="return 1"
	MESG="get_msg"
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
	# Assigns _response=true|false ; available to caller function 
	# Optional $1 input - `severe' ; which requires a user typed `yes'

	read _response
	
	# If flagged with positional parameter `severe' require full `yes' 
	if [ "$1" == "severe" ] ; then 
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
	# Get the value of <jail> <param> from JMAP. 
	# Variable indirection generalizes this function for all JMAP <params> 
	# OPTIONS
		# -d: If <_value> was null, do NOT the backup <#default> value in JMAP.
		#     Otherwise this function will substitute the <#default> in JMAP.
		# -e: echo <_value> rather than setting the global variable
		#	   Otherwise variable indirection will set <$_PARAM> with <_value> 
			## NOTE: If using [-e] for variable assignment in caller, should 
			## also k
		# -q: quiet any error/alert messages. Otherwise error messages are shown.
		# -s: skip checks and return 0. Otherwise, checks will be run.

	# Description of positional variables:
		# _param - The parameter to pull from JMAP
		# _PARAM - <_param> name converted to UPPER. Variable indirection: $_PARAM 
		#          is set to the <value> retreived from JMAP. 
		# _jail  - <jail> in JMAP

	# Process local options for this function  
	local _d ; local _e ; local _q ; local _s
	while getopts deqs opts ; do
		case $opts in
			d) _d="-d" ;;
			e) _e="-e" ;;
			q) _q="-q" ;; 
			s) _s="return 0" ;;
		esac
	done

	shift $(( OPTIND - 1 ))

	# Positional variables
	local _param ; _param="$1"  
	local _PARAM=$(echo "$_param" | tr '[:lower:]' '[:upper:]')
	local _jail ; _jail="$2"  

	# Either jail or param weren't provided 
	[ -z "$_jail" ] && get_msg $_q "_0" "jail" && eval $_s $RTRN
	[ -z "$_param" ] && get_msg $_q "_0" "parameter" && eval $_s $RTRN 

	# Get the <_value> from JMAP.
	_value=$(sed -nE "s/^${_jail}[[:blank:]]+${_param}[[:blank:]]+//p" $JMAP)

	# Substitute <#default> values, if specified 
	if [ -z "$_value" ] && [ -z "$_d" ] ; then
		_value=$(sed -nE "s/^#default[[:blank:]]+${_param}[[:blank:]]+//p" $JMAP)

		# Print warning message and return. Checks are skipped, assumes default
		get_msg $_q "_cj17" "$_param" 
	fi

	# Either echo the <value> , or assign global variable (as specified).
	[ "$_e" ] && echo "$_value" || eval $_PARAM="$_value"

	# Skip checks if indicated
	eval $_s 

	#NOTE!: Not all functions are used, so they're not included later. 
	# Variable indirection for checks. Escape \" avoids word splitting
	if eval "check_isvalid_${_param}" $_q \"$_value\" \"$_jail\" ; then
		# Return <_value> to caller and return
		return 0	
	else
		eval $_s $RTRN
	fi
}

##################################################################################
#####################  FUNCTIONS RELATED TO JAILS HANDLING #######################
##################################################################################

get_onjails(){
	# Prints a list of all jails that are currently running; or returns 1
	jls | awk '{print $2}' | tail -n +2 || return 1
}

restart_jail() {
	# Restarts jail. Passes postional parameters, so checks are not missed
	# Default behavior: If a jail is off, start it. 
	# Override default with $3="hold"

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional params and func variables. 
	local _jail ; _jail="$1"
	local _hold ; 	_hold="$2"

	# No jail specified. 
	[ -z "$_jail" ] && get_msg $_q "_0" "jail"  && return 1

	# If the jail was off, and the hold flag was given, don't start it.
	! check_isrunning_jail "$_jail" && [ "$_hold" == "hold" ] && return 0

	# Otherwise, cycle jail	
	stop_jail $_q "$_jail" && start_jail $_q "$_jail" 
}

start_jail() {
	# Performs required checks on a jail, starts if able, and returns 0.
	# Caller may pass positional: $2 , to dictate action on failure.
		# Default if no $2 provided, will return 1 silently.
	# _jf = jailfunction

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional params and func variables. 
	local _jail ; _jail="$1"

	# Check that JAIL was provided in the first place
	[ -z "$_jail" ] && get_msg $_q "_0" "jail" && return 1

	# none is an invalid jailname. Never start it. Always return 0. 
	[ "$_jail" == "none" ] && return 0

	# Check to see if _jail is already running 
	if	! check_isrunning_jail "$_jail" ; then

		# Run prelim checks on jail 
		if check_isvalid_jail $_q "$_jail" ; then
			
			# Checks were good, start jail, make a log of it 
			get_msg "_jf1" "$_jail" | tee -a $QBLOG
			jail -c "$_jail"  >> $QBLOG  ||  get_msg $_q "_jf2" "$_jail"

		fi
	else
		# Jail was already on.
		return 0
	fi
}

stop_jail() {
	# If jail is running, remove it. Return 0 on success; return 1 if fail.	
	# Unfortunately, due to the way mounts are handled during jail -r, the
	# command will exit 1, even the jail was removed successfully. 
	# Extra logic has to be embedded to handle this problem.

	# Caller may pass positional: $2 , to dictate action on failure.
		# Default, or if no $2 provided, will return 1 silently.

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional params and func variables. 
	local _jail ; _jail="$1"

	# Check that JAIL was provided in the first place
	[ -z "$_jail" ] && get_msg $_q "_0" "jail" && return 1

	# Check if jail is on, if so remove it 
	if check_isrunning_jail "$_jail" ; then	

		# TRY TO REMOVE JAIL NORMALLY 
		get_msg "_jf3" "$_jail" | tee -a $QBLOG
		jail -vr "$_jail"  >> $QBLOG 
		
		# Extra logic to check if jail removal was successful 
		if check_isrunning_jail "$_jail" ; then 		

			# FORCIBLY REMOVE JAIL  
			get_msg "_jf4" "$_jail" | tee -a $QBLOG
			jail -vR "$_jail"  >> $QBLOG 
			
			# Extra logic (same problem) to check jail removal success/fail 
			if check_isrunning_jail "$_jail" ; then 		

				# Print warning about failure to forcibly remove jail
				get_msg $_q "_jf5" "$_jail" 
			else
				# Run exec.poststop to clean up mounts, and print warning
				sh ${QBDIR}/exec.poststop "$_jail"
				get_msg "_jf6" "$_jail" | tee -a $QBLOG
			fi
		fi
	else
		# Jail was already off. Not regarded as an error.
		return 0
	fi
}


##################################################################################
#######################  CHECKS ON JAILS and PARAMETERS  #########################
##################################################################################

## NOTES ON HOW CHECKS ARE BUILT
## Each check should be called from the main function with positional parameters:
	# $1={value_of_the_thing_to_check}
   # $2={_if_err} - The literal command that you want to execute if failure
		# `eval` is applied to $_if_err, so the variable becomes the command.
		# Default action is `return 1` (fail with no error message).
		# For error message: $2="get_msg" is specified, which calls the
		# function:  get_msg() ; from  /usr/local/lib/quBSD/msg-quBSD.sh
		# get_msg also has positional parameters that should be specified. 
			# $1 uniquely identifies the msg to show from the case/in statement
         # $2 is an arbitrary "_passvar" which can be used in the message body.
				# This helps reduce total number of case/in elements in get_msg()
			# $3 Is an optional action to take after printing message. 
				# This should be largely unused, but user may specify:
					# exit_0, exit_1, return_0, return_1  
	  				# If not provided, default is return_1

check_isrunning_jail() {
	# Return 0 if jail is running; return 1 if not. 

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. 
	local _value; _value="$1"  

	# No jail specified. 
	[ -z "$_value" ] && get_msg $_q "_0" "jail" && return 1

	# Check if jail is running. No warning message returned if not.
	jls -j "$_value" > /dev/null 2>&1  || return 1 
}

check_isvalid_jail() {
	# Checks that jail has JCONF, JMAP, and corresponding ZFS dataset 
	# Return 0 if jail is running; return 1 if not. 

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. _q is passed as parameter to avoid getopts
	local _value; _value="$1"  
	local _class ; local _rootjail ; local _template

	# Fail if no jail specified
	[ -z "$_value" ] && get_msg $_q "_0" "jail" && return 1

	# Must have class in JMAP. Used later to find the correct zfs dataset 
	_class=$(sed -nE "s/^${_value}[[:blank:]]+class[[:blank:]]+//p" $JMAP)

	[ -z "$_class" ] && get_msg $_q "_cj1" "$_value" "class" && return 1
	# Must also have a designated rootjail in JMAP
	! grep -Eqs "^${_value}[[:blank:]]+rootjail[[:blank:]]+" $JMAP \
			&& get_msg $_q "_cj1" "$_value" "rootjail" && return 1

	# Jail must also have an entry in JCONF
	! grep -Eqs "^${_value}[[:blank:]]*\{" $JCONF \
			&& get_msg $_q "_cj3" && return 1

	# Verify existence of ZFS dataset
	case $_class in
		rootjail) 
			# Rootjails require a dataset at zroot/quBSD/jails 
			! zfs list ${JAILS_ZFS}/${_value} > /dev/null 2>&1 \
					&& get_msg $_q "_cj4" "$_value" "$JAILS_ZFS" && return 1
		;;
		appjail)
			# Appjails require a dataset at quBSD/zusr
			! zfs list ${ZUSR_ZFS}/${_value} > /dev/null 2>&1 \
					&& get_msg $_q "_cj4" "$_value" "$ZUSR_ZFS" && return 1
		;;
		dispjail)

			# Verify the dataset of the template for dispjail
			_template=$(sed -nE "s/^${_value}[[:blank:]]+template[[:blank:]]+//p"\
																								$JMAP)

			# First ensure that it's not blank			
			[ -z "$_template" ] && get_msg $_q "_cj5" "$_value" && return 1

			# Prevent infinite loop: $_template must not be a template for the  
			# jail under examination < $_value >. Otherwise, < $_value > would 
			# depend on _template, and _template would depend on < $_value >. 
			# However, it is okay for $_template to be a dispjail who's template 
			# is some other jail that is not < $_value >.
# NOTE: Technically speaking, this still has potential for an infinite loop, 
# but the user really has to try hard to create a circular reference.
			! check_isvalid_jail $_q "$_template" \
					&& get_msg $_q "_cj6" "$_value" "$_template" && return 1
		;;
			# Any other class is invalid
		*) get_msg $_q "_cj2" "$_class" "class"  && return 1
		;;
	esac
	return 0
}

check_isvalid_class() {
	# Return 0 if proposed class is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	local _value ; _value="$1"
	[ -z "$_value" ] && get_msg $_q "_0" "jail" && return 1 

	# Valid inputs are: appjail | rootjail | dispjail 
	case $_value in
		appjail|dispjail|rootjail) return 0 ;;
		*) get_msg $_q "_cj2" "$_value" "class" && return 1 ;;
	esac
}

check_isvalid_rootjail() {
	# Return 0 if proposed rootjail is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. 
	local _value ; _value="$1"

	# No jail specified. 
	[ -z "$_value" ] && get_msg $_q "_0" "class" && return 1

	# Must be designated as a rootjail in jailmap.con 
	_rootj=$(sed -nE "s/${_value}[[:blank:]]+class[[:blank:]]+//p" $JMAP) 
	! [ "$_rootj" == "rootjail" ] && get_msg $_q "_cj16" "$_value" && return 1

	# Must have an entry in JCONF 
	! grep -Eqs "^${_value}[[:blank:]]*\{" $JCONF \
			&& get_msg $_q "_cj3" && return 1
	
	# Rootjails require a dataset at zroot/quBSD/jails 
	! zfs list ${JAILS_ZFS}/${_value} > /dev/null 2>&1 \
			&& get_msg $_q "_cj4" "$_value" "$JAILS_ZFS" && return 1

	return 0
}

check_isvalid_gateway() {
	# Return 0 if proposed gateway is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. 
	local _value; _value="$1"  
	local _jail; _jail="$2"  

	# net-firewall gateway must be a tap interface in JMAP 
	if [ "$_jail" == "net-firewall" ] ; then 
		case "$_value" in
			tap[[:digit:]]) 
				return 0 ;;	
			tap[[:digit:]][[:digit:]]) 
				return 0 ;;	
			*) get_msg $_q "_cj7" "$_value" 
				return 1 ;;
		esac
	fi
	
	# `none' is valid for any jail except net-firewall. Order matters here.
	[ "$_value" == "none" ] && return 0

	# First check that gateway is a valid jail. (note: func already has messages)  
 	check_isvalid_jail $_q "$_value" || return 1

	# Checks that gateway starts with `net-'
	case $_value in
		net-*) return 0 ;;
		  	 *) get_msg $_q "_cj8" "$_value" "$_jail"  ;  return 1 ;;
	esac
}

check_isvalid_schg() {
	# Return 0 if proposed schg is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. 
	local _value; _value="$1"  

	# No value specified 
	[ -z "$_value" ] && get_msg $_q "_0" "schg" && return 1 

	# None is always a valid schg
	[ "$_value" == "none" ] && return 0 

	# Valid inputs are: none | sys | all
	case $_value in
		none|sys|all) return 0 ;;
		*) get_msg $_q "_cj2" "$_value" "schg"  ;  return 1
	esac
}

check_isvalid_seclvl() {
	# Return 0 if proposed seclvl is valid ; return 1 if invalid
	# NOTE: Securelevel of '-1' will error if options are enabled. 
	# For this reason, _q is taken as a positional parameter

	local _q ; _q="$1"
	[ "$_q" == '-q' ] && _value="$2" || _value="$_q"

	# No value specified 
	[ -z "$_value" ] && get_msg $_q "_0" "seclvl" && return 1

	# None is always a valid seclvl 
	[ "$_value" == "none" ] && return 0

	# Security defines levels from lowest == -1 to highest == 3
	[ "$_value" -lt -1 -o "$_value" -gt 3 ] \
			&& get_msg $_q "_cj2" "$_value" "seclvl" && return 1

	return 0
}

check_isvalid_maxmem() {
	# Return 0 if proposed maxmem is valid ; return 1 if invalid
# IMPROVEMENT IDEA - check that proposal isn't greater than system memory

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. 
	local _value; _value="$1"  

	# No value specified 
	[ -z "$_value" ] && get_msg $_q "_0" "maxmem" && return 1

	# None is always a valid maxmem
	[ "$_value" == "none" ] && return 0
	
	# Per man 8 rctl, user can assign units: G|g|M|m|K|k
   ! echo "$_value" | grep -Eqs "^[[:digit:]]+(G|g|M|m|K|k)\$" \
			&& get_msg $_q "_cj2" "$_value" "maxmem" && return 1

	return 0
}

check_isvalid_cpuset() {
	# Return 0 if proposed schg is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. _
	local _value ; _value="$1"

	# No value specified 
	[ -z "$_value" ] && get_msg $_q "_0" "cpuset" && return 1

	# None is always a valid cpuset 
	[ "$_value" == "none" ] && return 0
	
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

check_isvalid_mtu() {
	# Return 0 if proposed schg is valid ; return 1 if invalid

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. _
	local _value ; _value="$1"

	# No value specified 
	[ -z "$_value" ] && get_msg $_q "_0" "mtu" && return 1

	# None is always a valid mtu 
	[ "$_value" == "none" ] && return 0

	# Just push a warning, but don't error for MTU 
	[ "$_value" -ge 1000 ] && [ "$_value" -le 2000 ] \
			|| get_msg $_q "_cj18" "mtu" 

	return 0
}

check_isvalid_ipv4() {
	# Tests for validity of IPv4 CIDR notation.
	# return 0 if valid (or none), return 1 if not 

	# Variables below are required for caller function to perform other checks. 
	#   $_a0  $_a1  $_a2  $_a3  $_a4  

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. _
	local _value ; _value="$1"
	local _jail ; _jail="$2"

	local _b1 ; local _b2 ; local _b3

	# No value specified 
	[ -z "$_value" ] && get_msg $_q "_0" "IPv4" && return 1

	# None is always considered valid; but send warning for net-firewall
	[ "$_value" == "none" ] && return 0

	# Not as technically correct as a regex, but it's readable and functional 
	# IP represented by the form: a0.a1.a2.a3/a4 ; b-variables are local/ephemeral
	_a0=${_value%%.*.*.*/*}
	_a4=${_value##*.*.*.*/}
		b1=${_value#*.*}
		_a1=${b1%%.*.*/*}
			b2=${_value#*.*.*}
			_a2=${b2%%.*/*}
				b3=${_value%/*}
				_a3=${b3##*.*.*.}

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

check_isqubsd_ipv4() {
	# Checks for IP overlaps and/or mismatch in quBSD convention. 
	# Assigns the following, available to caller function:
		# $_isoverlap=true
		# $_ismismatch=true

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. _
	local _value ; _value="$1"
	local _jail ; _jail="$2"
	
	define_ipv4_convention
	_used_ips=$(get_used_ips)

	# No value specified 
	[ -z "$_value" ] && get_msg $_q "_0" "IPv4" 

	# net-firewall needs special attention
	if [ "$_jail" == "net-firewall" ] ; then 

		# IP0 `none' with net-firewall shouldn't really happen
		[ "$_value" == "none" ] \
					&& get_msg $_q "_cj9" "$_value" "$_jail" && return 1
	
		# All else gets ALERT message
		get_msg $_q "_cj15" "$_value" "$_jail" && return 1
	fi

	# IP0 `none' with < net- > jails should also be rare/never 
	[ "$_value" == "none" ] && [ -z "${_jail##net-*}" ] \
					&& get_msg $_q "_cj13" "$_value" "$_jail" && return 1
	
	# Otherwise, `none' is fine for any other jails. Skip additional checks.
	[ "$_value" == "none" ] && return 0 

	# Compare against JMAP, and _USED_IPS 
	if grep -qs "$_value" $JMAP \
			|| [ $(echo "$_used_ips" | grep -qs "${_value%/*}") ] ; then
	
		get_msg $_q "_cj11" "$_value" "$_jail" && return 1
	fi

	# Note that $a2 and $ip2 are missing, because that is the _cycle 
	# Any change to quBSD naming convention will require manual change.
	! [ "$_a0.$_a1.$_a3/$_a4" == "$_ip0.$_ip1.$_ip3/$_subnet" ] \
			&& get_msg $_q "_cj12" "$_value" "$_jail" && return 1

	_gateway=$(sed -nE "s/^${_jail}[[:blank:]]+gateway[[:blank:]]+//p" $JMAP)
	[ "$_gateway" == "none" ] && get_msg $_q "_cj14" "$_value" "$_jail" \
		&& return 1
	
	# Otherwise return 0
	return 0
}


# The checks below are a bit of a hack so that get_jail_parameter() can be a single
# simplified function, rather than multiple ones. 

check_isvalid_template() {
	# Return 0 if proposed template is valid ; return 1 if invalid
	# Exists mostly so that the get_jail_parameters() function works seamlessly

	# Quiet option
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	# Positional parmeters. _
	local _value ; _value="$1"
	local _jail; _jail="$2"  

	! check_isvalid_jail "$1" "$2" \
			&& get_msg $_q "_cj6" "$_value" "$_template" && return 1

	return 0
}
check_isvalid_IP0() {
	# IP0 probably should be changed to: ipv4 in jailmap.conf
	check_isvalid_ipv4 "$1" "$2" "$3"
}

check_is_trueorfalse() {
	# Positional parmeters. _q is passed as parameter to avoid getopts
	local _q ; _q="$1"
	local _value; _value="$2"  
	local _jail; _jail="$3"  

	# No value specified 
	[ -z "$_value" ] && get_msg $_q "_0" "$_param" 

	[ "$_value" == "true" -o "$_value" == "false" ] && return 0 \
			|| get_msg $_q "_cj2" "$_value" "$_param"
}


##################################################################################
#######################  FUNCTIONS RELATED TO NETWORKING #########################
##################################################################################

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
	
	# Assemble list of ifconfig inet addresses for all running jails
	for _jail in $(get_onjails) ; do
		_intfs=$(jexec -l -U root $_jail ifconfig -a inet | grep "inet")
		_USED_IPS=$(printf "%b" "$_USED_IPS" "\n" "$_intfs")
	done
}

discover_open_ipv4() {	
	# Finds an IP address unused by any running jails, or in jailmap.conf 
	# Echo open IP on success; Returns 1 if failure to find an available IP

	# Positional params and func variables. 
	local _q ; local _opts
	getopts q _opts && _q='-q'
	shift $(( OPTIND - 1 ))

	local _value; _value="$1"  
	local _temp_ip

	# net-firewall connects to external network. Assign DHCP, and skip checks. 
	[ "$_value" == "net-firewall" ] && echo "DHCP" && return 0

	# _used_ips checks IPs in running jails, to compare each _cycle against 
	local _used_ips ; _used_ips=$(get_used_ips)
		
	# Assigns values for each IP position, and initializes $_cycle
	define_ipv4_convention
	
	# Increment _cycle to find an open IP. 
	while [ $_cycle -le 255 ] ; do

		# $_ip2 uses variable indirection, which subsitutes "cycle"
		eval "_temp_ip=${_ip0}.${_ip1}.\${$_ip2}.${_ip3}"

		# Compare against JMAP, and the IPs already in use
		if grep -qs "$_temp_ip" $JMAP	\
					|| [ $(echo "$_used_ips" | grep -qs "$_temp_ip") ] ; then

			# Increment for next cycle
			_cycle=$(( _cycle + 1 ))

			# Failure to find IP in the quBSD conventional range 
			if [ $_cycle -gt 255 ] ; then 
				eval "_pass_var=${_ip0}.${_ip1}.x.${_ip3}"
				get_msg $_q "_jf7" "$_value" "$_pass_var"
				return 1
			fi
		else
			# Echo the value of the discovered IP and return 0 
			echo "${_temp_ip}/${_subnet}" && return 0
		fi
	done
}

remove_tap() {
	# If TAP is not already on host, find it and bring it to host
	# Return 1 on failure, otherwise return 0 (even if tap was already on host)

	# Assign name of tap
	[ -n "$1" ] && _tap="$1" || return 1
	
	# Check if it's already on host
	ifconfig "$_tap" > /dev/null 2>&1  &&  return 0
	
	# First find all jails that are on
	for _jail in $(get_onjails) ; do
		if `jexec -l -U root $o ifconfig -l | egrep -qs "$tap"` ; then
			ifconfig $tap -vnet $o
			ifconfig $tap down
		fi
	done

	# Bring tap down for host/network safety 
	ifconfig $_tap down 
}


##################################################################################
#######################  FUNCTIONS RELATED TO VM HANDLING ########################
##################################################################################

check_isrunning_vm() {
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
	[ "$2" == "quiet" ] && _quiet="true" 
	
	# pkill default is SIGTERM (-15) 
	pkill -f "bhyve: $_VM"  && get_msg_qb_vm "_3"

	# Monitor for VM shutdown, via process disappearance
	_count=1
	while check_isrunning_vm "$_VM" ; do
		
		# Prints	a period every second
		[ -z "$quiet" ] && sleep 1 && get_msg_qb_vm "_4"

		_count=$(( count + 1 ))
		[ "$_count" -gt 30 ] && get_msg_qb_vm "_5" "exit_1"
	done

}










