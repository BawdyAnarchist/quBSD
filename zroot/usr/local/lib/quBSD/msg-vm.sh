#!/bin/sh

get_msg_qb_vm() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _action is optional, and can be used to exit and/or show usage

	local _message
	local _action
	_message="$1"
	_action="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

Launching nicvm. Wait a moment
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

First command (load into memory): 
bhyveload -c stdio -m 600M -d /dev/zvol/${ZROOT}/nicvm -S nicvm

Second command (launch VM):
bhyve -c 1 -m 600M -H -A -P -S -s 0:0,hostbridge -s 1:0,lpc -s 2:0,virtio-net,   "$_TAP" -s 3:0,virtio-blk,/dev/zvol/${ZROOT}/nicvm -s 4:0,passthru,"$PPT_NIC" -l com1,stdio nicvm

ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

Shutting down nicvm to launch console. Please wait 

ENDOFMSG
	;;
	_4) cat << ENDOFMSG
echo -e "... \c"
ENDOFMSG
	;;
	_5) cat << ENDOFMSG

ERROR: Timeoute. < $_VM > has not shutdown within 90 seconds.
       Run again with [-d] to forcibly destroy. See usage.
ENDOFMSG
	;;
	_6) cat << ENDOFMSG
< $_VM > Shutdown complete
ENDOFMSG
	;;
	_7) cat << ENDOFMSG
Starting < $_VM > in console mode ...
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

qb-vm: Manages and automates nicvm connectivity
If you just need to turn on/off nicvm, use service

Usage: qb-nicvm [-c|-d|-h|-n]

   -c: (c)console. Launch console in specified VM. 
   -d: (d)estroy. Use bhyve tools to destroy VM. Warning! Use
       only if normal shutdown fails, as this can affect the
       functionality of PCI passthrough devices. 
   -h: (h)elp. Outputs this help message
   -n: (n)o_run. Don't run the console, just print the commands

ENDOFUSAGE
}

