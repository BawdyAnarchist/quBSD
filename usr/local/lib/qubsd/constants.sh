#!/bin/sh

## GLOBAL VARIABLES FOR LIBRARIES AND SCRIPTS ##

# Primary directories
export QETC="/usr/local/etc/qubsd"
export QLIB="/usr/local/lib/qubsd"
export QLEXEC="/usr/local/libexec/qubsd"
export QSHARE="/usr/local/share/qubsd"
export QRUN="/var/run/qubsd"

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
export ERR="$D_QERR/$BASENAME.$$.err"
export TRAP="rm -f $ERR"
export TRAP_SIGS="HUP INT TERM QUIT EXIT"
export BASENAME="$(basename $0)"
export DEBUG="/root/debug"
: ${VERBOSE:=}     # [true|false] Print commands to console before running them
: ${DRY_RUN:=}     # [true|false] Do not execute, just print commands to the console
: ${TRACE:=true}   # [true|false] Show the function trace in error/warning messages

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

# Runtime invariant lists
export PARAMS_BASE="AUTOSTART AUTOSNAP BACKUP CLASS CONTROL ENVSYNC GATEWAY IPV4 MTU NO_DESTROY P_ZFS R_ZFS ROOTENV TEMPLATE"
export PARAMS_JAIL="CPUSET MAXMEM SCHG SECLVL"
export PARAMS_VM="BHYVEOPTS BHYVE_CUSTM MEMSIZE PPT TAPS TMUX VCPUS VNC WIREMEM"
export PARAMS_ALL="$PARAMS_BASE $PARAMS_JAIL $PARAMS_VM"
export CONTEXT="CALLER JCONF QCONF P_DSET P_MNT R_DSET R_MNT RT_CTX"   # Convenient context paths
export CLASSES="rootjail appjail dispjail rootVM appVM dispVM cjail"

# Query results storage for rapid stacked/looped information retreival
export QUERY="CELLS CELLS_QPATHS DATASETS MOUNTS NCPU ONJAILS ONVMS PCICONF ROOTSNAPS PERSISTSNAPS SYSMEM"


#########################################   OLD  SYSTEM  CONSTANTS / OVERRIDES  ##########################################

# Function tracing. Used with `eval` to track logic flow for exception messages
# Temporary Overrides and error definitions for overhaul/migration. Will be deleted later

export JCONF="$QETC/jail.conf.d/jails"
export QCONF="$QETC/qubsd.conf"
export QLOG="/var/log/qubsd/quBSD.log"
export VMTAPS="$QRUN/vm_taps"

export _R0='_FN="$_fn_orig" ; return 0'
export _R1='_FN="$_fn_orig" ; return 1'



