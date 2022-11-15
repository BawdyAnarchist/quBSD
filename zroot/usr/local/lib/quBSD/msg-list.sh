#!/bin/sh

get_msg_qb_list() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _action is optional, and can be used to exit and/or show usage

   local _message
   local _action

	_message="$1"
	_action="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: must specify a jail, parameter, or [-z]
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Jail: < $JAIL > doesn't exist or is not configured properly
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: The parameter < $param > wasn't found in jailmap.conf
ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ERROR: Combination of < ${jail} > < ${param} > 
       were not found in jailmap.conf 
ENDOFMSG
	;;
	_5) cat << ENDOFMSG

ERROR: Invalid combination of options 
ENDOFMSG
	;;
	_6) cat << ENDOFMSG

ERROR: Postional arguments are not used. Use [-j|-p|-z] 
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

qb-list:  Lists jails and parameters from jailmap.conf,
          or datasets associated with a jail.

Usage: qb-list [-p <parameter>] 
       qb-list [-j <jail>] [-p <parameter>]
       qb-list [-h]|[-z] [-j <jail>] 
   -h: (h)elp:  Outputs this help message
   -j: (j)ail:  Show all settings for <jail>
   -l: (l)ist:  List names of all unique jails and containers 
   -p: (p)arameter:  Shows setting of PARAMETER for all jails
   -z: (z)fs:  List all zfs datasets associated with <jail>

   If no args provided, all jails and VMs listed 
   inside jailmap.conf will be sent to stdout

PARAMETERS   Saved at:  /usr/local/etc/quBSD/jailmap.conf
autostart:   Automatically start the jail during host boot. 
class:       appjail, dispjail, or rootjail
cpuset:      CPUs a jail may use, or \`none' for no limit
IP0:         IPv4 address for the jail.
maxmem:      RAM maximum allocation, or \'none' for no limit 
no_destroy:  Prevents accidental destruction of a jail
rootjail:    Fully installed rootjail is cloned for <jail>
schg:        Directories to receive schg flags: all|sys|none
seclvl:      kern.securelevel to protect <jail>: -1|0|1|2|3
template:    Dispjails require a template to clone.
tunnel:      Gateway to provides <jail> with network connection 
devfs_ruleset=  Provided for reference. See /etc/jail.conf

ENDOFUSAGE
}
