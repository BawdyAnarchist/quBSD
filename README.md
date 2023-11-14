#### quBSD is wrapper for a jails/bhyve implementation of a Qubes-inspired containerization schema. Written in shell, based on zfs, and uses the underlying FreeBSD tools.


#### 2023 Nov 13 UPDATE

Significant work is ongoing with quBSD. The original take was good, but this next iteration will be quite good. The code is MUCH cleaner, robust, best practices. VMs are largely integrated. The common library is comprehensive. Automatic snapshots, with time-to-live thinning are native to the system. Help files are useful. Safety checks are inbuilt throughout.

UP NEXT: Tor gateway/workstation pair. GUI isolation. ZFS encrypted jails. Run quBSD host as a normal user (not root) via a control jail. 

Once these are implemented, a new installer script will be written, a port created, and I intend to add this to the ports collection, as well as package it up for pkg.

If anyone feels like helping develop any of the remaining pieces listed above, please contact me. I'd like to get this project to a production state, and hopefully find at least one other person to help maintain it.


#### Summary of functionality and features: 

GUI Jails come default on the system, with a pre-configured template

Pre-configured networking firewall/gateway tunnel jails     
- Inter-jail networking is fully automated via startup scripts     
- Easily customizable. Create multiple VPN gateways, firewalls, and clients     
- Host never receives network connection except for updates and pkgs    

Virtual Machines isolate PCI devices    
- NIC is isolated inside a VM called "nicvm" ; and connects to networking jails    
- USB devices are isolated in a VM called "usbvm"     
   - Reduces the risk of plugging flash devices into your machine      

Jails Schema      
- *Rootjails* maintain a pristine root environment for launching all *appjails*    
- *Appjails* get a fresh rootjail clone at every start, destroyed at shutdown     
- Persistent storage for /home and for user specified root/system files    
   - For example: appjails can have custom rc.conf, pwd.db, /etc/files    
- *Disposable* jails have no persistent data. Completely destroyed upon shutdown       

Additional Features    
- Default i3 integration, but could easily be modified for any window manager    
- Single configuration file for all jail settings    
   - Resource control and security options (RAM, CPU, schg, securelevel)    
   - Internal network:  Set gateway (tunnel) and IP for each jail    
- exec.scripts automate all jail start/stop functions   
- qb-scripts facilitate    
   - Quick/easy creation of new jails     
   - Viewing and editing of jail parameters     
   - Realtime continuous monitoring of jail status and resource usage     
   - Descriptive help pages      
   - Simplified handling/access for nicvm and usbvm virtual machines     
