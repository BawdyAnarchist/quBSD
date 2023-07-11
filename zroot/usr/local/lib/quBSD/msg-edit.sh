#!/bin/sh

get_msg_edit() { 

	# Positional parameters
   local _message="$1"
   local _pass_cmd="$2"
	local _msg2="$3"

	# FORCE overrides 
	if [ -n "$FORCE" ] ; then 
		# Do not exit the script on errors 
		_pass_cmd="none"
		
		# The only message that should be shown, is the result.
		! [ "$_message" = "_8" ] && _message="none"
	fi

	# QUIET will skip over messages 
	[ -z "$QUIET" ] && case "$_message" in

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

ERROR: < NO_DESTROY > must be either true or false
ENDOFMSG
		;;
		_5) cat << ENDOFMSG

ERROR: Parameter < CLASS > cannot be changed with qb-edit.
ENDOFMSG
		;;
		_6) cat << ENDOFMSG

ERROR: < $PARAM > is not a valid parameter to change in 
       /usr/local/etc/quBSD/jailmap.conf
ENDOFMSG
		;;
		_7) cat << ENDOFMSG
ALERT: For changes to take effect, restart the following:
ENDOFMSG

[ -n "$_restart1" ] && echo "    $_restart1"
[ -n "$_restart2" ] && echo "    $_restart2"
echo -e "Should qb-edit to restart these jails? (y/n):  \c"
		;; 
		_8) 
			echo -e "Success \c" 
			qb-list -j $JAIL -p $PARAM
		;;
		_9) cat << ENDOFMSG

ALERT: net-firewall connects to the external internet, so its
       IP depends on your router. The following was modified: 
       ${M_ZUSR}/net-firewall/rw/etc/rc.conf 
       It's highly recommended to double check the IP address,
       assigned by your router, and this file.
ENDOFMSG
	;;

	# End of _message 
	esac


	# Secondary message - informs about the [-f] option 
	[ -z "$QUIET" ] && case $_msg2 in 
		_f) cat << ENDOFMSG

Run again with [-f] to force modification.
    (errors will still be printed to stdout, but ignored)

ENDOFMSG
		;;
	esac


	case $_pass_cmd in 
		usage_0) 
				[ -z "$QUIET" ] && usage 
				exit 0 ;;

		usage_1) 
				[ -z "$QUIET" ] && usage 
				exit 1 ;;

		exit_0) exit 0 ;;

		exit_1) exit 1 ;;

		*) : ;;
	esac
}

usage() { cat << ENDOFUSAGE 
qb-edit:  Modify jail parameters in jailmap.conf

Usage: qb-edit <jail> <PARAMETER> <value>
       qb-edit [-f][-h][-i][-r] <jail> <parameter> <value>

   -f: (f)orce. Ignore errors and modify anyways. Error msgs
       suppressed, but final state of <jail><param> is shown 
   -h: (h)elp. Outputs this help message
   -i: (i)pv4. Auto-assign IP address along quBSD conventions
   -q: (q)uiet output, do not print anything to stdout 
   -r: (r)estart the required jails for changes to take effect

PARAMETERS SAVED AT /usr/local/etc/quBSD/jailmap.conf
AUTOSNAP:    Snapshot jail with qb-autosnap /etc/crontab
AUTOSTART:   Automatically start with rc script during host boot.  
CLASS:       Cannot be modified. Use qb-create instead.
CPUSET:      CPUs a jail may use. Comma separated integers, or a
             range.  For example: 0,1,2,3 is the same as 0-3
             \`none' places no restrictions on jail's CPU access
GATEWAY:      Gateway for <jail> to receive network connectivity
IPV4:         IPv4 address for the jail.
MAXMEM:      RAM maximum allocation:  <integer><G|M|K> 
             For example: 4G or 3500M, or \'none' for no limit
MTU:         MTU for connections made when jail comes up. 
NO_DESTROY:  Prevents accidental destruction of <jail>
             Change to \`false' in order to use qb-destroy
ROOTJAIL:    Which rootjail system to clone for <jail> . If <jail>
             is a rootjail; then this entry is self referential,
             but important for script funcitonality.
SCHG:        Directories to receive schg flags: all|sys|none
             \`sys' are files like: /boot /bin /lib , and others
             \`all includes /usr and /home as well
SECLVL:      kern.securelevel to protect <jail>: -1|0|1|2|3
             \`1' or higher is required for schg to take effect
TEMPLATE:    Only applicable for dispjail. Designates jail to
             clone (including /home) for dispjail

ENDOFUSAGE
}

