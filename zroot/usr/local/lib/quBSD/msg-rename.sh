#!/bin/sh

msg_rename() { 
	while getopts eEm:u _opts ; do case $_opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		u) local _usage="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

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

	[ $_usage ] && usage
	eval $_exit :
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

