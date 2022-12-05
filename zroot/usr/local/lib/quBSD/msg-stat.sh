#!/bin/sh

usage() { cat << ENDOFUSAGE 

qb-stat: List status of all jails 

Usage: qb-stat [-c <column>] [-h]

   -c: (c)olumn to sort by
   -h: (h)elp: Outputs this help message

ENDOFUSAGE
}

