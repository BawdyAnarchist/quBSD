#!/bin/sh

msg_destroy() {
	case "$_message" in
	_e1) cat << ENDOFMSG
Exiting, no changes were made.
ENDOFMSG
	;;
	_e2) cat << ENDOFMSG
< $JAIL > has NO_DESTROY set to true in QMAP.
Use qb-edit to change this to 'false' and try again.
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG
Must specificy a <jail> to destroy
ENDOFMSG
	;;
	_e4) cat << ENDOFMSG
WARNING! < $JAIL > is a $CLASS
ENDOFMSG
	;;
	_e5) cat << ENDOFMSG
WARNING! This will destroy the following datasets:
ENDOFMSG
	;;
	_e5_1) cat << ENDOFMSG

ALERT: No datasets to destroy. Would you like to remove any
ENDOFMSG
echo -e "       lingering parts/pieces of jail/VM? (Y/n): \c"
	;;
	_e6) cat << ENDOFMSG

< $zrootDestroy >
                          Totaling: $zrootSize of ondisk data
ENDOFMSG
	;;
	_e7) cat << ENDOFMSG

< $zusrDestroy >
                          Totaling: $zusrSize of ondisk data

NOTE! Beware the difference between zroot jails, which are
rootjails and clones; VS zusr jails which contain user data
ENDOFMSG
	;;
	_e8)
		echo -e "\n          To continue, type yes: \c"
	;;
	usage) cat << ENDOFUSAGE

qb-destroy: Destroy <jail/VM> and purge associated configs:
            jail.conf ; qubsdmap.conf ; zfs datasets

Even if jail is partially created, this command will purge it.
qubsdmap.conf has a parameter called \`no_destroy', which
prevents destruction of jail/VM if set to true (default).
Manually edit this setting to false, to use qb-destroy.

Usage: qb-destroy [-h] <jail/VM>"
   -h: (h)elp. Outputs this help message"

ENDOFUSAGE
		;;
	esac
}

