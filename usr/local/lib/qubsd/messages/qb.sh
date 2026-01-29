#!/bin/sh

msg_qb() {
	while getopts eEm:quV opts ; do case $opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		q) local _q="true" ;;
		u) local _usage="true" ;;
		V) local _V="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	# Assemble/retreive the message
	_MESSAGE=$([ -z "${_message##_e*}" ] && echo "ERROR:  ${0##*/}" \
		; retreive_msg "$@" ; [ "$GET_MSG" ] && echo "$GET_MSG")

	# If exiting with error, send it to the log
	[ "$_exit" = "exit 1" ] && echo -e "$(date "+%Y-%m-%d_%H:%M")  $0\n$_MESSAGE" >> $QLOG

	# If -q wasnt specified, print message to the terminal
	[ -z "$_q" ] && echo "$_MESSAGE"

	# Evaluate usage and exit code
	[ $_usage ] && usage
	eval $_exit :
}

retreive_msg() {
	case "$_message" in
	_e1) cat << ENDOFMSG
ERROR: No command provided 
ENDOFMSG
		;;
	_e2) cat << ENDOFMSG
ERROR: < $1 > not found. Please provide a legitimate command to qb.
ENDOFMSG
		;;
	esac
}

usage() { cat << ENDOFUSAGE
qb: Primary user-interface for executing quBSD system command/control. 

Usage:
   qb [-h] | <command> <options>
   -h: (h)elp. Outputs this help message.

Commands: <command> [-h] for help with any individual command.
   autosnap
      Automated cron-based ZFS snapshots for your entire system
   backup
      Send duplicates of your ZFS datasets to a separate storage location
   cmd
      Primary means to launch commands in a jail, or launch a VM
   connect
      Adhoc network connection between two running jails
   create
      Single source for installing new jails or VMs
   destroy
      Destroy a container
   dpi
      Change your screen dpi (usually for sizing an app before launch)
   edit
      Edit the PARAMS of a container
   flags
      Change the flags (schg/uarch) for an entire jail
   hostnet
      Bring up a network connection on host (only for updates and new pkgs)
   i3-genconf
      i3wm - Converts your i3gen.conf into a usable i3 config
   i3-launch
      i3wm - Launches the programs/commands in your i3launch.conf
   i3-windows
      i3wm - Tells you which workspaces have which windows open
   ivpn
      Queries ivpn.net, allows you to select a new server, modifies wg.conf 
   list
      List containers, parameters, their datasets and current values 
   record
      Not maintained. Was designed to adhoc attach recording dev to jail 
   rename
      Rename any container
   start
      Not maintained, does not work, prevented from execution for now
   stat
      Real-time update for container status, settings, and resource usage
   stop
      Not maintained, does not work, prevented from execution for now
ENDOFUSAGE
}

