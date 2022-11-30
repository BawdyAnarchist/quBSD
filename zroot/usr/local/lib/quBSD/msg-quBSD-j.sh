#!/bin/sh

get_msg_qubsd() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _action is optional, and can be used to exit and/or show usage

	local _message ; local _value; local _passvar ; local _action
	_message="$1"  ;  _value="$2" ; _passvar="$3"  

	case "$_message" in

	# null case, no message	
	none) : ;;

	_0) cat << ENDOFMSG

ERROR: Missing argument. Must specify a < $_value >

ENDOFMSG
	;;	
	_cj0) cat << ENDOFMSG

ERROR: Invalid jail. 
       < $_value > is missing a < $_passvar > in jailmap.conf
ENDOFMSG
	;;	
	_cj1) cat << ENDOFMSG

ERROR: Invalid jail. 
       < $_value > is missing a < $_passvar > in jailmap.conf
ENDOFMSG
	;;	
	_cj2) cat << ENDOFMSG

ERROR: Invalid jail. 
       < $_value > is an invalid < $_passvar >
ENDOFMSG
	;;	
	_cj3) cat << ENDOFMSG

ERROR: Invalid jail. 
       < $_value > is missing from /etc/jail.conf
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
	_cj6) cat << ENDOFMSG

ERROR: < $_value > is a dispjail, which depends on a valid 
       template jail. However, the indicated template jail:
       < $_passvar > is invalid, as per the errors above. 
ENDOFMSG
	;;
	_cj7) cat << ENDOFMSG

ERROR: net-firewall should only have tunnel set to a tap  
       interface, typically tap0, which connects to nicvm
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

WARNING: < $_passvar > is the gateway jail for all external 
         network traffic. Setting IP to < $_value > will 
         prevent all traffic to outside networks (internet). 
ENDOFMSG
	;;
	_cj10) cat << ENDOFMSG

ERROR: Invalid IPv4. Use CIDR notation: a.b.c.d/subnet
ENDOFMSG
	;;
	_cj11) cat << ENDOFMSG

WARNING: < $_value > Overlaps with an IP already in use.
         The same IP can be used twice; but ensure that jails 
         with the same IP aren't connected to the same tunnel. 
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

WARNING: < $_passvar > is a < net- > jail, which typically 
         pass external traffic for client jails. Setting IP 
         to < $_value > will prevent < $_passvar > and its
         clients from reaching outside networks (internet). 
ENDOFMSG
	;;
	_cj14) cat << ENDOFMSG

ALERT: Assigning IP to < $_passvar > which has no tunnel. 
ENDOFMSG
	;;
	_cj15) cat << ENDOFMSG

ALERT: < $_passvar > is the gateway jail for all external 
       network traffic. IP is dependent on your external
       router. Changing this requires qb-edit to modify: 
            /zusr/net-firewall/rw/etc/rc.conf
            !Double check this file after qb-edit -f 
ENDOFMSG
	;;
	_ip1) cat << ENDOFMSG

ERROR: Failed to find open IP for < $_value > 
       in the quBSD designated range of < $_passvar > 

       It's permissible to use the same IP twice; but ensure that 
       jails with the same IP aren't connected to the same tunnel. 
ENDOFMSG
	;;
	_ip2) cat << ENDOFMSG

ENDOFMSG
	;;
	_ip2) cat << ENDOFMSG
ENDOFMSG
	;;
	_ip2) cat << ENDOFMSG
ENDOFMSG
	;;
	_ip2) cat << ENDOFMSG
ENDOFMSG
	;;
############################ ############################
############################ ############################
############################ ############################
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

WARNING: < $_jail > could not be stopped. Attempt to
         stop forcibly, failed. For more info, see: 
         /var/log/quBSD.log
ENDOFMSG
	;;
	_) cat << ENDOFMSG
ENDOFMSG
	;;
	_) cat << ENDOFMSG
ENDOFMSG
	;;
	_) cat << ENDOFMSG
ENDOFMSG
	;;
	_) cat << ENDOFMSG
ENDOFMSG
	;;
	_) cat << ENDOFMSG
ENDOFMSG
	;;
	_) cat << ENDOFMSG
ENDOFMSG
	;;
	_) cat << ENDOFMSG
ENDOFMSG
	;;
	_) cat << ENDOFMSG
ENDOFMSG
	;;
	_) cat << ENDOFMSG
ENDOFMSG
	;;
	esac
}




