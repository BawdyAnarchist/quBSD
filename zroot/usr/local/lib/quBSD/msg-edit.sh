#!/bin/sh

msg_edit() {
	while getopts eEm:M:u opts ; do case $opts in
		e) local _exit="exit 0" ;;
		E) local _exit="exit 1" ;;
		m) local _message="$OPTARG" ;;
		M) local _message2="$OPTARG" ;;
		u) local _usage="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	# FORCE overrides
	if [ -n "$FORCE" ] ; then
		# Do not exit the script on errors
		unset _exit ; unset _message2
		# The only message that should be shown, is the result.
		[ ! "$_message" = "_8" ] && unset _message
	fi

	case "$_message" in
	_e0) cat << ENDOFMSG
Missing argument. Need jail, parameter, and value (unless deleting line)
ENDOFMSG
		;;
	_e1) cat << ENDOFMSG
Jail/VM: < $JAIL > doesn't exist in QMAP. Check your spelling.
ENDOFMSG
		;;
	_e2) cat << ENDOFMSG
< $PARAM > isnt valid for CLASS: $CLASS. Valid params are:
   $FILT_PARAMS
ENDOFMSG
		;;
	_e3) cat << ENDOFMSG
Combination of < $JAIL $PARAM > not found in qubsd.conf
ENDOFMSG
		;;
	_e4) cat << ENDOFMSG
< CLASS > should almost never be changed.
ENDOFMSG
		;;
	_w0) cat << ENDOFMSG

ALERT: Changing GATEWAY to < $VALUE > but IPV4 is set to.
IP is necessary to connect < $JAIL > to < $VALUE >.

ENDOFMSG
echo -e "Would you like to change this to auto? (Y/n): \c"
	;;
	_w1) cat << ENDOFMSG
ALERT: ROOTENV is typically not changed, but it can be.
ENDOFMSG
		;;
	_w2) cat << ENDOFMSG
ALERT: For changes to take effect, restart the following:
ENDOFMSG

[ -n "$_restart1" ] && echo "    $_restart1"
[ -n "$_restart2" ] && echo "    $_restart2"
echo -e "Should qb-edit to restart these jails? (y/n):  \c"
		;;
	_m1) cat << ENDOFMSG
< $VALUE > is the same as the old value. No changes made.
ENDOFMSG
		;;
	_m2) [ -z "$_force" ] && cat << ENDOFMSG
Run again with [-f] to force modification.
ENDOFMSG
		;;
	_m3)
			echo -e "Success \c"
			qb-list -j $JAIL -p $PARAM
		;;
	_m4) cat << ENDOFMSG
Deleted the following line(s):
$_delline
ENDOFMSG
		;;
	_m5) cat << ENDOFMSG
New setting is same as #default:
$_default
ENDOFMSG
		;;
	usage) cat << ENDOFUSAGE

qb-edit:  Modify jail parameters in qubsd.conf

Usage: qb-edit <jail> <PARAMETER> <value>
       qb-edit [-h] | [-f][-q][-r] <jail> <PARAM> <value>
       qb-edit [-d][-q] <jail> <param> {<value>}  {optional}

   -d: (d)elete line. If <value> is not specified, then all
       lines matching: <jail> <param> will be deleted.
   -f: (f)orce. Ignore errors and modify. Error msgs suppressed
   -h: (h)elp. Outputs this help message
   -q: (q)uiet output, do not print anything to stdout
   -r: (r)estart the required jails for changes to take effect

For a list and description of PARAMETERS, run:
   qb-help params

ENDOFUSAGE
		;;
	esac
}

