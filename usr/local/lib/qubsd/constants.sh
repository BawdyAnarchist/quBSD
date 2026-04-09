#!/bin/sh

## GLOBAL VARIABLES FOR LIBRARIES AND SCRIPTS ##

# Primary directories
export QETC="/usr/local/etc/qubsd"
export QLIB="/usr/local/lib/qubsd"
export QLEXEC="/usr/local/libexec/qubsd"
export QSHARE="/usr/local/share/qubsd"
export QRUN="/var/run/qubsd"
export DEVFS="/etc/devfs.rules"

# Supporting directories
export D_QMSG="$QLIB/messages"
export D_QCONF="$QETC/qubsd.conf.d"
export D_CELLS="$D_QCONF/cells"
export D_JCONF="$QETC/jail.conf.d"
export D_JAILS="$D_JCONF/jails"
export D_RUNTM="$QRUN/runtime"
export D_QERR="$QRUN/err"
export D_QX11="$QRUN/X11"
export D_XFER="$QRUN/xfer"
export D_QTMP="$QRUN/tmp"

# Exception system and diagnostics
export BASENAME="$(basename $0)"
export ERR="$D_QERR/$BASENAME.$$.err"
export MESSAGES="$D_QMSG/lib*.msg $D_QMSG/$BASENAME.msg"
export TRAP="rm -f $ERR"
export TRAP_SIGS="HUP INT TERM QUIT EXIT"
export DEBUG="/root/debug"
: ${VERBOSE:=false}  # [true|false] Print commands to console before running them
: ${DRY_RUN:=false}  # [true|false] Do not execute, just print commands to the console
: ${TRACE:=false}     # [true|false] Show the function trace in error/warning messages

# Primary qubsd files
export QCOMMON="$QLIB/common.sh"
export DEF_BASE="$D_QCONF/defaults.base.conf"
export DEF_JAIL="$D_QCONF/defaults.jail.conf"
export DEF_VM="$D_QCONF/defaults.vm.conf"

# Relative system directories
export REL_ULOC="/usr/local"
export REL_LBIN="$REL_ULOC/bin"
export REL_LETC="$REL_ULOC/etc"
export REL_LLIB="$REL_ULOC/lib"
export REL_LLEX="$REL_ULOC/libexec"
export REL_LRCD="$REL_LETC/rc.d"
export REL_LX11="$REL_LETC/X11"
export REL_UNBOUND="/var/unbound"

# Common overlay directories
export OV="rw"
export OVETC="$OV/etc"
export OVULOC="$OV/usr/local"

# Common overlay files
export OV_FSTAB_L="$OVETC/fstab.local"
export OV_RC_CONF="$OVETC/rc.conf"
export OV_RC_CONF_L="$OVETC/rc.conf.local"
export OV_RC_L="$OVETC/rc.local"
export OV_PW_L="$OVETC/master.passwd.local"
export OV_GP_L="$OVETC/group.local"

# Runtime invariant lists. "CONTROL" is in the framework, but not added here. Uncertain about it's future.
export PARAMS_BASE="AUTOSTART,AUTOSNAP,BACKUP,CLASS,ENVSYNC,GATEWAY,IPV4,MTU,NO_DESTROY,P_ZFS,R_ZFS,ROOTENV,TEMPLATE"
export PARAMS_JAIL="CPUSET,DEVFS_RULE,MAXMEM,SCHG,SECLVL"
export PARAMS_VM="BHYVEOPTS,BHYVE_CUSTM,MEMSIZE,PPT,TAPS,TMUX,VCPUS,VNC,WIREMEM"
export PARAMS_ALL="$PARAMS_BASE,$PARAMS_JAIL,$PARAMS_VM"
export PARAMS_HOST="AUTOSNAP,GATEWAY,IPV4,MTU"  # Only modifiable params for "cell" `host'
export PARAMS_EXCL_DEFAULT="CLASS,PPT,TEMPLATE"
export CONTEXT="CALLER,JCONF,QCONF,P_DSET,P_MNT,R_DSET,R_MNT,RT_CTX"   # Convenient context paths
export CTX_VALIDATE="JCONF,P_DSET,R_DSET"     # Necessary validations in addition to PARAMS_
export CLASSES="rootjail,appjail,dispjail,rootVM,appVM,dispVM,cjail"

# Query results storage for rapid stacked/looped information retreival
export QUERY="CELLS,CELLS_QPATHS,DATASETS,MOUNTS,NCPU,ONJAILS,ONVMS,PCICONF,PERSISTSNAPS,ROOTSNAPS,RT_IPS,RT_EPAIRS,SNAPSHOTS,SYSMEM"

# zfs props relevant to qubsd operations. Used in `zfs list` queries
# DO NOT REORDER. Append only for new zfsprops, because awk uses this column ordering for parsing
# zfsprop creation takes up 5 cols ($3-$7)
export DSET_PROPS="name,mountpoint,mounted,origin,encryption"
export SNAP_PROPS="name,written,creation,qb:ttl,clones"

#########################################   OLD  SYSTEM  CONSTANTS / OVERRIDES  ##########################################

# Function tracing. Used with `eval` to track logic flow for exception messages
# Temporary Overrides and error definitions for overhaul/migration. Will be deleted later

export JCONF="$QETC/jail.conf.d/jails"
export QCONF="$QETC/qubsd.conf"
export QLOG="/var/log/qubsd/quBSD.log"
export VMTAPS="$QRUN/vm_taps"

export _R0='_FN="$_fn_orig" ; return 0'
export _R1='_FN="$_fn_orig" ; return 1'



