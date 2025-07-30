#!/bin/sh

msg_cmd() {
	case "$_message" in

	_e1) cat << ENDOFMSG
< $JAIL > Failed to start.
ENDOFMSG
		;;
	_e2) cat << ENDOFMSG
Failed to retreive a valid parameter from QCONF.
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
	_e8) cat << ENDOFMSG
Failed to launch Xephyr process for X11 related call.
ENDOFMSG
		;;
	_e9) cat << ENDOFMSG
Failed to find available X11 socket within 99 increments.
ENDOFMSG
		;;
	_e10) cat << ENDOFMSG
[-H and -x] are mutually exclusive.
ENDOFMSG
		;;
	_m1) cat << ENDOFMSG
The following command would be run (does not include env DISPLAY for Xephyr):
ENDOFMSG
		;;
	_m2) cat << ENDOFMSG
ALERT:  $0
< $JAIL > is tagged for VNC in QCONF, but the FBUF device hasn't
been detected yet. Waiting 12 more seconds before quitting.
ENDOFMSG
		;;
	usage) cat << ENDOFUSAGE

qb-cmd: Runs command in a jail, or connects to VM.
        Jail default is /bin/csh ; VM defaults to
        both tmux and VNC if no option specified.

Usage: qb-cmd <jail/VM>
       qb-cmd [-N][-d][-H|x][-p][-q][-r|-u <user>] <jail> <command>
       qb-cmd [-N] <VM>

   -d: (d)pi. Set DPI of the Xephyr window to be launched.
   -h: (h)elp. Outputs this help message
   -l: (l)inux default: /compat/ubuntu
   -L: (L)inux user-specified: /compat/<your_linux_compat>
   -H: (H)eadless. Explicitly prevent a new Xephyr instance.
   -N: (N)orun. Print the bhyve command that would be run,
       but do not launch. Only applies to VMs.
   -p: (p)opup. Receive command for <jail> via temporary popup. 
       Use this in combination with quick-key settings.
   -q: (q)uiet. Stdout suppressed.
   -r: (r)oot. Run cmd as root. Default is unprivileged user
   -s: (s)shell. Specify a shell to use. 
   -u: (u)ser. Run cmd as <user>. Default is unpriveleged
       user, which is the same name as the jail.
   -x: (x)ephyr. Explicitly launch a new X11 Xephyr instance.
       If jail isnt specified, default is the focused window.
   -X: (X)ephyr. Launch app inside the focused Xephyr window.

ENDOFUSAGE
		;;
	esac
}


