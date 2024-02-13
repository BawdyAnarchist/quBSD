#!/bin/sh

msg_backup() {
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
	[ "$_exit" = "exit 1" ] && echo -e "$(date "+%Y-%m-%d_%H:%M")  $0\n$_MESSAGE" >> $QBLOG

	# If -q wasnt specified, print message to the terminal
	[ -z "$_q" ] && echo "$_MESSAGE"

	# Evaluate usage and exit code
	[ $_usage ] && usage
	eval $_exit :
}

retreive_msg() {
	case "$_message" in
	_e1) cat << ENDOFMSG
   Invalid option
ENDOFMSG
	;;
	_e2) cat << ENDOFMSG
   [-a] and [-A] are mutually exclusive.
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG
UNUSED
ENDOFMSG
	;;
	_e4) cat << ENDOFMSG
   [-z <destination_dataset>] is mandatory, or qb-backup
   doesn't know where to send the backup datasets.
ENDOFMSG
	;;
	_e5) cat << ENDOFMSG
   The destination < $ZBAK > does not exist.
   Have you imported the zpool?
ENDOFMSG
	;;
	_e6) cat << ENDOFMSG
   The dataset < ${ZBAK}/${_dataset} > already exists
   at the destination. Pass [-F] to force zfs to overwrite.
ENDOFMSG
	;;
	_e7) cat << ENDOFMSG
   No datasets were specified for backup. Either choose
   [-a|-A|-f], or specify datasets as positional parameters.
ENDOFMSG
	;;
	_e8) cat << ENDOFMSG
   < $_dataset > is not a valid zfs dataset
ENDOFMSG
	;;
	_e9) cat << ENDOFMSG
   The following ROOTENVs are currently running. To avoid
   corruption, shut these down before performing a backup.
$_ONROOTS
       [Note: After the backup begins, you may then start/use these normally]
ENDOFMSG
	;;
	_w1) cat << ENDOFMSG
ALERT:  $0
   One or more the above appjails are running. This can potentially cause
   data corruption, especially for servers, databases, and P2P nodes.
   User programs like browsers, media, and office suites, should be okay.
   BEST PRACTICE IS TO SHUT DOWN ALL JAILS/VMs BEFORE BACKUP!

ENDOFMSG
	;;
	_m1) cat << ENDOFMSG

Backup destination is:  $ZBAK
Datasets to be sent:
ENDOFMSG
echo "$_PRINTSETS" | tail -n+2 | column -t
echo -e "$_SIZE  TOTAL\n"
	;;
	_m2)
		[ "$NORUN" ] && echo '(this is a dry run)'
		echo -e "PROCEED (Y/n):  \c"
	;;
	_m3) cat << ENDOFMSG
Exiting. No backups were started.
ENDOFMSG
	;;
	_m4) cat << ENDOFMSG

BACKUP COMPLETE. See $BAK_LOG for details
ENDOFMSG
	;;
	esac
}

usage() { cat << ENDOFUSAGE

qb-backup: Tool to backup selected jails/VMs, or the entire
   $R_ZFS and $U_ZFS datasets. Designed for periodic,
   one-off backups to a physically connected device.

Notes: Not designed for network backups. quBSD's qb-autosnap
   with default crontab settings, makes the snapshot state
   too dynamic for incremental send|recv.

   Thus, default behavior creates temporary snapshots: @qbBAK
   of selected datasets. This single snap is what gets sent.

   A nice feature of qb-backup, you can do a recursive [-r]
   backup, but without implying [-R]. Thus you can send all
   real descendant datasets without sending every incremental
   snapshot. But you can still use [-R] if desired.

Usage: qb-backup [-n][-F][-r][-R] [-z <destiation_dataset>]
       [-a|-A] [-f <file>] <dataset1> <dataset2>...<datasetX>

Usage: qb-backup
   -a: (a)uto. Jails/VMs tagged with BACKUP=true in QMAP; plus
       datasets indicated by <FILE> or positional arguments.
   -A: (A)ll $_RZFS $U_ZFS and descendants, plus datasets
       indicated by <FILE> or pos args.  Implies [-r] for all
       datasets passed to qb-backup. Can override with [-R].
   -h: (h)elp. Outputs this help message.
   -f: (f)ile. Datasets in <FILE> are inlcuded with datasets
       indicated by [-a|-A] and/or positional arguments.
   -F: (F)orce. Carries the [-F] option to: zfs recv -F
   -n: (n)orun. Do a dry run of zfs send. Same as zfs send -n
   -r: (r)ecursively send descendant datasets, but dont send
       incremental snapshots, only temporary @qbBAK (latest).
   -R: (R)eplicate. Carries [-R] option to zfs send -R
   -z: (z)fs destination dataset for backups. IS MANDATORY.

ENDOFUSAGE
}

