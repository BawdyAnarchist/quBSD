#!/bin/sh

get_msg_edit() { 

	# Positional parameters
   local _message="$1"
   local _pass_cmd="$2"
	local _msg2="$3"

	# FORCE overrides 
	if [ -n "$FORCE" ] ; then 
		# Do not exit the script on errors 
		_pass_cmd="none"
		
		# The only message that should be shown, is the result.
		! [ "$_message" = "_8" ] && _message="none"
	fi

	# QUIET will skip over messages 
	[ -z "$QUIET" ] && case "$_message" in

		_0) cat << ENDOFMSG
EXITING. No changes were made.
ENDOFMSG
		;;
		_1) cat << ENDOFMSG

ERROR: Missing argument. Need jail, parameter, and value (unless deleting line) 
ENDOFMSG
		;;	
		_2) cat << ENDOFMSG

ALERT: The new value entered is the same as the old value.
       No changes were made.
ENDOFMSG
		;;
		_2_1) cat << ENDOFMSG

ALERT: There was no combination of: < $JAIL $PARAM > to delete.
       No changes were made.
ENDOFMSG
		;;
		_3) cat << ENDOFMSG

ERROR: < $PARAM > isn't a valid parameter for a VM 
ENDOFMSG
		;;	
		_4) cat << ENDOFMSG

ERROR: < $PARAM > isn't a valid parameter for a jail
ENDOFMSG
		;;	
		_5) cat << ENDOFMSG

ERROR: The line: < $JAIL $PARAM > doesn't exist. Nothing to delete.
ENDOFMSG
		;;
		_6) cat << ENDOFMSG

ERROR: < $PARAM > is not a valid parameter to change in 
       /usr/local/etc/quBSD/jailmap.conf
ENDOFMSG
		;;
		_7) cat << ENDOFMSG
ALERT: For changes to take effect, restart the following:
ENDOFMSG

[ -n "$_restart1" ] && echo "    $_restart1"
[ -n "$_restart2" ] && echo "    $_restart2"
echo -e "Should qb-edit to restart these jails? (y/n):  \c"
		;; 
		_8) 
			echo -e "Success \c" 
			qb-list -j $JAIL -p $PARAM
		;;
		_8_1) cat << ENDOFMSG
Deleted the following line:
$_delline
ENDOFMSG
		;;
		_9) cat << ENDOFMSG
ALERT: net-firewall connects to the external internet, so its
       IP depends on your router. The following was modified: 
       ${M_ZUSR}/net-firewall/rw/etc/rc.conf 
       It's highly recommended to double check the IP address,
       assigned by your router, and this file.

ENDOFMSG
	;;
		_10) cat << ENDOFMSG

ALERT: Changing GATEWAY to < $VALUE > but IPV4 is set to 'none'.
       IP is necessary to connect < $JAIL > to < $VALUE >.

ENDOFMSG
echo -e "Would you like to change this to auto? (Y/n): \c"
	;;
		_11) cat << ENDOFMSG

ERROR: dispjails cannot have auto snapshots, as their
       dataset is a dependent clone of a template jail.
ENDOFMSG
	;;
	
		_12) cat << ENDOFMSG

ALERT: Setting SECLVL to 3 will make changes to pf
       impossible for < $JAIL >, without restarting it.
       Thus, restarting its gateway without restarting
       < $JAIL > might result in no network connection.    
ENDOFMSG
	# End of _message 
	esac

	# Secondary message - informs about the [-f] option 
	[ -z "$QUIET" ] && case $_msg2 in 
		_f) cat << ENDOFMSG

Run again with [-f] to force modification.
    (errors will still be printed to stdout, but ignored)

ENDOFMSG
		;;
	esac


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

usage() { cat << ENDOFUSAGE 
qb-edit:  Modify jail parameters in jailmap.conf

Usage: qb-edit <jail> <PARAMETER> <value>
       qb-edit [-h] | [-d][-f][-q][-r] <jail> <PARAM> <value>

   -d: (d)elete line. Only need <jail> <PARAM> to do so
   -f: (f)orce. Ignore errors and modify. Error msgs suppressed
   -h: (h)elp. Outputs this help message
   -q: (q)uiet output, do not print anything to stdout 
   -r: (r)estart the required jails for changes to take effect

ENDOFUSAGE
}

