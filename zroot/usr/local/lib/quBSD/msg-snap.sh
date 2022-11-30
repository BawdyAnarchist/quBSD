#!/bin/sh

get_msg_qb_snap() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _action is optional, and can be used to exit and/or show usage

	local _message
	local _action
	_message="$1"
	_action="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: Mutually exclusive options: [-c|-d|-l]
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: need to specify an action [-c|-d|-l]
ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: The user provided date < $DEL_DATE > 
       doesn't match script requirements.
ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ERROR: < ${_ZJAIL}${DATELABEL} > already exists.
       Snapshot labels are based on HH:mm ; so either
       delete this snapshot, or wait 1m and try agin.

ENDOFMSG
	;;
	_5) cat << ENDOFMSG

Success. To see new state of snapshots: qb-snap -l $JAIL 
ENDOFMSG
	;;
	_6) cat << ENDOFMSG

ALERT: < $JAIL > did not have any snapshots older than
       < $DEL_DATE > under the < $_ZFS > dataset.
       No changes were made. Exiting.

ENDOFMSG
	;;
	_7) cat << ENDOFMSG

The following snapshots will be destroyed:
$_DESTROY

The following jails are dependent on these snapshots,
and will be stopped if running:  
$_DEPENDS

ENDOFMSG
echo -e "WOULD YOU LIKE TO PROCEED? Fully type \"yes\": \c"
	;;
	_8) cat << ENDOFMSG

Exiting. No changes were made.
ENDOFMSG
	;;
	_9) cat << ENDOFMSG

ERROR: An error occurred while trying to stop < $_jail >.
       It's recommended that the cause be found before 
       attempting to destroy snapshots. Exiting.

ENDOFMSG
	;;
	_10) cat << ENDOFMSG

Success. To see new state of snapshots: qb-snap -l $JAIL 
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

qb-snap: Snapshot management tool for individual jails.
         Create, destroy, or list snapshots for any jail.

Usage: qb-snap [-c|-d|-l] <jail>
       qb-snap [-d <date>] <jail>

   -c: (c)create snapshot of <jail>. Snapshot will have
       the format:  <jail>@MMMdd_HH:mm_USER    
       Example: zroot/quBSD/jails/0net@Dec31_23:15_USER
   -d: (d)estroy snapshot(s) of <jail> older than <date>.
       <date> must be in ISO format: YYYY-MM-DDTHH:mm
       Example: 2022-12-31T23:15 
!ALL <JAIL> SNAPSHOTS OLDER THAN <date> WILL BE DESTROYED
   -h: (h)elp. Outputs this help message
   -l: (l)ist all snapshots of <jail>
   -y: (y)es. Assume "yes" to final confirmation before
       removing dependent jails and destroying snapshots.

ENDOFUSAGE
}



