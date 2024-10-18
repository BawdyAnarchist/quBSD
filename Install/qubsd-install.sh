#!/bin/sh

define_vars() {
	_REPO="/usr/local/share/quBSD"
	XINIT="/usr/local/etc/X11/xinit/xinitrc"
	QLOADER="/boot/loader.conf.d/qubsd_loader.conf"
	QCONF="/usr/local/etc/quBSD/qubsdmap.conf"
	QJ_CONF="/usr/local/etc/quBSD/jail.conf"

	# Read all uncommented variables from install.conf
	. ${_REPO}/install.conf
	. /usr/local/lib/quBSD/msg-installer.sh
}

load_kernel_modules() {
	# Required kernel modules
	kldload -n zfs.ko
	kldload -n vmm.ko
	kldload -n pf.ko
	kldload -n if_wg.ko
	kldload -n if_bridge.ko 
}

get_datasets() {
	# Loop until valid dataset is entered (either already exists, or could be created)
	while : ; do 
		zfs list "$jails_zfs" > /dev/null 2>&1 && break
		zfs create -n "$jails_zfs" && break

		msg_installer "_m1"
		read jails_zfs
	done
	while : ; do 
		zfs list "$zusr_zfs" > /dev/null 2>&1 && break
		zfs create -n "$zusr_zfs" > /dev/null 2>&1 && break

		msg_installer "_m2"
		read zusr_zfs
	done

	# Loop until valid mountpoints are entered (syntactically)
	while : ; do 
		echo "$jails_mount" | grep -Eqs '^(/[A-Za-z0-9._-]+)+$' && break
		msg_installer "_m3"
		read jails_mount
	done
	while : ; do 
		echo "$zusr_mount" | grep -Eqs '^(/[A-Za-z0-9._-]+)+$' && break
		msg_installer "_m4"
		read zusr_mount
	done
}

get_nic() {
	# Missing $nic implies pkg install failed to find interface. Ask user for input 
	if [ -z "$nic" ] ; then
		_NICS=$(pciconf -lv | grep -B3 "= network")
		_nics=$(echo "$_NICS" | grep -Eo "^[[:alnum:]]+" | grep -v none | tr '\n' ' ')
		get_msg "_m5" ; get_msg "_m6"
		read nic 

		while : ; do 
			echo "$_nics" | grep -Eqs "${nic}|skip" && break
			get_msg "_m7" ; get_msg "_m6"
			read nic
		done
	fi
	
	# Get the device bus based on the network card name selected
	[ ! "$nic" = "skip" ] && ppt_nic=$(pciconf -l ppt1 \
			| sed -E "s/ppt1@pci[[:digit:]]+:([^[:blank:]]+):.*/\1/" | sed -E "s#:#/#g")
}

get_usbs() {
	# temp files and background function, monitor/record USB ports for user ppt passthru selection.
	
	# Make temporary files for diff function and communication to `usb_config`
	tmp1=$(mktemp /tmp/qubsd_usbconf1)
	tmp2=$(mktemp /tmp/qubsd_usbconf2)
	tmp3=$(mktemp /tmp/qubsd_usbconf3)
	trap "rm $tmp1 $tmp2 $tmp3" INT TERM HUP QUIT EXIT
	
	# Set monitoring loop to background, give user instructions, wait for user input when finished.
	usb_config &
	clear && msg_installer "_m8"
	read _cont 

	# Signal usb_config infinite loop to exit, and give a moment for the loop to finish and exit 
	echo "exit" > $tmp3
	sleep 1
}

usb_config() {
	# Record pre-state of usb situation
	usbconfig > $tmp1 

	# Continuously monitor usbconfig output for changes as user plugs/unplugs USB to ports.
	while : ; do
		usbconfig > $tmp2	
		usb=$(diff $tmp1 $tmp2 | sed -En "/^> /s/^> //p")
		echo "$USBS" | grep -qs "$usb" || USBS=$(echo "$USBS" ; echo "$usb")
		sleep .5
		grep -qs "exit" $tmp3 && break 
	done	

	# Cleanup tmp files and trap
	rm $tmp1 $tmp2 $tmp3
	trap '' INT TERM HUP QUIT EXIT
}

translate_usbs() {
	# Translate the output of usbconfig to ppt devices

	# First find the corresponding PCI device name via sysctl
	usbus=$(echo $USBS | grep -Eo "usbus[[:digit:]]+" | sed -E 's/usbus/usbus./')
	for _usb in $usbus ; do
		dev_usbs=$(echo "$dev_usbs" ; sysctl dev.${_usb}.%parent | grep -Eo '[^[:blank:]]+$')
	done

	# Then translate each name to an actual bus location
	for _bus in $dev_usbs ; do
		_ppt=$(pciconf -l $_bus | grep -Eo "pci[^[:blank:]]+[[:digit:]]" | sed -E "s#:#/#g")
		ppt_usbs="$ppt_usbs $_ppt"		
	done
}

add_gui_pkgs() {
	# Install pkgs
	[ "$GUI" = "true" ] && _pkgs="xorg tigervnc-viewer"
	[ "$i3wm" = "true" ] && _pkgs="$_pkgs i3 i3lock i3status"
	pkg install -y $_pkgs

	# Modify xinitrc
	[ "$GUI" = "true" ] && echo "xhost + local:" >> $XINIT
	[ "$i3wm" = "true" ] && echo "i3" >> $XINIT
}

create_datasets() {
	# Create datasets and modify custom props appropriately
	! zfs list $jails_zfs > /dev/null 2>&1	\
			&& zfs create -o mountpoint="$mount_jails" -o qubsd:autosnap=true $jails_zfs
	! zfs list $zusr_zfs > /dev/null 2>&1	\
			&& zfs create -o mountpoint="$mount_zusr"  -o qubsd:autosnap=true $zusr_zfs

	# Modify qubsdmap and jail.conf with path for rootjails 
	sed -i '' -E "s:(#NONE[[:blank:]]+jails_zfs[[:blank:]]+)zroot/qubsd:\1$jails_zfs:" $QCONF
	sed -i '' -E "s:(^path=/)qubsd:\1${root_mount}:" $QJ_CONF 
}

modify_pptdevs() {
	# Avoid using pptdevs in case user modifies loader.conf. Instead pptdevs2 or 3
	if ! grep -qs "pptdevs2" /boot/loader.conf ; then
		devsnum="pptdevs2"
	else
		devsnum="pptdevs3"

		# loader.conf.d supercedes loader.conf, so copy over pptdevs3 if there was one.
		ppt3=$(grep "pptdevs3" /boot/loader.conf)
		[ "$ppt3" ] && echo "$ppt3" >> $QLOADER 
	fi

	# Modify qubsd_loader.conf
	sysrc -f $QLOADER "$devsnum"+="$ppt_nic $ppt_usbs"
}

modify_devfs_rules() {
	# /etc/devfs.rules is modified here and not at pkg install,
	# because it requires changing a file outside of /usr/local

	# Make a copy of the qubsd devfs.rules in /tmp 
	tmp_devfs=$(mktemp /tmp/qubsd_devfs)
	cp -a $REPO/zroot/etc/devfs.rules $tmp_devfs

	# Check /etc/devfs.rules, and search for two consecutive unused rule numbers 
	rulenum1=$(sed -n "s/^\[devfsrules.*=//p ; s/\]//p" /etc/devfs.rules | tail -1)
	while : ; do
		rulenum1=$(( rulenum1 + 1 ))
		rulenum2=$(( rulenum1 + 2 ))
			! grep -Eqs "^\[devfsrules.*=${rulenum1}" /etc/devfs.rules \
				&& ! grep -Eqs "^\[devfsrules.*=${rulenum2}" /etc/devfs.rules && break
	done

	# Add the discovered rule numbers to quBSD devfs and jail.conf
	cat ${_REPO}/zroot/etc/devfs.rules >> /etc/devfs.rules 
	sed -i '' -E "s/(^\[devfsrules_qubsd_netjail=)/\1$rulenum1/" $tmp_devfs 
	sed -i '' -E "s/(^\[devfsrules_qubsd_guijail=)/\1$rulenum2/" $tmp_devfs 
	sed -i '' -E "s/NETRULENUM1/$rulenum1/g" $QJ_CONF 
	sed -i '' -E "s/GUIRULENUM2/$rulenum2/g" $QJ_CONF

	# Check for all GPUs in pciconf, and uncomment/unhide based on available vendor(s)
	for _dev in $(pciconf -l | sed -En "/class=0x03/s/(^[[:alnum:]]+).*/\1/p") ; do
		if pciconf -lv $_dev | grep -Eqs "NVIDIA" ; then
			sed -i '' -E "s/^#(add path.*nvidia.*)/\1/" $tmp_devfs 
		else
			sed -i '' -E "s/^#(add path.*dri.*)/\1/" $tmp_devfs 
			sed -i '' -E "s/^#(add path.*drm.*)/\1/" $tmp_devfs 
		fi
	done

	# Copy prepared rules to the system devfs.rules and rm temp
	cat $tmp_devfs >> /etc/devfs.rules
	rm $tmp_devfs
}

main() {
	define_vars
	load_kernel_modules
	
	# PREPARATION - Get missing parameters from the user before making any changes 
	get_datasets
	get_nic
	get_usbs
	translate_usbs

	# SYSTEM INSTALLATION
	add_gui_pkgs
	create_datasets
	modify_pptdevs
	modify_devfs_rules

#	install_0base
		# zfs create zroot/qubsd/0base
		# tar -C /qubsd/0base -xvf /usr/freebsd-dist/base.txz 
		# head -1 /etc/fstab > /qubsd/0base/etc/fstab

#	install_0net
		# pkg install isc-dhcp44-server bind918 wireguard-tools vim jq
		# copy .cshrc and .vim*
		# ??change /rc.d/wireguard to remove the kldunload??

#	install_0gui	
		# pkg installs 
		# copy .cshrc and .vim*

	# qubsd_cron and rc.conf are last, so no code tries to run until install completion 
	cp -a ${_REPO}/zroot/etc/cron.d/qubsd_cron /etc/cron.d/qubsd_cron
	# Modify rc.conf
}

main
