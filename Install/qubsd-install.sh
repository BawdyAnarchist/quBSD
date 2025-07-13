#!/bin/sh

define_vars() {
	REPO="/usr/local/share/quBSD"
	XINIT="/usr/local/etc/X11/xinit/xinitrc"
	QLOAD="/boot/loader.conf.d/qubsd_loader.conf"
	Q_CONF="/usr/local/etc/quBSD/qubsd.conf"
	JCONF_D="/etc/jail.conf.d"
	QRC_CONF="${REPO}/zroot/etc/rc.conf"
	QLOG="/var/log/quBSD/install.log"

	# Read variables and messages
	. "${REPO}/Install/install.conf"
	. /usr/local/lib/quBSD/msg-installer.sh

	[ -d "$(dirname $QLOG)" ] || mkdir -p "$(dirname $QLOG)"
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
		dev_usbs="$dev_usbs $(pciconf -l | sed -En "s/(^[[:alnum:]]+)@.*${_dev}.*/\1/p")"
	done

	# First find the corresponding PCI device name via sysctl
	usbus=$(echo $USBS | grep -Eo "usbus[[:digit:]]+" | sed -E 's/usbus/usbus./')
	for _usb in $usbus ; do
		_usb=$(sysctl dev.${_usb}.%parent | grep -Eo '[^[:blank:]]+$')
		echo "$dev_usbs" | grep -qs "$_usb" || dev_usbs="$dev_usbs $_usb"
	done

	# Then translate each name to an actual bus location
	for _ppt in $dev_usbs ; do
		_ppt=$(pciconf -l $_ppt | sed -E "s/.*pci[0-9]+:([^[:blank:]]+):.*/\1/" | sed -E "s#:#/#g")
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

create_datasets() {
	# Create datasets and modify custom props appropriately
	zfs list $jails_zfs > /dev/null 2>&1 || zfs create $jails_zfs
	zfs set mountpoint="$jails_mount" qubsd:autosnap=true $jails_zfs

	zfs list $zusr_zfs > /dev/null 2>&1	|| zfs create $zusr_zfs
	zfs set mountpoint="$zusr_mount"  qubsd:autosnap=true $zusr_zfs
}

modify_pptdevs() {
	# Avoid using pptdevs in case user modifies loader.conf. Instead pptdevs2 or 3
	if ! grep -qs "pptdevs2" /boot/loader.conf ; then
		devsnum="pptdevs2"
	else
		devsnum="pptdevs3"

		# loader.conf.d supercedes loader.conf, so copy over pptdevs3 if there was one.
		ppt3=$(grep "pptdevs3" /boot/loader.conf)
		[ "$ppt3" ] && echo "$ppt3" >> $QLOAD
	fi
	# Modify qubsd_loader.conf
	sysrc -f $QLOAD "$devsnum"+="$ppt_nics $ppt_usbs"
}

discover_devfs_rulenums() {
	# Check /etc/devfs.rules, and search for two consecutive unused rule numbers
	_lastnum=$(sed -n "s/^\[devfsrules.*=//p ; s/\]//p" /etc/devfs.rules | tail -1)
	[ -z "$_lastnum" ] && _lastnum=0
	while : ; do
		rulenum1=$(( _lastnum + 1 ))
		rulenum2=$(( _lastnum + 2 ))
		! grep -Eqs "^\[devfsrules.*=${rulenum1}" /etc/devfs.rules \
			&& ! grep -Eqs "^\[devfsrules.*=${rulenum2}" /etc/devfs.rules && break
	done
}

modify_devfs_rules() {
	# /etc/devfs.rules is modified here and not at pkg install,
	# because it requires changing a file outside of /usr/local

	# Make backup copy of devfs.rules, or add the default if it doesnt exist
	[ -e "/etc/devfs.rules" ] \
		&& cp -a /etc/devfs.rules /etc/devfs.rules_qubsd_bak \
		|| cp -a /etc/defaults/devfs.rules /etc/devfs.rules

	# Make a copy of the qubsd devfs.rules in /tmp
	tmp_devfs=$(mktemp /tmp/qubsd_devfs)
	cp -a $REPO/zroot/etc/devfs.rules $tmp_devfs

	# Add the discovered rule numbers to quBSD devfs
	sed -i '' -E "s/(^\[devfsrules_qubsd_netjail=)/\1$rulenum1/" $tmp_devfs
	sed -i '' -E "s/(^\[devfsrules_qubsd_guijail=)/\1$rulenum2/" $tmp_devfs

	# Check for all GPUs in pciconf, and uncomment/unhide based on vendor(s)
	for _dev in $(pciconf -l | sed -En "/class=0x03/s/(^[[:alnum:]]+).*/\1/p") ; do
		if pciconf -lv $_dev | grep -Eqs "NVIDIA" ; then
			nvidia="nvidia-driver nvidia-settings"
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

modify_qubsdjail_conf() {
	# Modify qubsd.conf with path for rootjails
	sed -i '' -E "s:(#NONE[[:blank:]]+jails_zfs[[:blank:]]+)zroot/qubsd:\1$jails_zfs:" $Q_CONF

	# Must .include JCONF_D in jail.conf
	echo -e "\n#QUBSD ADDED" >> /etc/jail.conf
	echo -e '.include "/etc/jail.conf.d/*";' >> /etc/jail.conf

	# Modify JCONF_D's with correct paths and devfs rulenums
	for _jail in "${JCONF_D}"/* ; do 
		[ -f "$_jail" ] || continue
		sed -i '' -E "s:(^path=/)qubsd:\1${jails_mount}:" ${JCONF_D}/${_jail}
		sed -i '' -E "s/NETRULENUM1/$rulenum1/g" $JCONF_D
		sed -i '' -E "s/GUIRULENUM2/$rulenum2/g" $JCONF_D
	done
}

modify_rc_conf() {
	# Need to be careful about modifying user's rc.conf. Comment out duplicated lines
	[ -e "/etc/rc.conf" ] && cp -a /etc/rc.conf /etc/rc.conf_qubsd_bak

   while IFS= read -r _line ; do
		_param=$(echo $_line | sed -E "s/^#//" | sed -E "s@^(.*=).*@\1@")
		[ -n "$_param" ] && sed -i '' -E "s@^(${_param}.*)@#\1@" /etc/rc.conf
   done < "$QRC_CONF"

	# Also comment out any lines for ifconfig_, as all interfaces are going to ppt
	sed -i '' -E "s/^(ifconfig_.*)/#\1/" /etc/rc.conf

   cat $QRC_CONF >> /etc/rc.conf
}

add_gui_pkgs() {
	# Install pkgs
	[ "$GUI" = "true" ] && _pkgs="xorg Xephyr socat virtualgl tigervnc-viewer"
	[ "$i3wm" = "true" ] && _pkgs="$_pkgs i3 i3lock i3status"
	msg_installer "_m10"
	pkg install -y $_pkgs $nvidia >> $QLOG

	# xhost + local: requried for quBSD GUI jails. Also modify loader for nvidia modules
	[ "$GUI" = "true" ] && sysrc 'kld_list+=nvidia-modeset' \
		&& echo "xhost + local:" >> $XINIT && [ -n "$nvidia" ]

	# Add the quBSD i3 config supplementation, and change xinitrc for i3wm
	[ "$i3wm" = "true" ] && mkdir -p /root/.config/i3 >> /dev/null 2>&1 \
		&& cp -a ${REPO}/zroot/root/.config/i3/ /root/.config/i3 \
		&& sed -i '' -E "/twm/ d" $XINIT \
		&& sed -i '' -E "/xclock/ d" $XINIT \
		&& sed -i '' -E "/xterm -geometry/ d" $XINIT \
		&& echo "i3" >> $XINIT
}

install_rootjails() {
	# Create 0base and extract new jail
	zfs create -o mountpoint="${jails_mount}/0base" -o qubsd:autosnap="true" ${jails_zfs}/0base
	tar -C ${jails_mount}/0base -xf /usr/local/freebsd-dist/base.txz

	# Copy and modify files (copy all 0base user rc and conf files to root for convenience)
	head -1 /etc/fstab > /qubsd/0base/etc/fstab
	mkdir ${jails_mount}/0base/rw
	cp -a ${REPO}/zusr/0base/home/0base/.*shrc ${jails_mount}/0base/root/
	cp -a ${REPO}/zusr/0base/rw/etc/rc.conf ${jails_mount}/0base/etc/
	cp -a /etc/localtime  ${jails_mount}/0base/etc/

	# Find the user's shell and assume that shell for 0base and all jails thereafter
	_shell=$(pw usershow root | grep -Eo '/bin/.*$')
	pw -V ${jails_mount}/0base/etc usermod root -s $_shell
	pw -V ${jails_mount}/0base/etc usermod 1000 -s $_shell > /dev/null 2>&1

	# Update 0base (base.txz doesnt include latest patches), install pkg, and snapshot
	msg_installer "_m11"
	ASSUME_ALWAYS_YES="yes" ; export ASSUME_ALWAYS_YES
	PAGER='cat' freebsd-update -b ${jails_mount}/0base --not-running-from-cron \
		fetch install >>  $QLOG
	msg_installer "_m12"
	pkg -r ${jails_mount}/0base update >> $QLOG
	zfs snapshot ${jails_zfs}/0base@INSTALL

	# Install all other rootjails and their pkgs as indicated by install.conf
	[ "$GUI" = "true" ] && rootjails="0gui" && appjails="0gui"
	[ "$server" = "true" ] && rootjails="$rootjails 0serv" && appjails="$appjails 0serv"

	for _jail in 0net $rootjails ; do
		case $_jail in
			0net) _pkgs="vim jq wireguard-tools isc-dhcp44-server bind918" ;;
			0gui) _pkgs="vim xorg bspwm virtualgl $nvidia $guipkgs" ;;
			0serv) _pkgs="vim $serverpkgs" ;;
		esac

		# Create rootjail, install pkgs, and snapshot
		zfs send ${jails_zfs}/0base@INSTALL | zfs recv ${jails_zfs}/${_jail}
		msg_installer "_m13"
		pkg -r ${jails_mount}/${_jail} install -y $_pkgs >> $QLOG
		zfs destroy ${jails_zfs}/${_jail}@INSTALL
		zfs snapshot ${jails_zfs}/${_jail}@INSTALL
	done
}

install_appjails() {
	appjails="0base 0net 0control net-firewall net-vpn net-tor $appjails"

	for _jail in $appjails ; do
		zfs create -o mountpoint="${zusr_mount}/${_jail}" -o qubsd:autosnap="true" ${zusr_zfs}/${_jail}
		cp -a ${REPO}/zusr/${_jail}/ ${zusr_mount}/${_jail}
		modify_fstab "$_jail"
		zfs snapshot ${zusr_zfs}/${_jail}@INSTALL
	done

	# 0control needs some key management
	ssh-keygen -qt rsa -b 4096 -N "" -f ${zusr_mount}/0control/rw/root/.ssh/id_rsa
	cp -a /zusr/0control/rw/root/.ssh/id_rsa.pub ${zusr_mount}/0control/home/ftp
	rm ${zusr_mount}/0control/rw/root/.ssh/.gitkeep
}

modify_fstab() {
	# Mountpoints in rw/etc/fstab must reference the user's zfs mountpoints
	_jail="$1"

	# Use tmp file so that column can make the file pretty
	sed -E "s: /qubsd: ${jails_mount}:" ${zusr_mount}/${_jail}/rw/etc/fstab > /tmp/temp_fstab
	cat /tmp/temp_fstab > ${zusr_mount}/${_jail}/rw/etc/fstab
	sed -E "s:^/zusr:${zusr_mount}:" ${zusr_mount}/${_jail}/rw/etc/fstab | column -t > /tmp/temp_fstab
	cat /tmp/temp_fstab > ${zusr_mount}/${_jail}/rw/etc/fstab
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
	create_datasets
	modify_pptdevs
	discover_devfs_rulenums
	modify_devfs_rules
	modify_qubsdjail_conf
	modify_rc_conf
	add_gui_pkgs

	# JAILS/VM INSTALLATION
	install_rootjails
	install_appjails

# STILL DO DO
	# VM installation

	# qubsd_cron is last so no code tries to run until install completion
	cp -a ${REPO}/zroot/etc/cron.d/qubsd_cron /etc/cron.d/qubsd_cron

	msg_installer "_m14"
}


main



