
with NIC, make qb-edit so that a new NIC also updates loader.conf.

Just call it qubsd.conf and not qubsdmap.conf

There's a timing problem in qb-cmd regarding a VM, when i installed 0bsdvm

Instead of all the named and ftp nonsense in 0control, just use a fat32 formatted zvol on the creation of a new VM

When you restore, the datasets dont inherit their qubsd:autosnap properties

remember to remove pefs.ko entirely now that you're using zfs encryted datasets

This was a comment on 0net in the installer, but maybe it's old by now. Delete this line if there's no problems later
# ??change /rc.d/wireguard to remove the kldunload??

Maybe should really do the fstab inside the rootjail, and only fstab in /rw when necessary. Maybe rc.conf and pf.conf too


### UPGRADES

Host as Unprivileged user     
	- doas commands allowed by unprivileged user
	- Unprivileged user on host will pass jails SSH commands via Control Jail     
	- Control jail pf will block all, except port 22 between host and jails     

CREATE MANPAGES:  /usr/local/man/man1/qb-scripts
	- Replaces /share/quBSD
	- PARAMS should have manpage

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



### SPECIFIC SCRIPTS OR FUNCTIONS

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

ntpd - ntpd only runs during qb-hostnet. Maybe can nullfs mount or devfs? the ntpd database/location to a jail. 

qme-firefox needs fixed (personal note)

I think `jail` caches fstab before completion of exec.prepare which edits it. Need to prove/submit bug. Need dtrace


##### qubsd installer #######

zfs custom props to the datasets as created (qubsd-installer)

rc.conf

/qubsd/0base installer needs to create the /rw/ folder, or appjails based on it, won't mount properly
	Also touch /etc/fstab with header so disps work. (for all jails actually)

0base
	zfs create zroot/qubsd/0base
	tar -C /qubsd/0base -xvf /usr/freebsd-dist/base.txz
	head -1 /etc/fstab > /qubsd/0base/etc/fstab	

0net
	- pkg install isc-dhcp44-server bind918 wireguard-tools vim jq
	- copy .cshrc and .vim*
	- change /rc.d/wireguard to remove the kldunload

net-jails - Check that pf conf is updated with required dhcp port, and the simplified version

0serv and 0serv-template need integrated	
	- www and usr diretories are quite large. Script integration:
		- at quBSD installation, copy files over from 0serv
		- qb-create should in realtime copy over /usr/local/etc from 0serv
		- There might even be problems with pkg-upgrade operating on this dir
		- Make sure to chown the directories as appropriate

Should make the $qubsd/zroot/0net 0gui 0vms and everything files here for specific stuff like rc.conf

need to check if boot_mute is required now or if I got my messages problem for ttyv0 sorted out with _msg2 overhaul


### NEW INSTALLER NOTES 
pkg install might need xpra or xephyr added depending on how that all turns out. Also doas if you get off root.



### Control Jail
# KEYGEN
	- cp -a group master.passwd passwd pwd.db spwd.db from 0net to /zusr/0control/rw/etc/
	- mkdir -p /zusr/0control/home/0control
	- chown -R 1001:1001 /zusr/0control/home/0control
	- mkdir -p /zusr/0control/home/ftpd
	- chown -R 1002:1002 /zusr/0control/home/ftpd
	- chmod 755 /zusr/0control/home/ftpd
	- mkdir -p /zusr/0control/rw/root/.ssh
	- chmod 700 /zusr/0control/rw/root/.ssh
	- pw -V /zusr/0control/rw/etc useradd -n 0control -u 1001 -d /home/0control -s /bin/csh
	- pw -V /zusr/0control/rw/etc useradd -n ftpd -u 1002 -d /home/ftpd -s /bin/sbin/nologin
	- ssh-keygen -t rsa -b 4096 -N "" -f /zusr/0control/rw/root/.ssh/id_rsa
	- cp -a /zusr/0control/rw/root/.ssh/id_rsa.pub /zusr/0control/home/ftpd
	- cp -a qb_ssh script to /home/ftpd 
	- chmod 755 /zusr/0control/home/ftpd/*
	
# rootjails need copy of 0control pubkey	
# SSHD in all rootjails 
# 0bsdvm needs to have a daemon for continually checking/attmepting dhclient on vtnet0 


# NOTES FROM RE-INSTALL
	make sure that zroot/qubsd is mounted at /qubsd and not /zroot/qubsd
	
	pf.ko wasnt loaded ..?


### 0bsdvm Steps
/boot/loader
	autoboot_delay="2"

zpool import -f vmusr


