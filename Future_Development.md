### UPGRADES

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
	
Expand install options     
- Can select to merge zroot and zusr with other existing dataset/mount     

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

qb-windows
	- command that shows the jail, window title, and workspace of all active windows

net-firewall 
	- jail start should auto update the servIPs in pf.conf
		- This might require some thought about setting an "auto" option in the settings.
		  because people making servers might not want an auto setting

qb-autosnap 
	- Need to add changes /etc/crontab to qubsd-installer
	- Need to add the zfs custom props to the datasets as created (qubsd-installer)
		- be careful. Cloned datasets should not be autosnapped

qb-backup (already created in $ubin)
	- cron to run on both sides of source and dest, with ssh hostname, to automate backups

Detect changes in nic and USB so that you can rewrite the file if necessary

### BEST PRACTICES / CLEANUP

- net-firewall pf.conf might not be fully generalized for routerIP. 
	- basically, exec.created relies on setting the last number to "1". 
     - Then it modifes pf.conf, but that might be inappropriate
	- Also needs to aggregate *all* client connections wireguard ports
	- jIP is hand hammed from jailconf, but check that DHCP works too
	- The pass in from clients would also let servers do it
  		- Segregate the servers from clients more carefully
		- Maybe even segregate the wg gateways from clients as well

- networking rework. Need to update the IP conventions - both checks and docs 

qb-usbvm     
	- When xterm is closed with ssh connection, the tap1 connect between jail and usbvm should be severed. Need a "trap" command     
	- Need to rework usbvm automatic internet with option (due to general net rework)

column -t some of the conf files

qb-ivpn - sed error - needs better separation of the -j option to not throw error.
        - Also an unused variable "pingfail"
	   - Current server should be upgraded to show current settings, even if not connected
	   - Need to verify how well it works when connection is down
	   - pf.conf references the endpoint IP. Needs to be updated as well

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

qb-rename
	- didn't rename the subfolder under home
	- requires that you bring flags down for the jail in quesiton first (specifically the fstab was protected)

pf.conf
	- wgIP constant really should be called "endpointIP" or something like that

Coding practices
	shellcheck.net - need to go over all code with a fine toothed comb. fix the formatting errors (like if "$?" then ...)
	Create libraries to simplify functions used alot. /usr/local/lib/quBSD.sh	
	usage should be the first thing in the script. Then `case` should call it. Save space
	

### MINOR UPGRADES

Test out having the rootjails at high security levels when turned off.

exec.created (or prestart) - can use dirname for copying the /rw files

qb-dpi - make it so that a program can launch under alt dpi settings and return to normal
	- You could even add it as an option to qb-cmd, and i3gen.sh/conf
	
	- Also good to add it to startup.sh

qb-mvpn - Mullvad VPN: Query and parse mullvad server json; apply to VPN

qb-cam/mic - webcam and mic get brought up with script

qb-update - Update rootjails, create snapshots

qb-create - While in guided mode, add option to enter "auto" for IP assignment 

qb-list
	- extra options for seeing snapshots of jails

qb-edit 
	- the -i option should be able to be applied when setting the tunnel
	- the -r option didn't seem to restart the jails required
	- should have a check for duplicate IP0

qb-disp - Need to make sure that you're incrementing with a DISP number, so that you don't overlap when starting a new DISP more than once.

usbjail - Make a dedicated dispjail for usb handling, with some embedded scripts for copying (usbvm too)

add autostart option to jailmap.conf, and a service startup script for autostart

Crons
- Popup warning if zpool errors are discovered
- Popup warning if host has been network connected for too long
- Run checks for any other problems. Like ...?

