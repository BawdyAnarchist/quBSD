
qb-backup
	- actually on second thought, pos params arent contradictory to -a|-A|-f

root@quBSD:~ # jail -c 0net
0net: created
/usr/sbin/sysrc: cannot create /qubsd/0net/rw/etc/rc.conf: No such file or directory

get_jail_parameter uses _w2, but it's empty

Error messages are a bit disorganized now. Need to have useful higher function messages
	- **Give each jail and VM it's own separate log file under a quBSD directory, for clarity of log messages**
	- Default should be top level basic messages. -q quiets all, and -v drills down to deeper messages
	- Might need a -F force option.
	- Beef up the log file, and make reference to it in error messages
	NOTES ON MSG PROBLEM AREAS
		qb-cmd "all jails have started, but" ... It happens in alot of places it shouldnt. Should chk_isvm
		qb-cmd that has no user, only root, the -r is not a helpful command


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

Take another hack at the recording device problems

I2P Gateway


### SPECIFIC SCRIPTS OR FUNCTIONS

qb-create
	- It needs further and more extensive testing 
	- -z dirs recreated files too, not just directories

qb-help - overhaul to act like a manpage. Replacing /usr/local/share/quBSD
	- Each PARAM should have verbose message

qb_ssh
	- Probably can remove the FreeBSD parts of it. Maybe the Net/Open ones as well 

qb-i3-launch - had problems with double launching windows that already existed (on fully opened setup)

qb-pci
	- summary of PCI devices relevant to user
	- USB, NIC, maybe others
	- Show what was is currently passthrough'd

qb-list [-e] (evaluate) option to check jail-param combos for validity.
	- devfs_rule not showing well with summoned

qb-ephm - Clone from zroot too. Tricky, because of "reclone_zroot" operation in exec.prepare 

qb-update - Update rootjails, create snapshots

qb-backup (already created in $ubin)
	- cron to run on both sides of source and dest, with ssh hostname, to automate backups

qb-stat - Change hardcoded to more flexible setup: config file, col selector, RAM/CPU/DISK colorize



### GENERAL PROBLEMS / BEST PRACTICES / CLEANUP

Networking is still dicey. Hit and miss. Sometimes works, other times doesnt.
	- Might need to write daemons for dhclient and dhcpd servers
	- I notice it comes up fine if all jails have already started before startx (and qb-start -a). Maybe it's double running qb-start -a that's the problem)

dispVM
	- Add new class and boot practices
	- vm-rc.local should use its IP address to get it's hostname from 0control ftp server
		- This will require creating a new file in /home/ftp/<IPaddr> on 0control

GENERAL GUIDELINES, and maybe later double checks
	- Attempt to make scripts more robust and account for user error, when it makes sense to do so.
	- Try to use more redirects, tee's, and also try the 'wait' command for scripts that appear to hang (but are actually finished).
	- PARAMETERS should be CAPS when refering to the generic PARAM; lowercase when refering to a specific value
	- [test] { command ;} grouping. Can save alot of space and simplify the get_msg constructions
	- Double check on things that are positional items vs if they should be options 

Cycle all scripts through shellcheck again. 

zusr fstabs
	- They're hand jammed, but maybe qb-edit should come with a function for changing the zfs dataset and mounts
	- This should probably also change the fstabs? 
	- Really maybe a bit unnecessary, but maybe do it later

Hardened FreeBSD. Implements alot of HardenedBSD stuff with a simple .ini file and code.
https://www.reddit.com/r/freebsd/comments/15nlrp6/hardened_freebsd_30_released/

Generalize net-firewall
	[ "${_class_of_gateway##*VM}" ] and also maybe _class_of_client
	- chk_isqubsd_ipv4 - define_ipv4_convention - discover_open_ipv4

Crons - No crons running. Probably something long term security that should be integrated and automated.

ntpd - ntpd only runs during qb-hostnet. Needs a more "correct" solution. Maybe rolled into the/a control jail

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

c84ddda8e8a1c6e4a9943091fb2f9dc77931a43a0b55ca7894fd9287bd222c2b  qb-vmconf
