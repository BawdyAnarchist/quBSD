#!/bin/sh

get_msg_destroy() {

	local _message="$1"
	local	_pass_cmd="$2"

	case "$_message" in

	_1) cat << ENDOFMSG

Exiting, no changes were made.

ENDOFMSG
	;;
	_2) cat << ENDOFMSG

ERROR: < $JAIL > has the \`no_destroy protection flag' set in
       qubsdmap.conf.  Change flag to \`false', and run again.
ENDOFMSG
	;;
	_3) cat << ENDOFMSG

ERROR: Must specificy a <jail> to destroy
ENDOFMSG
	;;
	_4) cat << ENDOFMSG
WARNING! < $JAIL > is a $CLASS
ENDOFMSG
	;;
	_5) cat << ENDOFMSG
WARNING! This will destroy the following datasets:
ENDOFMSG
	;;
	_5_1) cat << ENDOFMSG

ALERT: No datasets to destroy. Would you like to remove any
ENDOFMSG
echo -e "       lingering parts/pieces of jail/VM? (Y/n): \c"
	;;
	_6) cat << ENDOFMSG

< $zrootDestroy >
                          Totaling: $zrootSize of ondisk data
ENDOFMSG
	;;
	_7) cat << ENDOFMSG

< $zusrDestroy >
                          Totaling: $zusrSize of ondisk data

NOTE! Beware the difference between zroot jails, which are
rootjails and clones; VS zusr jails which contain user data
ENDOFMSG
	;;
	_8)
		echo -e "\n          To continue, type yes: \c"
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

qb-destroy: Destroy <jail/VM> and purge associated configs:
            jail.conf ; qubsdmap.conf ; zfs datasets

Even if jail is partially created, this command will purge it.

There is a protection mechanism for all jails/VMs. qubsdmap.conf
has a parameter called: \`no_destroy', which defaults to true.
Must manually edit this setting to false, before qb-destroy

Usage: qb-destroy [-h] <jail/VM>"
   -h: (h)elp. Outputs this help message"

ENDOFUSAGE
}

