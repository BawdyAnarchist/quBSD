#!/bin/sh

get_msg_autostart() { 

	local _message="$1"
	local _pass_cmd="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: < $FILE > doesn't exist.
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Infinite loop detected. There likely a set of jails has
      gateways that circularly reference each other. Example:
      Jail-A has Jail-B as gateway,
             Jail-B has Jail-C as gateway,
                    Jail-C has Jail-A as gateway.
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

qb-autostart: Automatically start a set of jails. 
              Starts as many jails in parallel as possible.

Usage: qb-autostart
   -h: (h)elp. Outputs this help message.
   -f: (f)ile. Use a file with a list of jails to start, 
       instead of the default, which searches jailmap.conf
       for all jails tagged with autostart true.

ENDOFUSAGE
}

