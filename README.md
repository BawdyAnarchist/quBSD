### IMPORTANT NOTE ###

If anyone new is coming to check out my project, just know that I'm in the middle of a significant re-write of the shell scripts. I'm writing a common library, and have significantly improved my shell/code practices since last year. For now, the installer doesn't set the new pieces in place, and half of the shell scripts depend on those pieces. 

You can probably get some mileage out of the scripts in a manual sense, but as a whole, v0.2 isn't ready. 

I realize now that I should've created a separate branch while leaving the main version untouched, but well, hindsight. First time using a repository management tool. Give me a month or so, and it should be significantly better.

Finally, if anyone knows how to do packaging for FreeBSD ports, please let me know, because after this re-write, this should be a pretty solid project, worth adding to ports. 


#### quBSD is wrapper for a jails/bhyve implementation of a Qubes-inspired containerization schema. Written in shell, based on zfs, and uses the underlying FreeBSD tools.

The goal is to run all workloads inside of jails, and make host merely a coordinator. quBSD comes with an installer script, which creates and configures a series of jails, and even a couple VMs for PCI device isolation. There are a set of scripts which facilitate management of the entire setup.

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

For a full description of system functionality at [quBSD/zroot/usr/local/share/quBSD/](https://github.com/BawdyAnarchist/quBSD/tree/master/zroot/usr/local/share/quBSD)
