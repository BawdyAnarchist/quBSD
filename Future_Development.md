### BEST PRACTICES / FIXES 

qb-autosnap
	- Maybe it should do a "diff" and only snap when relevant. Reduces clutter
	- Should read both zfs and jmap autosnap
	- Then syncronize anything that was off. Sync to jmap
	- qb-edit
		- will needed added. and zfs mod takes place 

qb-disp with -Z option for cloning root dataset as well? 

pf.conf
	- wgIP constant really should be called "endpointIP" or something like that

qb-create 
	- GUIDED MODE needs to be completely redone.
	- Add the new jail to the i3gen.conf and execute keybindings
	- NEXT IN LINE

the word "template" really ought to be "parent." Create dispjail from PARENT. TEMPLATE should probably be relegated to the 0root-templates and to qb-create. 

qb-connect
	- could figure out what about stupid pf is preventing network connection for adhoc connected jails 

devfs.rules
	- The rulenames should include "qubsd" so as not to have a chance of overlapping other rules
	- Maybe the file should be added to the get_global_variables assignments library

ntpd
	- ntpd only runs during qb-hostnet. Needs a more "correct" solution.

Should cycle all scripts through shellcheck again. 
	- Case statements need catchalls to trap invalid options provided
	- Primarily with scripts that should error on invalid option

/usr/local/share/quBSD 
	- Needs updated in general after you're done
	- Needs to document that the rootjails must stay lowered schg
	- Update the guides regarding #defaults in jailmap.


### TROUBLE NOTES (uncertain, things to monitor)

It seems like exec.created might not *always* be updated pf.conf with the new epair.
	- On one restart immediately after pushing the big upgrade with qb-start/stop to github, one net-vpn jail didn't update
	- I'm not sure if it's because I'm defining VIF as a global in connect_client_gateway, with simultaneous starts.

jail -r 
	- <net-jail> is causing an "Operation not permitted" error

Renamed all JMAP parameters to CAPS
	- I think it's good, but there's alot of stuff in the scripts. Maybe missed something

Further networking ghosts
	- It seems like sometimes the restarting of net-firewall or net-vpn causes downstream connection issues.
     But then restarting again in sequence fixes the problem. I can't quite replicate it.

### MINOR UPGRADES

qme-firefox needs fixed (personal note)

qb-list - [-e] (evaluate) option to check jail-param combos for validity.
	 
### UPGRADES

pwd
	- I think the right way to do this, is export any existing pwd db in /rw, and import it into the created jail (or maybe vice versa) 
	- Right now I'm not so confident on how that's working

usbjail - Make a dedicated dispjail for usb handling, with some embedded scripts for copying (usbvm too)

ZFS Encrypted Jails

Tor and I2P Jails

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

### VIRTUAL MACHINE INTEGRATION
## Notes - the way to do this, is put bhyve VMs in jails.
	- Internal networking now all looks identical, between jail and VM
	- External networking can be managed exactly how you manage jails now

quBSD.conf 
	- ppt_nic and usb should probably be more like: check /boot/loader.conf against pciconf 
	- This would leave only the quBSD_root (zroot/quBSD). I prefer to remove this file entirely	
	- Maybe this value can just get stored in quBSD.sh

A full management scheme for ZFS datasets that will serve as VM templates for VMs 

A set of start/stop scripts that plug into JMAP

Integration into the existing qb-scripts, especially quBSD.sh

USBVM - As a temporary/initial solution, could zfs clone a template for USBVM.
	- Make the usbvm disposable/ephemeral, as a malware countermeasure      
	- Auto-install various useful mounting stuff for common devices     
	- Create a proper unprivileged user with devd.conf and automounts     
	- Auto remove password from unprivleged usbvm user     
	- When xterm is closed with ssh connection, the tap1 connect between jail and usbvm should be severed. Need a "trap" command     
	- Need to rework usbvm automatic internet with option (due to general net rework)

NICVM 
  - Make it a Linux VM so that it can use all the wireless protocols.
     - Someone made a post about this in FreeBSD

net-firewall
	There are lingering issues with making specific exceptions for 'net-firewall', when it should be generalized.
	OVERALL - I would like to wait on cleaning this up, because there should be alot of improvement when the 
	VM integrations are completed. These are some of the problems of net-firewall as they stand now.

	- There is quite alot of work to do, to make this proerly generalized. Exceptions are made for 'net-firewall' in numerous places.
		- qb-edit ; quBSD.sh 
	
	- There could be some problems with the way IP addys are handled.
		- net-firewall default gateway is assumed to be a.b.c.1 (dot-one) ; which I think is okay, but maybe some research/thought is needed 
	- pf.conf 
		- Currently does not integrate all unique wireguard ports of clients (net-jails).
		- DHCP has not been verified to work. Needs tested 
	- The pass in from clients would also let servers do it
  		- Segregate the servers from clients more carefully
		- Maybe even segregate the wg gateways from clients as well
	- jail start should auto update the servIPs in pf.conf
		- This might require some thought about setting an "auto" option in the settings.
		  because people making servers might not want an auto setting


### MINOR UPGRADES IF ANYONE ELSE OUT THERE WANTS TO DO IT
qb-mvpn - Mullvad VPN: Query and parse mullvad server json; apply to VPN
qb-update - Update rootjails, create snapshots
Crons - I have no crons running. This is probably something long term security that should be integrated and automated.
man pages

