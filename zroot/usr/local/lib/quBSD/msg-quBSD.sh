#!/bin/sh

get_msg() {
	# $1 : _message is pulled by very long case statement
	# $2 : _value of the thing that was checked ($1 from the caller)
	# $3 : _passvar is a supplementary parameter to aid message specificity.

   # Quiet option finally resolves. Will return 0 to caller immediately
	while getopts m:q opts ; do case $opts in
		m) local _message="$OPTARG" ;;
		q) local _q ; return 0 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	case "$_message" in
	_e2) cat << ENDOFMSG

ERROR: < $1 > is missing a < $2 > in qubsdmap.conf
ENDOFMSG
	;;
	_e3) cat << ENDOFMSG

ERROR: < $1 > is an invalid < $2 >
ENDOFMSG
	;;
	_e4) cat << ENDOFMSG

ERROR: < $1 > is missing from /etc/jail.conf
ENDOFMSG
	;;
	_e5) cat << ENDOFMSG

ERROR: < $1 > has no ZFS dataset at: < $2 >
ENDOFMSG
	;;
	_e6) cat << ENDOFMSG

ERROR: < $1 > is a dispjail. Requires a valid template.
       Missing < template > in qubsdmap.conf
ENDOFMSG
	;;
	_e6_1) cat << ENDOFMSG

ERROR: Dispjail templates cannot be dispjails themselves.
ENDOFMSG
	;;
	_e7) cat << ENDOFMSG

ERROR: < $1 > is a dispjail, which depends on a valid
       template jail. However, the indicated template jail:
       < $2 > is invalid, as per the errors above.
ENDOFMSG
	;;
	_e8) cat << ENDOFMSG

ERROR: < $1 > is a ROOTENV. For security reasons,
       it should never be used as a gateway.

ENDOFMSG
	;;
	_e9) cat << ENDOFMSG

ERROR: ${0##*/}: Failed to retreive a valid value for < $1 >
ENDOFMSG
	;;
	_e10) cat << ENDOFMSG

ERROR: Invalid IPv4. Use CIDR notation, <auto>, or <none>.
ENDOFMSG
	;;
	_e11) cat << ENDOFMSG

ERROR: Invalid option for a /usr/local/lib/quBSD/quBSD.sh function
ENDOFMSG
	;;
	_e12) cat << ENDOFMSG

ERROR: Missing argument. Must specify a < $1 >
ENDOFMSG
	;;
	_e13) cat << ENDOFMSG

ERROR: < $1 > was not found in qubsdmap.conf, and
       < $2 > was blank in qmap. Manually edit
       $2 in /usr/local/etc/quBSD/qubsdmap.conf
ENDOFMSG
	;;
	_e14) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_e15) cat << ENDOFMSG

ERROR: Proposed jailname < $1 > is disallowed.

ENDOFMSG
	;;
	_e15_1) cat << ENDOFMSG

ERROR: Proposed jailname < $1 > is already in use
       for at least one of the following:  jail.conf,
       qubsdmap.conf, or has a zfs dataset under quBSD.

Use \`qb-destroy' to remove any lingering pieces of a jail

ENDOFMSG
	;;
	_e15_2) cat << ENDOFMSG

ERROR: Proposed names must start and end with alpha-numeric.
       It may contain non-consecutive \`-' or \`_'
       (dash or underscore), but no other special characters.

ENDOFMSG
	;;
	_e16) cat << ENDOFMSG

ERROR: < $1 > needs to be designated as a
       < $2 > in qubsdmap.conf
ENDOFMSG
	;;
	_e17) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_e18) cat << ENDOFMSG

ERROR: < $1 > Must be <true or false>
ENDOFMSG
	;;
	_e19) cat << ENDOFMSG

ERROR: VCPUS must be less than or equal to the number
       of physical cores on host < $2 > ; AND
       less than or equal to the bhyve limit of 16.
ENDOFMSG
	;;
	_e20) cat << ENDOFMSG

ERROR: RAM allocation < $1 > should be less than the
       host's available RAM < $2 bytes >
ENDOFMSG
	;;
	_e21) cat << ENDOFMSG

ERROR: \`none' is not permitted for VM memsize
ENDOFMSG
	;;
	_e22) cat << ENDOFMSG

ERROR: PCI device < $1 > doesn't exist on the host machine.
ENDOFMSG
	;;
	_e23) cat << ENDOFMSG

ERROR: PCI device < $1 > exists on host, but isn't
       designated as ppt. Check that it's in /boot/loader.conf
       and reboot host. Note: In loader.conf, use the form:
       pptdevs="$2"
ENDOFMSG
	;;
	_e24) cat << ENDOFMSG

ERROR: Cant access PCI device < $1 >
       Likely attached to another VM.
ENDOFMSG
	;;
	_e25) cat << ENDOFMSG

ERROR: Was unable to re-attach PCI device < $1 >
       after detaching (to probe if it was busy or not).
ENDOFMSG
	;;
	_e26) cat << ENDOFMSG

ERROR: PCI device < $1 > is not attached.
       Attempted to attach with devctl, but failed.
ENDOFMSG
	;;
	_e34) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_e35) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_e29) cat << ENDOFMSG

ERROR: < $1 > Contains an invalid argument for bhyve.
       The only permissible bhyve options here, are those
       which require no additiona args:  AaCDeHhPSuWwxY
       !note! - do not include the '-'
ENDOFMSG
	;;
	_e30) cat << ENDOFMSG

ERROR: < $1 > contains a duplicate character.
ENDOFMSG
	;;
	_e31) cat << ENDOFMSG

ERROR: VM < $1 > failed to launch
ENDOFMSG
	;;
	_e32) cat << ENDOFMSG
quBSD msg: VM < $1 > has ended
ENDOFMSG
	;;
	_e33) cat << ENDOFMSG

ERROR: Tried to launch < $1 > but there were
       errors while assembling VM parameters.
ENDOFMSG
	;;
	_e40) cat << ENDOFMSG
${0##*/} is starting < $1 >
ENDOFMSG
	;;
	_e41) cat << ENDOFMSG

ERROR: < $1 > could not be started. For more
       information, see log at: /var/log/quBSD.log
ENDOFMSG
	;;
	_e42) cat << ENDOFMSG
${0##*/} is shutting down < $1 >
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

ERROR: Failed to find open IP for < $1 >

       It's permissible to use the same IP twice; but ensure that
       jails with the same IP aren't connected to the same gateway.
ENDOFMSG
	;;
	_e47) cat << ENDOFMSG

ERROR: Parameter < $1 > for < $2 >
       had a null value in $QBDIR/qubsdmap.conf

ENDOFMSG
	;;
	_e48) cat << ENDOFMSG

ERROR: < $1 > is not a clone (has no zfs origin).
       Likely is a ROOTENV.
ENDOFMSG
	;;
	_e49) cat << ENDOFMSG

ERROR: < $1 > needs a ROOTENV clone. However, its
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

ERROR: ${2##*bin/} failed to ${2##*qb-} all jails/VMs
       within the allotted timeout of < $2 secs >.
ENDOFMSG
	;;
	_e52) cat << ENDOFMSG
UNUSED_UNUSED
ENDOFMSG
	;;
	_e53) cat << ENDOFMSG

ERROR: No jails to start. Please specify [-a|-A|-f <file>],
or < jail list > at the end of the command.
ENDOFMSG
	;;
	_e54) cat << ENDOFMSG

ERROR: [-e] can only be used with [-a|-A|-f <file>], because
the positional params are assumed to be jail starts.
ENDOFMSG
	;;
	_e55) cat << ENDOFMSG

ERROR: The file < $_SOURCE > doesn't exist.
ENDOFMSG
	;;
	_e56) cat << ENDOFMSG

ERROR: [-e] should come with a < jail list > as positional
parameters at the end of the command.
ENDOFMSG
	;;
	_e57) cat << ENDOFMSG

ERROR: The file < $_EXFILE > doesn't exist.
ENDOFMSG
	;;
	_e58) cat << ENDOFMSG

ERROR: Valid bhyve resolutions for VNC viewer are as follows:
       640x480 | 800x600 | 1024x768 | 1920x1080
ENDOFMSG
	;;
	_e59) cat << ENDOFMSG

ERROR: $1 must be an integer
ENDOFMSG
	;;
	_e60) cat << ENDOFMSG

ERROR: $1 Should be $2 < $3 >
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
         For details see quBSD log:  /var/log/quBSD.log
ENDOFMSG
	;;
	_w4) cat << ENDOFMSG

WARNING: < $1 > could not be stopped. Forcible stop failed.
         Recommend running the following commands:
				jail -R $1
				mount | grep $1
         For more info, see: /var/log/quBSD.log
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

Waiting for < $1 > to stop. Timeout in < $2 seconds >
ENDOFMSG
	;;
	esac
}
