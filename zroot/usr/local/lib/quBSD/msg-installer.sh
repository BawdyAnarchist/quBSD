#!/bin/sh

msg_installer() {
	case "$1" in
	_m1) 
		echo -e "Proposed dataset for rootjails < $jails_zfs > doesnt exist and cant be created."
		echo -e "Enter valid name (normally zroot/qubsd):  \c"
		;;
	_m2)
		echo -e "Proposed dataset for appjails < $zusr_zfs > doesnt exist and cant be created." 
		echo -e "Enter valid name (normally zroot/zusr):  \c"
		;;
	_m3)
		echo -e "Proposed mountpoint for rootjails < $jails_mount > isnt a valid name." 
		echo -e "Enter valid name (normally /qubsd):  \c"
		;;
	_m4)
		echo -e "Proposed mountpoint for appjails < $jails_mount > isnt a valid name." 
		echo -e "Enter valid name (normally /zusr):  \c"
		;;
	_m5)
		echo -e "Installer couldnt determine a network interface to passthru to the nicvm." 
		echo -e "Here's a list of physical network interfaces:  $_nic"
		echo -e "Please enter one of the above interfaces (or: skip):  \c"
		;;
	_m6)
		echo -e "< $_nic > is not a valid response. Try again:  \c"
		;;
	_m7) cat << ENDOFMSG
It's safer to handle USB storage devices inside a VM. Here you can select USB
ports that will be set for pci passthru, and only available inside the usbvm.
Simply plug/unplug a USB to each port one at a time. Press {Enter} when done. 
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

