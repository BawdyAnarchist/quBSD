##### VIRTUAL MACHINE INTEGRATION

- qb-connect
	- VM integration: jail/VM connections, specifically SSH preparation for files copy

New scripts
	qb-pci
		- summary of PCI devices relevant to user
		- USB, NIC, maybe others
		- Show what was is currently passthrough'd

Ubuntu upgrades
	zusr dataset integration
		- try Ubuntu zfs install 
		- User profiles
	0ubuntu - install vlc (or something). Add common connection commands

USBVM 
	- Create a proper unprivileged user with devd.conf and automounts     
	- Auto remove password from unprivleged usbvm user     
	- When xterm is closed with ssh connection, the tap1 connect between jail and usbvm should be severed. Need a "trap" command     
	- usbjail - Make a dedicated dispjail for usb handling, with some embedded scripts for copying (usbvm too)

NICVM 
  - Make a Linux VM so that it can use all the wireless protocols.
     - Someone made a post about this in FreeBSD

VM customization
	- Create the VMs for all your uses
	- Create the i3 quick keys and i3gen.conf

net-firewall
	- pf.conf 
		- Currently does not integrate all unique wireguard ports of clients (net-jails).
		- needs careful review. Use chatGPT-4


### UPGRADES

ZFS Encrypted Jails

Tor and I2P Jails

Xephyr
	- Integrate the qb-xephyr command into qb-cmd -X, including VMs. Make sure works with -n as well.
	- Integrate an "X" option for qb-disp as well.
	- Wayland/sway might be a good bonus to run in a separate tty

qb-disp
	- Really should be called class=ephemeral
	- Should clone zroot from template as well. 
	- Make it so you can run a specific command directly at the command line.
	- Also make it so that you dont need a terminal. That's annoying. Keep jail alive based on presence of X-window from jail 
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

Try to use more redirects, tee's, and also try the 'wait' command for scripts that appear to hang (but are actually finished).

You really need to run Wayland and/or figure out Xauth, xpra, and isolation of gui

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
		- Getting the #default shouldnt be the default behavior. -d should say "get default if nothing is there"
		- (x)tra check on chk_valid_{param} for certain circumstances
		-(r)esolve value (for stuff like ip auto)
		- Could also beef up the log file, and make reference to it in error messages
		- **Give each jail and VM it's own separate log file under a quBSD directory, for clarity of log messages**

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

Make some kind of function: chk_isinteger "lower_bound" "upper_bound". You have a lot of integer checks.

in qubsd.sh - alot of positional stuff really should be options stuff

qb-hostnet _TIME variable should be called TIMEOUT, and it should have a better check

qb-stat
	- I like my hardcode setup, but columns sorting and even a generalized setup file might be better
	- Also the ability to choose which columns are displayed
	- You should use background colors for the RAM and CPU usage. Maybe disk as well

qb-autosnap
	- It should look for all snaps older than their qubsd:destroy-date , and reclone them (stale zroots)

${JAILS_ZFS} should probably be ROOT_Z and maybe also then ZUSR_Z.  Also M_ROOT instead of M_JAILS

The reality is that all PARAMETERS should always be capitalized to refer to the generic PARAM,
and lowercase when refering to a specific value for PARAMETER. This requires alot of grammar changes.

qb-edit and qb-create
	- Probably should offload the jail/VM non-mixing check for root, class, and template, into qubsd.sh 

qb-stop
	- the monitoring is still not right. It exits early, coz pgrep returns nothing after 2 cycles for no gd reason 

### MINOR UPGRADES 

If you really wanted to make everything robust, you could do the same robustness that qb-list has, with other commands

qb-help:
	- forget the docs, make the more in depth stuff part of qb-help. Like a man page
	- Make it robust like qb-list
	- Each PARAM has a verbose message

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


