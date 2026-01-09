#!/bin/sh

get_os() {
   if grep -qsi 'freebsd' /etc/os-release ; then
      echo 'freebsd'
   elif grep -qsi 'linux' /etc/os-release ; then
      echo 'linux'
   elif grep -qsi 'openbsd' /etc/os-release ; then
      echo 'openbsd'
   elif grep -qsi 'netbsd' /etc/os-release ; then
      echo 'netbsd'
   fi
}


main() {
   _DIR="/mnt/rootstrap/"
   _OS=get_os;

   case "$_OS" in
      freebsd) exec sh ${_DIR}/freebsd/rootstrap-freebsd.sh $_DIR
         ;;
      linux)   exec sh ${_DIR}/linux/rootstrap-linux.sh $_DIR
         ;;
      openbsd) # placeholder
         ;;
      netbsd)  # placeholder
         ;;
   esac
}

main
