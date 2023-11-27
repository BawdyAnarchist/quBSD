##### VIRTUAL MACHINE INTEGRATION

# After SSH, scp, 0control, and the startstop issues are all hammered out, make another system backup 

# CONTROL JAIL
	control key needs added to all rootjails - also to qb-create
	0bsdvm needs to have a daemon for continually checking/attmepting dhclient on vtnet0 
	add permanent checks to prevent any changes to control via normal qb-commands

qb-copy
	- Library functions b/c qb-connect will also integrate
	- will use /media as the default copy locations between any two jail/VM combos
	- Can specify copy location as well
	- automatically brings up the SSH connection if necessary, then brings it down

# Finish VM setup

qb-connect
	- VM integration: jail/VM connections, specifically SSH preparation for files copy
	- Inside VMs - qb-copy <file> ... which sends to the ssh-jail, or copies from it

qb-pci
	- summary of PCI devices relevant to user
	- USB, NIC, maybe others
	- Show what was is currently passthrough'd

Ubuntu - zusr dataset integration; user profiles

USBVM 
	- Create a proper unprivileged user with devd.conf and automounts     
	- Auto remove password from unprivleged usbvm user     


### UPGRADES

ZFS Encrypted Jails

Tor and I2P Jails

GUI SECURITY
	- Test Wayland in separate tty
	- Test Xpra, Xauth and try to isolate xhost 
	Xephyr - Unfortunately I'm not sure this is a real solution. Everything still shares the unix socket
		- Might not matter, but if I keep it, some ideas:
			- the qb-xephyr command into qb-cmd -X, including VMs. Make sure works with -n as well.
			- Integrate an "X" option for qb-ephm as well.

pwd
	- I think the right way to do this, is export any existing pwd db in /rw, and import it into the created jail (or maybe vice versa) 
	- Right now I'm not so confident on how that's working
	- To get around the pw -V problem, you could put /usr/local/bin/pw wrapper

Host as Unprivileged user     
	- All jails will have an epair to an offline *Control Jail*      
	- Unprivileged user on host will pass jails SSH commands via Control Jail     
	- Control jail pf will block all, except port 22 between host and jails     

NICVM - Linux VM so that it can use all the wireless protocols.
     - Someone made a post about this in FreeBSD

Take another hack at the recording device problems

QMAP - New PARAM - CONNECT, that establishes a connection to a specified jail/VM


### SPECIFIC SCRIPTS

You can probably bring seclvl=3 for gateways now. Also I dont think gateway require restarts anymore on qb-edit

qb-stop
	- Detect settings if the VM has PPT, and warn to stop internally. Popup warn if necessary.
	- monitor_vm_stop is probably outdated now since `wait` commands are being used. Needs reviewed 

qb-i3-launch - had problems with double launching windows that already existed (on fully opened setup)

Error messages are a bit disorganized now. Need to have useful higher function messages
	- Change the exit action to an option command instead of postional
	- Change the message selection to an OPTARG. Two messages -m and -M   
	- All positinals are for related variables only. Reference them with $1, $2, $3, etc
	- **Give each jail and VM it's own separate log file under a quBSD directory, for clarity of log messages**
	- Default should be top level basic messages. -q quiets all, and -v drills down to deeper messages
	- Might need a -F force option.
	- Beef up the log file, and make reference to it in error messages

qb-list [-e] (evaluate) option to check jail-param combos for validity.


qb-help - overhaul to act like a manpage. Replacing /usr/local/share/quBSD
	- Each PARAM should have verbose message

qb-ephm - Clone from zroot too. Tricky, because of "reclone_zroot" operation in exec.prepare 

qb-update - Update rootjails, create snapshots

qb-backup (already created in $ubin)
	- cron to run on both sides of source and dest, with ssh hostname, to automate backups

qb-stat - Change hardcoded to more flexible setup: config file, col selector, RAM/CPU/DISK colorize



### GENERAL / BEST PRACTICES / CLEANUP

The test for exec.created modifying wg0, pf, and dhcp, should be if they're included/enabled in the jail's rc script

GENERAL GUIDELINES, and maybe later double checks
	- Attempt to make scripts more robust and account for user error, when it makes sense to do so.
	- Try to use more redirects, tee's, and also try the 'wait' command for scripts that appear to hang (but are actually finished).
	- PARAMETERS should be CAPS when refering to the generic PARAM; lowercase when refering to a specific value
	- [test] { command ;} grouping. Can save alot of space and simplify the get_msg constructions
	- while getopts <opts> opts ; do case $opts in
	  esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift
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

Intelligent resizing of fonts depending on dpi or xrandr resolution

ntpd - ntpd only runs during qb-hostnet. Needs a more "correct" solution. Maybe rolled into the/a control jail

qme-firefox needs fixed (personal note)

I think `jail` caches fstab before completion of exec.prepare which edits it. Need to prove/submit bug. Need dtrace


##### qubsd installer #######

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
I think I need to touch /etc/fstab with header so disps work? Or something like that

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
	pkg install isc-dhcp44-server bind918 wireguard wireguard-go jq
	- Check that pf conf is updated with required dhcp port, and the simplified version

R_ZFS and U_ZFS ; and mountpoints changed. Less cumbersome, more straightforward

VMs integration
	- install bhyve-uefi firmware
	
quBSD.conf removed. Everything now in jailmap.conf

Should make the $qubsd/zroot/0net 0gui 0vms and everything files here for specific stuff like rc.conf

### Control Jail
# KEYGEN
	- cp -a group master.passwd passwd pwd.db spwd.db from 0net to /zusr/0control/rw/etc/
	- mkdir -p /zusr/0control/usr/home/0control
	- chown -R 1001:1001 /zusr/0control/usr/home/0control
	- mkdir -p /zusr/0control/usr/home/ftpd
	- chown -R 1002:1002 /zusr/0control/usr/home/ftpd
	- chmod 755 /zusr/0control/usr/home/ftpd
	- mkdir -p /zusr/0control/rw/root/.ssh
	- chmod 700 /zusr/0control/rw/root/.ssh
	- pw -V /zusr/0control/rw/etc useradd -n 0control -u 1001 -d /usr/home/0control -s /bin/csh
	- pw -V /zusr/0control/rw/etc useradd -n ftpd -u 1002 -d /usr/home/ftpd -s /bin/sbin/nologin
	- ssh-keygen -t rsa -b 4096 -N "" -f /zusr/0control/rw/root/.ssh/id_rsa
	- cp -a /zusr/0control/rw/root/.ssh/id_rsa.pub /zusr/0control/usr/home/ftpd
	- cp -a qb_ssh script to /usr/home/ftpd 
	- chmod 755 /zusr/0control/usr/home/ftpd/*
	
# rootjails need copy of 0control pubkey	
# SSHD in all rootjails 
# 0bsdvm needs to have a daemon for continually checking/attmepting dhclient on vtnet0 



