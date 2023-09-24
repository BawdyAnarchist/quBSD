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
		_msg2="none"
		# The only message that should be shown, is the result.
		[ ! "$_message" = "_8" ] && _message="none"
	fi

	# QUIET will skip over messages 
	[ -z "$QUIET" ] && case "$_message" in

		_0) cat << ENDOFMSG

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
		_3) cat << ENDOFMSG

ERROR: < $PARAM > isnt valid. Valid PARAMETERS for CLASS < $CLASS >, are:
       $FILT_PARAMS
ENDOFMSG
		;;	
		_4) cat << ENDOFMSG

ERROR: Combination of < $JAIL $PARAM > was not found in jailmap.conf
       No changes were made.
ENDOFMSG
		;;	
		_5) cat << ENDOFMSG

ERROR: CLASS shouldn't be changed. You can, but you're playing with fire.
ENDOFMSG
		;;
		_6) cat << ENDOFMSG

WARNING: ROOTJAIL is typically not changed, but it can be if desired. 
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
		_10) cat << ENDOFMSG

ALERT: Changing GATEWAY to < $VALUE > but IPV4 is set to 'none'.
       IP is necessary to connect < $JAIL > to < $VALUE >.

ENDOFMSG
echo -e "Would you like to change this to auto? (Y/n): \c"
	;;

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
       qb-edit -d <jail> <param>  {removes all lines that match}

   -d: (d)elete line. Only need <jail> <PARAM> to do so
   -f: (f)orce. Ignore errors and modify. Error msgs suppressed
   -h: (h)elp. Outputs this help message
   -q: (q)uiet output, do not print anything to stdout 
   -r: (r)estart the required jails for changes to take effect

For a list and description of PARAMETERS, run:
   qb-help params
ENDOFUSAGE
}

