#!/bin/sh

get_msg() {
	local _msg1= ; local _msg2= ; local _error

   # Quiet option finally resolves.
	while getopts m:M:pqV opts ; do case $opts in
		m) _msg1="$OPTARG" ;;
		M) _msg2="$OPTARG" ;;
		q) local _q="true" ;;
		p) local _popup="true" ;;
		V) local _V="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 )) ; [ "$1" = "--" ] && shift

	# DEBUG helps to see what the chain of functions was for an error.
	[ "$DEBUG" = "1" ] && echo "$(date "+%Y-%m-%d_%H:%M")  $0  ${_FN}" >> $QBLOG

	case $_msg1 in
		_m*) [ -z "$_q" ] && msg_qubsd "$@" ;;
		_w*|_e*) # Append messages to top of $ERR1. Must end with `|| :;}` , for `&& cp -a` to work
			[ -z "$_q" ] && { msg_qubsd "$@" ; [ "$_msg2" ] && _msg1="$_msg2" && msg_qubsd "$@" \
				; [ -s "$ERR1" ] && cat $ERR1 || :;} > $ERR2 && cp -a $ERR2 $ERR1

			# If -V was passed, then print the message immediately
			[ "$_V" ] && msg_qubsd "$@"
			;;
	esac

	unset _msg1 _msg2
	return 0
}

msg_qubsd() {
	case "$_msg1" in
	_e0) cat << ENDOFMSG
   func: $_fn() expected to be passed a $1, but was null
ENDOFMSG
		;;
	_e0_1) cat << ENDOFMSG
ERROR: There is no $1 PARAMETER in QCONF. Expecting a valid ZFS dataset.
       This is a global error, as quBSD can't function without this PARAMETER.
ENDOFMSG
		;;
	_e0_2) cat << ENDOFMSG
ERROR: QCONF PARAMETER $1 is set to: < $2 >, which isnt a valid zfs dataset.
       This is a global error, as quBSD can't function without this PARAMETER.
ENDOFMSG
		;;
	_e0_3) cat << ENDOFMSG
ERROR: ZFS dataset < $1 > does not have a valid mountpoint.
       This is a global error, as quBSD can't function without this mountpoint.
ENDOFMSG
		;;
	_e1) cat << ENDOFMSG
   < $1 > is an invalid $2
ENDOFMSG
	;;
	_e2) cat << ENDOFMSG
   < $1 > has no $2 in QCONF
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG
   < $1 > has an invalid $2 in QCONF
ENDOFMSG
		;;
	_e4) cat << ENDOFMSG
   ${0##*/} Failed to start < $1 >
ENDOFMSG
	;;
	_e4_1) cat << ENDOFMSG
   Failed to detect a VM process for < $1 > within 3 sec of launch.
ENDOFMSG
	;;
	_e4_2) cat << ENDOFMSG
   Can't configure network for < $1 >. Timeout, waiting for VM to launch.
   Sometimes a passthru device can delay/hang a launch if it's not responsive.
   If this VM has a PPT device (like a USB), consider rebooting.
ENDOFMSG
	;;
	_e5) cat << ENDOFMSG
   < $1 > has no ZFS dataset at: < $2 >
ENDOFMSG
	;;
	_e6_1) cat << ENDOFMSG
   < $1 > is a dispjail. Can't have another dispjail as its TEMPLATE
ENDOFMSG
	;;
	_e6_2) cat << ENDOFMSG
   < $1 > has an invalide TEMPLATE: < $2 >
ENDOFMSG
	;;
	_e7) cat << ENDOFMSG
   < $1 > is missing from $JCONF_D 
ENDOFMSG
	;;
	_e8) cat << ENDOFMSG
   < $1 > is a ROOTENV. For security, it should never be a GATEWAY.
ENDOFMSG
	;;
	_e9) cat << ENDOFMSG
   quBSD.sh function: $_fn() received an invalid option. Possibly a bug.
ENDOFMSG
	;;
	_e10) cat << ENDOFMSG
   < $1 > Must be true|false
ENDOFMSG
	;;
	_e11) cat << ENDOFMSG
   < $1 > is not an integer
ENDOFMSG
	;;
	_e12) cat << ENDOFMSG
   $1 < $2 > is not $3 $4
ENDOFMSG
	;;
	_e13) cat << ENDOFMSG
   Proposed jailname < $1 > is disallowed.
ENDOFMSG
	;;
	_e13_1) cat << ENDOFMSG
   Proposed names must start and end with alpha-numeric.
   It may contain non-consecutive \`-' or \`_'
   (dash or underscore), but no other special characters.
ENDOFMSG
	;;
	_e13_2) cat << ENDOFMSG
   JAILNAME < $1 > has an entry in at least one of the following:
   $JCONF_D, $QCONF , $U_ZFS, or $R_ZFS
   Destroy/remove all occurrences with:  qb-destroy $1
ENDOFMSG
	;;
	_e14) cat << ENDOFMSG
   < $1 > Contains an invalid bhyve option. Permissible bhyve
   options are <AaCDeHhPSuWwxY>. Don't include the dash \`-'
ENDOFMSG
	;;
	_e14_1) cat << ENDOFMSG
   < $1 > contains a duplicate character.
ENDOFMSG
	;;
	_e15) cat << ENDOFMSG
   CLASS may only be <appjail|dispjail|rootjail|cjail|rootVM|appVM>
ENDOFMSG
	;;
	_e16) cat << ENDOFMSG
   Only comma separated intergers, range, or combo of both. man 1 cpuset
ENDOFMSG
	;;
	_e16_1) cat << ENDOFMSG
   < $1 > is not among the list of valid cores. Highest core is < $2 >
ENDOFMSG
	;;
	_e17) cat << ENDOFMSG
   Must have the form: <name>=<rulenum>, and be present in devfs.rules
ENDOFMSG
	;;
	_e18) cat << ENDOFMSG
   Use CIDR notation for IPV4 addresses. Or <auto|none>.
ENDOFMSG
	;;
	_e19) cat << ENDOFMSG
   Must be <integer><G|g|M|m|K|k>. See man 8 rctl
ENDOFMSG
	;;
	_e20) cat << ENDOFMSG
   < $1 > exceeds host's available RAM: ${2}b
ENDOFMSG
	;;
	_e21) cat << ENDOFMSG
   < none > is not permitted for VM memsize
ENDOFMSG
	;;
	_e22) cat << ENDOFMSG
   Failed to attach PCI device < $1 > to VM < $2 >
ENDOFMSG
	;;
	_e22_0) cat << ENDOFMSG
   PCI device < $1 > doesn't exist on the host machine.
ENDOFMSG
	;;
	_e22_1) cat << ENDOFMSG
   Cant access PCI < $1 >. Is it attached to another VM or in use?
   Some PCI devices arent dynamic, and must be designated PPT at boottime.
ENDOFMSG
	;;
	_e22_2) cat << ENDOFMSG
   Unable to change < $1 > to PPT.
ENDOFMSG
	;;
	_e22_3) cat << ENDOFMSG
	Failed to attach PCI device < $1 > with devctl.
ENDOFMSG
	;;
	_e23) cat << ENDOFMSG
   < $1 > is an invalid CLASS for a ROOTENV.
ENDOFMSG
	;;
	_e24) cat << ENDOFMSG
   < $1 > is an invalid SECLVL. Must be: <-1|0|1|2|3>
ENDOFMSG
	;;
	_e25) cat << ENDOFMSG
   < $1 > is an invalid SCHG. Must be: <none|sys|all>
ENDOFMSG
	;;
	_e26) cat << ENDOFMSG
   < $1 > must be less-than the number of CPUs cores on
   the host ($2), and less than bhyve limit of 16.
ENDOFMSG
	;;
	_e27) cat << ENDOFMSG
   Invalid VNC. Must be: <true|false|640x480|800x600|1024x768|1920x1080>
   (A value of 'true' will default to a resolution of 1920x1080)
ENDOFMSG
	;;
	_e28) cat << ENDOFMSG
ENDOFMSG
	;;
	_e29) cat << ENDOFMSG
ENDOFMSG
	;;
	_e30) cat << ENDOFMSG
   Couldn't find open IP for < $1 > in the range: < $2 >
ENDOFMSG
	;;
	_e31) cat << ENDOFMSG
   No jails to start. Please specify [-a|-A|-f <file>],
   or < jail list > at the end of the command.
ENDOFMSG
	;;
	_e31_1) cat << ENDOFMSG
   [-e] can only be used with [-a|-A|-f <file>], because
   the positional params are assumed to be jail starts.
ENDOFMSG
	;;
	_e31_2) cat << ENDOFMSG
   The file < $_SOURCE > doesn't exist.
ENDOFMSG
	;;
	_e31_3) cat << ENDOFMSG
   [-e] requires a < jail list > as positional parameters.
ENDOFMSG
	;;
	_e31_4) cat << ENDOFMSG
   The file < $_EXFILE > doesn't exist.
ENDOFMSG
	;;
	_e31_5) cat << ENDOFMSG
   $0 did not find any jails to ${0##*qb-}
ENDOFMSG
	;;
	_e32) cat << ENDOFMSG
   < $1 > is not a clone (has no zfs origin).
   Likely is a ROOTENV.
ENDOFMSG
	;;
	_e32_1) cat << ENDOFMSG
   < $1 > needs a ROOTENV clone. However, its
   ROOTENV < $2 > has no existing snapshots,
   and is curently running. Running ROOTENVs should
   not be snapshot/cloned until turned off.
ENDOFMSG
	;;
	_e33) cat << ENDOFMSG
   ${2##*bin/} failed to ${2##*qb-} all jails/VMs
   within the allotted timeout of < $2 secs >.
ENDOFMSG
	;;
	_w1) cat << ENDOFMSG
WARNING: < $1 > had to be forcibly stopped. Recommend double
   checking mounts with: mount | grep $1
   For details see log at: $QBLOG
ENDOFMSG
	;;
	_w2) cat << ENDOFMSG
WARNING: < $1 > could not be stopped. Forcible stop failed.
Recommend running the following commands:
   jail -R $1
   mount | grep $1
   For details see log at: $QBLOG
ENDOFMSG
	;;
	_w3) cat << ENDOFMSG
WARNING: < $2 > is a gateway for external traffic. Setting
   IP to < $1 > will prevent traffic to outside internet.
ENDOFMSG
	;;
	_w4) cat << ENDOFMSG
WARNING: < $1 > Is already in use. Not fatal, but you
   must ensure jail/gateway/IP deconfliction. Recommend <auto>.
ENDOFMSG
	;;
	_w5) cat << ENDOFMSG
WARNING: Was unable to revert PPT: < $1 > to host after VM stop.
ENDOFMSG
	;;
	_m1) cat << ENDOFMSG
${0##*/} is starting < $1 >
ENDOFMSG
	;;
	_m2) cat << ENDOFMSG
${0##*/} is stopping < $1 >
ENDOFMSG
	;;
	_m3) cat << ENDOFMSG
EXITED $0
ENDOFMSG
	;;
	_m4) cat << ENDOFMSG
Waiting for < $1 > to stop. Timeout in < $2 seconds >
ENDOFMSG
	;;
	_m5) cat << ENDOFMSG
ALERT: Another instance of qb-start or qb-stop is running.
   Will wait for < $1 secs > before aborting.
ENDOFMSG
	;;
	_m6) cat << ENDOFMSG
ALERT: < $2 > is a gateway,
   pass external traffic for client jails. Setting IP
   to < $1 > will prevent < $2 > and its
   clients from reaching the outside internet.
ENDOFMSG
	;;
	_m7) cat << ENDOFMSG
ALERT: Assigning IP to < $2 > which has no gateway.
ENDOFMSG
	;;
	_m9) cat << ENDOFMSG
ALERT: < $1 > diverges from quBSD convention.
       See table below for typical assignments.
JAIL              GATEWAY        IPv4 Range
net-firewall      nicvm          External Router Dependent
net-<gateway>     net-firewall   10.255.x.2/30
serv-jails        net-firewall   10.128.x.2/30
appjails          net-<gateway>  10.1.x.2/30
cjails            none           10.99.x.2/30
< adhoc created by qb-connect >  10.88.x.2/30
ENDOFMSG
	;;
	esac
}

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

