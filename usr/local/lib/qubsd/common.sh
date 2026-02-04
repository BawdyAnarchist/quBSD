#!/bin/sh

## SINGLE SOURCE FOR LIBRARY MODULARITY 

. /usr/local/lib/qubsd/constants.sh  # Bootstrap global constants
. $QLIB/messages/lib_common.sh       # qubsd library messages

# Library Components
. $QLIB/exception.sh
. $QLIB/query.sh
. $QLIB/check.sh 
. $QLIB/validate.sh 
. $QLIB/compose.sh 
. $QLIB/network.sh 
. $QLIB/lifecycle.sh 
. $QLIB/bhyve.sh 

# Verify Environment
[ -d "$D_CELLS" ] || mkdir -p $D_CELLS
[ -d "$D_JAILS" ] || mkdir -p $D_JAILS
[ -d "$D_QERR" ] || mkdir -p $D_QERR
[ -d "$D_QX11" ] || mkdir -p $D_QX11
[ -d "$D_XFER" ] || mkdir -p $D_XFER
