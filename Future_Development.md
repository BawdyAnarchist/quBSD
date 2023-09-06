
##### VIRTUAL MACHINE INTEGRATION

problems with qb-start_temp_ip lingering and not getting removed before operation

Generalization of the VMs implementation (for fbsd vms)
	- other dataset script
		- change hostname
		- configure network
		- symlink files
		- User profiles (if any) stored here
		- possible you'll need early script (for symlinks) and later script (network, etc)
		- Probably changing the swap space?
	- 0vms will always gateway, like 0rootjails, for updates

make sure to add the new variables to [-h] for: qb-start , stop, cmd, 

1. qubsd.sh 
	Fix the "net-firewall" switches.
		# the solution is: if [ ${_class_of_gateway##*VM} ] and also maybe _class_of_client

   #chk_valid_gateway
	- Type implementation?  "firewall" "gateway" "server" "app"  
	- chk_isqubsd_ipv4
	- define_ipv4_convention
	- discover_open_ipv4
	- exec scripts
	- exec.created
	- qb-edit 
		- rc.conf changes (no longer use rc.conf if IP is static
		- Add check when assigning app or disp CLASS, that it doesnt have a zfs origin 

2. jailmap
	- Add a generic parameter that tacks on any "-s 99:0 <options>" 

3. Scripts that should integrate VMs
	- qb-stop , qb-start, qb-edit (now needs "add" function for multiple taps at least), qb-rename , qb-destroy, qb-stat, qb-create, qb-disp
	- qb-edit really should be an eval command like in get_jail_parameter ... for ex: eval "chk_valid_param $_q $VALUE" 

4. New scripts
	qb-pci
		- summary of PCI devices relevant to user
		- USB, NIC, maybe others
		- Show what was is currently passthrough'd
	qb-vm
		- For create, since that might be non-trivial, and your qb-create is already pretty good

# CLEANUP STUFF
quBSD.conf 
	- remove ppt_nic. It's now in jmap.
	- Think of way to remove the file entirely. 

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

Cleanup the github. You have scripts in there that arent relevant from full copies of $ubin

Are there going to be differences to code into prepare_vm between Linux, Windows, and FreeBSD?

Integrate in qb-i3-launch as well

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

### BEST PRACTICES / FIXES / CLEANUP

Xephyr is an absolute must. Wayland/sway might be a good bonus to run in a separate tty

connect_client_to_gateway
	- It could be space efficiencized. For now just uses dumb switches for VMs, duplicating lines 

Cycle all scripts through shellcheck again. 
	- local variables need to be removed and func variables checked for clean/sanitary
	- the && || constructions are NOT if/then/else
		-- Sometimes this is fine, you're just calling messages, but other times might not be

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
		- Master -V (verbose) command could be included on all top level scripts, with -q as default 
		- Could also beef up the log file, and make reference to it in error messages

qubsd_ipv4 - there's probably room for IP expansion for multiple strings of gateways .. maybe.

zusr fstabs
	- They're hand jammed, but maybe qb-edit should come with a function for changing the zfs dataset and mounts
	- This should probably also change the fstabs? 
	- Really maybe a bit unnecessary, but maybe do it later

Hardened FreeBSD. Implements alot of HardenedBSD stuff with a simple .ini file and code.
https://www.reddit.com/r/freebsd/comments/15nlrp6/hardened_freebsd_30_released/

## When my system crashed with the power, it can leave things in a dirty state 
	- DISP-torrents was still there
		- Probably an rc that cleans up old states

qb-autosnap might need looked at for leaving snapshots that could be deleted

get_jail_parameter needs more variables
	-(x)tra check on chk_valid_{param}
	-(r)esolve value (for stuff like ip auto)

exec.created
	- clean it up. I left the old function there coz was scurd. remove it

You should make a check for a circular reference in the networking.
	- firewall client is ivpn-bra. ivpn-bra client is torrents. torrents client is firewall

qb-cmd should pull from the user's chosen shell, not default to csh
	- I do worry tho, that the csh -c '<commands>' construction might fail if I do that

pretty sure reclone_zroot needs to be optimized

new sed discovery
	- -En with (parenthesis) and \1. Just solid amazing stuff

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


