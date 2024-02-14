#!/bin/sh

msg_autosnap() {
	case "$_message" in
	_e1) cat << ENDOFMSG
   Invalid [-t <time-to-live>]. Must be formatted: <integer><unit-of-time>
ENDOFMSG
		;;
	_e2) cat << ENDOFMSG
   Invalid option selected
ENDOFMSG
		;;
	_e3) cat << ENDOFMSG
   There was a problem when attempting to replace old an old $U_ZFS clone.
   dataset: < $_clone > ; origin: < $_origin >
ENDOFMSG
		;;
	usage) cat << ENDOFUSAGE

qb-autosnap:  Tool for automated snapshots and thinning
Usage:  qb-autosnap
        qb-autosnap [-d][-t <integer><unit-of-time>]
        qb-autosnap [-l dataset|snapshot]

   -d:  (d)estroy snapshots older than qubsd:destroy-date.
   -h:  (h)elp.  Outputs this help message.
   -l:  (l)ist associated datasets and exit. Can filter with
        <dataset> or <snapshot>. No arguments will show all.
   -s:  (s)napshot datasets tagged with qubsd:autosnap.
   -t:  (t)ime-to-live:  TTL_UNITS are:  m|H|D|W|Y
                         For example:  120m | 48H | 30D
        If [-t] unspecified, snapshot will never be thinned

This tool creates custom ZFS User Properties to track and
manage all datasets associated with qb-autosnap:
   qubsd:autosnap      'true' designates inclusion in autosnap
   qubsd:time-to-live  Human readable surive time of snapshot
   qubsd:destroy-date  Unix time to destroy (thin) the snap
   qubsd:autocreated   All datasets associated with this tool
   qubsd:backup        Backups sync'd to secondary dataset
       Recommend using a separate zpool disk for backups.
       Future dev will allow for ssh <hostname> backups.

Datasets can be added/removed from management, with ZFS:
   zfs set qubsd:autosnap=<true|false> <dataset>

This script integrates into /etc/crontab. User must manually
uncomment lines to activate. Edit lines to adjust frequency.

ENDOFUSAGE
		;;
	esac
}

