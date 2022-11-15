#!/bin/sh

get_msg_qubsd() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _action is optional, and can be used to exit and/or show usage

	local _message
	local _action

	_message="$1"
	_action="$2"
	
	case "$_message" in

	_0) cat << ENDOFMSG

ERROR: Missing argument. Must specify < jail >

ENDOFMSG
	;;	
	_1) cat << ENDOFMSG

ERROR: < $_jail > is invalid. Missing <class> in jailmap

ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: < $_jail > is invalid. Missing <rootjail> in jailmap

ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ERROR: < $_jail > is invalid. Missing /etc/jail.conf

ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ERROR: < $_jail > is missing a ZFS dataset at: $JAILS_ZFS

ENDOFMSG
	;;
	_5) cat << ENDOFMSG

ERROR: <$_jail > is missing a ZFS dataset at: $ZUSR_ZFS

ENDOFMSG
	;;
	_6) cat << ENDOFMSG

ERROR: < $_jail > is a dispjail. Requires a valid template. 
       Missing <template> for dispjail.

ENDOFMSG
	;;
	_7) cat << ENDOFMSG

ERROR: template for dispjail is missing dataset: $ZUSR_ZFS"

ENDOFMSG
	;;
	_8) cat << ENDOFMSG

ERROR: < $_jail > has an invalid class in jailmap.conf 

ENDOFMSG
	;;
	_9) cat << ENDOFMSG

WARNING: < $_jail > had to be forcibly stopped. For details,
       see quBSD log:  /var/log/quBSD.log
ENDOFMSG
	;;
	_10) cat << ENDOFMSG

WARNING: < $_jail > couldn't be stopped. Attempt to forcibly 
         stop failed. For more info, see: /var/log/quBSD.log
ENDOFMSG
	;;
	_11) cat << ENDOFMSG

ERROR: < $_jail > could not be started. For more 
       information, see log at: /var/log/quBSD.log
ENDOFMSG
	;;
	esac

	case $_action in 
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		pass)  return 1 ;;
	esac
}


