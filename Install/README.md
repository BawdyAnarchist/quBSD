
**ADVISEMENTS**   
- quBSD doesn't configure host Xorg / sound. User should've already configured these. 
- Minimize host pkgs, try to put the rest in jails. Here's an example of my host pkgs:
   - doas Xorg nvidia-driver vim i3 i3status i3lock dbus pefs-kmod virtual_oss webcamd    
- Putting your user data (zusr) on a separate pool that the root system, is a good idea.

**REQUIREMENTS**
- You must have at least one zfs zpool/dataset available on host
- Copy the installer script to:  `/usr/local/bin/qubsd-installer`  
- It's an interactive script, requires user input 
   - If you have multiple zpools, you'll need to select which one(s) to use
   - Two FreeBSD installers require user attention:  one for jails, the other VMs 
   - Time to install, 30-60 minutes, mostly waiting for GUI jail pkgs to install. 
      - *you may decline to install (most of) these if you wish*

After you're done with the install, highly recommend going through the tutorial at:
[quBSD/zroot/usr/local/share/quBSD/](https://github.com/BawdyAnarchist/quBSD/tree/master/zroot/usr/local/share/quBSD)
