#!/bin/sh

# Configuration script for a new FreeBSD rootVM. Run this on first launch of the VM.

_DIR="$1"

modify_rc() {
  # Edit rc.conf
  { echo ; echo '# qubsd boot script' ; echo 'qubsd_init_enable="YES"' ;} >> /etc/rc.conf

  # Copy the rc.d script
  [ -d "/usr/local/etc/rc.d" ] || mkdir -p /usr/local/etc/rc.d
  cp ${_DIR}/freebsd/qubsd-init /usr/local/etc/rc.d/
}

handle_users() {
#  TEMP NOTE: REWORKING: There's some other way to make this like rc.conf.local in the /overlay
}

manage_ssh() {
#  TEMP NOTE: REWORKING: Will probably still need this for versatile SSH ops into VMs from control.
#   #  virtio-vsock. Guest listens on vsock or uses socat pipe to map vsock to localhost:22 (or maybe 2222)

  # Copy ssh pubkeys from the control jail and set permissions
  [ -d "/root/.ssh/" ] || mkdir -p /root/.ssh
  chmod 700 /root/.ssh

  # OLD COMMAND: fetch -o /root/.ssh/authorized_keys ftp://0control.qubsd.local/id_rsa.pub
  # SHOULD BE PUSHING THE KEY THROUGH THE FAT32 CONFIG ZVOL 
  # NEW COMMAND (incomplete): cp -a /dev/location/authorized_keys /root/.ssh/authorized_keys

  chmod 600 /root/.ssh/authorized_keys
  cp -a /root/.ssh /home/user/

  # Modify sshd, enable, and restart sshd
  sed -i '' -E 's/^#(PermitRootLogin).*/\1 yes/' /etc/ssh/sshd_config

  sed -i '' -E 's/^(PermitRootLogin).*/\1 yes/' /etc/ssh/sshd_config
  sed -i '' -E 's/^#(PasswordAuthentication).*/\1 no/' /etc/ssh/sshd_config
  sed -i '' -E 's/^(PasswordAuthentication).*/\1 no/' /etc/ssh/sshd_config
  sysrc sshd_enable="YES"
  service sshd restart
}

main() {
  modify_rc
  handle_users
  manage_ssh 
}

main


