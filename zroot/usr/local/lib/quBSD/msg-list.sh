#!/bin/sh

msg_list() {
	case "$_message" in
	_e1) cat << ENDOFMSG

   Unable to differentiate betweeen desired JAIL and PARAM.
   Use options [-j <jail>] and/or [-p <PARAM>] to deliniate.
ENDOFMSG
	;;
	_m1) cat << ENDOFMSG
$0: NO RESULTS TO SHOW
ENDOFMSG
	;;
	usage) cat << ENDOFUSAGE

qb-list: List all parameters associated with jail/VM;
         AND/OR zfs datasets associated with jails/VM.

         Jail/VM specific parameters are listed first,
         followed by '#default' parameters for reference.

Robust script that'll respond to any valid combo of:
       qb-list <opts> <jail> <parameter>
       [-j][-p] typically not needed

Usage: qb-list [-aHlsz]   {will show all jails/VMs}
       qb-list [-aHlsz] <jail> OR [-j <jail>]
           {#default values substituted for missing params}
       qb-list [-aHlsz] <jail> <parameter>
       qb-list <parameter> OR [-p <parameter>]
       qb-list [-aHlsz] [-j <jail>] [-p <parameter>]

   -a: (a)autosnap. Show qubsd:autosnap column in zfs output
   -h: (h)elp: Outputs this help message
   -H: (H)eaders (none). Scripting mode, no headers for PARAMs
   -j: (j)ail: Show qmap settings for <jail>
   -l: (l)ist: List names of all unique jails and VMs
   -p: (p)arameter: Show all qmap entries with <parameter>
   -s: (s)napshots: Show zfs snapshots in results
   -z: (z)fs: Show zfs datasets (snapshots only with [-s])
   -Z: (Z)fs: ONLY show zfs datasets, but not parameters

For a list and description of PARAMETERS, run:
   qb-help params

ENDOFUSAGE
		;;
	esac
}
