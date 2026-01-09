#!/bin/sh

msg_start() {
	case $_message in
	_e0) cat << ENDOFMSG
Two instances of qb-stop or qb-start are already running.
Cannot queue another instance until one of these finishes.

$(pgrep -fl '/bin/sh /usr/local/bin/qb-st(art|op)')
ENDOFMSG
		;;
	_e1) cat << ENDOFMSG
Conflicting options. Specify only one: [-a|-A|-f]
ENDOFMSG
		;;
	_e2) cat << ENDOFMSG
Conflicting options. Either use [-E <file>], or use
[-e] and type a list of exclusion jails as positional
parameters (aka, at the end of the command).
ENDOFMSG
		;;
	_e3) cat << ENDOFMSG
Infinite loop detected. There likely a set of jails has
gateways that circularly reference each other. Example:
Jail-A has Jail-B as gateway,
   Jail-B has Jail-C as gateway,
      Jail-C has Jail-A as gateway.
ENDOFMSG
		;;
	_e4) cat << ENDOFMSG
< $_JAIL > failed to start. It serves these clients (also not started):
ENDOFMSG
		get_info _CLIENTS "$_JAIL"
		for _client in $_CLIENTS ; do
			echo_grep "$_client" "$_JLIST" && echo $_client
		done
		;;
	_e5) cat << ENDOFMSG
[-t <timeout>] must be integer from 5 to 600.
(Choose longer timeouts if starting multiple gateways in a row).
ENDOFMSG
		;;
	_m0) cat << ENDOFMSG
qb-start:  All jails/VMs were already running. No action to take.
ENDOFMSG
		;;
	_m1) cat << ENDOFMSG
qb-start has finished
ENDOFMSG
		;;
	usage) cat << ENDOFUSAGE

!IMPORTANT; qb-start MUST be used when starting multiple
jails in parallel to avoid race conditions and errors.

qb-start [-a|-A|-f <file>] [-e|-E <file>]
         [-t <timeout>] <jail list>

   If no [-a|-A|-f] is specified; < jail list > (positional
   parameters) at the end are assumed to be jail starts.

   -a: (a)uto. Start all jails tagged with autostart in qconf
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
		;;
	esac
}

