#!/bin/sh

msg_rename() {
	case "$_message" in
	_e0) cat << ENDOFMSG
< $JAIL > is invalid/incomplete. If you still wish to
rename whatever pieces might exist, use [-f] (force).
ENDOFMSG
	;;
	_e1) cat << ENDOFMSG
< $_jail > could not be stopped. Aborting qb-rename.
ENDOFMSG
	;;
	_m1) cat << ENDOFMSG
The following jails/VMs have a dependency on < $JAIL >
They will be stopped/updated. To prevent this, use [-n]
ENDOFMSG
chk_isblank "$_CLIENTS"  || echo $_CLIENTS
chk_isblank "$ROOT_FOR"  || echo $ROOT_FOR
chk_isblank "$TEMPL_FOR" || echo $TEMPL_FOR
echo -e "\nCONTINUE? (Y/n): \c"
	;;
	_m2) cat << ENDOFMSG
EXITING. No changes were made.
ENDOFMSG
	;;
	_m3) cat << ENDOFMSG
Rename complete
ENDOFMSG
	;;
	_m4) cat << ENDOFMSG
Restarting jails/VMs that were stopped.
ENDOFMSG
	;;
	usage) cat << ENDOFUSAGE

qb-rename: Renames <jail> ; and automatically updates any
jails which depend on it as a gateway, root, or template.

Usage: qb-rename [-d][-f] <jail> <new_jailname>
   -f: (f)orce rename, even if jail is invalid/incomplete
   -h: (h)elp. Outputs this help message
   -n: (n)o_update. Do not update dependent jails/VMs.

ENDOFUSAGE
		;;
	esac
}

