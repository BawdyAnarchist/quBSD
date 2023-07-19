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

ERROR: Invalid jail. 
       < $_value > has no ZFS dataset at: < $_passvar > 
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

ERROR: < $_value > is not a valid < virt_intf > name 
       for < $_passvar >.  
ENDOFMSG
	;;
	_cj7_1) cat << ENDOFMSG

ERROR: < $_value > is a rootjail, and for security
       reasons, should never be used as a gateway. 

ENDOFMSG
	;;
	_cj7_2) cat << ENDOFMSG

ALERT: < net-firewall > should usually have a gateway, 
         a connection point to the outside internet.       
ENDOFMSG
	;;
	_cj7_3) cat << ENDOFMSG

ALERT: < net-firewall > usually connects to nicvm,
         the connection point to the outside internet.       
ENDOFMSG
	;;
	_cj8) cat << ENDOFMSG

ALERT: < $_value > doesn't start with < net- > . Typically, 
       workstation jails connect to outside internet via 
       gateway jails. However, it is possible/valid to  
       configure a default connection between any two jails.  
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
       rootjail in jailmap.conf
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

ERROR: MTU: < $_value > is invalid. Must be a number.
ENDOFMSG
	;;
	_cj19) cat << ENDOFMSG

ERROR: < $_passvar > Must be <true or false>
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

ERROR: ${_value##*/qb-} timeout. Gave up waiting for jails to ${_value#*qb-}
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




