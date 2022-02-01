
### PRE-INSTALL 

**RECOMMENDATIONS**   
- Better to run in a console, rather than an X11 xterm    
- Likely to avoid errors if done on a fresh FreeBSD install, (but not strictly required).    
- quBSD comes with i3 integration, but could easily be adapted to any other WM.    
- quBSD doesn't configure Xorg or sound (on host). User should already have configured these.    
- Here's an example of my host packages:    
   - doas Xorg nvidia-driver vim i3 i3status i3lock dbus pefs-kmod virtual_oss webcamd    


**REQUIREMENTS** 

quBSD depends on the dataset:  zroot/jails  mounted at  /jails     
- EITHER ...    
- Dataset and directory must both be empty (and quBSD will create them), OR    
- zroot/jails can be pre-existing, but MUST have mountpoint /jails    

quBSD depends on a separate zpool from zroot:  zusr  mounted at /zusr       
- If the zpool zusr does not exist, the user MUST exit and create zusr     
  - It's outside the scope of the installer to create a new zpool     
- If you already have a separate zpool, you can re-import it:    
   - This operation merely renames the zpool, data is preserved    
   - zpool export <your_old_poolname>     
   - zpool import <your_old_poolname> zusr     

Clone the git repository to /zusr/


**INSTALL**

You have two choices:
- Run the script:  /zusr/quBSD/zroot/usr/local/bin/qubsd-installer
   - This is an interactive script and requires your input
- OR follow the guide at:  /zusr/quBSD/zroot/usr/local/share/quBSD/5_Manual_Install
   - This will be quite a long process, as there are alot of moving parts    
