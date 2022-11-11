#!/bin/sh

get_msg_qb_edit() { 
	_message="$1"
	_action="$2"

	# If force option is used, return to caller function
	[ "$FORCE" ] && return 0
	
	case "$_message" in

	_0) cat << ENDOFMSG
EXITING. No changes were made.
ENDOFMSG
	;;
	_1) cat << ENDOFMSG

ERROR: Missing argument. Must specify jail, parameter, and new value

ENDOFMSG
	;;	
	_2) cat << ENDOFMSG

ERROR: Combination of < $JAIL >< $PARAM > [jail and parameter]
       doesn't exist in jailmap.conf

ENDOFMSG
	;;	
	_3) cat << ENDOFMSG

ALERT: The new value entered is the same as the old value.
       No changes were made.

ENDOFMSG
	;;
	_4) cat << ENDOFMSG

ERROR: Parameter < class > cannot be changed with qb-edit. If
       you wish to create a rootjail or dispjail, use qb-create

ENDOFMSG
	;;
	_5) cat << ENDOFMSG

ERROR: < cpuset > CPUs must exist, and entered in valid format
       For example:  0,1,2,3  OR  0-3 
       Run command:  cpuset -g  ;  or see man 1 cpuset 

ENDOFMSG
	;;
	_6) cat << ENDOFMSG

ERROR: < maxmem > must be of valid format:  <integer><G|M|K>
       See: man 8 rctl 

ENDOFMSG
	;;
	_7) cat << ENDOFMSG

ERROR: < no_destroy > must be either true or false

ENDOFMSG
	;;
	_8) cat << ENDOFMSG

ERROR: Invalid rootjail. Here's a list of valid rootjails: 
ENDOFMSG

		# All rootjails in JMAP with valid zroot/quBSD/jails/<jail>
		sed -nE "s/[[:blank:]]+class[[:blank:]]+rootjail[[:blank:]]*//gp" $JMAP \
										| uniq | xargs -I@ zfs list -Ho name $JAILS_ZFS/@
		echo ''
	;;
	_9) cat << ENDOFMSG

ERROR: < schg > can only be one of the following: none|sys|all

ENDOFMSG
	;;
	_10) cat << ENDOFMSG

ERROR: < seclvl > must be one of the following: -1|0|1|2|3
       See man 7 security

ENDOFMSG
	;;
	_11) cat << ENDOFMSG

ERROR: Invalid template. Here's a list of valid templates: 

ENDOFMSG
		# All appjails in JMAP with zusr/<jail>
		sed -nE "s/[[:blank:]]+class[[:blank:]]+(appjail)[[:blank:]]*//gp" $JMAP \
										| uniq | xargs -I@ zfs list -Ho name $ZUSR_ZFS/@
		echo ''
	;;
	_12) cat << ENDOFMSG

ALERT: Jail: < $VAL > doesn't start with < net- > , which is the
       convention for gateway jails. However, a network connection 
       can still be made between < $JAIL > and < $VAL >
       Run again with [-f] option to force override this alert. 

ENDOFMSG
	;;
	_13) cat << ENDOFMSG

WARNING: Jail: < $VAL > does not have entries at: 
         /usr/local/etc/quBSD/jailmap.conf  
         Use [-f] option to force change in jailmap.conf  

ENDOFMSG
	;;
	_13_1) cat << ENDOFMSG

WARNING: Jail: < $VAL > does not have a valid zfs dataset at: 
         $ZUSR_ZFS/${VAL}
         Use [-f] option to force change in jailmap.conf  

ENDOFMSG
	;;
	_14) cat << ENDOFMSG

ERROR: No availalbe IPv4 was found in the range: "$_ip_range"
       It's permissible to use the same IP twice; but ensure that 
       jails with the same IP aren't connected to the same tunnel. 
       Run again with [-f] option, to force override this error.

ENDOFMSG
	;;
	_15) cat << ENDOFMSG

ERROR: Invalid IPv4. Use CIDR notation:  IP.IP.IP.IP/subnet 

ENDOFMSG
	;;
	_16) cat << ENDOFMSG

WARNING: < $VAL > Overlaps with an IP already in use.
         The same IP can be used twice; but ensure that jails 
         with the same IP aren't connected to the same tunnel. 
         Run again with [-f], to force override this warning.

ENDOFMSG
	;;
	_17) cat << ENDOFMSG

ALERT: < $VAL > diverges from quBSD convention. 
       Run again with [-f], to force override this alert.

CONVENTIONAL quBSD INTERNAL IP ASSIGNMENTS:
JAIL              GATEWAY        IPv4 Range
net-firewall      nicvm          External Router Dependent
net-<gateway>     net-firewall   10.255.x.2/30
serv-jails        net-firewall   10.128.x.2/30
appjails          net-<gateway>  10.1.x.2/30
usbvm             variable       10.88.88.1/30
< adhoc created by qb-connect >  10.99.x.2/30

ENDOFMSG
	;;
	_18) cat << ENDOFMSG

ALERT: Assigning IP address to < $JAIL > which has no tunnel.
 
ENDOFMSG
	;;
	_19) cat << ENDOFMSG

ERROR: The only valid tunnel for net-firewall, is a tap interface, 
       typically tap0, which connects to the nicvm.

ENDOFMSG
	;;
	_20) cat << ENDOFMSG

ERROR: < $PARAM > is not a valid parameter to change in 
       /usr/local/etc/quBSD/jailmap.conf

ENDOFMSG
	;;
	_21) cat << ENDOFMSG
ALERT: Restart the following jails for changes to take effect: 
$_restarts

ENDOFMSG
	# echo -e ending with \c prevents newline, so read command prints nicely
	echo -e "Should qb-edit to restart these jails? (y/n):  \c"
	;; 
	esac
	
	# Options to show usage and/or exit
	case $_action in 
		usage_0) usage_qb_edit ; exit 0 ;;
		usage_1) usage_qb_edit ; exit 1 ;;
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		*) : ;;
	esac
}

usage_qb_edit() { 
	cat << ENDOFUSAGE 

qb-edit:  Modify jail parameters in jailmap.conf

Usage: qb-edit <jail> <parameter> <value>
qb-edit [-f][-h][-i][-r] <jail> <parameter> <value>

   -f: (f)orce: Ignore potential errors and modify anyways
   -h: (h)elp:  Outputs this help message
   -i: (i)pv4:  Auto-assign IP address along quBSD conventions
   -r: (r)estart the required jails for changes to take effect

PARAMETERS SAVED AT /usr/local/etc/quBSD/jailmap.conf
autostart:   Automatically start with rc script during host boot.  
class:       Cannot be modified. Use qb-create instead.
cpuset:      CPUs a jail may use. Comma separated integers, or a
             range.  For example: 0,1,2,3 is the same as 0-3
             \`none' places no restrictions on jail's CPU access
IP0:         IPv4 address for the jail.
maxmem:      RAM maximum allocation:  <integer><G|M|K> 
             For example: 4G or 3500M, or \'none' for no limit
no_destroy:  Prevents accidental destruction of <jail>
             Change to \`false' in order to use qb-destroy
rootjail:    Which rootjail system to clone for <jail> . If <jail>
             is a rootjail; then this entry is self referential,
             but important for script funcitonality.
schg:        Directories to receive schg flags: all|sys|none
             \`sys' are files like: /boot /bin /lib , and others
             \`all includes /usr and /home as well
seclvl:      kern.securelevel to protect <jail>: -1|0|1|2|3
             \`1' or higher is required for schg to take effect
template:    Only applicable for dispjail. Designates jail to
             clone (including /home) for dispjail
tunnel:      Gateway for <jail> to receive network connectivity

ENDOFUSAGE
}

