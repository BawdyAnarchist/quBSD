# GLOBAL VARIABLES FOR LIBRARIES AND SCRIPTS

# Primary directories
export QETC="/usr/local/etc/qubsd"
export QLIB="/usr/local/lib/qubsd"
export QLEXEC="/usr/local/libexec/qubsd"
export QSHARE="/usr/local/share/qubsd"
export QRUN="/var/run/qubsd"

# Supporting directories and files
export QUBSD="$QLIB/qubsd.sh"
export B_DEF="$QETC/qubsd.conf.d/defaults.base.conf"
export J_DEF="$QETC/qubsd.conf.d/defaults.jail.conf"
export V_DEF="$QETC/qubsd.conf.d/defaults.vm.conf"
export CELLS="$QETC/qubsd.conf.d/cells"
export JCONF="$QETC/jail.conf.d/jails"
export QLOG="/var/log/qubsd/quBSD.log"
export VMTAPS="$QRUN/vm_taps"

# Function tracing. Used with `eval` to track logic flow for exception messages 
_R0='_FN="$_fn_orig" ; return 0'
_R1='_FN="$_fn_orig" ; return 1'
