#!/bin/sh

get_msg_rename() { 

	local _message="$1"
	local _pass_cmd="$2"

	case "$_message" in
	_0) cat << ENDOFMSG

ERROR: < $JAIL > is invalid/incomplete. If you still wish to
       rename whatever pieces might exist, use [-f] (force). 
ENDOFMSG
	;;	
	_1) cat << ENDOFMSG

The following jails/VMs have a dependency on < $JAIL >
They will be stopped/updated. To prevent this, use [-n]

ENDOFMSG
chk_isblank "$_CLIENTS"  || echo $_CLIENTS
chk_isblank "$ROOT_FOR"  || echo $ROOT_FOR
chk_isblank "$TEMPL_FOR" || echo $TEMPL_FOR
echo -e "\nCONTINUE? (Y/n): \c"
	;;	
	_2) cat << ENDOFMSG

EXITING. No changes were made.
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: < $_jail > could not be stopped. Aborting qb-rename.
ENDOFMSG
	;;
	_4) cat << ENDOFMSG

Rename complete
ENDOFMSG
	;;
	_5) cat << ENDOFMSG
Restarting jails/VMs that were stopped.
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

qb-rename: Renames <jail> ; and automatically updates any
jails which depend on it as a gateway, root, or template.

Usage: qb-rename [-d][-f] <jail> <new_jailname>
   -f: (f)orce rename, even if jail is invalid/incomplete 
   -h: (h)elp. Outputs this help message
   -n: (n)o_update. Do not update dependent jails/VMs. 

ENDOFUSAGE
}

