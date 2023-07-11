#!/bin/sh

get_msg_start() { 

	local _message="$1"
	local _pass_cmd="$2"

	case "$_message" in

	_e0) cat << ENDOFMSG

ERROR: An instance of qb-start or qb-stop is already running.
       Absolutely should never run these in in parallel, due 
       to the high probability of errors, hangs, and loops.

$(pgrep -fl qb-start)
$(pgrep -fl qb-stop)
	
ENDOFMSG
	;;	
	_e1) cat << ENDOFMSG

ERROR: Conflicting options. Specify only one: [-a|-A|-f]
ENDOFMSG
	;;	
	_e2) cat << ENDOFMSG

ERROR: Conflicting options. Either use [-E <file>], or use
       [-e] and type a list of exclusion jails as positional 
       parameters (aka, at the end of the command).
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG

ERROR: [-e] can only be used with [-a|-A|-f <file>], because
       the positional params are assumed to be jail starts.  
ENDOFMSG
	;;	
	_e4) cat << ENDOFMSG

ERROR: No jails to start. Please specify [-a|-A|-f <file>],
       or < jail list > at the end of the command.
ENDOFMSG
	;;	
	_e5) cat << ENDOFMSG

ERROR: The file < $_SOURCE > doesn't exist.
ENDOFMSG
	;;	
	_e6) cat << ENDOFMSG

ERROR: [-e] should come with a < jail list > as positional 
       parameters at the end of the command. 
ENDOFMSG
	;;	
	_e7) cat << ENDOFMSG

ERROR: The file < $_EXFILE > doesn't exist.
ENDOFMSG
	;;	
	_e8) cat << ENDOFMSG

ERROR: Infinite loop detected. There likely a set of jails has
      gateways that circularly reference each other. Example:
      Jail-A has Jail-B as gateway,
             Jail-B has Jail-C as gateway,
                    Jail-C has Jail-A as gateway.
ENDOFMSG
	;;	
	_7) cat << ENDOFMSG
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

!IMPORTANT; qb-start MUST be used when starting multiple
jails in parallel to avoid networking errors. User scripts
should only start jails in serial, or call this script. 

qb-start [-h] [-a|-A|-f <file>] [-e|-E <file>]  < jail list >

   If no [-a|-A|-f] is specified, the < jail list > (positional
   parameters) at the end are assumed to be jail starts. 

   -a: (a)uto. Start all jails tagged with autostart in jmap
       This is the default behavior if no opts are specified.
   -A: (A)ll. Start ALL valid jails on the system. 
   -e: (e)xclude. Starts jails as indicated by options, 
       except those as positional parameters in < jail list >
   -E: (E)xclude. Start jails as indicated by options,
       but exlude any jails listed in <file>. 
   -h: (h)elp. Outputs this help message.
   -f: (f)ile. Use a file with a list of jails to start.

ENDOFUSAGE
}
