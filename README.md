#### quBSD is a FreeBSD jails/bhyve wrapper which implements a Qubes inspired containerization schema. Written in shell, based on zfs, and uses the underlying FreeBSD tools.

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

### Security Schema
*Rootjails* maintain a pristine root environment for launching appjails.   
*Appjails* clone a designated rootjail at every start, destroyed at shutdown.   
&nbsp;&nbsp;- Persistent /home directory lives in a separate zfs dataset   
&nbsp;&nbsp;- Can specify persistent system files like rc.conf, pwd.db, pf.conf, etc ...   
*Dispjails* have no persistent data. Completely destroyed at jail shutdown.   
*Ephemeral* jails clone the exact state of a running jail.   
&nbsp;&nbsp;- Open untrusted files/attachments    
&nbsp;&nbsp;- Test experimental operations on a clone, before performing in appjail   
*RootVMs* maintain a pristine root environment on which to base appVMs.   
*AppVMs* clone a designated rootVM same as appjail, with persistent /home.   
*DispVMs* No persistent data. Completely destroyed upon VM shutdown.   

Host remains offline, except for updates.    
Physical network card and USBs are isolated in VMs (nicvm and usbvm)

### Additional Features
Well documented man pages
i3wm integration (still usable with other window managers)
Control jail is used with ssh for file transfers between VMs.

### Install to host
`pkg install qubsd`
