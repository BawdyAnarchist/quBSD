#!/bin/sh

get_msg_stop() {

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

ERROR: One or more jails appear to be hung and havent stopped.
       Check /var/log/quBSD.sh for details, and check jls
       list to manually kill all `jail -R` operations.

       NOTE - No restarts were attempted, due to error.
ENDOFMSG
	;;
	_e4) cat << ENDOFMSG

ERROR: One or more jails appear to be hung and havent stopped.
       Check /var/log/quBSD.sh for details, and check process
       list to manually kill all jail stop operations.
ENDOFMSG
	;;
	_e5) cat << ENDOFMSG

ERROR: [-t <timeout>] must be integer from 5 to 600. Caution,
       choose a timeout appropriate for number of starts,
       longer if starting multiple gateways/clients in a row
ENDOFMSG
	;;
	_m1) cat << ENDOFMSG

ALERT: Force stopping jails/VMs is non-graceful and not preferred.
       For example, passthru'd PCI devices attached to a VM will
       likely become unavailable until after a system reboot.
       Use this only as a last resort for misbehaving containers.

ENDOFMSG
echo -e "Continue? (Y/n): \c"
	;;
	_m2) cat << ENDOFMSG

All jails/VMs have been stopped 
ENDOFMSG
	;;
	_m3) cat << ENDOFMSG

All jails/VMs were already stopped. No action to take.
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
}

