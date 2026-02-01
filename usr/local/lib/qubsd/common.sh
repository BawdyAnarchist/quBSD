#!/bin/sh

## SINGLE SOURCE FOR LIBRARY MODULARITY 

. /usr/local/lib/qubsd/constants.sh  # Bootstrap global constants
. $QLIB/messages/lib_common.sh       # qubsd library messages

# Library Components
. $QLIB/exception.sh
. $QLIB/query.sh
. $QLIB/validate.sh 
. $QLIB/network.sh 
. $QLIB/lifecycle.sh 
. $QLIB/vm.sh 

# Output Redirects
quiet() { "$@" > /dev/null 2>&1 ; }     # Pure silence
hush() { "$@" 2 > /dev/null ; }         # Hush errors
verbose() { echo ">> $*" >&2; "$@" ; }  # Debug tool
