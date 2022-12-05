#!/bin/sh

get_msg_rename() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _pass_cmd is optional, and can be used to exit and/or show usage

	local _message
	local _pass_cmd
	_message="$1"
	_pass_cmd="$2"

	case "$_message" in
	_0) cat << ENDOFMSG

Exiting. No changes were made.
ENDOFMSG
	;;	
	_1) cat << ENDOFMSG

ERROR: Must specify < new_jailname >
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Invalid jailname < none > . Using "none" as a jailname
       will likely cause errors for quBSD operation, as this 
       word is often used as an exception during various checks
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ALERT: < $JAIL > has client jail dependencies. 
       Is a rootjail for the following jails:
$rootj_for
ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ALERT: < $JAIL > has client jail dependencies.
       Is a template for the following jails: 
$template_for
ENDOFMSG
	;;
	_5) cat << ENDOFMSG

ALERT: < $JAIL > has client jail dependencies.
       Is a network gateway for the following jails: 
$tunnel_for
ENDOFMSG
	;;
	_6) cat << ENDOFMSG

Would you like to automatically update the dependent jails 
with the new jailname? This will restart any running jails
ENDOFMSG
echo -e "                                    Enter (y/n): \c"
	;;
	_7) cat << ENDOFMSG

WARNING: < $_jail > Could not be stopped. qb-rename will
         continue, but there might be errors with 
         < $_jail> until it is restarted.
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

