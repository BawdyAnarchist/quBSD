#!/bin/sh

# Copies primary files onto host machine in a way that requires no user input.
# This function will become the ports/pkg install script, with a secondary installer required later. 

# Repo location for files copy
_SHARE="/usr/local/share/"
_SHARE="/usr/local/share/quBSD"

# Install dependencies - possibly also xpra, xephyr, and doas in later revisions
pkg install bhyve-firmware tmux

# Fetch repo to /usr/local/share
fetch -o ${_SHARE} https://github.com/BawdyAnarchist/quBSD/archive/refs/heads/main.zip
unzip -qd ${_SHARE} ${_SHARE}/main.zip
mv ${_SHARE}/quBSD-main ${_REPO}
rm ${_SHARE}/main.zip

# Make sure the required directories exist
[ -e /usr/local/lib/quBSD ] || mkdir -p /usr/local/lib/quBSD
[ -e /usr/local/bin/quBSD ] || mkdir -p /usr/local/bin/quBSD
[ -e /usr/local/etc/quBSD ] || mkdir -p /usr/local/etc/quBSD
[ -e /usr/local/etc/rc.d ]  || mkdir -p /usr/local/etc/rc.d   
[ -e /boot/loader.conf.d ]  || mkdir -p /boot/loader.conf.d

# Copy files to their directories 
[ -e /etc/pf.conf ] && mv /etc/pf.conf /etc/pf.conf_orig
cp -a ${_REPO}/zroot/usr/local/bin/*       /usr/local/bin/
cp -a ${_REPO}/zroot/usr/local/lib/quBSD/* /usr/local/lib/quBSD/
cp -a ${_REPO}/zroot/usr/local/etc/quBSD/* /usr/local/etc/quBSD/
cp -a ${_REPO}/zroot/usr/local/etc/rc.d/*  /usr/local/etc/rc.d/
cp -a ${_REPO}/zroot/boot/loader.conf.d/*  /boot/loader.conf.d/

# Check for AMD CPU, and add it to the loader file 
dmesg | grep -Eqs "^CPU.*AMD" && echo 'hw.vmm.amdvi.enable="1"' >> /boot/loader.conf.d/qubsd_loader.conf
