#!/bin/sh

get_msg_qb_autosnap() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _action is optional, and can be used to exit and/or show usage

   local _message
   local _action

	_message="$1"
	_action="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

qb-autosnap: ERROR: Format for [-t] must be <integer><unit-of-time>
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

qb-autosnap: ERROR: Invalid option selected
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

qb-autosnap:  Tool for automated snapshots and thinning 

Usage:  qb-autosnap 
        qb-autosnap [-d][-t <integer><unit-of-time>]
        qb-autosnap [-l dataset|snapshot]

   -d:  (d)estroy snapshots older than qubsd:destroy-date.
   -h:  (h)elp.  Output this help message.
   -l:  (l)ist associated datasets and exit. Can filter with
        <dataset> or <snapshot>. No arguments will show all.
   -s:  (s)napshot datasets tagged with qubsd:autosnap.
   -t:  (t)ime-to-live:  TTL_UNITS are:  m|H|D|W|Y  
                         For example:  120m | 48H | 30D 
        If [-t] unspecified, snapshot will never be thinned

This tool creates custom ZFS User Properties to track and 
manage all datasets associated with qb-autosnap:
   qubsd:autosnap      Designates inclusion in autosnap 
   qubsd:time-to-live  Human readable surive time of snapshot 
   qubsd:destroy-date  Unix time to destroy snapshot (thin) 
   qubsd:autocreated   All datasets associated with this tool 
   qubsd:backup        Backups sync'd to secondary dataset 
       Recommend using a separate zpool disk for backups. 
       Future dev will allow for ssh <hostname> backups. 

Datasets can be added/removed from management, with ZFS: 
   zfs set qubsd:autosnap=<true|false> <dataset>

This script integrates into /etc/crontab. User must manually
uncomment lines to activate. Edit lines to adjust frequency. 

ENDOFUSAGE
}

