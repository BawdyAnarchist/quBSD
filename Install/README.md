## MAIN CONFIG FILE
	usr/local/share/quBSD/Install/install.conf

## ENVIRONMENT CUSTOMIZATION

## ROOT FILESYSTEM CONFIGS

## REQUIREMENTS
- You must have at least one zfs zpool/dataset available on host
- It's an interactive script, requires user input 
   - If you have multiple zpools, you'll need to select which one(s) to use
   - Two FreeBSD installers require user attention:  one for jails, the other VMs 
   - Time to install, 30-60 minutes, mostly waiting for GUI jail pkgs to install. 
      - *you may decline to install (most of) these if you wish*

## ADVISEMENTS
- quBSD doesn't configure host Xorg / sound. User should've already configured these. 
- Minimize host pkgs, try to put the rest in jails. Here's an example of my host pkgs:
   - doas Xorg nvidia-driver vim i3 i3status i3lock dbus virtual_oss webcamd    
- The installer allows you to choose the same zpool for both rootjail data, and jail's user data (zusr). However, it's best practice (even on a normal system), to segregate user data to a different pool/partition.

## TUTORIAL

## MAN PAGES
