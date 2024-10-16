#!/bin/sh

# Copies primary files onto host machine in a way that requires no user input.
# This function will become the ports/pkg install script, with a secondary installer required later. 

# Repo location for files copy
_SHARE="/usr/local/share/"
_REPO="/usr/local/share/quBSD"

# Install dependencies - possibly also xpra, xephyr, and doas in later revisions
pkg install bhyve-firmware tmux

# Fetch repo to /usr/local/share
fetch -o ${_SHARE} https://github.com/BawdyAnarchist/quBSD/archive/refs/heads/main.zip
unzip -qd ${_SHARE} ${_SHARE}/main.zip
mv ${_SHARE}/quBSD-main ${_REPO}
rm ${_SHARE}/main.zip

# Make sure the required directories exist
[ -e /usr/local/etc/quBSD ] || mkdir -p /usr/local/etc/quBSD
[ -e /usr/local/lib/quBSD ] || mkdir -p /usr/local/lib/quBSD
[ -e /usr/local/etc/rc.d ]  || mkdir -p /usr/local/etc/rc.d   
[ -e /boot/loader.conf.d ]  || mkdir -p /boot/loader.conf.d
[ -e /etc/cron.d ]          || mkdir -p /etc/cron.d

# Copy files to their directories 
cp -a ${_REPO}/zroot/usr/local/etc/quBSD/* /usr/local/etc/quBSD/
cp -a ${_REPO}/zroot/usr/local/bin/*       /usr/local/bin/
cp -a ${_REPO}/zroot/usr/local/lib/quBSD/* /usr/local/lib/quBSD/
cp -a ${_REPO}/zroot/usr/local/etc/rc.d/*  /usr/local/etc/rc.d/
cp -a ${_REPO}/zroot/boot/loader.conf.d/*  /boot/loader.conf.d/
cp -a ${_REPO}/zroot/etc/cron.d/qubsd_cron /etc/cron.d/qubsd_cron

# Check for AMD CPU, and add it to the loader file 
dmesg | grep -Eqs "^CPU.*AMD" && echo -e "# This machine has an AMD CPU\nhw.vmm.amdvi.enable=\"1\"" \
	>> /boot/loader.conf.d/qubsd_loader.conf

# Handle devfs.rule by trying to find the first available rule numbers, then adding them
rulenum1=$(sed -n "s/^\[devfsrules.*=//p ; s/\]//p" /etc/devfs.rules | tail -1)
while : ; do
	rulenum1=$(( rulenum1 + 1 ))
	rulenum2=$(( rulenum1 + 2 ))
	! grep -Eqs "^\[devfsrules.*=${rulenum1}" /etc/devfs.rules \
		&& ! grep -Eqs "^\[devfsrules.*=${rulenum2}" /etc/devfs.rules && break
done

# Modify devfs.rules and also update jail.conf
cat ${_REPO}/zroot/etc/devfs.rules >> /etc/devfs.rules 
sed -i '' -E "s/(^\[devfsrules_qubsd_netjail=)/\1$rulenum1/" /etc/devfs.rules
sed -i '' -E "s/(^\[devfsrules_qubsd_guijail=)/\1$rulenum2/" /etc/devfs.rules
sed -i '' -E "s/NETRULENUM1/$rulenum1/g" /usr/local/etc/quBSD/jail.conf
sed -i '' -E "s/GUIRULENUM2/$rulenum2/g" /usr/local/etc/quBSD/jail.conf

# Based on pciconf class=network, find the first interface listed in rc.conf and assume it's the primary nic 
_nics=$(pciconf -lv | grep -B3 "= network" | grep -Eo "^[[:alnum:]]+" | grep -v none)
for _dev in $_nics ; do
	grep -E "^ifconfig_${_dev}" /etc/rc.conf \
		&& sed "s/#nic=.*/nic=${_nic}/" ${_REPO}/Install/install.conf \
		&& nic="$_dev" && break
done
