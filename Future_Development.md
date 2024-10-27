
When back on normal setup, fix the i3gen.conf to match QubesTricks

ALL file names should ALWAYS be variables defined in get_global_variables

rc.conf -nmdm cuse and dbus specifically, I dont know if I need them or what for

ntpd - ongoing
	1. Modified /etc/ntp.conf
	2. Modified qb-hostnet -c to copy /var/db/ntpd.drift from net-firewall
	3. Modified net-firewall rc.conf to enable ntp 
	# still need to modify firwall pf
	# installer should modify ntp.conf of host, or replace with its own
	# had a problem with schg and seclvl of firewall when launching ntp

Instead of all the named and ftp nonsense in 0control, just use a fat32 formatted zvol on the creation of a new VM
generalize the schg to being able to list specific files, and not my preselected ones
Maybe should do the fstab inside the rootjail, and only fstab in /rw when necessary. Maybe rc.conf and pf.conf too

with NIC, make qb-edit so that a new NIC also updates loader.conf.
There's a timing problem in qb-cmd regarding a VM, when i installed 0bsdvm
When you restore, the datasets dont inherit their qubsd:autosnap properties


### UPGRADES

PUT XORG and i3 in a jail - At least try it. Might work?

CREATE MANPAGES:  /usr/local/man/man1/qb-scripts
	- Replaces /share/quBSD
	- PARAMS should have manpage

Host as Unprivileged user     
	- doas commands allowed by unprivileged user
	- Unprivileged user on host will pass jails SSH commands via Control Jail     
	- Control jail pf will block all, except port 22 between host and jails     

pwd
	- I think the right way to do this, is export any existing pwd db in /rw, and import it into the created jail (or maybe vice versa) 
	- Right now I'm not so confident on how that's working
	- To get around the pw -V problem, you could put /usr/local/bin/pw wrapper

dispVM
	- vm-rc.local should use its IP address to get it's hostname from 0control ftp server
		- This will require creating a new file in /home/ftp/<IPaddr> on 0control

NICVM - Linux VM (probably alpine) so that it can use all the wireless cards. 
     - Someone made a post about this in FreeBSD

I2P Gateway

0serv 


### SPECIFIC SCRIPTS OR FUNCTIONS

qb-ivpn
	the ivpn server directory info needs its own directory for correctness, not stuffed in wireguard	
	also, it is isnt synced on my system and the repo. Not even synced between my jails and $ubin

qb-i3-launch - had problems with double launching windows that already existed (on fully opened setup)

qb-create
	- It needs further and more extensive testing 
	- -z dirs recreated files too, not just directories
	- qb-create removal of achi-hd might not be working. I dunno I changed it to hd so maybe that was why

qb_ssh [[actually it's likely I dont need this now that I'm gonna go to fat32 zfs volumes for new VMs)
	- Probably can remove the FreeBSD parts of it. Maybe the Net/Open ones as well 

qb-pci
	- summary of PCI devices relevant to user
	- USB, NIC, maybe others
	- Show what was is currently passthrough'd

qb-ephm - Clone from zroot too. Tricky, because of "reclone_zroot" operation in exec.prepare 

qb-update - Update rootjails, create snapshots

qb-backup - Add ssh option

qb-stat
	- Change hardcoded to more flexible setup: config file, col selector, RAM/CPU/DISK colorize
	- Give a popup option that can be closed with any key (quickview kinda stuff)
	- Add a column for worspace location of active windows



### GENERAL PROBLEMS / BEST PRACTICES / CLEANUP

0control qb-copy is SLOW af alot of times

/etc/devfs.rules
	- I probably have the mixer being added, but jails don't need it.
	- the new one for webcam

Take another hack at the recording device problems

Check HDAC - I think my sound board is now supported.

Hardened FreeBSD. Implements alot of HardenedBSD stuff with a simple .ini file and code.
https://www.reddit.com/r/freebsd/comments/15nlrp6/hardened_freebsd_30_released/

Generalize net-firewall
	[ "${_class_of_gateway##*VM}" ] and also maybe _class_of_client
	- chk_isqubsd_ipv4 - define_ipv4_convention - discover_open_ipv4

Crons - No crons running. Probably something long term security that should be integrated and automated.

qme-firefox needs fixed (personal note)

I think `jail` caches fstab before completion of exec.prepare which edits it. Need to prove/submit bug. Need dtrace


##### qubsd installer #######

This was a comment on 0net in the installer, but maybe it's old by now. Delete this line if there's no problems later
# ??change /rc.d/wireguard to remove the kldunload??

