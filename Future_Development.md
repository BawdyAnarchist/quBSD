

0control review and overhaul 
   remember that you turned it off in exec.created, quBSD.sh (VMs), qb-start, qb-cmd, start_jail
  	remove all the extra services like named, ftp, others? Only need DHCP now 
	**update nicvm**
	CHANGES:

qb-start
	- Needs updated with new networking functions in mind
	- Simultaneous starts of clients could mess up wireguard restarting

There are still demons in the xephyr-xclip daemon
   - Pretty sure they're all related to the closing of windows. It gets corrupted or something when I close windows. probably I'm not sufficiently detecting all possible events -- Like, maybe the disappearance of a socket is still problematic or something?
   - You need to kill the clipboard ownership inside the source as well after releasing. Otherwise you get inconsistent waffling on lease expiry, where what FEELS like stale clipboard then can still paste if you're inside the same socket for a window. Causes problems

Why does Telegram freeze so much?

Sound in Linuxulator?



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

pwd: Overaul plan two parts:
   - rootjail contains a default qubsd_pw.conf - Just a 1-liner manifest for basic user creation 
   - /rw/etc/ (or /rw/usr/local/etc/) qubsd.conf.local - Users can add new groups/users. Created at jail start

dispVM
	- vm-rc.local should use its IP address to get it's hostname from 0control ftp server
		- This will require creating a new file in /home/ftp/<IPaddr> on 0control

NICVM - Linux VM (probably alpine) so that it can use all the wireless cards. 
     - Someone made a post about this in FreeBSD

I2P Gateway

0serv 


### SPECIFIC SCRIPTS OR FUNCTIONS

qubsd.conf
   - generalize the schg to being able to list specific files, and not my preselected ones.

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

qb-i3-launch - overhauled now that I'm using Xephyr

qb-cmd -e [ephm]
   - Ideally you would also clone the zroot from whatever jail you're ephm'ing. 

qb-create
	- [-z dupl] still needs to create and copy the fstab of the template jail, and maybe the rc.conf too. 
	- It needs further and more extensive testing 
	- -z dirs recreated files too, not just directories
	- qb-create removal of achi-hd might not be working. I dunno I changed it to hd so maybe that was why
	- There needs to be a template for parameters, and a template for zusr
	- You can in install a brand new rootjail via tar base.txz, and this should be an opt coz of the little qubSD required adjustments 

qb-pci
	- summary of PCI devices relevant to user
	- USB, NIC, maybe others
	- Show what was is currently passthrough'd

qb-update - Update rootjails, create snapshots

qb-backup - Add ssh option

qb-stat
   - Monitor for unfocused CPU resource usage - Flag/Notify. For user
	- Change hardcoded to more flexible setup: config file, col selector, RAM/CPU/DISK colorize
	- Give a popup option that can be closed with any key (quickview kinda stuff)
	- Add a column for worspace location of active windows

consider - https://it-notes.dragas.net/2023/08/14/boosting-network-performance-in-freebsds-vnet-jails/
	- It's for vnet jails and NAT. Disables hardware checksums for virtual interfaces, and extra filtering on bridges


### GENERAL PROBLEMS / BEST PRACTICES / CLEANUP

It sounds like I still need magic cookies because some jails will still have opt to be on nullfs on host x11-unix

eliminate all files and directories that reference quBSD ... It should just be qubsd
remove all of the local var=asdf ; local var2=lkj ... you can just say local ONCE

TIMEOUT overhaul - timeout is a real command that will exit a command after a certain time. wow that would've been useful a long time ago

rc.conf -nmdm cuse , I dont know if I need them or what for

When you restore, the datasets dont inherit their qubsd:autosnap properties

Instead of all the named and ftp nonsense in 0control, just use a fat32 formatted zvol on the creation of a new VM

ALL file names should ALWAYS be variables defined in get_global_variables ?

Take another hack at the recording device problems

Hardened FreeBSD. Implements alot of HardenedBSD stuff with a simple .ini file and code.
https://www.reddit.com/r/freebsd/comments/15nlrp6/hardened_freebsd_30_released/

Crons - No crons running. Probably something long term security that should be integrated and automated.


### INSTALLER SCRIPT CHANGES ###
cjails ssh
	- Generate separate ssh key for root vs 0control user

local unbound
  chroot 0net && service local_unbound setup
    - MODIFY THE chroot line to:  `chroot: ""`
	 - include: /var/unbound/forward.conf
  touch /var/unbound/foward.conf
  copy the qubsd_server.conf file (should already be done)

roots
	mkdir /usr/local/bin && cp qubsd_dhcp
	mkdir /usr/local/etc/rc.d && cp qubsd_dhcp
	/etc/rc.conf qubsd_dhcp_enable="YES"
	touch /qubsd/0base/etc/resolv.conf
	dbus added to host when GUI option is selected 

X11 segregation
  install socat on host, bspwm in 0gui
  copy the bspwmrc to 0gui /usr/local/etc/X11/ 
  copy /etc/login.conf to 0gui, then chroot and cap_mkdb (for GLX etc problems and avoidance)

Linuxulator:
  install debootstrap to host
  mkdir then debootstrap jammy /qubsd/0gui/compat/ubuntu
  mkdir /qubsd/0gui/compat/ubuntu/tmp/.X11-unix
  modify /etc/apt/sources.list
  apt update && apt upgrade
  /etc/bash.bashrc - PS1 you can add 'ubuntu ' in front of ${debian_...}
    - same for /root/.bashrc
    - this will help when you're the LINUX user/root in the jail, to show that clearly at terminal
  /etc/environment - newline: `_JAVA_AWT_WM_NONREPARENTING=1`
    - coz java refuses to honor bspwm
  ?? Do I need to change the env for GUI programs in Linux as well?? Like with /etc/login.conf? Maybe.


### GENERIC SHELL LIBRARY FUNCTIONS
exists_then_copy "<file>" "<location>"
check_yesno
get_user_response


