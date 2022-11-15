#!/bin/sh

get_msg_qb_destroy() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _action is optional, and can be used to exit and/or show usage

	local _message
	local	_action

	_message="$1"
	_action="$2"

	case "$_message" in

	_1) cat << ENDOFMSG

Exiting, no changes were made.

ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: < $JAIL > has the \`no_destroy protection flag' set in 
       jailmap.conf.  Change flag to \`false', and run again. 
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG
#[[OPEN ENTRY, NO MESSAGES HERE]]
ENDOFMSG
	;;
	_4) cat << ENDOFMSG
WARNING! $JAIL is a rootjail
ENDOFMSG
	;;
	_5) cat << ENDOFMSG
WARNING! This will destroy the following datasets:
ENDOFMSG
	;;
	_6) cat << ENDOFMSG

< $zrootDestroy > 
                          Totaling: $zrootSize of ondisk data
ENDOFMSG
	;;
	_7) cat << ENDOFMSG

< $zusrDestroy > 
                          Totaling: $zusrSize of ondisk data

NOTE! Beware the difference between zroot jails, which are
rootjails and clones; VS zusr jails which contain user data 
ENDOFMSG
	;;
	_8) 
		echo -e "\n          To continue, type yes: \c"
	;;

	esac

	case $_action in 
		usage_0) usage ; exit 0 ;;
		usage_1) usage ; exit 1 ;;
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		*) : ;;
	esac
}

usage() { cat << ENDOFUSAGE

qb-destroy: Destroys <jail> and purges jail from configs at:
            jail.conf ; jailmap.conf ; zfs datasets

There is a protection mechanism for all jails. jailmap.conf	
has a parameter called: \`no_destroy', which defaults to true.
Must manually edit this setting to false, before qb-destroy

Usage: qb-destroy [-h] <jail>"
   -h: (h)elp. Outputs this help message"

ENDOFUSAGE
}

