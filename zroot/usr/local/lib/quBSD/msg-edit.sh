#!/bin/sh

get_msg_edit() { 
	# Print messages and/or exiting script execution entirely 
	# Positional parameters are used for determining action.
	# $1 _message: Identifier tag for message
		# To avoid calling a message, "none" is fine to pass
	# $2 _pass_cmd: What type of exit to perform if any
	# $3 _msg2: A bit of a hack, for a catch-all [-f] message

	# FORCE should override all calls to the msg and exit function
	[ -n "$FORCE" ] && return 0 
	
	# Positional parameters
   local _message ; _message="$1"
   local _pass_cmd ; _pass_cmd="$2"
	local _msg2 ; _msg2="$3"


#################################################################
#####################  BEGIN MESSAGE TAGS  ######################

	# QUIET should skip over messages 
	[ -z "$QUIET" ] && case "$_message" in

	_0) cat << ENDOFMSG
EXITING. No changes were made.
ENDOFMSG
	;;
	_1) cat << ENDOFMSG

ERROR: Missing argument. Must specify jail, parameter, and new value
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Combination of < $JAIL >< $PARAM > [jail and parameter]
       doesn't exist in jailmap.conf
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ALERT: The new value entered is the same as the old value.
       No changes were made.
ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ERROR: < no_destroy > must be either true or false
ENDOFMSG
	;;
	_5) cat << ENDOFMSG

ERROR: Parameter < class > cannot be changed with qb-edit.
ENDOFMSG
	;;
	_6) cat << ENDOFMSG

ERROR: < $PARAM > is not a valid parameter to change in 
       /usr/local/etc/quBSD/jailmap.conf
ENDOFMSG
	;;
	_7) cat << ENDOFMSG
ALERT: For changes to take effect, restart the following:
$_restarts

ENDOFMSG
	# \c prevents newline. User input can happen on the same line 
	echo -e "Should qb-edit to restart these jails? (y/n):  \c"
	;; 
	_8) 
		echo -e "Success \c" 
		qb-list -j $JAIL -p $PARAM
	;;
		
# NOTE: _8 and _9 are unused. Maybe integrate later.
	_10) cat << ENDOFMSG

ERROR: Invalid rootjail. Here's a list of valid rootjails: 
ENDOFMSG

		# All rootjails in JMAP with valid zroot/quBSD/jails/<jail>
		sed -nE "s/[[:blank:]]+class[[:blank:]]+rootjail[[:blank:]]*//gp" $JMAP \
										| uniq | xargs -I@ zfs list -Ho name $JAILS_ZFS/@
		echo ''
	;;
	_9) cat << ENDOFMSG

ERROR: Invalid template. Here's a list of valid templates: 
ENDOFMSG
		# All appjails in JMAP with zusr/<jail>
		sed -nE "s/[[:blank:]]+class[[:blank:]]+(appjail)[[:blank:]]*//gp" $JMAP \
										| uniq | xargs -I@ zfs list -Ho name $ZUSR_ZFS/@
		echo ''
	;;

	esac

####################  MESSAGES TAGS FINISHED  #####################
###################################################################

	# Print message informing user that [-f] can overcome errors. 
	# It's not really appropriate to include an option specific to
	# qb-edit, in the main error messages with msg-qubsd.sh.


	# QUIET should skip over messages 
	[ -z "$QUIET" ] && case $_msg2 in 
		_f) cat << ENDOFMSG

Run again with [-f] to force modification.
    (errors will still be printed to stdout, but ignored)

ENDOFMSG
		;;
	esac


###################################################################
#####################  FINAL IF_ERR TO TAKE  ######################

	case $_pass_cmd in 
		usage_0) 
				[ -z "$QUIET" ] && usage 
				exit 0 ;;

		usage_1) 
				[ -z "$QUIET" ] && usage 
				exit 1 ;;

		exit_0) exit 0 ;;

		exit_1) exit 1 ;;

		*) : ;;
	esac
}


###################################################################
############################  USAGE  ##############################

usage() { cat << ENDOFUSAGE 
qb-edit:  Modify jail parameters in jailmap.conf

Usage: qb-edit <jail> <parameter> <value>
       qb-edit [-f][-h][-i][-r] <jail> <parameter> <value>

   -f: (f)orce. Ignore errors and modify anyways. 
       Errors messages will still print to stdout.
   -h: (h)elp. Outputs this help message
   -i: (i)pv4. Auto-assign IP address along quBSD conventions
   -q: (q)uiet output, do not print anything to stdout 
   -r: (r)estart the required jails for changes to take effect

PARAMETERS SAVED AT /usr/local/etc/quBSD/jailmap.conf
autostart:   Automatically start with rc script during host boot.  
class:       Cannot be modified. Use qb-create instead.
cpuset:      CPUs a jail may use. Comma separated integers, or a
             range.  For example: 0,1,2,3 is the same as 0-3
             \`none' places no restrictions on jail's CPU access
IPV4:         IPv4 address for the jail.
maxmem:      RAM maximum allocation:  <integer><G|M|K> 
             For example: 4G or 3500M, or \'none' for no limit
no_destroy:  Prevents accidental destruction of <jail>
             Change to \`false' in order to use qb-destroy
rootjail:    Which rootjail system to clone for <jail> . If <jail>
             is a rootjail; then this entry is self referential,
             but important for script funcitonality.
schg:        Directories to receive schg flags: all|sys|none
             \`sys' are files like: /boot /bin /lib , and others
             \`all includes /usr and /home as well
seclvl:      kern.securelevel to protect <jail>: -1|0|1|2|3
             \`1' or higher is required for schg to take effect
template:    Only applicable for dispjail. Designates jail to
             clone (including /home) for dispjail
gateway:      Gateway for <jail> to receive network connectivity

ENDOFUSAGE
}

