
qb-cmd doesnt seem to have good error messages for failed gateway on message

popups - Improve sizing of the popup box (screen resolution? DPI?)

### UPGRADES

GUI SECURITY
	- Test Xpra, Xauth and try to isolate xhost 
	- Xephyr - Unfortunately I'm not sure this is a real solution. Everything still shares the unix socket
		- Might not matter, but if I keep it, some ideas:
			- the qb-xephyr command into qb-cmd -X, including VMs. Make sure works with -n as well.
			- Integrate an "X" option for qb-ephm as well.

pwd
	- I think the right way to do this, is export any existing pwd db in /rw, and import it into the created jail (or maybe vice versa) 
	- Right now I'm not so confident on how that's working
	- To get around the pw -V problem, you could put /usr/local/bin/pw wrapper

Host as Unprivileged user     
	- doas commands allowed by unprivileged user
	- Unprivileged user on host will pass jails SSH commands via Control Jail     
	- Control jail pf will block all, except port 22 between host and jails     

NICVM - Linux VM (probably alpine) so that it can use all the wireless protocols.
     - Someone made a post about this in FreeBSD

I2P Gateway

CREATE MANPAGES:  /usr/local/man/man1/qb-scripts
	- Replaces /share/quBSD
	- PARAMS should have manpage

dispVM
	- Add new class and boot practices
	- vm-rc.local should use its IP address to get it's hostname from 0control ftp server
		- This will require creating a new file in /home/ftp/<IPaddr> on 0control

Take another hack at the recording device problems


### SPECIFIC SCRIPTS OR FUNCTIONS

qb-create
	- It needs further and more extensive testing 
	- -z dirs recreated files too, not just directories

qb_ssh
	- Probably can remove the FreeBSD parts of it. Maybe the Net/Open ones as well 

qb-i3-launch - had problems with double launching windows that already existed (on fully opened setup)

qb-pci
	- summary of PCI devices relevant to user
	- USB, NIC, maybe others
	- Show what was is currently passthrough'd

qb-list [-e] (evaluate) option to check jail-param combos for validity.

qb-ephm - Clone from zroot too. Tricky, because of "reclone_zroot" operation in exec.prepare 

qb-update - Update rootjails, create snapshots

qb-backup - Add ssh option

qb-stat
	- Change hardcoded to more flexible setup: config file, col selector, RAM/CPU/DISK colorize
	- Give a popup option that can be closed with any key (quickview kinda stuff)

qb-i3-windows - popup option


### GENERAL PROBLEMS / BEST PRACTICES / CLEANUP

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

kldload pf is required (in addition to others)

/etc/devfs.rules - I probably have the mixer being added, but jails don't need it.
	- qb-autosnap 
	- /etc/crontab
	- Need to add the zfs custom props to the datasets as created (qubsd-installer)

qb-autostart
	/etc/rc.conf
	/rc.d/jautostart 

Expand install options     
	Can select to merge zroot and zusr with other existing dataset/mount     

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

0serv and 0serv-template need integrated	
	- www and usr diretories are quite large. Script integration:
		- at quBSD installation, copy files over from 0serv
		- qb-create should in realtime copy over /usr/local/etc from 0serv
		- There might even be problems with pkg-upgrade operating on this dir
		- Make sure to chown the directories as appropriate
	
devfs.rules
	- add qubsd to the naming convention
	- the new one for webcam
	- Maybe the file should be added to the get_global_variables assignments library

net-jails
	pkg install isc-dhcp44-server bind918 wireguard-tools jq vim
	- Check that pf conf is updated with required dhcp port, and the simplified version

R_ZFS and U_ZFS ; and mountpoints changed. Less cumbersome, more straightforward

VMs integration
	- install bhyve-uefi firmware
	
quBSD.conf removed. Everything now in jailmap.conf

Should make the $qubsd/zroot/0net 0gui 0vms and everything files here for specific stuff like rc.conf

loader.conf needs if_wg_load="YES"



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

