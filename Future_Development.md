##### VIRTUAL MACHINE INTEGRATION

- qb-connect
	- VM integration: jail/VM connections, specifically SSH preparation for files copy
	- Maybe even a 2nd tap, with sshd for ubuntu (or other VMs) on vtnet0 and vtnet1

New scripts
	qb-pci
		- summary of PCI devices relevant to user
		- USB, NIC, maybe others
		- Show what was is currently passthrough'd

Ubuntu upgrades
	zusr dataset integration
		- try Ubuntu zfs install 
		- User profiles

USBVM 
	- Create a proper unprivileged user with devd.conf and automounts     
	- Auto remove password from unprivleged usbvm user     
	- When xterm is closed with ssh connection, the tap1 connect between jail and usbvm should be severed. Need a "trap" command     
	- usbjail - Make a dedicated dispjail for usb handling, with some embedded scripts for copying (usbvm too)

NICVM 
  - Make a Linux VM so that it can use all the wireless protocols.
     - Someone made a post about this in FreeBSD


### UPGRADES

ZFS Encrypted Jails

Tor and I2P Jails

GUI SECURITY
	- Test Wayland in separate tty
	- Test Xpra, Xauth and try to isolate xhost 
	Xephyr - Unfortunately I'm not sure this is a real solution. Everything still shares the unix socket
		- Might not matter, but if I keep it, some ideas:
			- the qb-xephyr command into qb-cmd -X, including VMs. Make sure works with -n as well.
			- Integrate an "X" option for qb-disp as well.

pwd
	- I think the right way to do this, is export any existing pwd db in /rw, and import it into the created jail (or maybe vice versa) 
	- Right now I'm not so confident on how that's working

Host as Unprivileged user     
	- All jails will have an epair to an offline *Control Jail*      
	- Unprivileged user on host will pass jails SSH commands via Control Jail     
	- Control jail pf will block all, except port 22 between host and jails     


### SPECIFIC SCRIPTS

qb-stat
	- I like my hardcode setup, but columns sorting and even a generalized setup file might be better
	- Also the ability to choose which columns are displayed
	- You should use background colors for the RAM and CPU usage. Maybe disk as well

qb-list [-e] (evaluate) option to check jail-param combos for validity.

qb-autosnap and qb-snap
	- you might review that to see if listing the autosnaps could be improved on a per-jail basis
	- either that, or just remove the list function entirely and roll into qb-list
	- I'm really thinking that "autosnap" should just be a specific case of the general qb-snap

qb-stop - monitoring is still not right. It exits early, coz pgrep returns nothing after 2 cycles 

qb-help:
	- forget the docs, make the more in depth stuff part of qb-help. Like a man page
	- Make it robust like qb-list
	- Each PARAM has a verbose message
/usr/local/share/quBSD - Will need a complete overhaul, and maybe roll all into qb-help 

quBSD.sh and msg-qubsd.sh
	- Error messages are a bit disorganized now. Need to have useful higher function messages
		- **Give each jail and VM it's own separate log file under a quBSD directory, for clarity of log messages**
		- Master -V (verbose) command could be included on all top level scripts, with -q as default 
		- Beef up the log file, and make reference to it in error messages
	- get_jail_parameter
		- Passing more variables like -f force , and -x extra , for extra checks sometimes
		- Getting the #default shouldnt be the default behavior. -d should say "get default if nothing is there"
		-(r)esolve value (for stuff like ip auto)
	- Double check on things that are positional items vs if they should be options 
	- chk_isinteger [-l lower_bound] [-u "upper_bound"]. You have a lot of integer checks.

qb-disp
	- Really should be called class=ephemeral
	- Should clone zroot from template as well. 
	- Make it so you can run a specific command directly at the command line.
	- Also make it so that you dont need a terminal. That's annoying. Keep jail alive based on presence of X-window from jail 
	- Needs significant rework, to allow for using an appjail as a rootjail
     and the reclone operation for that appjail's zroot.

qb-update - Update rootjails, create snapshots

qb-backup (already created in $ubin)
	- cron to run on both sides of source and dest, with ssh hostname, to automate backups


### GENERAL / BEST PRACTICES / CLEANUP

GRAMMAR and NOMENCLATURE
	- ${JAILS_ZFS} should probably be ROOT_Z and maybe also then ZUSR_Z.  Also M_ROOT instead of M_JAILS
	- PARAMETERS should be CAPS when refering to the generic PARAM; lowercase when refering to a specific value

FUNCTIONS THAT NEED CLEANED UP AND REVIEWED STILL
	- connect_client_to_gateway ; uses a lot of dumb switches and repeat code
	- reclone_zroot probably needs to be optimized. Maybe not. Seems okay
	- monitor_startstop is on hold and not looking great.

Try to use more redirects, tee's, and also try the 'wait' command for scripts that appear to hang (but are actually finished).

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

Attempt to make scripts more robust and account for user error, when it makes sense to do so.

Crons - No crons running. Probably something long term security that should be integrated and automated.

Intelligent resizing of fonts depending on dpi or xrandr resolution

ntpd - ntpd only runs during qb-hostnet. Needs a more "correct" solution.

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

Double check the install script that it copies qb-ivpn to 0net

/var/log/quBSD.log - line added to /usr/local/etc/X11/xinit/xinitrc to remove the log at each startx
	- This could be made a cron, to periodically delete it.
	
/jails/0base installer needs to create the /rw/ folder, or appjails based on it, won't mount properly

0serv and 0serv-template need integrated	
	- www and usr diretories are quite large. Script integration:
		- at quBSD installation, copy files over from 0serv
		- qb-create should in realtime copy over /usr/local/etc from 0serv
		- There might even be problems with pkg-upgrade operating on this dir
		- Make sure to chown the directories as appropriate

0net
	- /usr/local/etc/rc.d/qb_dhcpd 
	- /usr/local/etc/
	
devfs.rules
	- add qubsd to the naming convention
	- the new one for webcam
	- Maybe the file should be added to the get_global_variables assignments library

net-jails
	- isc-dhcp44-server installed
	- /jails/0net/usr/local/etc/dhcpd.conf 
	- Check that pf conf is updated with required dhcp port, and the simplified version

JAILS_ZFS and ZUSR_ZFS ; and mountpoints changed. Less cumbersome, more straightforward

VMs integration
	- install bhyve-uefi firmware
	
quBSD.conf removed. Everything now in jailmap.conf


