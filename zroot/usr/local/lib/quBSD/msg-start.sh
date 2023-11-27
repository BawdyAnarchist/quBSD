#!/bin/sh

get_msg_start() {

	local _message="$1"
	local _pass_cmd="$2"

	case "$_message" in

	_e0) cat << ENDOFMSG

ERROR: Two instances of qb-stop or qb-start are already running.
       Cannot queue another instance until one of these finishes.

$(pgrep -fl '/bin/sh /usr/local/bin/qb-st(art|op)')
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

ERROR: Infinite loop detected. There likely a set of jails has
      gateways that circularly reference each other. Example:
      Jail-A has Jail-B as gateway,
             Jail-B has Jail-C as gateway,
                    Jail-C has Jail-A as gateway.
ENDOFMSG
	;;
	_e4) cat << ENDOFMSG

ERROR: < $_JAIL > failed to start. It serves network to
       client jails. Exiting
ENDOFMSG
	;;
	_e5) cat << ENDOFMSG

ERROR: [-t <timeout>] must be integer from 5 to 600. Caution,
       choose a timeout appropriate for number of starts,
       longer if starting multiple gateways/clients in a row
ENDOFMSG
	;;
	_m1) cat << ENDOFMSG

All jails/VMs have been launched, but VMs might need a moment.
ENDOFMSG
	;;
	_m2) cat << ENDOFMSG

All jails/VMs were already running. No action to take.
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
jails in parallel to avoid race conditions and errors.

qb-start [-a|-A|-f <file>] [-e|-E <file>]
         [-t <timeout>] <jail list>

   If no [-a|-A|-f] is specified; < jail list > (positional
   parameters) at the end are assumed to be jail starts.

   -a: (a)uto. Start all jails tagged with autostart in qmap
       This is the default behavior if no opts are specified.
   -A: (A)ll. Start ALL valid jails on the system.
   -e: (e)xclude. Starts jails as indicated by options,
       except those as positional parameters in < jail list >
   -E: (E)xclude. Start jails as indicated by options,
       but exlude any jails listed in <file>.
   -f: (f)ile. Use a file with a list of jails to start.
   -h: (h)elp. Outputs this help message.
   -t: (t)imeout in secs, to wait for jail starts before error
       *This is auto calculated, so normally dont change this.
ENDOFUSAGE
}

