#!/bin/sh

msg_pefs() { 
	while getopts eEm:u _opts ; do case $_opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		u) local _usage="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Mutually exclusive options [-c|-m|-u] 
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Must specify an action [-c|-m|-u] 
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: < $U_FOLDER > doesn't exist
ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ERROR: [-d] should specify a directory inside of < $JAIL > 
       < ${M_ZUSR}/${JAIL} > directory path
ENDOFMSG
	;;
	_5) cat << ENDOFMSG

ERROR: Failed to load pefs.ko kernel module.
       Check that pefs-kmod pkg is installed on host.
ENDOFMSG
	;;
	_6) cat << ENDOFMSG

ERROR: Failed to unmount < $(echo $_dir | sed "s:${M_ZUSR}:${M_QROOT}:") > 
ENDOFMSG
	;;
	_7) cat << ENDOFMSG

ERROR: Failed to unmount < $_dir > 
ENDOFMSG
	;;
	esac

	[ $_usage ] && usage
	eval $_exit :
}

usage() { cat << ENDOFUSAGE

qb-pefs: Handles pefs (encryption) operations for jails 

Usage: qb-pefs [-h] [-c|-m|-u] [-d <directory>] <jailname>
   -c: (c)reate:  Create and configure new pefs directory
   -d: (d)irectory: Target for the specified action 
       <directory> must be inside /zusr/<jail>/usr/ 
       If not specified, default directory is:
          ${M_ZUSR}/<jail>/home/<jail>/crypt
   -h: (h)elp.  Outputs this help message
   -m: (m)mount an existing pefs directory.  
   -u: (u)nmount: umount (re-encrypts the data). 

Notes: Persistent storage occurs on /zusr/<jail>/<path>
However, qb-pefs performs mount/unmount at both
/zusr/<jail>/<path/  and  /jails/<jail>/<path> 
Shutting down jail will unmount pefs at both locations.

ENDOFUSAGE
}
