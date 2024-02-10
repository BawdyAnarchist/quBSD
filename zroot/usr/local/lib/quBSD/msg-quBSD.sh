#!/bin/sh

get_msg() {
	local _msg1= ; local _msg2= ; local _error

   # Quiet option finally resolves.
	while getopts l:m:M:qV opts ; do case $opts in
		m) _msg1="$OPTARG" ;;
		M) _msg2="$OPTARG" ;;
		q) local _q="true" ;;
		V) local _V="true" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	# DEBUG helps to see what the chain of functions was for an error.
	[ "$DEBUG" = "1" ] && echo "$(date "+%Y-%m-%d_%H:%M")  $0  ${_FN}" >> $QBLOG

	case $_msg1 in
		_m*) [ -z "$_q" ] && msg_qubsd "$@" ;;
		_w*|_e*) # Append messages to top of $ERR1. Must end with `|| :;}` , for `&& cp -a` to work
			{ msg_qubsd "$@" ; [ "$_msg2" ] && _msg1="$_msg2" && msg_qubsd "$@" \
				; [ -s "$ERR1" ] && cat $ERR1 || :;} > $ERR2 && cp -a $ERR2 $ERR1
			;;
	esac

	unset _msg1 _msg2
	return 0
}

msg_qubsd() {
	case "$_msg1" in
	_e0) cat << ENDOFMSG
   $_fn expected to be passed a $1, but was null
ENDOFMSG
		;;
	_e1) cat << ENDOFMSG
   < $1 > is an invalid $2
ENDOFMSG
	;;
	_e2) cat << ENDOFMSG
   < $1 > has no $2 in QMAP
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG
   < $1 > has an invalid $2 in QMAP
ENDOFMSG
		;;
	_e4) cat << ENDOFMSG
   < $1 > is missing from /etc/jail.conf
ENDOFMSG
	;;
	_e5) cat << ENDOFMSG
   < $1 > has no ZFS dataset at: < $2 >
ENDOFMSG
	;;
	_e6) cat << ENDOFMSG
   < $1 > is a dispjail. Can't have another dispjail as its TEMPLATE
ENDOFMSG
	;;
	_e6_1) cat << ENDOFMSG
   Dispjail templates cannot be dispjails themselves.
ENDOFMSG
	;;
	_e7) cat << ENDOFMSG
   < $1 > has an invalide TEMPLATE: < $2 >
ENDOFMSG
	;;
	_e8) cat << ENDOFMSG
   < $1 > is a ROOTENV. For security, it should never be a GATEWAY.
ENDOFMSG
	;;
	_e9) cat << ENDOFMSG
   ${0##*/}: Failed to retreive a valid value for < $1 >
ENDOFMSG
	;;
	_e10) cat << ENDOFMSG
   SubError: Invalid IPv4. Use CIDR notation, <auto>, or <none>.
ENDOFMSG
	;;
	_e11) cat << ENDOFMSG
   SubError: Invalid option for a /usr/local/lib/quBSD/quBSD.sh function
ENDOFMSG
	;;
	_e12) cat << ENDOFMSG
   SubError: Missing argument. Must specify a < $1 >
ENDOFMSG
	;;
	_e13) cat << ENDOFMSG
   SubError: The combination of < $1 > < $2 > was not found in QMAP.
ENDOFMSG
	;;
	_e14) cat << ENDOFMSG
   SubError: Received an invalid option for a function in /usr/local/lib/quBSD/quBSD.sh
   This is likely a bug with quBSD, please report it.
   For details see: $QBLOG
ENDOFMSG
	;;
	_e15) cat << ENDOFMSG
   SubError: Proposed jailname < $1 > is disallowed.
ENDOFMSG
	;;
	_e15_1) cat << ENDOFMSG
   SubError: Proposed jailname < $1 > is already in use
   for at least one of the following:  jail.conf,
   qubsdmap.conf, or has a zfs dataset under quBSD.
Use \`qb-destroy' to remove any lingering pieces of a jail
ENDOFMSG
	;;
	_e15_2) cat << ENDOFMSG
   SubError: Proposed names must start and end with alpha-numeric.
   It may contain non-consecutive \`-' or \`_'
   (dash or underscore), but no other special characters.
ENDOFMSG
	;;
	_e16) cat << ENDOFMSG
   SubError: < $1 > needs to be designated as a
       < $2 > in qubsdmap.conf
ENDOFMSG
	;;
	_e17) cat << ENDOFMSG
   Missing argument for: $_fn(). < $1 > must be provided.
ENDOFMSG
	;;
	_e18) cat << ENDOFMSG
   SubError: < $1 > Must be <true or false>
ENDOFMSG
	;;
	_e19) cat << ENDOFMSG
   SubError: VCPUS must be less than or equal to the number
   of physical cores on host < $2 > ; AND
   less than or equal to the bhyve limit of 16.
ENDOFMSG
	;;
	_e20) cat << ENDOFMSG
   SubError: RAM allocation < $1 > should be less than the
   host's available RAM < $2 bytes >
ENDOFMSG
	;;
	_e21) cat << ENDOFMSG
   SubError: \`none' is not permitted for VM memsize
ENDOFMSG
	;;
	_e22) cat << ENDOFMSG
   SubError: PCI device < $1 > doesn't exist on the host machine.
ENDOFMSG
	;;
	_e23) cat << ENDOFMSG
   SubError: PCI device < $1 > exists on host, but isn't
   designated as ppt. Check that it's in /boot/loader.conf
   and reboot host. Note: In loader.conf, use the form:
   pptdevs="$2"
ENDOFMSG
	;;
	_e24) cat << ENDOFMSG
   SubError: Cant access PCI device < $1 >
   Likely attached to another VM.
ENDOFMSG
	;;
	_e25) cat << ENDOFMSG
   SubError: Was unable to re-attach PCI device < $1 >
   after detaching (to probe if it was busy or not).
ENDOFMSG
	;;
	_e26) cat << ENDOFMSG
   SubError: PCI device < $1 > is not attached.
   Attempted to attach with devctl, but failed.
ENDOFMSG
	;;
	_e27) cat << ENDOFMSG
UNUSED
ENDOFMSG
	;;
	_e28) cat << ENDOFMSG
   SubError: A valid CLASS was not found for jail: < $JAIL >
ENDOFMSG
	;;
	_e29) cat << ENDOFMSG

   SubError: < $1 > Contains an invalid argument for bhyve.
       The only permissible bhyve options here, are those
       which require no additiona args:  AaCDeHhPSuWwxY
       !note! - do not include the '-'
ENDOFMSG
	;;
	_e30) cat << ENDOFMSG

   SubError: < $1 > contains a duplicate character.
ENDOFMSG
	;;
	_e31) cat << ENDOFMSG

   SubError: VM < $1 > failed to launch
ENDOFMSG
	;;
	_e32) cat << ENDOFMSG
quBSD msg: VM < $1 > has ended
ENDOFMSG
	;;
	_e33) cat << ENDOFMSG

   SubError: Tried to launch < $1 > but there were
       errors while assembling VM parameters.
ENDOFMSG
	;;
	_e40) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_e41) cat << ENDOFMSG

   SubError: < $1 > could not be started. For more
       information, see log at: $QBLOG
ENDOFMSG
	;;
	_e42) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_e43) cat << ENDOFMSG
ENDOFMSG
	;;
	_e44) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_e45) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_e46) cat << ENDOFMSG

   SubError: Failed to find open IP for < $1 >

       It's permissible to use the same IP twice; but ensure that
       jails with the same IP aren't connected to the same gateway.
ENDOFMSG
	;;
	_e47) cat << ENDOFMSG

   SubError: Parameter < $1 > for < $2 >
       had a null value in $QBDIR/qubsdmap.conf

ENDOFMSG
	;;
	_e48) cat << ENDOFMSG

   SubError: < $1 > is not a clone (has no zfs origin).
       Likely is a ROOTENV.
ENDOFMSG
	;;
	_e49) cat << ENDOFMSG

   SubError: < $1 > needs a ROOTENV clone. However, its
       ROOTENV < $2 > has no existing snapshots,
       and is curently running. Running ROOTENVs should
       not be snapshot/cloned until turned off.

ENDOFMSG
	;;
	_e50) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_e51) cat << ENDOFMSG

   SubError: ${2##*bin/} failed to ${2##*qb-} all jails/VMs
       within the allotted timeout of < $2 secs >.
ENDOFMSG
	;;
	_e52) cat << ENDOFMSG
   SubError: $0 did not find any jails to ${0##*qb-}
ENDOFMSG
	;;
	_e53) cat << ENDOFMSG

   SubError: No jails to start. Please specify [-a|-A|-f <file>],
or < jail list > at the end of the command.
ENDOFMSG
	;;
	_e54) cat << ENDOFMSG

   SubError: [-e] can only be used with [-a|-A|-f <file>], because
the positional params are assumed to be jail starts.
ENDOFMSG
	;;
	_e55) cat << ENDOFMSG

   SubError: The file < $_SOURCE > doesn't exist.
ENDOFMSG
	;;
	_e56) cat << ENDOFMSG

   SubError: [-e] should come with a < jail list > as positional
parameters at the end of the command.
ENDOFMSG
	;;
	_e57) cat << ENDOFMSG

   SubError: The file < $_EXFILE > doesn't exist.
ENDOFMSG
	;;
	_e58) cat << ENDOFMSG

   SubError: Valid bhyve resolutions for VNC viewer are as follows:
       640x480 | 800x600 | 1024x768 | 1920x1080
ENDOFMSG
	;;
	_e59) cat << ENDOFMSG

   SubError: $1 must be an integer
ENDOFMSG
	;;
	_e60) cat << ENDOFMSG

   SubError: $1 Should be $2 < $3 >
ENDOFMSG
	;;
	_w1) cat << ENDOFMSG

WARNING: < $1 > Overlaps with an IP already in use.
         The same IP can be used twice; but ensure that jails
         with the same IP aren't connected to the same gateway.
ENDOFMSG
	;;
	_w2) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_w3) cat << ENDOFMSG

WARNING: < $1 > had to be forcibly stopped. Recommend double
         checking mounts with: mount | grep $1
         For details see log at: $QBLOG
ENDOFMSG
	;;
	_w4) cat << ENDOFMSG

WARNING: < $1 > could not be stopped. Forcible stop failed.
         Recommend running the following commands:
				jail -R $1
				mount | grep $1
         For more info, see log at: $QBLOG
ENDOFMSG
	;;
	_m1) cat << ENDOFMSG

ALERT: < $2 > is the gateway jail for all external
         network traffic. Setting IP to < $1 > will
         prevent all traffic to outside networks (internet).
ENDOFMSG
	;;
	_m2) cat << ENDOFMSG

ALERT: < $1 > diverges from quBSD convention.
       See table below for typical assignments.
JAIL              GATEWAY        IPv4 Range
net-firewall      nicvm          External Router Dependent
net-<gateway>     net-firewall   10.255.x.2/30
serv-jails        net-firewall   10.128.x.2/30
appjails          net-<gateway>  10.1.x.2/30
cjails            none           10.99.x.2/30
usbvm             variable       10.88.88.1/30
< adhoc created by qb-connect >  10.99.x.2/30
ENDOFMSG
	;;
	_m3) cat << ENDOFMSG

ALERT: < $2 > is a < net- > jail, which typically
         pass external traffic for client jails. Setting IP
         to < $1 > will prevent < $2 > and its
         clients from reaching the outside internet.
ENDOFMSG
	;;
	_m4) cat << ENDOFMSG

ALERT: Assigning IP to < $2 > which has no gateway.
ENDOFMSG
	;;
	_m5) cat << ENDOFMSG

ALERT: Another instance of qb-start or qb-stop is running.
       Will wait for < $1 secs > before aborting.
ENDOFMSG
	;;
	_m6) cat << ENDOFMSG

EXITED $0
ENDOFMSG
	;;
	_m7) cat << ENDOFMSG

Waiting for < $1 > to stop. Timeout in < $2 seconds >
ENDOFMSG
	;;
	_m8) cat << ENDOFMSG
${0##*/} is starting < $1 >
ENDOFMSG
	;;
	_m9) cat << ENDOFMSG
${0##*/} is stopping < $1 >
ENDOFMSG
	;;
	esac
}
