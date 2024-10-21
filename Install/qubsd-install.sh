#!/bin/sh

define_vars() {
	REPO="/usr/local/share/quBSD"
	XINIT="/usr/local/etc/X11/xinit/xinitrc"
	QLOADER="/boot/loader.conf.d/qubsd_loader.conf"
	Q_DIR="/usr/local/etc/quBSD"
	Q_CONF="${Q_DIR}/qubsdmap.conf"
	J_CONF="${Q_DIR}/jail.conf"
	RC_CONF="${Q_DIR}/rc.conf"

	# Read all uncommented variables from install.conf
	. ${REPO}/Install/install.conf
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
		zfs create -n "$jails_zfs" > /dev/null 2>&1 && break

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
	_NICS=$(pciconf -lv | grep -B3 "= network")
	_nics=$(echo "$_NICS" | grep -Eo "^[[:alnum:]]+" | grep -v none | tr '\n' ' ')

	# Missing $nic implies pkg install failed to find interface. Ask user for input 
	if [ -z "$nic" ] ; then
		msg_installer "_m5"
		read nic 

		while : ; do 
			echo "$_nics skip" | grep -Eqs "${nic}" && break
			msg_installer "_m6"
			read nic
		done
	fi
	
	# $nic will be used later for nicvm, but all NICs will be passthru, for host security.
	for _dev in $_nics ; do
		_nic=$(pciconf -l $_dev | sed -E "s/^${_dev}@pci([^[:blank:]]+):.*/\1/" | sed -E "s#:#/#g")
		echo "$ppt_nics" | grep -qs "$_nic" || ppt_nics="$ppt_nics $_nic"
	done
}

get_usbs() {
	# temp files and background function monitor/record USB ports for user ppt passthru selection.

	#Make sure that tmp files dont already exist (in case install was killed ungracefully previously.
	rm /tmp/qubsd_usbconf* > /dev/null 2>&1

	# Make temporary files for diff function and communication to `usb_config`
	tmp1=$(mktemp /tmp/qubsd_usbconf1)
	tmp2=$(mktemp /tmp/qubsd_usbconf2)
	tmp3=$(mktemp /tmp/qubsd_usbconf3)
	tmp4=$(mktemp /tmp/qubsd_usbconf4)
	trap 'rm $tmp1 $tmp2 $tmp3 $tmp4' INT TERM HUP QUIT EXIT

	# Set monitoring loop to background, give user instructions, wait for user input when finished.
	usb_config &
	clear && msg_installer "_m7" 
	read _cont 

	# Signal usb_config infinite loop to exit, and give a moment for the loop to finish and exit 
	echo "exit" > $tmp4
	sleep 1
}

usb_config() {
	# Record pre-state of usb situation
	usbconfig > $tmp1 

	# Continuously monitor usbconfig output for changes as user plugs/unplugs USB to ports.
	while : ; do
		usbconfig > $tmp2	
		usbs=$(diff $tmp1 $tmp2 | sed -En "/^> /s/^> //p")

		# read-while necessary in case the user plugs multiple usbs simultaneously
		echo "$usbs" | while IFS= read -r _line ; do
			grep -qs "$_line" $tmp3 || echo "${_line}" >> $tmp3
		done

		sleep .5
		grep -qs "exit" $tmp4 && break 
	done	

	return 0
}

translate_usbs() {
	# Translate the output of usbconfig to ppt devices

	USBS=$(cat $tmp3)
	# Cleanup tmp files and trap
	rm $tmp1 $tmp2 $tmp3 $tmp4
	trap '' INT TERM HUP QUIT EXIT

	# For final_confirmation, if install.conf has ppts_usbs specified, translate them to names
	for _dev in $ppt_usbs ; do
		_dev=$(echo $_dev | sed -E 's#/#:#g')
		dev_usbs=$(echo "$dev_usbs $(pciconf -l | sed -En "s/(^[[:alnum:]]+)@.*${_dev}.*/\1/p")")
	done	

	# First find the corresponding PCI device name via sysctl
	usbus=$(echo $USBS | grep -Eo "usbus[[:digit:]]+" | sed -E 's/usbus/usbus./')
	for _usb in $usbus ; do
		_usb=$(sysctl dev.${_usb}.%parent | grep -Eo '[^[:blank:]]+$')
		echo "$dev_usbs" | grep -qs "$_usb" || dev_usbs="$dev_usbs $_usb"
	done

	# Then translate each name to an actual bus location
	for _ppt in $dev_usbs ; do
		_ppt=$(pciconf -l $_ppt | sed -E "s/^.*@pci([^[:blank:]]+):.*/\1/" | sed -E "s#:#/#g")
		echo "$ppt_usbs" | grep -Eqs "$_ppt" || ppt_usbs="$ppt_usbs $_ppt"		
	done

	# Clean up spaces in final variables. Set variable so "at" doesnt appear if there were no usbs.
	dev_usbs=$(echo $dev_usbs | sed -E 's/^[[:blank:]]+(.*)[[:blank:]]+$/\1/')
	[ -n "$dev_usbs" ] && _at=" at "
}

final_confirmation() {
	msg_installer "_m8"
	read _response
   case "$_response" in
      y|Y|yes|YES) return 0 ;;
      *) msg_installer "_m9" ; exit 0 ;;
   esac 
}

add_gui_pkgs() {
	# Install pkgs
	[ "$GUI" = "true" ] && _pkgs="xorg tigervnc-viewer"
	[ "$i3wm" = "true" ] && _pkgs="$_pkgs i3 i3lock i3status"
	pkg update
	pkg install -y $_pkgs

	# Modify xinitrc
	[ "$GUI" = "true" ] && echo "xhost + local:" >> $XINIT
	[ "$i3wm" = "true" ] && echo "i3" >> $XINIT
}

create_datasets() {
	# Create datasets and modify custom props appropriately
	zfs list $jails_zfs > /dev/null 2>&1 || zfs create $jails_zfs
	zfs set mountpoint="$jails_mount" qubsd:autosnap=true $jails_zfs
	
	zfs list $zusr_zfs > /dev/null 2>&1	|| zfs create $zusr_zfs
	zfs set mountpoint="$zusr_mount"  qubsd:autosnap=true $zusr_zfs

	# Modify qubsdmap and jail.conf with path for rootjails 
	sed -i '' -E "s:(#NONE[[:blank:]]+jails_zfs[[:blank:]]+)zroot/qubsd:\1$jails_zfs:" $Q_CONF
	sed -i '' -E "s:(^path=/)qubsd:\1${root_mount}:" $J_CONF 
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
	sysrc -f $QLOADER "$devsnum"+="$ppt_nics $ppt_usbs"
}

modify_devfs_rules() {
	# /etc/devfs.rules is modified here and not at pkg install,
	# because it requires changing a file outside of /usr/local

	# Add default devfs if it doesnt exist.
	[ -e "/etc/devfs.rules" ] || cp -a /etc/defaults/devfs.rules /etc/devfs.rules

	# Make a copy of the qubsd devfs.rules in /tmp 
	tmp_devfs=$(mktemp /tmp/qubsd_devfs)
	cp -a $REPO/zroot/etc/devfs.rules $tmp_devfs

	# Check /etc/devfs.rules, and search for two consecutive unused rule numbers 
	_lastnum=$(sed -n "s/^\[devfsrules.*=//p ; s/\]//p" /etc/devfs.rules | tail -1)
	[ -z "$_lastnum" ] && _lastnum=0
	while : ; do
		rulenum1=$(( _lastnum + 1 ))
		rulenum2=$(( _lastnum + 2 ))
			! grep -Eqs "^\[devfsrules.*=${rulenum1}" /etc/devfs.rules \
				&& ! grep -Eqs "^\[devfsrules.*=${rulenum2}" /etc/devfs.rules && break
	done

	# Add the discovered rule numbers to quBSD devfs and jail.conf
	sed -i '' -E "s/(^\[devfsrules_qubsd_netjail=)/\1$rulenum1/" $tmp_devfs 
	sed -i '' -E "s/(^\[devfsrules_qubsd_guijail=)/\1$rulenum2/" $tmp_devfs 
	sed -i '' -E "s/NETRULENUM1/$rulenum1/g" $J_CONF 
	sed -i '' -E "s/GUIRULENUM2/$rulenum2/g" $J_CONF

	# Check for all GPUs in pciconf, and uncomment/unhide based on vendor(s)
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

modify_rc_conf() {
	# Need to be careful about modifying user's rc.conf. Comment out duplicate lines
   while IFS= read -r _line ; do
      _param=$(echo $_line | sed -E "s/^#//" | sed -E "s@^(.*=).*@\1@")
      [ -n "$_param" ] && sed -i '' -E "s@^(${_param}.*)@#\1@" /etc/rc.conf
   done < "${REPO}/zroot/etc/rc.conf"

   # Copy qubsd lines and restart jail
   cat ${REPO}/zroot/etc/rc.conf >> /etc/rc.conf
   service jail restart
}

install_0base() {
	# Create the zroot/qubsd dataset and extract the new jail
	zfs create -o mountpoint="${jails_mount}/0base" -o qubsd:autosnap="true" ${jails_zfs}/0base
	tar -C ${jails_mount}/0base -xf /usr/local/freebsd-dist/base.txz
	head -1 /etc/fstab > /qubsd/0base/etc/fstab

	# Create the zusr dataset and copy/modify files from the repo
	zfs create -o mountpoint="${zusr_mount}/0base" -o qubsd:autosnap="true" ${zusr_zfs}/0base
	cp -a ${REPO}/zusr/0base/ ${zusr_mount}/0base
	cp ${REPO}/zusr/0base/home/0base/ ${jails_mount}/0base/root
	change_fstab "0base"
	mkdir ${jails_mount}/0base/rw

	# base.txz point releases do not include patches. Update 0base
	PAGER=cat freebsd-update -b ${jails_mount}/0base --not-running-from-cron fetch install

	ASSUME_ALWAYS_YES="yes" export $ASSUME_ALWAYS_YES
	pkg -r ${jails_mount}/0base update

	# Snapshot 0base so it can be used for other rootjails
	zfs snapshot ${jails_zfs}/0base@INSTALL
}

install_0net() {
	# Duplicate 0base for 0net
	zfs send ${jails_zfs}/0base@INSTALL | zfs recv ${jails_zfs}/0net

	# Create the zusr dataset and copy files from the repo
	zfs create -o mountpoint="${zusr_mount}/0net" -o qubsd:autosnap="true" ${zusr_zfs}/0net
	cp -a ${REPO}/zusr/0net/ ${zusr_mount}/0net

	change_fstab "0net"

	pkg -r ${jails_mount}/0net install -y isc-dhcp44-server bind918 wireguard-tools vim jq
}

install_0gui() {
	# pkg installs 
	# copy .cshrc and .vim*

}

change_fstab() {
	# Mountpoints in rw/etc/fstab must reference the user's zfs mountpoints
	_jail="$1"

	# Use tmp file so that column can make the file pretty
	sed -E "s: /qubsd: ${jails_mount}:" ${jails_mount}/${_jail}/rw/etc/fstab > /tmp/temp_fstab
	cat /tmp/temp_fstab > ${jails_mount}/${_jail}/rw/etc/fstab
	sed -E "s:^/zusr:${zusr_mount}:" ${jails_mount}/${_jail}/rw/etc/fstab | column -t > /temp/temp_fstab
	cat /tmp/temp_fstab > ${jails_mount}/${_jail}/rw/etc/fstab
	rm /tmp/temp_fstab
}

main() {
	define_vars
	load_kernel_modules

	# PREPARATION - Get missing parameters from the user before making any changes 
	get_datasets
	get_nic
	get_usbs
	translate_usbs
	final_confirmation

	# SYSTEM INSTALLATION
	add_gui_pkgs
	create_datasets
	modify_pptdevs
	modify_devfs_rules
	modify_rc_conf
	[ -d "/tmp/quBSD" ] || mkdir /tmp/quBSD

	# ROOTJAILS INSTALLATION
	install_0base

echo MY SAFETY EXIT
exit 0
	install_0net
	install_0gui

####
# Still to do: VM installation

###

	# qubsd_cron is last so no code tries to run until install completion 
	cp -a ${REPO}/zroot/etc/cron.d/qubsd_cron /etc/cron.d/qubsd_cron

# FINAL NOTES ABOUT WHICH SYSTEM FILES WERE MODIFIED/ADDED
	# rc.conf 
	# devfs.rules
	# /boot/loader.conf.d ; /etc/cron.d
# REBOOT SYSTEM
}

setlog() {
	set -x 
	exec > /root/debug 2>&1
}

main




