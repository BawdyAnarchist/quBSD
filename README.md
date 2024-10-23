#### quBSD is a jails/bhyve wrapper which emulates a Qubes inspired containerization schema. Written in shell, based on zfs, and uses the underlying FreeBSD tools.

### Summary of Default Features: 

X11 GUI Jails, with a cloneable template.
Network gateway jails/VMs for firewall, VPNs, and Tor.
Disposable/ephemeral jails/VMs. 
Automatic rolling zfs snapshots, with thinning.
Streamlined configuration/editing:
- resource constraint (memory, CPU)
- filesystem protections (chflags schg, secure level)
- gateway changes
- autostart, automatic snapshots
- create/destroy/rename/edit/list
- realtime mo

### Security Schema
*Rootjails* maintain a pristine root environment for launching appjails.
*Appjails* clone a designated rootjail at every start, destroyed at shutdown.
- Persistent /home directory lives in a separate zfs dataset
- Can specify persistent system files like rc.conf, pwd.db, pf.conf, etc ...
*Dispjails* have no persistent data. Completely destroyed at jail shutdown.
*Ephemeral* jails can be cloned from any existing jail.
- Open untrusted files/attachments
- Test experimental operations on a clone, before performing in appjail
*RootVMs* maintain a pristine root environment on which to base appVMs.
*AppVMs* clone a designated rootVM same as appjail, with persistent /home.
*DispVMs* No persistent data. Completely destroyed upon VM shutdown.

Host remains offline, except for updates.
Physical network card and USBs are isolated in VMs (nicvm and usbvm)

### Additional Features
i3wm integration, if desired (still usable with other window managers).
-
Well documented man pages
Control jail is used with ssh for file transfers between VMs.

- exec.scripts automate all jail start/stop functions   
- qb-scripts facilitate    
   - Quick/easy creation of new jails     
   - Viewing and editing of jail parameters     
   - Realtime continuous monitoring of jail status and resource usage     
   - Descriptive help pages      
   - Simplified handling/access for nicvm and usbvm virtual machines     

