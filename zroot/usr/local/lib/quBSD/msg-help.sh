#!/bin/sh

get_msg_help() { 
	local _message="$1"

	case "$_message" in
	help_msg) cat << ENDOFMSG

qb-help: Quick help for quBSD scripts

Usage: qb-help list|show > Shows all scripts
       qb-help params|parameters > Shows all quBSD.conf parameters
       qb-help -h > shows this help message

NOTE:  In most cases <jail> refers to both VMs and jails;
       except for commands/parameters which apply only to jails. 
ENDOFMSG
	;;	
	list_scripts) cat << ENDOFMSG

qb-autosnap: Tool to automate the creation, management, and thinning
             of ZFS snapshots. Works in combination with /etc/crontab.
qb-cmd:      Runs a command inside of a jail - starts the jail if off
qb-connect:  Creates/destroys epairs between jails. Options for
             auto-configuration for immediate internet connectivity
qb-create:   Automates creation of new jails. Options exist to clone
             an existing jail, initialize/cofigure from scratch,
             or a guided mode with descriptive help and input prompts
qb-destroy:  Destroys jail and removes all lingering pieces
qb-disp:     Launches a disposable jail on the basis of any jail.
             Useful for opening questionable files in an isolated env. 
qb-dpi:      Modify dpi to launch a program, then autoreverts to default.
qb-edit:     Edit jailmap. Checks performed to ensure valid entry
qb-flags:    Remove or re-apply schg flags from all jail files,
qb-floatcmd: Launches a popup to accept/run a single command for a jail. 
qb-hostnet:  Bring up internet connectivity for host.
qb-i3-genconf: Generates/adds key i3 bindings, based on: i3gen.conf 
qb-i3-launch:  Starts jails and launches programes based on: launch.conf
qb-i3-windows: Lists all i3 workspaces, and the windows/programs in them.
qb-ivpn:     Change ivpn servers for gateway jail
qb-list:     List jailmap settings for a particular jail or parameter
qb-pefs:     Creation pefs directory, mount, or decrypt pefs-kmod in jail
qb-record:   Toggles webcam and virtual_oss off/on
qb-rename:   Renames a jail. Option to update downstream dependencies
qb-snap:     Create jail snapshot. Necessary for rootjails and dispjails
qb-start:    Start jails in parallel. from list, file, or jmap autostarts
qb-stat:     Continuously running status script for quBSD and jail status
qb-stop:     Remove/restart specified jails. Options for -all and -except
ENDOFMSG
	;;	
	params) cat << ENDOFMSG

PARAMETERS SAVED AT /usr/local/etc/quBSD/jailmap.conf
To see default values, run:  qb-list #default
To see detailed description of each PARAMETER, run: qb-help <PARAMETER>

AUTOSNAP:    Snapshot <jail/VM> with qb-autosnap, via /etc/crontab
AUTOSTART:   Automatically start <jail/VM> during host boot
BHYVEOPTS:   Options to pass to bhyve (non-argument options).
CLASS:       rootjail|rootVM|appjail|appVM|dispjail 
CPUSET:      Limit <jail> to specific CPU cores. \`none' means unrestricted
             Comma separated, or range:  0,1,2,3 is the same as 0-3
GATEWAY:     Gateway through which <jail/VM> connects to external network
IPV4:        IPv4 address for <jail/VM>. Normally should be set to 'auto' 
MAXMEM:      RAM maximum allocation for <jail>:  <integer><G|M|K> 
             For example: 4G or 3500M, or \`none' for no limit
MEMSIZE:     RAM allocation for <VM>. Same format as MAXMEM,
             except that \`none' is not permissible
MTU:         MTU for interfaces created for <jail/VM>
NO_DESTROY:  Prevents accidental destruction of <jail/VM>
             Change to \`false' in order to use qb-destroy
PPT:         PCI_PassThru. Devices will be passed to <VM>. Must have
             same form as in /boot/loader.conf  <bus/device/function>
ROOTJAIL:    Which rootjail system to clone for <jail> . If <jail>
             is a rootjail; then this entry is self referential,
             but important for script funcitonality
ROOTVM:      Same as ROOTJAIL, but for <VM>. VMs are cloned from ROOTVM
SCHG:        Directories to receive schg flags: all|sys|none
             \`sys' are files like: /boot /bin /lib , and others
             \`all includes /usr and /home as well
SECLVL:      kern.securelevel to protect <jail>: -1|0|1|2|3
             \`1' or higher is required for schg to take effect
TAPS:        Number of "tap" (virtual) interfaces to create for <VM>
TMUX:        Launch <VM> with tmux wrapper. Connect and open terminal with:
               qb-cmd -t <VM>
TEMPLATE:    Only applicable for dispjail. Designates jail to
             clone (including /home) for dispjail
VCPUS:       Number of virtual CPUs to allocate to <VM>
ENDOFMSG
	;;
	_4) cat << ENDOFMSG
#####
ENDOFMSG
	;;
	_5) cat << ENDOFMSG
#####
ENDOFMSG
	;;
	esac
}
