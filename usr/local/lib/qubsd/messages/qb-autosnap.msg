
:parse_args:
Must provide a command. [-d] and/or [-s]
/END/

:parse_args_2:
Invalid [-s <time-to-live>]. Must include a TTL for autosnaps
/END/

::
There was a problem when attempting to replace an old $U_ZFS clone.
dataset: < $_clone > ; origin: < $_origin >
/END/

:w:usage:
qb-autosnap:  Tool for automated cell dataset snapshots/thinning
Usage:  qb-autosnap [-d][-s <integer><m|H|D|W|M>]

   -d:  (d)estroy snapshots older than their zfsprop 'qb:ttl'
   -s:  (s)napshot all cell datasets with AUTOSNAP=true
        Must provide TTL. For example:  120m | 48H | 30D
        Custom zfsprop 'qb:ttl' is added to the snapshot

Integrate this command into /etc/cron.d/qubsd_cron
/END/
