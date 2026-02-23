#!/bin/sh

## SINGLE SOURCE FOR LIBRARY MODULARITY
. /usr/local/lib/qubsd/constants.sh  # Bootstrap global constants

# Library Components
. $QLIB/exception.sh
. $QLIB/context.sh
. $QLIB/query.sh
. $QLIB/assert.sh
. $QLIB/validate.sh
. $QLIB/compose.sh
. $QLIB/network.sh
. $QLIB/lifecycle.sh
. $QLIB/bhyve.sh

# Verify Environment
[ -d "$D_CELLS" ] || mkdir -p $D_CELLS
[ -d "$D_JAILS" ] || mkdir -p $D_JAILS
[ -d "$D_QRUN" ] || mkdir -p $D_RUNTM
[ -d "$D_QERR" ] || mkdir -p $D_QERR
[ -d "$D_QX11" ] || mkdir -p $D_QX11
[ -d "$D_XFER" ] || mkdir -p $D_XFER


# CURRENT (OLD) SYSTEM LIBRARIES TO EVENTUALLY BE REMOVED
. $QLIB/qubsd_dump.sh   # Re-aggregation of old functions for cleaner view of new system
. $QLIB/messages/lib_common.sh       # old qubsd library message script
