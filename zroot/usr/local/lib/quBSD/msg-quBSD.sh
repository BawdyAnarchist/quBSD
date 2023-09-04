#!/bin/sh

get_msg() { 
	# $1 : _message is pulled by very long case statement
	# $2 : _value of the thing that was checked ($1 from the caller)
	# $3 : _passvar is a supplementary parameter to aid message specificity.

   # Quiet option finally resolves. Will return 0 to caller immediately 
	local _q ; local _opts 
	getopts q _opts && return 0 
	shift $(( OPTIND - 1 ))

	local _message="$1"
	local _value="$2"
	local _passvar="$3"

	case "$_message" in

	_0) cat << ENDOFMSG

ERROR: Missing argument. Must specify a < $_value >

ENDOFMSG
	;;	
	_1) cat << ENDOFMSG

ERROR: Invalid variable to quBSD.sh function: create_epairs() 

ENDOFMSG
	;;	
	_cj1) cat << ENDOFMSG

ERROR: < $_value > is missing a < $_passvar > in jailmap.conf
ENDOFMSG
	;;	
	_cj2) cat << ENDOFMSG

ERROR: < $_value > is an invalid < $_passvar >
ENDOFMSG
	;;	
	_cj3) cat << ENDOFMSG

ERROR: < $_value > is missing from /etc/jail.conf
ENDOFMSG
	;;
	_cj4) cat << ENDOFMSG

ERROR: < $_value > has no ZFS dataset at: < $_passvar > 
ENDOFMSG
	;;
	_cj5) cat << ENDOFMSG

ERROR: < $_value > is a dispjail. Requires a valid template. 
       Missing < template > in jailmap.conf
ENDOFMSG
	;;
	_cj5_1) cat << ENDOFMSG

ERROR: Dispjail templates cannot be dispjails themselves. 
ENDOFMSG
	;;
	_cj6) cat << ENDOFMSG

ERROR: < $_value > is a dispjail, which depends on a valid 
       template jail. However, the indicated template jail:
       < $_passvar > is invalid, as per the errors above. 
ENDOFMSG
	;;
	_cj7) cat << ENDOFMSG

ERROR: < $_value > is invalid. Must be a single digit integer.
ENDOFMSG
	;;
	_cj7_1) cat << ENDOFMSG

ERROR: < $_value > is a rootjail or rootVM. For security
       reasons, it should never be used as a gateway. 

ENDOFMSG
	;;
	_cj7_2) cat << ENDOFMSG

ALERT: < net-firewall > should usually have a gateway, 
         a connection point to the outside internet.       
ENDOFMSG
	;;
	_cj9) cat << ENDOFMSG

ALERT: < $_passvar > is the gateway jail for all external 
         network traffic. Setting IP to < $_value > will 
         prevent all traffic to outside networks (internet). 
ENDOFMSG
	;;
	_cj10) cat << ENDOFMSG

WARNING: Invalid IPv4. Use CIDR notation, <auto>, or <none>.
ENDOFMSG
	;;
	_cj11) cat << ENDOFMSG

WARNING: < $_value > Overlaps with an IP already in use.
         The same IP can be used twice; but ensure that jails 
         with the same IP aren't connected to the same gateway. 
ENDOFMSG
	;;
	_cj12) cat << ENDOFMSG

ALERT: < $_value > diverges from quBSD convention.
       See table below for typical assignments. 
JAIL              GATEWAY        IPv4 Range
net-firewall      nicvm          External Router Dependent
net-<gateway>     net-firewall   10.255.x.2/30
serv-jails        net-firewall   10.128.x.2/30
appjails          net-<gateway>  10.1.x.2/30
usbvm             variable       10.88.88.1/30
< adhoc created by qb-connect >  10.99.x.2/30
ENDOFMSG
	;;
	_cj13) cat << ENDOFMSG

ALERT: < $_passvar > is a < net- > jail, which typically 
         pass external traffic for client jails. Setting IP 
         to < $_value > will prevent < $_passvar > and its
         clients from reaching the outside internet.
ENDOFMSG
	;;
	_cj14) cat << ENDOFMSG

ALERT: Assigning IP to < $_passvar > which has no gateway. 
ENDOFMSG
	;;
	_cj15) cat << ENDOFMSG

ERROR: Proposed jailname < $_value > is disallowed.

ENDOFMSG
	;;
	_cj15_1) cat << ENDOFMSG

ERROR: Proposed jailname < $_value > is already in use 
       for at least one of the following:  jail.conf,
       jailmap.conf, or has a zfs dataset under quBSD.

Use \`qb-destroy' to remove any lingering pieces of a jail

ENDOFMSG
	;;
	_cj15_2) cat << ENDOFMSG

ERROR: Jail must start with alpha/numeric, and then only 
       \`-' or \`_' (dash or underscore) as special chars

ENDOFMSG
	;;
	_cj16) cat << ENDOFMSG

ERROR: < $_value > needs to be designated as a
       < $_passvar > in jailmap.conf
ENDOFMSG
	;;
	_cj17) cat << ENDOFMSG

ALERT: < $_value > for jail:< $_jail > was not found in
         jailmap.conf. #default was applied instead.
ENDOFMSG
	;;
	_cj17_1) cat << ENDOFMSG

WARNING: < $_value > was not found in jailmap.conf, and 
         < $_passvar > was blank in jmap. Manually edit
         $_passvar in /usr/local/etc/quBSD/jailmap.conf
ENDOFMSG
	;;
	_cj18) cat << ENDOFMSG

ALERT: MTU is outside of sanity bounds (1200 to 1600)
ENDOFMSG
	;;
	_cj18_1) cat << ENDOFMSG

ERROR: < $_passvar >: < $_value > is invalid. Must be a number.
ENDOFMSG
	;;
	_cj19) cat << ENDOFMSG

ERROR: < $_passvar > Must be <true or false>
ENDOFMSG
	;;
	_cj20) cat << ENDOFMSG

ERROR: VCPUS must be less than or equal to the number
       of physical cores on host < $_passvar > ; AND
       less than or equal to the bhyve limit of 16. 
ENDOFMSG
	;;
	_cj21) cat << ENDOFMSG

ERROR: RAM allocation < $_value > should be less than the
       host's available RAM < $_passvar bytes >
ENDOFMSG
	;;
	_cj22) cat << ENDOFMSG

ERROR: PCI device < $_value > doesn't exist on the host machine. 
ENDOFMSG
	;;
	_cj23) cat << ENDOFMSG

ERROR: PCI device < $_value > exists on host, but isn't
       designated as ppt. Check that it's in /boot/loader.conf 
       and reboot host. Note: In loader.conf, use the form:
       pptdevs="$_passvar"
ENDOFMSG
	;;
	_cj24) cat << ENDOFMSG

ERROR: Cant access PCI device < $_value >
       Likely attached to another VM. 
ENDOFMSG
	;;
	_cj25) cat << ENDOFMSG

ERROR: Was unable to re-attach PCI device < $_value >
       after detaching (to probe if it was busy or not).
ENDOFMSG
	;;
	_cj26) cat << ENDOFMSG

ERROR: PCI device < $_value > is not attached.
       Attempted to attach with devctl, but failed.
ENDOFMSG
	;;
	_cj27) cat << ENDOFMSG

ERROR: Waiting for < $_vif > to appear on host in order to 
       connect < $_value > to its gateway, but timed out.
ENDOFMSG
	;;
	_cj28) cat << ENDOFMSG

ERROR: < $_value > attempts to use too many bhyve slots.
ENDOFMSG
	;;
	_cj29) cat << ENDOFMSG

ERROR: < $_value > Contains an invalid argument for bhyve.
       The only permissible bhyve options here, are those
       which require no additiona args:  AaCDeHhPSuWwxY
       !note! - do not include the '-'
ENDOFMSG
	;;
	_cj30) cat << ENDOFMSG

ERROR: < $_value > contains a duplicate character.
ENDOFMSG
	;;
	_cj31) cat << ENDOFMSG

ERROR: VM < $_value > failed to launch 
ENDOFMSG
	;;
	_cj32) cat << ENDOFMSG

quBSD msg: VM < $_value > has ended 
ENDOFMSG
	;;
	_jf1) cat << ENDOFMSG

$0 is starting < $_value > 
ENDOFMSG
	;;
	_jf2) cat << ENDOFMSG

ERROR: < $_value > could not be started. For more 
       information, see log at: /var/log/quBSD.log
ENDOFMSG
	;;
	_jf3) cat << ENDOFMSG

$0 is attempting to shutdown < $_value >       
ENDOFMSG
	;;
	_jf4) cat << ENDOFMSG

Normal removal failed.
$0 will attempt to forcibly removing < $_value >
ENDOFMSG
	;;
	_jf5) cat << ENDOFMSG

WARNING: < $_value > had to be forcibly stopped. 
         For details see quBSD log:  /var/log/quBSD.log
ENDOFMSG
	;;
	_jf6) cat << ENDOFMSG

WARNING: < $_value > could not be stopped. Attempt to
         forcibly stop, failed. For more info, see: 
         /var/log/quBSD.log
ENDOFMSG
	;;
	_jf7) cat << ENDOFMSG

ERROR: Failed to find open IP for < $_value > 

       It's permissible to use the same IP twice; but ensure that 
       jails with the same IP aren't connected to the same gateway. 
ENDOFMSG
	;;
	_jf8) cat << ENDOFMSG

ERROR: Parameter < $_value > for < $_passvar > 
       had a null value in $QBDIR/jailmap.conf

ENDOFMSG
	;;
	_jo0) cat << ENDOFMSG

ERROR: < $_value > is not a clone (has no zfs origin).
       Likely is a rootjail or rootVM
ENDOFMSG
	;;
	_jo1) cat << ENDOFMSG

ERROR: < $_value > needs a rootjail clone; however, there are
       no existing clones, and the rootjail at: < $_passvar > 
       is either being updated, or installing pkgs. New clone
       shouldn't be taken until these operations are complete. 

ENDOFMSG
	;;
	_jo2) cat << ENDOFMSG

${_value##*/}: All jails have ${_value#*qb-}ed
ENDOFMSG
	;;
	_jo3) cat << ENDOFMSG

ERROR: ${_value##*/} timeout. Gave up waiting for jails to ${_value#*qb-}
ENDOFMSG
	;;
	_je1) cat << ENDOFMSG

ERROR: No jails to start. Please specify [-a|-A|-f <file>],
or < jail list > at the end of the command.
ENDOFMSG
	;;
	_je2) cat << ENDOFMSG

ERROR: [-e] can only be used with [-a|-A|-f <file>], because
the positional params are assumed to be jail starts.  
ENDOFMSG
	;;
	_je3) cat << ENDOFMSG

ERROR: The file < $_SOURCE > doesn't exist.
ENDOFMSG
	;;
	_je4) cat << ENDOFMSG

ERROR: [-e] should come with a < jail list > as positional 
parameters at the end of the command. 
ENDOFMSG
	;;
	_je5) cat << ENDOFMSG

ERROR: The file < $_EXFILE > doesn't exist.
ENDOFMSG
	;;
	esac
}




