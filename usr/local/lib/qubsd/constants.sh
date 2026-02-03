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
export D_QERR="$QRUN/err"
export D_QX11="$QRUN/X11"
export D_XFER="$QRUN/xfer"

# Relative system directories
export REL_ULOC="/usr/local"
export REL_LBIN="$REL_ULOC/bin"
export REL_LETC="$REL_ULOC/etc"
export REL_LLIB="$REL_ULOC/lib"
export REL_LLEX="$REL_ULOC/libexec"
export REL_LRCD="$REL_LETC/rc.d"
export REL_LX11="$REL_LETC/X11"
export REL_UNBOUND="/var/unbound"

# Primary qubsd files
export QCOMMON="$QLIB/common.sh"
export DEF_BASE="$D_QCONF/defaults.base.conf"
export DEF_JAIL="$D_QCONF/defaults.jail.conf"
export DEF_VM="$D_QCONF/defaults.vm.conf"

# Temporary Overrides for overhaul/migration. Will be deleted later
export JCONF="$QETC/jail.conf.d/jails"
export QCONF="$QETC/qubsd.conf"
export QLOG="/var/log/qubsd/quBSD.log"
export VMTAPS="$QRUN/vm_taps"

# Function tracing begins with the main script
export BASENAME=$(basename $0)
export ERR="$D_QERR/$BASENAME.$$.err"
export TRAP_SIGS="HUP INT TERM QUIT EXIT"

# Runtime invariant lists
export PARAMS_COMN="AUTOSTART AUTOSNAP BACKUP CLASS CONTROL ENVSYNC
                    GATEWAY IPV4 MTU NO_DESTROY ROOTENV TEMPLATE R_ZFS U_ZFS"
export PARAMS_JAIL="CPUSET MAXMEM SCHG SECLVL"
export PARAMS_VM="BHYVEOPTS BHYVE_CUSTM MEMSIZE PPT TAPS TMUX VCPUS VNC WIREMEM X11"
export CLASSES="rootjail appjail dispjail rootVM appVM dispVM"

# Function tracing. Used with `eval` to track logic flow for exception messages 
# TEMPORARY: will be removed after overhaul
export _R0='_FN="$_fn_orig" ; return 0'
export _R1='_FN="$_fn_orig" ; return 1'
