
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
- Can select to merge zroo and zusr with other existing dataset/mount     

0SERV Default and 0serv-template
  - You will need to chown the www directory structures
  - Decision on whether or not to role the zusr under a single zfs snapshot, or snapshot usrlocal

nicvm 
  - Make it a Linux VM so that it can use all the wireless protocols.
     - Someone made a post about this in FreeBSD
  - Make it strictly a passthrough, promiscuous
  - Make net-tap into net-firewall, and handles all the routing operations
     - NAT all networks separately so that no traffic is visible to other networks
	  In other words, each IVPN jail is NATed from separate subnets on net-firewall, just as
	  each appjail is NATed from separate subnets on the IVPN jail.
     - Servers will "look" like they're at a similar "gateway layer depth" as the IVPN jails.


### BEST PRACTICES / CLEANUP

qb-usbvm     
- When xterm is closed with ssh connection, the tap1 connect between jail and usbvm should be severed. Need a "trap" command     

All files inside scripts should be made into variable references     

column -t some of the conf files

qb-ivpn - sed error - needs better separation of the -j option to not throw error.
        - Also an unused variable "pingfail"
	   - Current server should be upgraded to show current settings, even if not connected
	   - Need to verify how well it works when connection is down

qb-create 
	- Really should have some trap functions set when zfs cloning
	- apparently -g selecting "none" template is having zfs problems
	- Failed to create /etc/jail.conf entry for: qb-create -T net-vpn net-wireguard
	- It's still screwed up somehow. Not accepting a creation with all options. 
	- Need to go through with a fine tooth comb. And/or do some fuzzing.

pf.conf
	- wgIP constant really should be called "endpointIP" or something like that

### MINOR UPGRADES

Test out having the rootjails at high security levels when turned off.

exec.created (or prestart) - can use dirname for copying the /rw files

qb-mvpn - Mullvad VPN: Query and parse mullvad server json; apply to VPN

qb-cam/mic - webcam and mic get brought up with script

qb-update - Update rootjails, create snapshots

qb-snap - Add an option for snapshotting host before an update

qb-create - While in guided mode, add option to enter "auto" for IP assignment 

qb-stat - Change "class" column to class_rootjail. Maybe even realtime switching of sort, columns, and presentation (maybe)

qb-edit - the -i option should be able to be applied when setting the tunnel
	   - the -r option didn't seem to restart the jails required

qb-disp - Need to make sure that you're incrementing with a DISP number, so that you don't overlap when starting a new DISP more than once.

usbjail - Make a dedicated dispjail for usb handling, with some embedded scripts for copying (usbvm too)

startup.conf and startup.sh - Config file that maps workspaces to GUI apps; script to launch apps startx

add autostart option to jailmap.conf, and a service startup script for autostart

Crons
- Popup warning if zpool errors are discovered
- Popup warning if host has been network connected for too long
