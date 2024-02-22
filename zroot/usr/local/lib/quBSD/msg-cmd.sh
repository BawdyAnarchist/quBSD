#!/bin/sh

msg_cmd() {
	case "$_message" in

	_e1) cat << ENDOFMSG
< $JAIL > Failed to start.
ENDOFMSG
		;;
	_e2) cat << ENDOFMSG
Failed to retreive a valid parameter from QMAP.
PARAMETER: < $1 > for jail: < $2 >
ENDOFMSG
		;;
	_e3) cat << ENDOFMSG
Timed out while waiting for VNC FBUF device to appear in sockstat
ENDOFMSG
		;;
	_e4) cat << ENDOFMSG
tmux tried and failed to connect to < $JAIL >
ENDOFMSG
		;;
	_e5) cat << ENDOFMSG
No TMUX or VNC was found for < $JAIL >
Check VM parameters with:  qb-list $JAIL
ENDOFMSG
		;;
	_e6) cat << ENDOFMSG
Attempt to produce the bhyve command caused the following errors:
ENDOFMSG
		;;
	_e7) cat << ENDOFMSG
User: < $_USER > doesn't have a /home directory inside of jail.
Use [-r] if you need to run as root inside of the jail.
ENDOFMSG
		;;
	_m1) cat << ENDOFMSG
The following bhyve command would be run:
ENDOFMSG
		;;
	_m2) cat << ENDOFMSG
ALERT:  $0
< $JAIL > is tagged for VNC in QMAP, but the FBUF device hasn't
been detected yet. Waiting 12 more seconds before quitting.
ENDOFMSG
		;;
	usage) cat << ENDOFUSAGE

qb-cmd: Runs command in a jail, or connects to VM.
        Jail default is /bin/csh ; VM defaults to
        both tmux and VNC if no option specified.

Usage: qb-cmd <jail/VM>
       qb-cmd [-n][-r|-u <user>][-v] <jail> <command>
       qb-cmd [-N|-v] <VM>

   -h: (h)elp. Outputs this help message
   -n: (n)ew window. Run command in new window. If jail is not
       specified, default environment is the active window
   -N: (N)orun. Print the bhyve command that would be run,
       but do not launch. Only applies to VMs.
   -p: (p)opup. Receive command for <jail> via temporary popup. 
       Use this in combination with quick-key settings.
   -r: (r)oot. Run cmd as root. Default is unprivileged user
   -u: (u)ser. Run cmd as <user>. Default is unpriveleged
       user, which is the same name as the jail.
   -v: (v)erbose. Output of <command> will print to stdio.
       (Default behavior sends output to /dev/null).For VM,
       this will print the bhyve command, and launch the VM.

ENDOFUSAGE
		;;
	esac
}


