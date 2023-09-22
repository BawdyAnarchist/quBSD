#!/bin/sh

get_msg_list() { 

   local _message="$1"
   local _pass_cmd="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: must specify a jail, parameter, or [-z]
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Jail: < $JAIL > doesn't exist or is not configured properly
ENDOFMSG
	;;	
	_2_1) cat << ENDOFMSG

ERROR: Argument < $POS1 > was neither valid jail, nor jailmap parameter.
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

ERROR: Unable to differentiate betweeen desired JAIL and PARAM.
       Use options [-j <jail>] and/or [-p <PARAM>] to deliniate.
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

qb-list: List jails, VMs, and parameters from jailmap.conf; 
         AND/OR list zfs datasets associated with jails/VMs.

Robust script that'll respond to any valid combo of: <opts>
<jail> <parameter>. [-j] and [-p] normally arent needed. 

Usage: qb-list [-alsz]   {will show all jails/VMs}
       qb-list [-alsz] <jail> <parameter>
       qb-list <parameter> OR [-p <parameter>]
       qb-list [-alsz] <jail> OR [-j <jail>] 
       qb-list [-alsz] [-j <jail>] [-p <parameter>]

   -a: (a)autosnap. Show qubsd:autosnap column in zfs output
   -h: (h)elp: Outputs this help message
   -j: (j)ail: Show jailmap settings for <jail>
   -l: (l)ist: List names of all unique jails and VMs 
   -p: (p)arameter: All jailmap entries with <parameter>
   -s: (s)napshots: Show zfs snapshots in results 
   -z: (z)fs: Show zfs datasets (snapshots only with [-s])

For a list and description of PARAMETERS, run:
   qb-help params
ENDOFUSAGE
}
