#!/bin/sh

msg_exec() {
	case "$_message" in
	_e1) cat << ENDOFMSG
   < $2 > has an invalid $1 in QCONF
ENDOFMSG
		;;
	_e2) cat << ENDOFMSG
   Was unable to clone ROOTENV: < $2 > for jail: < $1 >
ENDOFMSG
		;;
	_e3) cat << ENDOFMSG
   Was unable to clone the $U_ZFS TEMPLATE: < $2 > for jail: < $1 >
ENDOFMSG
		;;
esac
}

