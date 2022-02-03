
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


### BEST PRACTICES / CLEANUP

qb-usbvm     
- When xterm is closed with ssh connection, the tap1 connect between jail and usbvm should be severed. Need a "trap" command     

All files inside scripts should be made into variable references     

column -t some of the conf files


### MINOR UPGRADES

Test out having the rootjails at high security levels when turned off.

qb-mvpn - Mullvad VPN: Query and parse mullvad server json; apply to VPN

qb-cam/mic - webcam and mic get brought up with script

qb-update - Update rootjails, create snapshots 

Config file that maps workspaces to GUI apps; script to launch apps startx

Crons
- Popup warning if zpool errors are discovered
- Popup warning if host has been network connected for too long


