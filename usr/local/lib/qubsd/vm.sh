#!/bin/sh

## FUNCTIONS RELATED TO VM HANDLING ##

rootstrap_bsdvm() {
	# Prepares a new rootVM with qubsd specific files and init
	local _fn="rootstrap_bsdvm" _fn_orig="$_FN" _FN="$_FN -> $_fn"
	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Positional and local variables and checks
	local _VM="$1" volsize="$2" vm_zroot zvol distdir bsdvm tmp_zpool alt_mnt
	[ -z "$_VM" ] && get_msg $_q -m _e0 "VM name" && eval $_R1
	chk_avail_jailname "$_VM" && get_msg $_q -m _e1 "$_VM" "VM name" && eval $_R1

	[ -z "$volsize" ] && get_msg $_q -m _e0 "zvol volume size" && eval $_R1
   ! echo "$volsize" | grep -Eqs "^[[:digit:]]+(T|t|G|g|M|m|K|k)\$" \
			&& get_msg $_q -m _e1 -- "$volsize" "zvol size" && eval $_R1

	# Interim variables
	local vm_zroot="zroot/qubsd/$_VM"
	local zvol="/dev/zvol/zroot/qubsd/$_VM"
	local distdir="$QSHARE/freebsd-dist"
	local release=$(freebsd-version -u | cut -d- -f1)
	local arch=$(uname -m)
	local bsdvm="$QSHARE/templates/0bsdvm/rootstrap"
	local tmp_zpool="zrootvm"
	local alt_mnt="/mnt/$tmp_zpool"
	local timeout=5

	# Check network connection, inform if missing, give option to procede or exit
	if ping -ot $timeout freebsd.org > /dev/null 2>&1 ; then
		network=true
	else
		get_msg -Vm _w6 && ! get_user_response && get_msg2 -E
	fi

	# Download the dist files if necessary.
	mkdir -p $distdir
	export DISTRIBUTIONS="GITBRANCH base.txz kernel.txz"
	export BSDINSTALL_DISTSITE="https://download.freebsd.org/ftp/releases/$arch/${release}-RELEASE/"
	export BSDINSTALL_DISTDIR=$distdir
	export BSDINSTALL_CHROOT=$alt_mnt
	[ "$(grep -o "[[:digit:]].*" $distdir/GITBRANCH)" = "$release" ] || bsdinstall distfetch

	# Create the zvol and partitions
	zfs create -V $volsize -o volmode=geom -o qubsd:autosnap=true $vm_zroot
	gpart create -s gpt "$zvol"
	gpart add -t efi -s 200M -l efiboot "$zvol"
	gpart add -t freebsd-zfs -l rootfs "$zvol"
	newfs_msdos -L EFIBOOT "${zvol}p1"

	# zpool -t deconflicts host zroot with the vm's 'zroot'. No cachefile created (not really necessary for VM)
	sysctl vfs.zfs.vol.recursive=1    # zpool create WILL NOT WORK without this
	zpool create -f -o altroot="$alt_mnt" -O mountpoint=/zroot -O atime=off -t ${tmp_zpool} zroot ${zvol}p2
	sysctl vfs.zfs.vol.recursive=0    # recursive is deadlock prone. Set it back to default
	zfs create -o atime=off -o mountpoint=none ${tmp_zpool}/ROOT
	zfs create -o atime=off -o mountpoint=/ ${tmp_zpool}/ROOT/default
	zpool set bootfs=$tmp_zpool/ROOT/default $tmp_zpool

	# Extract the distribution to the VM root
	export DISTRIBUTIONS="base.txz kernel.txz"   # Have to remove GITBRANCH or the extraction will fail
	bsdinstall distextract

	# Create the boot files
	mkdir -p $alt_mnt/boot/efi
	mount -t msdosfs ${zvol}p1 $alt_mnt/boot/efi
	mkdir -p $alt_mnt/boot/efi/EFI/BOOT
	cp $alt_mnt/boot/loader.efi $alt_mnt/boot/efi/EFI/BOOT/BOOTX64.EFI
	umount "$alt_mnt/boot/efi"

	# Files and directories to prepare for a running system
	mkdir -p $alt_mnt/home
	mkdir -p $alt_mnt/usr/local/bin
	mkdir -p $alt_mnt/usr/local/etc/rc.d
	mkdir -p $alt_mnt/xfer && chmod -R 777 $alt_mnt/xfer    # For virtio-9p file sharing between host/VM
	cp -a $bsdvm/fstab       $alt_mnt/etc/fstab
	cp -a $bsdvm/loader.conf $alt_mnt/boot/loader.conf
	cp -a $bsdvm/qubsd-dhcp  $alt_mnt/usr/local/bin/qubsd-dhcp
	cp -a $bsdvm/qubsd-dhcpd $alt_mnt/usr/local/etc/rc.d/qubsd-dhcpd
	cp -a $bsdvm/qubsd-init  $alt_mnt/usr/local/etc/rc.d
	cp -a $bsdvm/rc.conf     $alt_mnt/etc/rc.conf
	cp -a $bsdvm/sysctl.conf $alt_mnt/etc/sysctl.conf
	cp -a /etc/localtime     $alt_mnt/etc/localtime
	sysrc -f $bsdvm/rc.conf hostname="$_VM"
	
	if [ "$network" ] ; then
		# Update the container
		freebsd-update --not-running-from-cron -b $alt_mnt/ -d /var/db/freebsd-update fetch install

		# pkg and installs are more complete/correct with chroot, but requires devfs, resolv, and ldconfig
		mount -t devfs devfs $alt_mnt/dev
		cp /etc/resolv.conf $alt_mnt/etc
		chroot $alt_mnt /etc/rc.d/ldconfig forcerestart
		pkg -c $alt_mnt bootstrap -yf
		pkg -c $alt_mnt install -y vim tmux automount fusefs-exfat fusefs-ext2 fusefs-ifuse fusefs-jmtpfs
		umount $alt_mnt/dev
	fi

	# Unmount, export, and set the volmode correctly
	umount $alt_mnt/zroot
	umount $alt_mnt
	rm -r $alt_mnt
	zpool export $tmp_zpool
	zfs set volmode=dev $vm_zroot

	[ "$network" ] && get_msg -m _m11 "$_VM" || get_msg -m _m12 "$_VM"
}

configure_bsdvm_zusr() {
	# Rough function for VM reconfiguration. Will eventually be made more robust for installer and qb-create 
	# Creates the zusr zvol, and configures it
	local _fn="configure_vm_zusr" _fn_orig="$_FN" _FN="$_FN -> $_fn"
	while getopts d:qV _opts ; do case $_opts in
		d) local _dircopy="$OPTARG" ;;
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Positional and local variables and checks
	local _VM="$1" volsize="$2" vm_zusr zvol tmp_zpool alt_mnt
	[ -z "$_VM" ] && get_msg $_q -m _e0 "VM name" && eval $_R1
	chk_avail_jailname "$_VM" && get_msg $_q -m _e1 "$_VM" "VM name" && eval $_R1

	[ -z "$volsize" ] && get_msg $_q -m _e0 "zvol volume size" && eval $_R1
   ! echo "$volsize" | grep -Eqs "^[[:digit:]]+(T|t|G|g|M|m|K|k)\$" \
			&& get_msg $_q -m _e1 -- "$volsize" "zvol size" && eval $_R1

	# Interim variables
	local vm_zusr="zusr/$_VM/persist"
	local zvol="/dev/zvol/$vm_zusr"
	local mnt="/mnt/$_VM"

	# Create the zvol, filesystem, and mount it
	zfs create -o atime=off -o qubsd:autosnap=true $U_ZFS/$_VM
	zfs create -V $volsize -o volmode=geom -o qubsd:autosnap=true $vm_zusr
	newfs -L zusr $zvol	  # Creates a label used in qubsd-init to identify the primary persistence drive
	mkdir -p $mnt
	mount $zvol $mnt
	
	# Files and directories to prepare for a running system
	if [ "$_dircopy" ] ; then            # Preference user specified directory
		cp -a $_dircopy/ $mnt
	elif [ -e "$QSHARE/templates/$_VM" ] ; then   # Fallback - If VM name matches a template, use it
		cp -a $QSHARE/templates/$_VM/ $mnt
	fi

	umount $mnt
	rm -r $mnt
	zfs set volmode=dev $vm_zusr
}

return_ppt() {
	# After VM completion, put PPT devices back to original state (as specified in loader.conf)
	local _fn="return_ppt" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _VM="$1"
	[ -z "$_VM" ] && get_msg $_q -m _e0 -- "VM name" && eval $_R1

	# Get PPT devices from the actual bhyve command that was launched for the VM
	_bhyvecmd=$(tail -1 "${QLOG}_${_VM}" 2>&1)
	while : ; do
		_newppt=$(echo "$_bhyvecmd" | sed -En "s@.*passthru,([0-9/]+[0-9/]+[0-9/]+ ).*@\1@p")
		[ -z "$_newppt" ] && break
		_ppt="$_ppt $_newppt"
		_bhyvecmd=$(echo "$_bhyvecmd" | sed -E "s@$_newppt@@")
	done

	# If there were any _ppt values, reset them to their state before VM launch
	_pciconf=$(pciconf -l | awk '{print $1}')
	for _val in $_ppt ; do
		# convert _val to native pciconf format with :colon: instead of /fwdslash/
		_val2=$(echo "$_val" | sed "s#/#:#g")

		# Search for the individual device and specific device for devctl functions later
		_pciline=$(echo "$_pciconf" | grep -Eo ".*${_val2}")
		_pcidev=$(echo "$_pciline" | grep -Eo "pci.*${_val2}")

		# PCI device doesnt exist on the machine
		[ -z "$_pciline" ] && get_msg $_q -m _e22 -- "$_val" "PPT" \
			&& get_msg -Vpm _e1 -- "$_val" "PPT" && eval $_R1

		# If the device isnt listed in loader.conf, then return it to host
		if ! grep -Eqs "pptdevs=.*${_val}" /boot/loader.conf ; then
			# Detach the PCI device, and examine the error message
			_dtchmsg=$(devctl detach "$_pcidev" 2>&1)
			[ -n "${_dtchmsg##*not configured}" ] && get_msg -m _e22_1 -- "$_pcidev" \
				&& get_msg -Vpm _w5 -- "$_pcidev"

			# Clear the driver returns it back to the host driver (unless it booted as ppt)
			! devctl clear driver $_pcidev && get_msg -Vpm _w5 -- "$_pcidev" && eval $_R1
		fi
	done
	eval $_R0
}

cleanup_vm() {
	# Cleanup function after VM is stopped or killed in any way
	local _fn="cleanup_vm" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Positional params and func variables.
	while getopts nqV opts ; do case $opts in
			n) local _norun="-n" ;;
			q) local _qcv="-q" ;;
			V) local _V="-V" ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	# Positional variables
	local _VM="$1"  _rootenv="$2"   _ct  _gw  _jail
	[ -z "$_VM" ] && get_msg $_qcv -m _e0 && eval $_R1

	# Bring all recorded taps back to host, and destroy. Skip checks for speed (non-essential)
	_ct=$(get_jail_parameter -des CONTROL $_VM)
	_gw=$(get_jail_parameter -des GATEWAY $_VM)
	for _tap in $(sed -En "s/^$_VM [^[:blank:]]+ ([^[:blank:]]+)/\1/p" $VMTAPS 2> /dev/null) ; do
		grep -Eqs "CJ_SSH $_tap" $VMTAPS && _jail="$_ct"
		grep -Eqs "EXT_IF $_tap" $VMTAPS && _jail="$_gw"
		remove_interface -d "$_tap" "$_jail"
	done
	sed -i '' -E "/^$_VM /d" $VMTAPS   # Remove any lines in VMTAPS associated to the VM

	# Destroy the VM
	bhyvectl --vm="$_VM" --destroy > /dev/null 2>&1

	# Set the PPT device back to its original state before VM prep/launch
	[ ! "$_ppt" = "none" ] && return_ppt "$_VM"

	# If it was a norun, dont spend time recloning
	[ -n "$_norun" ] && eval $_R0

	# Pull _rootenv in case it wasn't provided, and reclone it
	[ -z "$_rootenv" ] && ! _rootenv=$(get_jail_parameter -e ROOTENV $_VM) && eval $_R1
	reclone_zroot -q "$_VM" "$_rootenv"

	# If it's a dispVM with a template, then make a fresh clone of the template zusr (all children)
	local _template=$(get_jail_parameter -e TEMPLATE $_VM)
	if [ "$_template" ] && [ "$(get_jail_parameter -es CLASS $_VM)" = "dispVM" ] ; then
		reclone_zusr "$_VM" "$_template" || eval $_R1
	fi

	# Make sure the persistent zusr zvol is unmounted and converted back to dev not geom
	umount /dev/zvol/$U_ZFS/$_VM/persist
	zfs set volmode=dev "$U_ZFS/$_VM/persist"

	rm "${QRUN}/qb-bhyve_${_VM}" 2> /dev/null
	rm_errfiles
	eval $_R0
}

prep_bhyve_options() {
	# Prepares both line options and the host system for the bhyve command
	# CAPS variables are the final line options for the bhyve command
	local _fn="prep_bhyve_options" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _qs='-q' ;;
		V) local _V="-V" ;;
		*) get_msg -m _e9 ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Get simple QCONF variables
	_VM="$1"
	_cpuset=$(get_jail_parameter -de CPUSET "$_VM")        || eval $_R1
	_gateway=$(get_jail_parameter -dez GATEWAY "$_VM")     || eval $_R1
	_clients=$(get_info -e _CLIENTS "$_VM")
	_control=$(get_jail_parameter -de  CONTROL "$_VM")     || eval $_R1
	_memsize=$(get_jail_parameter -de MEMSIZE "$_VM")      || eval $_R1
	_wiremem=$(get_jail_parameter -de WIREMEM "$_VM")      || eval $_R1
	_bhyveopts=$(get_jail_parameter -de BHYVEOPTS "$_VM")  || eval $_R1
	_rootenv=$(get_jail_parameter -e ROOTENV "$_VM")       || eval $_R1
	_taps=$(get_jail_parameter -de TAPS "$_VM")            || eval $_R1
	_template=$(get_jail_parameter -ez TEMPLATE "$_VM")    || eval $_R1
	_vcpus=$(get_jail_parameter -de VCPUS "$_VM")          || eval $_R1
	_vnc=$(get_jail_parameter -dez VNC "$_VM")             || eval $_R1
	_x11=$(get_jail_parameter -dez X11 "$_VM")             || eval $_R1
	_ppt=$(get_jail_parameter -dexz PPT "$_VM")            || eval $_R1
	_tmux=$(get_jail_parameter -dez TMUX "$_VM")           || eval $_R1
	# UEFI bootrom
	_BOOT="-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd"

	# Add leading '-' to _bhyveopts
	_BHOPTS="-${_bhyveopts}"

	# Get wildcard bhyve option added by user
	_bhyve_custm=$(sed -En "s/${_VM}[ \t]+BHYVE_CUSTM[ \t]+//p" $QCONF \
						| sed -En "s/[ \t]+/ /p")

	# RAM and memory handling
	_RAM="-m $_memsize"
	[ "$_wiremem" = "true" ] && _WIRE='-S' || _WIRE=''

	# Assign hostbridge based on CPU
	grep -Eqs "^CPU.*AMD" /var/run/dmesg.boot \
		&& _HOSTBRG="-s 0,amd_hostbridge" \
		|| _HOSTBRG="-s 0,hostbridge"

	# Handle CPU pinning, or if none, then just assign the number of vcpus
	_vcpu_count=0 ; IFS=','
	for _range in $_cpuset; do
		case "$_range" in
			none) # CPUSET was none, so there is no pinning. Assign the variable and break
				_CPU="-c $_vcpus"
				break
			;;
			*-*) # It's a range; extract the start and end
				_start=$(echo "$_range" | cut -d'-' -f1)
				_end=$(echo "$_range" | cut -d'-' -f2)

				# Loop over the range to append to the _cpupin string
				while [ "$_start" -le "$_end" ]; do
					_CPUPIN="$_CPUPIN -p $_vcpu_count:$_start"
					_vcpu_count=$(( _vcpu_count + 1 ))
					_start=$(( _start + 1 ))
				done
			;;
			*) # It's a single number; directly append to the _CPUPIN string
				_CPUPIN="$_CPUPIN -p $_vcpu_count:$_range"
				_vcpu_count=$(( _vcpu_count + 1 ))
			;;
		esac
	done

	# Output the final _cpupin string
	[ -z "$_CPU" ] && _CPU="-c $_vcpu_count"
	unset IFS

	# BEGIN SLOT ASSIGNMENTS FOR PCI DEVICES
	_slot=1
	_LPC="-s 31,lpc"

	# Assign zroot blk device
	_BLK_ROOT="-s ${_slot},virtio-blk,/dev/zvol/${R_ZFS}/${_VM}"
	_slot=$(( _slot + 1 ))

	# Assign zusr blk device. Must be a volume; or should be blank
	_zvols=$(zfs list -Hro name -t volume $U_ZFS/$_VM)
	[ -z "$_zvols" ] && _BLK_ZUSR=''    # Set the variable to empty if no volumes are present
	for _vol in $_zvols ; do
		_BLK_ZUSR="-s ${_slot},virtio-blk,/dev/zvol/$_vol"
		_slot=$(( _slot + 1 ))
	done

	# 9p creates a shared directory for file transfer. Directory must exist or bhyve will fail
	mkdir -p "$QRUN/xfer/$_VM" 2>/dev/null
	_BLK_9P="-s ${_slot},virtio-9p,xfer=$QRUN/xfer/$_VM"
	_slot=$(( _slot + 1 ))

	# Handling BHYVE_CUST options
	[ "$_bhyve_custm" ] && while IFS= read -r _line ; do

		# User can specify for quBSD to fill in the slot for -s.
		if [ -z "${_line##-s \#*}" ] ; then
			# If a slot was included with a '#', it means to autofill the slot
			_line=$(echo "$_line" | sed -E "s/-s #/-s ${_slot}/")
			_slot=$(( _slot + 1 )) ; [ "$_slot" -eq 29 ] && _slot=32
		fi

		# Make _BHYVE_CUSTM a single line variable for later inclusion with bhyve command
		_BHYVE_CUSTM=$(printf "%b" "${_BHYVE_CUSTM} ${_line}")

	# Personal note: herefile is required; else, `echo $var | while` subshell will lose _BHYVE_CUSTM
	done << EOF
$_bhyve_custm
EOF

	# Assign passthrough variables
	if [ ! "$_ppt" = "none" ] ; then
		for _pci in $_ppt ; do
			_PPT=$(printf "%b" "${_PPT} -s ${_slot},passthru,\"${_pci}\"")
			_WIRE="-S"
			_slot=$(( _slot + 1 )) ; [ "$_slot" -eq 29 ] && _slot=32
		done
	fi

	# Assign VNC FBUF options
	if [ "$_vnc" ] && [ ! "$_vnc" = "false" ] ; then

		# Define height/width from the QCONF entry
		_w=$(echo "$_vnc" | grep -Eo "^[[:digit:]]+")
		_h=$(echo "$_vnc" | grep -Eo "[[:digit:]]+\$")

		# Find all sockets in use, and define starting socket to search
		_socks=$(sockstat -P tcp | awk '{print $6}' | grep -Eo ":[[:digit:]]+")
		_vncport=5900

		# cycle through sockets until an unused one is found
		while : ; do
			echo "$_socks" | grep -qs "$_vncport" && _vncport=$(( _vncport + 1 )) || break
		done

		_FBUF="-s 29,fbuf,tcp=0.0.0.0:${_vncport},w=${_w},h=${_h}"
		_TAB="-s 30,xhci,tablet"
	fi

	# Launch a serial port if tmux is set in QCONF. The \" and TMUX2 closing " are intentional.
	[ "$_tmux" = "true" ] && _STDIO="-l com1,stdio" \
		&& _TMUX1="/usr/local/bin/tmux new-session -d -s $_VM \"" && _TMUX2='"'

	# Invoke the trap function for VM cleanup, in case of any errors after modifying host/trackers
	trap "cleanup_vm -n $_VM ; exit 0" INT TERM HUP QUIT

#CJAIL BEING DEPRECATED
# Default number of taps is 0. Add 1 for the control jail SSH connection
#_taps=$(( _taps + 1 ))
	# Also, for every gateway or client the VM touches, it needs another tap
	[ -n "$_gateway" ] && [ ! "$_gateway" = "none" ] && _taps=$(( _taps + 1 ))
	[ -n "$_clients" ] && [ ! "$_clients" = "none" ] \
			&& _taps=$(( _taps + $(echo $_clients | wc -w) ))
	# Add another tap if X11FWD is true
	[ "$_x11" = "true" ] && _taps=$(( _taps + 1 ))

	_cycle=0
	while [ "$_taps" -gt 0 ] ; do

		# Create tap, make sure it's down, increment slot
		_tap=$(ifconfig tap create)
		sed -i '' -E "/${_tap}[ \t]*/d" $VMTAPS # Delete any stray lingering taps in the VMTAPS tracker
		ifconfig $_tap group "${_VM}_" down   # Use ifconfig groups to track which VM this tap belongs to
		_VTNET=$(printf "%b" "${_VTNET} -s ${_slot},virtio-net,${_tap}")
		_slot=$(( _slot + 1 )) ; [ "$_slot" -eq 29 ] && _slot=32
		_taps=$(( _taps - 1 ))

		# Tracker file for which taps are related to which VM, and for which purpose (_vif tags)
		case "$_cycle" in
#CJAIL BEING DEPRECATED
#			0) 
#ifconfig $_tap group "CJ_SSH" ; echo "$_VM CJ_SSH $_tap" >> $VMTAPS
#				;;
			0) ifconfig $_tap group "EXT_IF" ; echo "$_VM EXT_IF $_tap" >> $VMTAPS ;;
			1) ifconfig $_tap group "X11"    ; echo "$_VM X11 $_tap"    >> $VMTAPS ;;
			2) ifconfig $_tap group "EXTRA_${_cycle}_" ; echo "$_VM EXTRA_${_cycle}_ $_tap" >> $VMTAPS ;;
		esac
		_cycle=$(( _cycle + 1 ))
	done

	# Define the full bhyve command
	_BHYVE_CMD="$_TMUX1 bhyve $_CPU $_CPUPIN $_RAM $_BHOPTS $_WIRE $_HOSTBRG $_BLK_ROOT $_BLK_ZUSR \
		$_BLK_9P $_BHYVE_CUSTM $_PPT $_VTNET $_FBUF $_TAB $_LPC $_BOOT $_STDIO $_VM $_TMUX2"

	# unset the trap
	trap - INT TERM HUP QUIT EXIT

	eval $_R0
}


finish_vm_connections() {
	# While the _BHYVE_CMD appears in ps immediately, emulated devices are not yet attached, and
	# would cause an error. Due to qb-start dynamics/timeouts, we dont want to wait. Instead,
	# return 0 so that launches can continue, and let this function handle the connections later.
	local _fn="finish_vm_connections" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Wait for the actual bhyve VM to appear in ps. If ppt a device is bad, launch can delay 15 secs
	_count=0
	while ! pgrep -xfq "bhyve: $_VM" ; do
		sleep 1 ; _count=$(( _count + 1 ))
		[ "$_count" -ge 15 ] && get_msg -m _e4_2 -- "$_VM" && eval $_R1
	done

	# Connect to control jail and gateway
	connect_client_to_gateway -dt EXT_IF -- "$_VM" "$_gateway" > /dev/null
#CJAIL BEING DEPRECATED
#	connect_client_to_gateway -dt CJ_SSH -- "$_VM" "$_control" > /dev/null

	# Connect VM to all of it's clients (if there are any)
	for _cli in $(get_info -e _CLIENTS "$_VM") ; do
		chk_isrunning "$_cli" && connect_client_to_gateway -t EXT_IF "$_cli" "$_VM"
	done

	eval $_R0
}

mount_persistent_zvol() {
	_VM="$1"
	local zvol_dev="/dev/zvol/$U_ZFS/$_VM/persist"

	zfs set volmode=geom "$U_ZFS/$_VM/persist"
	sleep .2        # Without this delay, fs_typ fails (presumably due to zfs delays in chaning the volmode)

	fs_type=$(fstyp $zvol_dev)
	case "$fs_type" in
		ufs) mount -o rw $zvol_dev $M_ZUSR/$_VM
			;;
		ext*) mount -t ext2fs -o rw $zvol_dev $M_ZUSR/$_VM
			;;
		*) # Other filetypes arent supported. INSERT msg here
			;;
	esac
}

monitor_vm_stop() {
	# Loops until VM stops, or timeout (20 seconds)
	local _fn="monitor_vm_stop" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts qV _opts ; do case $_opts in
		q) local _qms='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	local _jail="$1"
		[ -z "$_jail" ] && eval $_R1
	local _timeout="$2"
		: ${_timeout:=20}
	local _count=1

	# Get message about waiting
	get_msg $_qms -m _m4 -- "$_jail" "$_timeout"

	# Check for when VM shuts down.
	while [ "$_count" -le "$_timeout" ] ; do
		sleep 1

		if ! pgrep -xqf "bhyve: $_jail" ; then
			# If we _count was being shown, put an extra line before returning
			[ -z "$_qms" ] && echo ''
			eval $_R0
		fi

		_count=$(( _count + 1 ))
		[ "$_qms" ] || printf "%b" " .. ${_count}"
	done

	# Fail for timeout
	eval $_R1
}

launch_bhyve_vm() {
	# Need to detach the launch an monitoring of VMs completely from qb-cmd and qb-start

	# Get globals, although errfiles arent needed
	get_global_variables
	rm_errfiles

	# Create trap for post VM exit
	trap "cleanup_vm $_VM $_rootenv ; mount_persistent_zvol $_VM ; exit 0" INT TERM HUP QUIT EXIT

	# Log the exact bhyve command being run
	echo "\$(date "+%Y-%m-%d_%H:%M") Starting VM: $_VM" | tee -a $QLOG ${QLOG}_${_VM}
	echo $_BHYVE_CMD >> ${QLOG}_${_VM}

	# Launch the VM to background
	eval $_BHYVE_CMD

	sleep 5   # Allow plent of time for launch. Sometimes weirdness can delay pgrep appearance

	# Monitor the VM, perform cleanup after done
	while pgrep -xfq "bhyve: $_VM" ; do sleep 1 ; done
	echo "\$(date "+%Y-%m-%d_%H:%M") VM: $_VM HAS ENDED." | tee -a $QLOG ${QLOG}_${_VM}
	exit 0
}

exec_vm_coordinator() {
	# Executive management of launching the VM
	local _fn="exec_vm_coordinator" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts nqtV opts ; do case $opts in
			n) local _norun="-n" ;;
			q) local _qs="-q" ; _quiet='/dev/null 2>&1'   ;;
			t) local _tmux="-t"  ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	_VM="$1"

	# Ensure that there's nothing lingering from this VM before trying to start it
	cleanup_vm $_norun $_qs "$_VM"

	# Pulls variables for the VM, and assembles them into bhyve line options
	! prep_bhyve_options $_qs $_tmux "$_VM" && eval $_R1

	# If norun, echo the bhyve start command, cleanup the taps/files, and return 0
	if [ -n "$_norun" ] ; then
		echo $_BHYVE_CMD
		cleanup_vm -n $_VM
		eval $_R0
	fi

	# Start upstream jails/VMs, as well as control jail
	#start_jail -q $_control
	! start_jail $_gateway && eval $_R1

	# Launch VM sent to background, so connections can be made (network, vnc, tmux)
	get_msg -m _m1 -- "$_jail" | tee -a $QLOG ${QLOG}_${_VM}
	export COMMON _BHYVE_CMD _VM _rootenv QLOG
	daemon -t "bhyve: $_jail" -o /dev/null -- /bin/sh -c '. $COMMON ; launch_bhyve_vm'

	# Monitor to make sure that the bhyve command started running, then return 0
	local _count=0 ; sleep .5

	while ! { pgrep -xfq "bhyve: $_VM" \
				|| pgrep -fl "bhyve" | grep -Eqs "^[[:digit:]]+ .* ${_VM}[ \t]*\$" ;} ; do
	sleep .5 ; _count=$(( _count + 1 ))
	[ "$_count" -ge 10 ] && get_msg -m _e4_1 -- "$_VM" && eval $_R1
	done

	finish_vm_connections &
	eval $_R0
}

