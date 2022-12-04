### UPGRADES

qb-cam/mic - webcam and mic get brought up with script

usbjail - Make a dedicated dispjail for usb handling, with some embedded scripts for copying (usbvm too)

Host as Unprivileged user     
- All jails will have an epair to an offline *Control Jail*      
- Unprivileged user on host will pass jails SSH commands via Control Jail     
- Control jail pf will block all, except port 22 between host and jails     

ZFS Encrypted Jails

Tor and I2P Jails

USBVM     
- Make the usbvm disposable/ephemeral, as a malware countermeasure      
- Auto-install various useful mounting stuff for common devices     
- Create a proper unprivileged user with devd.conf and automounts     
- Auto remove password from unprivleged usbvm user     
	
0SERV Default and 0serv-template
  - Integrate into install script
  - www and usr diretories are quite large. Script integration:
  	- at quBSD installation, copy files over from 0serv
     - qb-create should in realtime copy over usr/local/etc from 0serv
     - There might even be problems with pkg-upgrade operating on this dir
	- Make sure to chown the directories as appropriate

nicvm 
  - Make it a Linux VM so that it can use all the wireless protocols.
     - Someone made a post about this in FreeBSD

net-firewall 
	- jail start should auto update the servIPs in pf.conf
		- This might require some thought about setting an "auto" option in the settings.
		  because people making servers might not want an auto setting

qb-autosnap 
	- Need to add the zfs custom props to the datasets as created (qubsd-installer)
	- Would be good to beef up the script. If there's another snap taken within say 30sec 
     of another one, to discard whichever the shortest timeframe was. 

qb-backup (already created in $ubin)
	- cron to run on both sides of source and dest, with ssh hostname, to automate backups

Detect changes in nic and USB so that you can rewrite the file if necessary

qubsd_installer
	- Autosnap 
		/etc/crontab
		zfs datasets need to be tagged 	

	- Autostart
		/etc/rc.conf
		/rc.d/jautostart 

	Expand install options     
		Can select to merge zroot and zusr with other existing dataset/mount     

	- Double check the install script that it copies qb-ivpn to 0net

	- /var/log/quBSD.log - line added to /usr/local/etc/X11/xinit/xinitrc to remove the log at each startx
		- log isn't working as well as I'd hope.


### BEST PRACTICES / CLEANUP

quBSD.conf 
	- ppt_nic and usb should probably be more like: check /boot/loader.conf against pciconf 
	- This would leave only the quBSD_root (zroot/quBSD). I prefer to remove this file entirely	
	- Maybe this value can just get stored in quBSD.sh

qubsd.sh - check that case can be applied to isqubsd_ipv4 and others

- net-firewall pf.conf might not be fully generalized for routerIP. 
	- basically, exec.created relies on setting the last number to "1". 
     - Then it modifes pf.conf, but that might be inappropriate
	- Also needs to aggregate *all* client connections wireguard ports
	- jIP is hand hammed from jailconf, but check that DHCP works too
	- The pass in from clients would also let servers do it
  		- Segregate the servers from clients more carefully
		- Maybe even segregate the wg gateways from clients as well

qb-usbvm     
	- When xterm is closed with ssh connection, the tap1 connect between jail and usbvm should be severed. Need a "trap" command     
	- Need to rework usbvm automatic internet with option (due to general net rework)

qb-create 
	- Really should have some trap functions set when zfs cloning
	- apparently -g selecting "none" template is having zfs problems
	- Failed to create /etc/jail.conf entry for: qb-create -T net-vpn net-wireguard
	- It's still screwed up somehow. Not accepting a creation with all options. 
	- Need to go through with a fine tooth comb. And/or do some fuzzing.
	- Need to add an option for copying usrlocal
	- Add option for "auto" IP assignment during guided
	- Logic on "Would you like to also .... something about /home directory of template"
		needs fixed, because no template shouldn't ask you to copy a non existent home.
	- autostart option
	- autosnap options - the custom zfs props need to be set
		- be careful. Cloned datasets should not be autosnapped
	- While in guided mode, add option to enter "auto" for IP assignment 
	- You need to disallow 'none' and 'quBSD' as jailnames

pf.conf
	- wgIP constant really should be called "endpointIP" or something like that

/usr/local/share/quBSD 
	- Needs to document that the rootjails must stay lowered schg
	- Needs updated in general after you're done
	- Update the guides regarding #defaults in jailmap.

quBSD.sh 
	- Clean up the list of functions at the top
	- Check it thoroughly for test lines
	- There's probably still functions you can generalize from $ubin

### MINOR UPGRADES

qb-autostart still needs thought out

startup.sh should also take qb-dpi settings

qb-help
	Make sure to update it after changes

qb-mvpn - Mullvad VPN: Query and parse mullvad server json; apply to VPN

qb-update - Update rootjails, create snapshots

Crons
- Popup warning if zpool errors are discovered
- Popup warning if host has been network connected for too long
- Run checks for any other problems. Like ...?

