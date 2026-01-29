#!/bin/sh

## NETWORKING FUNCTIONS ##

connect_client_to_gateway() {

	# Unified function for connecting two jails.
		# [-d] Indicates the need for restarting isc-dhcpd in the gateway. Unused for now.
		# [-i] Provide an exact IPV4 address
		# [-q] Quiet error message
		# [-s] Services restart  -- CURRENTLY UNUSED. Probably remove later
		# [-t] separates SSH (cjail) from EXT_IF (regular gateway). Expandable
	local _fn="connect_client_to_gateway" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts di:qst:V opts ; do case $opts in
		d) local _d='true' ;;
		i) local  ipv4="$OPTARG";;
		q) local _q='-q' ;;
		s) local _s='-s' ;;
		t) local _type="$OPTARG" ;;
		V) local _V="-V" ;;
		*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	# Positional params
	local _client="$1"  _gateway="$2"  _type="${_type:=EXT_IF}"
	local ipv4  _mtu _gw_mod  _cl_mod  _gw_ip  _cl_ip  _groupmod  _cl_root

	# Get gateway if necessary. Decide whether to continue or not.
	: "${_gateway:=$(get_jail_parameter -de GATEWAY $_client)}"
	[ "$_gateway" = "none" ] && eval $_R0
	! chk_isrunning "$_gateway" && get_msg $_q $_V -m _e28 && eval $_R1

	# Reduce verbosity/switches by setting some mods for later commands
	[ "$_gateway" = "host" ] ||   _gw_mod="-j $_gateway"
	[ "$_client"  = "host" ] || { _cl_mod="-j $_client" ; _cl_root="${M_QROOT}/${_client}" ;}

	# Resolve IP addr. Respect [-i] first, otherwise assign based on _type.
	case $_type in
		CJ_SSH) : "${ipv4:=$(get_jail_parameter -de IPV4 $_gateway)}" ;;  # Should only be DHCP or auto
		EXT_IF) : "${ipv4:=$(get_jail_parameter -de IPV4 $_client)}"  ;;
	esac
	case $ipv4 in
		DHCP)
			_groupmod="group DHCPD"  # Later for ifconfig interface groups
			chk_isvm $_gateway || _gw_ip=$(discover_open_ipv4 -g -t "$_type" -- "$_client" "$_gateway")
			;;
		auto)
			_gw_ip=$(discover_open_ipv4 -g -t "$_type" -- "$_client" "$_gateway")
			_cl_ip="${_gw_ip%.*/*}.2/30"
			;;
		*)
			get_msg $_q $_V -m _e2 -- "$_gateway" && eval $_R1      # cjail IP should not be hand jammed
### SELF NOTE: ISNT THIS AN UNREACHABLE COMMAND?? WHAT WAS I DOING HERE?
			_gw_ip="${ipv4%.*/*}.1/${ipv4#*/}"
			_cl_ip="$ipv4"
			;;
	esac

	# Respect jail's QCONF. If no jail-specific MTU, limit to the gw ETX_IF mtu size. Fallback to #default
	_mtu="$(get_jail_parameter -ez MTU $_client)"
	: "${_mtu:=$(ifconfig $_gw_mod -ag EXT_IF 2>/dev/null | sed -En "s/.*mtu ([^ \t]+)/\1/p")}"
	: "${_mtu:=$(get_jail_parameter -de MTU $_client)}"

	# Assign or create interfaces (_vif)
	chk_isvm $_gateway && _vif_cl=$(sed -En "s/${_gateway} ${_type} (.*)/\1/p" $VMTAPS)
	chk_isvm $_client  && _vif_gw=$(sed -En "s/${_client} ${_type} (.*)/\1/p" $VMTAPS)
	if ! chk_isvm $_gateway && ! chk_isvm $_client ; then
		_vif_gw=$(ifconfig epair create)
		_vif_cl="${_vif_gw%?}b"
	fi

	# Transport the interfaces if they belong in a jail
	[ -n "$_vif_gw" ] && [ -n "$_gw_mod" ] && ifconfig $_vif_gw vnet $_gateway
	[ -n "$_vif_cl" ] && [ -n "$_cl_mod" ] && ifconfig $_vif_cl vnet $_client

	# Assign group tags to the interfaces
	[ -n "$_vif_gw" ] && ifconfig $_gw_mod $_vif_gw group ${_client}_ group CLIENTS
	[ -n "$_vif_cl" ] && ifconfig $_cl_mod $_vif_cl group $_type $_groupmod

	# Configure the interfaces with IP addr and route, if not DHCP
	[ ! "$ipv4" = "dhcp" ] && [ -n "$_vif_gw" ] && ifconfig $_gw_mod $_vif_gw inet $_gw_ip mtu $_mtu up
	[ ! "$ipv4" = "dhcp" ] && [ -n "$_vif_cl" ] && ifconfig $_cl_mod $_vif_cl inet $_cl_ip mtu $_mtu up \
		&& route $_cl_mod add default "${_gw_ip%/*}" > /dev/null 2>&1

	# Final configuration for each client depending on type of connection being made
	case $_type in
		EXT_IF) configure_client_network ; reset_gateway_services ;;
#CJAIL BEING DEPRECATED
#CJ_SSH)
#configure_ssh_control "$_client" "$_gateway" ;;
	esac

	eval $_R0
}

reset_gateway_services() {
	local _fn="reset_gateway_services" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	if sysrc -nqj $_gateway dhcpd_enable 2>/dev/null | grep -q "YES" ; then
		# Only attempt restart if it's already running
		service -qj $_gateway isc-dhcpd status && service -qj $_gateway isc-dhcpd restart
	fi
}

configure_client_network() {
	local _fn="configure_client_network" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Make sure flags dont prevent update inside the jail
	chflags noschg -R ${_cl_root}/etc ${_cl_root}/etc/resolv.conf ${_cl_root}/etc/resolvconf.conf 2>/dev/null

	# DNS and pf management
	if sysrc -nqj $_client dnscrypt_proxy_enable 2>/dev/null | grep -q "YES" ; then
		# Using DoH, presumably for external-router connected (net-firewall) gateway
		rm "${_cl_root}/var/unbound/forward.conf" 2>/dev/null 
		chroot ${_cl_root} /bin/sh -c 'ln -s /var/unbound/forward-doh.conf /var/unbound/forward.conf'

	elif sysrc -nqj $_client wireguard_enable 2>/dev/null | grep -q "YES" ; then
		# Wireguard itself will update resolvconf, and thus, unbound
		rm "${_cl_root}/var/unbound/forward.conf" 2>/dev/null 
		chroot ${_cl_root} /bin/sh -c 'ln -s /var/unbound/forward-resolv.conf /var/unbound/forward.conf'

		# Endpoint IP
		local _ep=$(sed -nE "s/[ \t]*Endpoint[ \t]*=[ \t]*([^[ \t]+):.*/\1/p" \
				${M_ZUSR}/${_client}/rw/usr/local/etc/wireguard/wg0.conf)
		chflags noschg ${_cl_root}/etc/pf-wg_ep.table 2>/dev/null
		echo "$_ep" > ${_cl_root}/etc/pf-wg_ep.table

		# Wireguard restart is required if its upstream gateway restarts. $_CLI comes from exec.created
		[ "$_CLI" = "$_client" ] && service $_cl_mod wireguard restart

	else
		# All other gateways use normal resolvconf mechanism
		if sysrc -nqj $_client local_unbound_enable 2>/dev/null | grep -qs "YES" ; then
			rm "${_cl_root}/var/unbound/forward.conf" 2>/dev/null 
			chroot ${_cl_root} /bin/sh -c 'ln -s /var/unbound/forward-resolv.conf /var/unbound/forward.conf'
		fi
		if [ ! "$ipv4" = "DHCP" ] ; then      # Without DHCP, resolvconf doesnt know the assigned IP
			if [ "$_client" = "host" ] ; then
				echo "nameserver ${_gw_ip%/*}" | resolvconf -a tmpdns0 -m 0 > /dev/null 2>&1
			else
				chroot ${_cl_root} /bin/sh -c \
					"echo \"nameserver ${_gw_ip%/*}\" | resolvconf -a tmpdns0 -m 0 > /dev/null 2>&1"
			fi
		fi
	fi
	eval $_R0
}

configure_ssh_control() {
#CJAIL BEING DEPRECATED - whole function 
	# Ensures that the latest pubkey for the cjail SSH is copied to the controlled jail

	_pubkey=".ssh/cjail_authorized_keys"
	for _dir in $(ls -1 ${_cl_root}/home/) ; do
		_homes="${_cl_root}/home/${_dir}  ${_homes}"   # Mechanism to get root ssh and all the users' ssh
	done

	for _parent in ${_cl_root}/root ${_homes} ; do
		ls -alo $_parent | awk '{print $5}' | grep -qs schg && _schg_H='true'     # Record for later reset
		ls -alo $_parent/.ssh 2>/dev/null | awk '{print $5}' | grep -qs schg && _schg_S='true'
		chflags -R noschg ${_parent} ${_parent}/.ssh 2>/dev/null                  # Lift flags for edits

		[ ! -d "${_parent}/.ssh" ] && mkdir ${_parent}/.ssh \
			&& _owner=$(ls -lnd $_parent | awk '{print $3":"$4}')      # We need the owner:group of parent

		# For root ops in a container, use cjail root ssh. For normal ops, use cjail user
		[ -z "${_parent##*/root}" ] \
			&& cp ${M_ZUSR}/${_gateway}/rw/root/.ssh/id_rsa.pub ${_parent}/${_pubkey} \
			|| cp ${M_ZUSR}/${_gateway}/home/${_gateway}/.ssh/id_rsa.pub ${_parent}/${_pubkey}

		chmod 700 ${_parent}/.ssh
		chmod 600 ${_parent}/.ssh/cjail_authorized_keys

       # Reset flags if necessary, and chown if we created the directory
		[ -n "$_schg_H" ] && chflags schg ${_parent}
		[ -n "$_schg_S" ] && chflags -R schg ${_parent}/.ssh
		[ -n "$_owner" ] && chown -R $_owner ${_parent}/.ssh
	done
	eval $_R0
}

discover_open_ipv4() {
	# Finds an IP address unused by any running jails, or in qubsd.conf.
	# Nonlocal vars: _ip0._ip1._ip2._ip3/_subnet ; Required for chk_isqubsd_ipv4
	# _ip1 designates quBSD usecase ; _ip2 increments per jail ; _ip3 = (1 or 2) for gw vs client
		# qb-connect    (ADHOC):  10.88.X.0/29
		# Gateways     (EXT_IF):  10.99.X.0/30
		# Control jails(CJ_SSH):  10.255.X.0/30
		# Server jails   (serv):  10.128.X.0/30
		# Endpoint client  (EP):  10.1.x.0/30
	local _fn="discover_open_ipv4" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts cgqt:TV opts ; do case $opts in
			g) _ip3="1" ;;  # [-g] Returns the gateway IP ending in .1, instead of client IP of .2
			q) _qi="-q" ;;
			t) local _type="$OPTARG" ;;
			T) # This function is used in IP deconflictin by qb-start. Create TMP file
				_TMP_IP="${_TMP_IP:=${QRUN}/.qb-start_temp_ip}" ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 )) ; [ "$1" = "--" ] && shift

	local _client="$1"  _ip0=10  _ip2=1  _ip3=${_ip3:=2}  _subnet=30

	# The quBSD IP conventions for various use cases.
	case "$_type" in
		ADHOC) _ip1=88  ; _subnet=29 ;;
		CJ_SSH)   _ip1=255 ;;
		EXT_IF|*) # If the jail has clients, go with 99. Otherwise, it's an endpoint or server
				[ -n "$(get_info -e _CLIENTS $_client)" ] && _ip1=99 \
					|| { [ -z "${_client##serv-*}" ] && _ip1=128 || _ip1=1 ;} ;;
	esac

	# Get a list of IPs already in use, then increment $_ip2 until an unused IP is found
	get_info _USED_IPS
	while [ $_ip2 -le 255 ] ; do
		# Compare against QCONF, and the IPs already in use, including the temp file.
		local _ip_test="${_ip0}.${_ip1}.${_ip2}"
		if grep -Fq "$_ip_test" $QCONF || echo "$_USED_IPS" | grep -Fq "$_ip_test" \
				|| grep -Fqs "$_ip_test" "$_TMP_IP" ; then

			# Increment and continue, or return 1 if unable to find an IP in the available range
			_ip2=$(( _ip2 + 1 ))
			[ $_ip2 -gt 255 ] \
				&& get_msg $_qi -m _e30 -- "$_client" "${_ip0}.${_ip1}.X.${_ip3}" && eval $_R1
		else
			# Echo the value of the discovered IP and return 0
			echo "${_ip_test}.${_ip3}/${_subnet}" && eval $_R0
		fi
	done
	eval $_R0
}

remove_interface() {
	# Removes intf's from jails to host. Destroy or put down. Modify tracking files.
	local _fn="remove_interface" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts d opts ; do case $opts in
		d) local _action="destroy" ;;
		*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	# Pos params and _action. taps stay on host but epairs get destroyed
	local _intf="$1"  _jail="$2"  _action="${_action:=down}"

	# First check if it's already on host
	if ifconfig "$_intf" > /dev/null 2>&1 ; then
		ifconfig "$_intf" $_action

	# If a specific jail was passed, check that as the first possibility to find/remove tap
	elif [ -n "$_jail" ] && ifconfig -j $_jail -l | grep -Eqs "$_intf" ; then
		ifconfig "$_intf" -vnet "$_jail"
		ifconfig "$_intf" $_action

	# If the above fails, then check all jails
	else
		for _j in $(get_info -e _ONJAILS) ; do
			if ifconfig -j $_j -l 2>/dev/null | grep -Eqs "${_intf}" ; then
				ifconfig $_intf -vnet $_j
				ifconfig $_intf $_action
			fi
		done
	fi

	eval $_R0
}

