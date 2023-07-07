#!/bin/sh

get_msg_rename() { 

	local _message="$1"
	local _pass_cmd="$2"

	case "$_message" in
	_0) cat << ENDOFMSG

Exiting. No changes were made.
ENDOFMSG
	;;	
	_1) cat << ENDOFMSG

#############################################
###### UNUSED ERROR MESSAGE DESIGNATOR ######
#############################################

ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

#############################################
###### UNUSED ERROR MESSAGE DESIGNATOR ######
#############################################
       
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ALERT: < $JAIL > is a rootjail for the following:
$rootj_for
ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ALERT: < $JAIL > is a template for the following: 
$template_for
ENDOFMSG
	;;
	_5) cat << ENDOFMSG

ALERT: < $JAIL > is a gateway for the following: 
$gateway_for
ENDOFMSG
	;;
	_6) cat << ENDOFMSG

Would you like to automatically update the dependent jails 
with the new jailname? This will restart any running jails
ENDOFMSG
echo -e "                                    Enter (y/n): \c"
	;;
	_7) cat << ENDOFMSG

ERROR: < $_jail > could not be stopped. Aborting qb-rename.
ENDOFMSG
	;;
	_7_1) cat << ENDOFMSG

ERROR: \`chflags noschg\` failed. schg could prevent rename. 
ENDOFMSG
	;;
	_8) cat << ENDOFMSG

Final confirmation to change < $JAIL > to < $NEWNAME >
ENDOFMSG
echo -e "                                    Enter (y/n): \c"
	;;
	_9) cat << ENDOFMSG
Rename complete. Might take a moment for restarts to finish. 
ENDOFMSG
	;;
	esac

	case $_pass_cmd in 
		usage_0) usage ; exit 0 ;;
		usage_1) usage ; exit 1 ;;
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		*) : ;;
	esac
}

usage() { cat << ENDOFUSAGE

qb-rename: Renames jail
Usage: qb-rename [-a] <jail> <new_jailname>
   -a: (a)utomatically update dependencies of client jails 
       which depend on the <jail> being renamed, for things 
       like: gateway, rootjail, and as a template.  
   -h: (h)elp. Outputs this help message

ENDOFUSAGE
}

