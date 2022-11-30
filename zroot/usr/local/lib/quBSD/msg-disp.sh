#!/bin/sh

get_msg_qb_disp() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _action is optional, and can be used to exit and/or show usage

   local _message
   local _action

	_message="$1"
	_action="$2"
	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Must specify a < jail > to clone for dispjail
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: < $JAIL > is not properly configured or does not exist
ENDOFMSG
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

qb-disp: Creates a disposable jail, using snapshot of existing  
         <jail>. Launches terminal inside new DISP-jail, which
         is destroyed upon closing the terminal.

         **Use dispjails for conducting risky operations**

Usage: qb-disp [-h]|<existing_jail> 
Usage: qb-disp -p 
   -h: (h)elp. Outputs this help message
	-v: (v)erbose. Print any error messages

ENDOFUSAGE
}

