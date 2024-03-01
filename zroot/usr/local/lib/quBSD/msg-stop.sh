#!/bin/sh

msg_stop() {
	case "$_message" in
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
Potential infinite loop detected. Likely some set of jails
has gateways that circularly reference each other. Example:
  Jail-A has Jail-B as gateway,
    Jail-B has Jail-C as gateway,
      Jail-C has Jail-A as gateway.
ENDOFMSG
	;;
	_e4) cat << ENDOFMSG
Failed to stop all jails/VMs within the timeout of < $_TIMEOUT secs >.
Check /var/log/quBSD, and/or forcibly stop with: qb-stop -F
ENDOFMSG
	;;
	_e5) cat << ENDOFMSG
[-t <timeout>] must be integer from 5 to 600.
(Choose longer timeouts if stopping multiple gateways in a row).
ENDOFMSG
	;;
	_m1) cat << ENDOFMSG
WARNING: $0
Force stopping is non-graceful. Any passthru PCI devices will
likely become unavailable until host reboot. Use as last resort.
ENDOFMSG
	echo -e "Continue? (Y/n): \c"
	;;
	_m2) cat << ENDOFMSG
qb-stop has finished
ENDOFMSG
	;;
	_m3) cat << ENDOFMSG
All jails/VMs were already stopped. No action to take.
ENDOFMSG
	;;
	usage) cat << ENDOFUSAGE

!IMPORTANT; qb-stop MUST be used when stopping multiple
jails in parallel to avoid race conditions and errors.

qb-stop [-a|-A|-f <file>] [-e|-E <file>] [-r]
        [-t <timeout>] <jail_list>
qb-stop [-F] <jail_list>

   If no [-a|-A|-f] is specified, < jail list > (positional
   parameters) at the end are assumed to be jail stops.

   -a: (a)uto. Stop all jails tagged with autostop in qmap
       This is the default behavior if no opts are specified.
   -A: (A)ll. Start ALL valid jails on the system.
   -e: (e)xclude. Start [-a|-A] jails, but exclude jails
       passed via positional parameters <jail list>
   -E: (E)xclude. Start [-a|-A|< jail list >], but
       exclude any jails listed in <file>
   -f: (f)ile. Use a file with a list of jails to stop.
   -F: (F)orce non-graceful termination of jail/VM.
   -h: (h)elp. Outputs this help message.
   -r: (r)estart. Restart all jails after stopping them.
   -t: (t)timeout in secs, to wait for jail stops before error
       *This is auto calculated, so normally dont change this.

ENDOFUSAGE
		;;
	esac
}

