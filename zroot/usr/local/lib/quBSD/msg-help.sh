#!/bin/sh

get_msg_help() {
	local _message="$1"

	case "$_message" in
	help_msg) cat << ENDOFMSG

qb-help: Quick help for quBSD scripts

Usage: qb-help list|show > Shows all scripts
       qb-help params|parameters > Shows all quBSD.conf parameters
       qb-help -h > shows this help message

NOTE:  Some commands/parameters apply to both jails and VMs. Others
       apply only to one or the other.  <jail/VM> | <jail> | <VM>
ENDOFMSG
	;;
	list_scripts) cat << ENDOFMSG

qb-autosnap: Tool to automate the creation, management, and thinning
             of ZFS snapshots. Works in combination with /etc/crontab.
qb-cmd:      Runs command inside <jail>; OR connects to <VM> via
             tmux/vncviewer. If <jail/VM> is off, it will be started.
qb-connect:  Creates a network connection between any two jails, and/or
             between a jail and VM, depending on the VM configuration.
qb-create:   Automates creation of new jails/VMs. Options exist to clone
             an existing jail, initialize/cofigure from scratch,
             or a guided mode with descriptive help and input prompts
qb-destroy:  Destroys jail/VM, and removes all lingering pieces
qb-disp:     Launches a disposable jail/VM on the basis of any template.
             Useful for opening questionable files in an isolated env.
qb-dpi:      Modify dpi to launch a program, then autoreverts to default.
qb-edit:     Edit qubsdmap. Checks performed to ensure valid entry
qb-flags:    Jails only - Modify chflags schg/noschg for a running jail.
qb-floatcmd: Launches popup for user-entered command to runside <jail>.
qb-hostnet:  Bring up internet connectivity for host.
qb-i3-genconf: Generates/adds key i3 bindings, based on: i3gen.conf
qb-i3-launch:  Start jails/VMs and launch programes based on i3launch.conf
qb-i3-windows: Lists all i3 workspaces, and the windows/programs in them.
qb-ivpn:     Change ivpn servers for <gateway>. Jails only.
qb-list:     List qubsdmap settings for <jail/VM>, host, or parameter.
qb-pefs:     Create pefs directory, mount, or decrypt pefs-kmod in jail.
qb-record:   Toggles webcam and virtual_oss off/on.
qb-rename:   Renames <jail/VM>. Dependencies are automatically updated.
qb-snap:     Create <jail> snapshot. Necessary for rootjails and dispjails
qb-start:    Start <jails/VMs> in parallel. You MUST use this for parallel
             starts, or you WILL have errors. Dont use custom scripts.
qb-stat:     Realtime status for all jails/VMs (on/off,CPU,RAM,disk,etc)
qb-stop:     Stop <jails/VMs> in parallel. You MUST use this for parallel
             stops or you WILL have errors. Dont use custom scripts.
ENDOFMSG
	;;
	params) cat << ENDOFMSG

PARAMETERS SAVED AT /usr/local/etc/quBSD/qubsdmap.conf
To see default values, run:  qb-list #default
To see detailed description of each PARAMETER, run: qb-help <PARAMETER>

AUTOSNAP:    Snapshot <jail/VM> with qb-autosnap, via /etc/crontab
AUTOSTART:   Automatically start <jail/VM> during host boot
BHYVEOPTS:   Options to pass to bhyve (non-argument options only).
BHYVE_CUSTM: One or more custom [-option <args>] for bhyve launch command.
             Dont include bus:slot, they're automatically set at launch.
CLASS:       rootjail|rootVM|appjail|appVM|dispjail
CPUSET:      Limit <jail/VM> to specific CPU threads. \`none' is unrestricted
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
ROOTENV:     Which <rootenv> zfs system to clone for <jail/VM> . If
             <jail/VM> is itself a ROOTENV; then this entry is self
             referential, but important for script funcitonality.
SCHG:        <jail> directories to flag for chflags schg: <all|sys|none>
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
