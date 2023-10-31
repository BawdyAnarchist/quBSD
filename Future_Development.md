##### VIRTUAL MACHINE INTEGRATION

net-firewall DHCP - could it be nicvm MTU?

qb-cmd VM is still spitting out noise

reinstall 0base

qubsd.sh
	- reclone_zroot probably needs to be optimized. Maybe not. Seems okay

# After SSH and scp is hammered out, make another system backup 
Overview - taps will live on host. Each VM gets 1, and it's vtnet0.
This should tie in nicely with an eventual control jail. STEPS:
	1) Beef up security of pf_pass.conf. TAPS never. Epair only. Unique static IP
	2) Add cron to continually re-assert the DOWN state of taps 
	3) qb-hostnet edits
	4) prep_bhyve_options changes
		- taps handled differenty now, automatic+1 for qmap entry
	5) change the zusr of VMs to vtnet1, because all vtnet0 is now for control tap 

qb-connect - VM integration: jail/VM connections, specifically SSH preparation for files copy

qb-pci
	- summary of PCI devices relevant to user
	- USB, NIC, maybe others
	- Show what was is currently passthrough'd

Ubuntu - zusr dataset integration; user profiles

USBVM 
	- Create a proper unprivileged user with devd.conf and automounts     
	- Auto remove password from unprivleged usbvm user     
	- usbjail - Make a dedicated dispjail for usb handling, with some embedded scripts for copying (usbvm too)


### UPGRADES

ZFS Encrypted Jails

Tor and I2P Jails

GUI SECURITY
	- Test Wayland in separate tty
	- Test Xpra, Xauth and try to isolate xhost 
	Xephyr - Unfortunately I'm not sure this is a real solution. Everything still shares the unix socket
		- Might not matter, but if I keep it, some ideas:
			- the qb-xephyr command into qb-cmd -X, including VMs. Make sure works with -n as well.
			- Integrate an "X" option for qb-ephm as well.

pwd
	- I think the right way to do this, is export any existing pwd db in /rw, and import it into the created jail (or maybe vice versa) 
	- Right now I'm not so confident on how that's working

Host as Unprivileged user     
	- All jails will have an epair to an offline *Control Jail*      
	- Unprivileged user on host will pass jails SSH commands via Control Jail     
	- Control jail pf will block all, except port 22 between host and jails     

NICVM - Linux VM so that it can use all the wireless protocols.
     - Someone made a post about this in FreeBSD


### SPECIFIC SCRIPTS

qb-i3-launch - had problems with double launching windows that already existed (on fully opened setup)

quBSD.sh and msg-qubsd.sh
	- Error messages are a bit disorganized now. Need to have useful higher function messages
		- **Give each jail and VM it's own separate log file under a quBSD directory, for clarity of log messages**
		- Master -V (verbose) command could be included on all top level scripts, with -q as default 
		- Might need a -F force option.
		- Beef up the log file, and make reference to it in error messages

qb-list [-e] (evaluate) option to check jail-param combos for validity.

qb-stop
	- monitoring is still not right. It exits early, coz pgrep returns nothing after 2 cycles 
	- It's too slow. There's got to be a way to make it more efficient

qb-help - overhaul to act like a manpage. Replacing /usr/local/share/quBSD
	- Each PARAM should have verbose message

qb-ephm - Clone from zroot too. Tricky, because of "reclone_zroot" operation in exec.prepare 

qb-update - Update rootjails, create snapshots

qb-backup (already created in $ubin)
	- cron to run on both sides of source and dest, with ssh hostname, to automate backups

qb-stat - Change hardcoded to more flexible setup: config file, col selector, RAM/CPU/DISK colorize


### GENERAL / BEST PRACTICES / CLEANUP

GENERAL GUIDELINES, and maybe later double checks
	- Attempt to make scripts more robust and account for user error, when it makes sense to do so.
	- Try to use more redirects, tee's, and also try the 'wait' command for scripts that appear to hang (but are actually finished).
	- PARAMETERS should be CAPS when refering to the generic PARAM; lowercase when refering to a specific value
	- [test] { command ;} grouping. Can save alot of space and simplify the get_msg constructions
	- while getopts <opts> opts ; do case $opts in
	  esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift
	- Double check on things that are positional items vs if they should be options 

Cycle all scripts through shellcheck again. 
	- local variables are fine for FreeBSD 
	- [] && || constructions are NOT if/then/else. Most are fine, just msg printing, but needs reviewed

zusr fstabs
	- They're hand jammed, but maybe qb-edit should come with a function for changing the zfs dataset and mounts
	- This should probably also change the fstabs? 
	- Really maybe a bit unnecessary, but maybe do it later

Hardened FreeBSD. Implements alot of HardenedBSD stuff with a simple .ini file and code.
https://www.reddit.com/r/freebsd/comments/15nlrp6/hardened_freebsd_30_released/

NOTE: The "net-firewall" switches solution is
	if [ ${_class_of_gateway##*VM} ] and also maybe _class_of_client
	- chk_isqubsd_ipv4
	- define_ipv4_convention
	- discover_open_ipv4

Crons - No crons running. Probably something long term security that should be integrated and automated.

Intelligent resizing of fonts depending on dpi or xrandr resolution

ntpd - ntpd only runs during qb-hostnet. Needs a more "correct" solution. Maybe rolled into the control jail

qme-firefox needs fixed (personal note)

I think `jail` caches fstab before completion of exec.prepare which edits it. Need to prove/submit bug. Need dtrace


##### qubsd installer #######

/etc/devfs.rules - I probably have the mixer being added, but jails don't need it.
	- qb-autosnap 
	- /etc/crontab
	- Need to add the zfs custom props to the datasets as created (qubsd-installer)

qb-autostart
	/etc/rc.conf
	/rc.d/jautostart 

Expand install options     
	Can select to merge zroot and zusr with other existing dataset/mount     

/qubsd/0base installer needs to create the /rw/ folder, or appjails based on it, won't mount properly
I think I need to touch /etc/fstab with header so disps work? Or something like that

0serv and 0serv-template need integrated	
	- www and usr diretories are quite large. Script integration:
		- at quBSD installation, copy files over from 0serv
		- qb-create should in realtime copy over /usr/local/etc from 0serv
		- There might even be problems with pkg-upgrade operating on this dir
		- Make sure to chown the directories as appropriate
	
devfs.rules
	- add qubsd to the naming convention
	- the new one for webcam
	- Maybe the file should be added to the get_global_variables assignments library

net-jails
	- isc-dhcp44-server installed
	- Check that pf conf is updated with required dhcp port, and the simplified version

R_ZFS and U_ZFS ; and mountpoints changed. Less cumbersome, more straightforward

VMs integration
	- install bhyve-uefi firmware
	
quBSD.conf removed. Everything now in jailmap.conf

Should make the $qubsd/zroot/0net 0gui 0vms and everything files here for specific stuff like rc.conf


