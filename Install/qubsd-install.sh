#!/bin/sh

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
	# Manually load ppt devices to the appropriate locations
	[ -z "$nic" ] && get_msg "_5"
}

get_usbs() {

}

modify_host() {
	# Install pkgs
	[ "$GUI" = "true" ] && _pkgs="xorg tigervnc-viewer"
	[ "$i3wm" = "true" ] && _pkgs="$_pkgs i3 i3lock i3status"
	pkg install -y $_pkgs

	# Modify xinitrc
	[ "$GUI" = "true" ] && echo "xhost + local:" >> /usr/local/etc/X11/xinit/xinitc 
	[ "$i3wm" = "true" ] && echo "i3" >> /usr/local/etc/X11/xinit/xinitrc 

	# Create datasets and modify custom props appropriately

	# Modify qubsdmap and jail.conf with path for rootjails 
	sed -i '' -E "s:(#NONE[[:blank:]]+jails_zfs[[:blank:]]+)zroot/qubsd:\1$jails_zfs:" \
			/usr/local/etc/quBSD/qubsdmap.conf
	sed -i '' -E "s:(^path=/)qubsd:\1${root_mount}:" /usr/local/etc/quBSD/jail.conf

	# Modify loader.conf with ppt devices and with schedul.thresh=0

	# Modify devfs.rules

	# Modify rc.conf
}

main() {
	# Read all uncommented variables from install.conf
	_REPO="/usr/local/share/quBSD"
	. ${_REPO}/install.conf
	. /usr/local/lib/quBSD/msg-installer.sh

	load_kernel_modules
	
	# Get any missing parameters from the user before proceeding with install
	get_datasets
	get_nic
	get_usbs

	# Begin system modification
	modify_host

	# Unpack 0base rootjail
		# zfs create zroot/qubsd/0base
		# tar -C /qubsd/0base -xvf /usr/freebsd-dist/base.txz 
		# head -1 /etc/fstab > /qubsd/0base/etc/fstab

	# Clone 0base to 0net  
		# pkg install isc-dhcp44-server bind918 wireguard-tools vim jq
		# copy .cshrc and .vim*
		# ??change /rc.d/wireguard to remove the kldunload??

	# Clone 0base to 0gui
		# pkg installs 
		# copy .cshrc and .vim*
}

main
