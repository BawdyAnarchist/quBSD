
##### VIRTUAL MACHINE INTEGRATION

qb-list
	- should show default value where none exists for jail/VM	
	- jail.conf devfs ruleset should integrate too

figure out why your snapshots are being label with qubsd:autosnap

qb-i3-launch
	- It should have a monitoring time for qb-autostart to finish 

VMs implementation 
	zusr dataset, script internal, in /vmusr
		- hostname ; configure network ; symlink files ;
		- User profiles (if any) stored here

Scripts that should integrate VMs
	- qb-rename , qb-destroy, qb-stat, qb-create, qb-disp
	- Beef up [-h] for at least: qb-start , stop, cmd, 

New scripts
	qb-pci
		- summary of PCI devices relevant to user
		- USB, NIC, maybe others
		- Show what was is currently passthrough'd


# CLEANUP STUFF

USBVM 
	- Auto-install various useful mounting stuff for common devices     
	- Create a proper unprivileged user with devd.conf and automounts     
	- Auto remove password from unprivleged usbvm user     
	- When xterm is closed with ssh connection, the tap1 connect between jail and usbvm should be severed. Need a "trap" command     
	- usbjail - Make a dedicated dispjail for usb handling, with some embedded scripts for copying (usbvm too)

NICVM 
  - Make a Linux VM so that it can use all the wireless protocols.
     - Someone made a post about this in FreeBSD

net-firewall
	- pf.conf 
		- Currently does not integrate all unique wireguard ports of clients (net-jails).
		- needs careful review. Use chatGPT-4


### UPGRADES

ZFS Encrypted Jails

Tor and I2P Jails

Xephyr
	- An absolute must for pw managers and pw entry
	- You might be able to make it a wrapper?
	- Maybe integrate an "X" option for qb-cmd and qb-disp.
	- Wayland/sway might be a good bonus to run in a separate tty

qb-disp
	- Really should be called class=ephemeral
	- Should clone zroot from template as well. 
	- Make it so you can run a specific command directly at the command line.
	- Needs significant rework, to allow for using an appjail as a rootjail
     and the reclone operation for that appjail's zroot.

pwd
	- I think the right way to do this, is export any existing pwd db in /rw, and import it into the created jail (or maybe vice versa) 
	- Right now I'm not so confident on how that's working

Host as Unprivileged user     
	- All jails will have an epair to an offline *Control Jail*      
	- Unprivileged user on host will pass jails SSH commands via Control Jail     
	- Control jail pf will block all, except port 22 between host and jails     

qb-backup (already created in $ubin)
	- cron to run on both sides of source and dest, with ssh hostname, to automate backups

qubsd_installer
	- /etc/devfs.rules - I probably have the mixer being added, but jails don't need it.
	- qb-autosnap 
		- /etc/crontab
		- Need to add the zfs custom props to the datasets as created (qubsd-installer)

	- qb-autostart
		/etc/rc.conf
		/rc.d/jautostart 

	- Expand install options     
		Can select to merge zroot and zusr with other existing dataset/mount     

	- Double check the install script that it copies qb-ivpn to 0net

	- /var/log/quBSD.log - line added to /usr/local/etc/X11/xinit/xinitrc to remove the log at each startx
		- This could be made a cron, to periodically delete it.
	
	- /jails/0base installer needs to create the /rw/ folder, or appjails based on it, won't mount properly

	- 0serv and 0serv-template need integrated	
		- www and usr diretories are quite large. Script integration:
			- at quBSD installation, copy files over from 0serv
			- qb-create should in realtime copy over /usr/local/etc from 0serv
			- There might even be problems with pkg-upgrade operating on this dir
			- Make sure to chown the directories as appropriate

	- 0net
		- /usr/local/etc/rc.d/qb_dhcpd 
		- /usr/local/etc/
	
	- devfs.rules
		- add qubsd to the naming convention
		- the new one for webcam
		- Maybe the file should be added to the get_global_variables assignments library

	- net-jails
		- isc-dhcp44-server installed
		- /jails/0net/usr/local/etc/dhcpd.conf 
		- Check that pf conf is updated with required dhcp port, and the simplified version

	- JAILS_ZFS and ZUSR_ZFS ; and mountpoints changed. Less cumbersome, more straightforward
	
	- VMs integration
		- install bhyve-uefi firmware
	
	- quBSD.conf removed. Everything now in jailmap.conf

### BEST PRACTICES / FIXES / CLEANUP

Convert all JMAP to QCONF , and rename jailmap.conf quBSD.conf

connect_client_to_gateway
	- It could be efficiencized. For now just uses dumb switches for VMs, duplicating lines 

Cycle all scripts through shellcheck again. 
	- local variables need to be removed and func variables checked for clean/sanitary
	- the && || constructions are NOT if/then/else
		-- Sometimes this is fine, you're just calling messages, but other times might not be

/usr/local/share/quBSD 
	- Needs updated in general after you're done
	- Needs to document that the rootjails must stay lowered schg
	- Update the guides regarding #defaults in jailmap.

quBSD.sh and msg-qubsd.sh
	- Error messages feel a bit disorganized now.
		- Rework the name/numbering scheme.
		- Review if there are extra/excess. Trim them
		- Sometimes errors seem too specific and not general enough.
			Example - instead of "jail invalid" often we get a generic: "needs a class" 
		
	- There might be some consideration to further generalization of major functions like get_jail_parameter
		- Passing through the -q [quiet] -s [skipchecks] and even a new [-f force] 
			This enables easier to implement features (like with ephemeral jails that use appjail clones as rootjails
		- Master -V (verbose) command could be included on all top level scripts, with -q as default 
		- (x)tra check on chk_valid_{param} for certain circumstances
		-(r)esolve value (for stuff like ip auto)
		- Could also beef up the log file, and make reference to it in error messages

qubsd_ipv4 - there's probably room for IP expansion for multiple strings of gateways .. maybe.

zusr fstabs
	- They're hand jammed, but maybe qb-edit should come with a function for changing the zfs dataset and mounts
	- This should probably also change the fstabs? 
	- Really maybe a bit unnecessary, but maybe do it later

Hardened FreeBSD. Implements alot of HardenedBSD stuff with a simple .ini file and code.
https://www.reddit.com/r/freebsd/comments/15nlrp6/hardened_freebsd_30_released/

qb-autosnap might need looked at for leaving snapshots that could be deleted

You should make a check for a circular reference in the networking.
	- firewall client is ivpn-bra. ivpn-bra client is torrents. torrents client is firewall

qb-cmd should pull from the user's chosen shell, not default to csh
	- I do worry tho, that the csh -c '<commands>' construction might fail if I do that

pretty sure reclone_zroot needs to be optimized

new sed discovery
	- -En with (parenthesis) and \1. Just solid amazing stuff

NOTE: The "net-firewall" switches solution is
	if [ ${_class_of_gateway##*VM} ] and also maybe _class_of_client
	- chk_isqubsd_ipv4
	- define_ipv4_convention
	- discover_open_ipv4

sed doesnt need /g for the substitutions. Just leave it be. g is only for multiple matches in same line (not document)
	- go through and remove these g's. Unnecessary

### MINOR UPGRADES 

qb-help: forget the docs, make the more in depth stuff part of qb-help. Like a man page

monitor_startstop
	- Could make this granular to each jail/VM

qb-update - Update rootjails, create snapshots

qb-list or qb-edit - [-e] (evaluate) option to check jail-param combos for validity.

qb-autosnap and qb-snap
	- you might review that to see if listing the autosnaps could be improved on a per-jail basis
	- either that, or just remove the list function entirely and roll into qb-list
	- I'm really thinking that "autosnap" should just be a specific case of the general qb-snap

qb-mvpn - Mullvad VPN: Query and parse mullvad server json; apply to VPN

Crons - I have no crons running. This is probably something long term security that should be integrated and automated.
man pages

Intelligent resizing of fonts depending on dpi or xrandr resolution

ntpd
	- ntpd only runs during qb-hostnet. Needs a more "correct" solution.

qme-firefox needs fixed (personal note)


