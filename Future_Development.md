
### VIRTUAL MACHINE INTEGRATION
quBSD.conf 
	- ppt_nic and usb should probably be more like: check /boot/loader.conf against pciconf 
	- This would leave only the quBSD_root (zroot/quBSD). I prefer to remove this file entirely	
	- Maybe this value can just get stored in quBSD.sh

A full management scheme for ZFS datasets that will serve as VM templates for VMs 

Generalize staticIP vs auto vs DHCP
	- DHCP requires a split in the logic of starting the jail, where no IP is assigned to the client
	- Requires modifying exec.created ; and the rc.conf for the jail.

A set of start/stop scripts that plug into JMAP

net-jails
	- Now they're dhcpd servers for tap interfaces
	- MTU will need to be targeted and changed in dhcpd.conf at every net-jail start

USBVM 
	- Auto-install various useful mounting stuff for common devices     
	- Create a proper unprivileged user with devd.conf and automounts     
	- Auto remove password from unprivleged usbvm user     
	- When xterm is closed with ssh connection, the tap1 connect between jail and usbvm should be severed. Need a "trap" command     
	- usbjail - Make a dedicated dispjail for usb handling, with some embedded scripts for copying (usbvm too)

NICVM 
  - Make it a Linux VM so that it can use all the wireless protocols.
     - Someone made a post about this in FreeBSD

net-firewall
	- There are many exceptions for net-firewall across the board in the scripts
		- qb-edit ; quBSD.sh ; exec scripts
	- Perhaps it's time to give jails a "purpose" or a "type", in addition to class.
		- Type: firewall jail ; nicvm ; usbvm ; gateway VM ;
	- pf.conf 
		- Currently does not integrate all unique wireguard ports of clients (net-jails).
		- needs careful review. Use chatGPT-4

qb-pci
	- summary of PCI devices relevant to user
	- USB, NIC, maybe others
	- Show what was is currently passthrough'd


### UPGRADES

ZFS Encrypted Jails

Tor and I2P Jails

qb-disp
	- Implement ephemeral jails, which clone the zroot dataset as well 
	- Needs significant rework, to allow for using an appjail as a rootjail
     and the reclone operation for that appjail's zroot.
	- Might not be worth it tbh.

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
	
	- devfs.rules
		- add qubsd to the naming convention
		- the new one for webcam
		- Maybe the file should be added to the get_global_variables assignments library

	- net-jails
		- isc-dhcp44-server installed
		- /jails/0net/usr/local/etc/dhcpd.conf 
		- Check that pf conf is updated with required dhcp port, and the simplified version

### BEST PRACTICES / FIXES / CLEANUP

Cycle all scripts through shellcheck again. 

/usr/local/share/quBSD 
	- Needs updated in general after you're done
	- Needs to document that the rootjails must stay lowered schg
	- Update the guides regarding #defaults in jailmap.

jail -r 
	- <net-jails> are getting an "Operation not permitted" error, I think on wg attempted changing of resolv.conf

quBSD.sh and msg-qubsd.sh
	- Error messages feel a bit disorganized now.
		- Rework the name/numbering scheme.
		- Review if there are extra/excess. Trim them
		- Sometimes errors seem too specific and not general enough.
			Example - instead of "jail invalid" often we get a generic: "needs a class" 
		
	- There might be some consideration to further generalization of functions
		- Passing through the -q [quiet] -s [skipchecks] and even a new [-f force] 
			This enables easier to implement features (like with ephemeral jails that use appjail clones as rootjails


### MINOR UPGRADES IF ANYONE ELSE OUT THERE WANTS TO DO IT

qb-update - Update rootjails, create snapshots

qb-list - [-e] (evaluate) option to check jail-param combos for validity.

qb-mvpn - Mullvad VPN: Query and parse mullvad server json; apply to VPN

Crons - I have no crons running. This is probably something long term security that should be integrated and automated.
man pages

Intelligent resizing of fonts depending on dpi or xrandr resolution

ntpd
	- ntpd only runs during qb-hostnet. Needs a more "correct" solution.

qme-firefox needs fixed (personal note)
