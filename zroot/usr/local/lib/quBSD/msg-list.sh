#!/bin/sh

get_msg_list() {

   local _message="$1"
   local _pass_cmd="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Argument < $POS1 > was neither valid jail, nor jailmap parameter.
ENDOFMSG
	;;
	_2) cat << ENDOFMSG

ERROR: Unable to differentiate betweeen desired JAIL and PARAM.
       Use options [-j <jail>] and/or [-p <PARAM>] to deliniate.
ENDOFMSG
	;;
	_3) cat << ENDOFMSG

ERROR: A zfs option was selected [-a|-s|-z], but no datasets exist for < $JAIL >
ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ERROR: Jail: < $JAIL > doesn't exist or is not configured properly
ERROR: The parameter < $param > wasn't found in jailmap.conf
ERROR: Combination of < ${jail} > < ${param} >
       were not found in jailmap.conf
ENDOFMSG
	;;
	_5) cat << ENDOFMSG

ERROR: Invalid combination of options
ENDOFMSG
	;;
	_6) cat << ENDOFMSG

NO RESULTS TO SHOW
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

qb-list: List all parameters associated with jail/VM;
         AND/OR zfs datasets associated with jails/VM.

         Jail/VM specific parameters are listed first,
         followed by '#default' parameters for reference.

Robust script that'll respond to any valid combo of:
       qb-list <opts> <jail> <parameter>
       [-j][-p] typically not needed

Usage: qb-list [-alsz]   {will show all jails/VMs}
       qb-list [-alsz] <jail> OR [-j <jail>]
           {#default values substituted for missing params}
       qb-list [-alsz] <jail> <parameter>
       qb-list <parameter> OR [-p <parameter>]
       qb-list [-alsz] [-j <jail>] [-p <parameter>]

   -a: (a)autosnap. Show qubsd:autosnap column in zfs output
   -h: (h)elp: Outputs this help message
   -j: (j)ail: Show jailmap settings for <jail>
   -l: (l)ist: List names of all unique jails and VMs
   -p: (p)arameter: All jailmap entries with <parameter>
   -s: (s)napshots: Show zfs snapshots in results
   -z: (z)fs: Show zfs datasets (snapshots only with [-s])
   -Z: (Z)fs: ONLY show zfs datasets, but not parameters

For a list and description of PARAMETERS, run:
   qb-help params
ENDOFUSAGE
}
