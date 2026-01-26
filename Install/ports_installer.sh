#!/bin/sh

# Copies primary files onto host machine in a way that requires no user input, 
# and which doesn't modify any pre-existing files outside of /usr/local 
# This function will become the ports/pkg install script, with a secondary installer required later. 

download_base() {
	# Download the latest base.txz
	BASETXZ="/usr/local/freebsd-dist/base.txz"
	rel=$(freebsd-version -u | sed -E 's/([0-9]+\.[0-9]+).*$/\1-RELEASE/')
	link_txz="https://ftp.freebsd.org/releases/$(uname -m)/${rel}/base.txz"
	dl_size=$(echo "$(fetch -s $link_txz) / 1048576" | bc)
	[ -d "${BASETXZ%/*}" ] || mkdir ${BASETXZ%/*} 
	fetch -o $BASETXZ $link_txz > /dev/null 2>&1
	DL_PID="$!"
}

fetch_repo() {
	# Fetch repo to /usr/local/share
	REPO="/usr/local/share/quBSD"
	fetch -o ${REPO%/*} https://github.com/BawdyAnarchist/quBSD/archive/refs/heads/main.zip
	unzip -qd ${REPO%/*} ${REPO%/*}/main.zip > /dev/null 2>&1
	mv ${REPO%/*}/quBSD-main ${REPO}
	rm ${REPO%/*}/main.zip
}

copy_repo() {
	# Make sure the required directories exist
	[ -e /usr/local/etc/qubsd ] || mkdir -p /usr/local/etc/qubsd
	[ -e /usr/local/lib/qubsd ] || mkdir -p /usr/local/lib/quBSD
	[ -e /usr/local/etc/rc.d ]  || mkdir -p /usr/local/etc/rc.d   
	[ -e /boot/loader.conf.d ]  || mkdir -p /boot/loader.conf.d
	[ -e /etc/cron.d ]          || mkdir -p /etc/cron.d
	[ -e /etc/jail.conf.d ]     || mkdir -p /etc/jail.conf.d

	# Copy files to their directories 
	cp -a ${REPO}/zroot/usr/local/etc/qubsd/ /usr/local/etc/qubsd/
	cp -a ${REPO}/zroot/usr/local/bin/       /usr/local/bin/
	cp -a ${REPO}/zroot/usr/local/lib/quBSD/ /usr/local/lib/quBSD/
	cp -a ${REPO}/zroot/usr/local/etc/rc.d/  /usr/local/etc/rc.d/
	cp -a ${REPO}/zroot/boot/loader.conf.d/  /boot/loader.conf.d/
	cp -a ${REPO}/zroot/etc/jail.conf.d/     /etc/jail.conf.d/
}

modify_files() {
	# Check for AMD CPU, and add it to the loader file 
	dmesg | grep -Eqs "^CPU.*AMD" && echo -e "\n# This machine has an AMD CPU\nhw.vmm.amdvi.enable=\"1\"" \
		>> /boot/loader.conf.d/qubsd_loader.conf

	# Based on pciconf class=network, find the first interface listed in rc.conf and assume it's the primary nic 
	_nics=$(pciconf -lv | grep -B3 "= network" | grep -Eo "^[[:alnum:]]+" | grep -v none)
	for _nic in $_nics ; do
		grep -Eqs "^ifconfig_${_nic}" /etc/rc.conf \
			&& sed -i '' -E "s/nic=/nic=${_nic}/" ${REPO}/Install/install.conf \
			&& break
	done
}

verify_base_download() {
	while ps -p $DL_PID > /dev/null 2>&1 ; do
		sleep 1

		# Calculate % completion of download, only if the file exists
		[ -e "$BASETXZ" ] \
			&& dl_prog=$(ls -lh $BASETXZ | awk '{print $5}' | sed -E 's/.$//') \
			&& dl_pct=$(echo "scale=2 ; ( ${dl_prog} + 0 ) / ${dl_size} * 100" | bc)
		printf "\033[1A"
		printf "\033[K"
		echo "  $BASETXZ     ${dl_pct%%.*}% of ${dl_size}M"
	done			
}

install_instructions() { cat << ENDOFMSG

You will have a better installation if you read and follow:
  /usr/local/share/quBSD/Install/README.md

AT A MINIMUM, TO FINISH INSTALLING YOU MUST:
  1. Edit:  /usr/local/share/quBSD/Install/install.conf
  2. Run:   sh /usr/local/share/quBSD/Install/qubsd-install.sh
  3. REBOOT
ENDOFMSG
}

main() {
	download_base &
	
	# Install dependencies - possibly also xpra, xephyr, and doas in later revisions
	pkg install -y bhyve-firmware tmux e2fsprogs-core

	fetch_repo
	copy_repo	
	modify_files
	verify_base_download
	install_instructions
}

main
