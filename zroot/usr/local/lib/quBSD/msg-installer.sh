#!/bin/sh

msg_installer() {
	case "$1" in
	_m1) 
		echo -e "Proposed dataset for rootjails < $jails_zfs > doesnt exist and cant be created."
		echo -e "Enter valid name (normally zroot/qubsd):  \c"
		;;
	_m2) cat << ENDOFMSG
		echo -e "Proposed dataset for appjails < $zusr_zfs > doesnt exist and cant be created." 
		echo -e "Enter valid name (normally zroot/zusr):  \c"
ENDOFMSG
		;;
	_m3)
		echo -e "Proposed mountpoint for rootjails < $jails_mount > isnt a valid name." 
		echo -e "Enter valid name (normally /qubsd):  \c"
		;;
	_m4)
		echo -e "Proposed mountpoint for appjails < $zusr_mount > isnt a valid name." 
		echo -e "Enter valid name (normally /zusr):  \c"
		;;
	_m5)
		echo -e "For host security, all network interfaces will be designated for pci passthru:"
		echo -e "   $_nics"
		echo -e "Enter one of the above to be used for the nicvm (or "skip"):  \c"
		;;
	_m6)
		echo -e "< $_nic > is not a valid response. Try again:  \c"
		;;
	_m7) cat << ENDOFMSG
Safer to keep USB storage devices inside a VM. Select USB ports to be set for
pci passthru, and only available inside the usbvm. Simply plug/unplug a USB
to each port you want, one at a time. Press {Enter} when done (or to skip).
ENDOFMSG
		;;
	_m8) cat << ENDOFMSG
Configuration to be installed:
Rootjail Dataset:    $jails_zfs
Rootjail Mountpoint: $jails_mount
Appjail Dataset:     $zusr_zfs
Appjail Mountpoint:  $zusr_mount
Network Interface:   $nic
USBs for usbvm:      $dev_usbs $_at $ppt_usbs
Install GUI (xorg):  $GUI
Install i3wm:        $i3wm 
ENDOFMSG
echo -e "Continue? (Y/n):  \c"
		;;
	_m9) cat << ENDOFMSG
EXITING. No changes were made.
ENDOFMSG
		;;

	esac
}

usage() { cat << ENDOFUSAGE

qb-

Usage: qb-
   -h: (h)elp. Outputs this help message.

ENDOFUSAGE
}
