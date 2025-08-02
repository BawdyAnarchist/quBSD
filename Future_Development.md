
MTU is not being honored and now some jails (no VPN, connect to firewall) are failing to put resolv.conf correctly

control_netmap is borked and constantly double lists

qb-start
	- Needs updated with new networking functions in mind
	- Simultaneous starts of clients could mess up wireguard restarting

qb-edit - < GATEWAY > isnt valid for CLASS: host. Valid params are:

TIMEOUT overhaul - timeout is a real command that will exit a command after a certain time. wow that would've been useful a long time ago

zfs decryption wasnt working quite right. I need to recheck it

When back on normal setup, fix the i3gen.conf to match QubesTricks


### INSTALLER SCRIPT CHANGES ###
Linuxulator upgrade - ubuntu full session
  debootstrap jammy /qubsd/0gui/compat/ubuntu
  Then set jconf mounts. Including a shared home directory
    - This I will try for now, but might end up being problematic later? We'll see
 


### INSTALLER SCRIPT CHANGES ###
roots
	mkdir /usr/local/bin && cp qubsd_dhcp
	mkdir /usr/local/etc/rc.d && cp qubsd_dhcp
	/etc/rc.conf qubsd_dhcp_enable="YES"
	touch /qubsd/0base/etc/resolv.conf
	dbus added to host when GUI option is selected 

rc.conf -nmdm cuse , I dont know if I need them or what for

Instead of all the named and ftp nonsense in 0control, just use a fat32 formatted zvol on the creation of a new VM

generalize the schg to being able to list specific files, and not my preselected ones. Overall pf and everything needs examined/revised

There's a timing problem in qb-cmd regarding a VM, when i installed 0bsdvm
When you restore, the datasets dont inherit their qubsd:autosnap properties

consider - https://it-notes.dragas.net/2023/08/14/boosting-network-performance-in-freebsds-vnet-jails/
	- It's for vnet jails and NAT. Disables hardware checksums for virtual interfaces, and extra filtering on bridges

There is some question now as to the dispjails and their templates, and the devfs in jail.conf. 


### UPGRADES

Make jail locations just another parameter. Example: I almost needed a separate vdev for data 

Constrain the memory and CPU that the jails "see." This might require a kernel change to intercept the sysctl call for jails.

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

qb-edit
	- chk_isqubsd_ipv4 - [-x] isnt used anywhere, but a check for quBSD IP convention would be a good addon 
	- Make changing of parameters without jail restarts, like for gateway. Use the new/improved functions.
	- with NIC, make qb-edit so that a new NIC also updates loader.conf.

qb-ivpn
	- no need to restart jail, simply pfctl the EP 
	- the ivpn server directory info needs its own directory for correctness, not stuffed in wireguard	
	- also, it is isnt synced on my system and the repo. Not even synced between my jails and $ubin

qb-connect
	- Needs reviewed and reworked based on new networking functions

qb-i3-launch - had problems with double launching windows that already existed (on fully opened setup)

qb-create
	- [-z dupl] still needs to create and copy the fstab of the template jail, and maybe the rc.conf too. 
	- It needs further and more extensive testing 
	- -z dirs recreated files too, not just directories
	- qb-create removal of achi-hd might not be working. I dunno I changed it to hd so maybe that was why
	- There needs to be a template for parameters, and a template for zusr
	- You can in install a brand new rootjail via tar base.txz, and this should be an opt coz of the little qubSD required adjustments 

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

ALL file names should ALWAYS be variables defined in get_global_variables

0control qb-copy is SLOW af alot of times

/etc/devfs.rules
  - I probably have the mixer being added, but jails don't need it.
  - the new one for webcam

Take another hack at the recording device problems

Hardened FreeBSD. Implements alot of HardenedBSD stuff with a simple .ini file and code.
https://www.reddit.com/r/freebsd/comments/15nlrp6/hardened_freebsd_30_released/

Crons - No crons running. Probably something long term security that should be integrated and automated.

I think `jail` caches fstab before completion of exec.prepare which edits it. Need to prove/submit bug. Need dtrace


### FAILURES - DO NOT TRY AGAIN

PUT XORG and i3 in a jail
  - Sounds nice, but after you launch X11, you're permanently in the jail.



### GENERIC SHELL LIBRARY FUNCTIONS
exists_then_copy "<file>" "<location>"
check_yesno
get_user_response


