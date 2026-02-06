
:chk_args_set:
Argument missing or blank
/END/

:_invalid:
Invalid %s < %s >
/END/

:_invalid2:
Invalid %s < %s >. %s
/END/

:chk_bool_tf:
Boolean string required: [true|false]
/END/

:chk_integer:
Invalid input: < %s >. Integer required.
/END/

:chk_bhyveopts1:
%s < %s > contains an invalid option. Permissible: <AaCDeHhPSuWwxY>.
/END/

:chk_bhyveopts2:
%s < %s > contains a duplicate character.
/END/

:chk_ipv4:
%s < %s > is not in CIDR 
Use CIDR notation for IPV4 addresses. Or <auto|none>.
/END/

:compare_integer:
%s %s %s
/END/

:internal:
Internal bug: Invalid getopts option
/END/

:chk_cellname:
Invalid cellname < %s >. Must start/end with alpha-numeric.
May contain '-' or '_', but not consecutively.
/END/



ERROR: There is no $1 PARAMETER in QCONF. Expecting a valid ZFS dataset.
       This is a global error, as quBSD can't function without this PARAMETER.
	_e0_2) cat << ENDOFMSG
ERROR: QCONF PARAMETER $1 is set to: < $2 >, which isnt a valid zfs dataset.
       This is a global error, as quBSD can't function without this PARAMETER.
	_e0_3) cat << ENDOFMSG
ERROR: ZFS dataset < $1 > does not have a valid mountpoint.
       This is a global error, as quBSD can't function without this mountpoint.
	_e1) cat << ENDOFMSG
   < $1 > is an invalid $2
	_e2) cat << ENDOFMSG
   < $1 > has no $2 in QCONF
	_e3) cat << ENDOFMSG
   < $1 > has an invalid $2 in QCONF
	_e4) cat << ENDOFMSG
   ${0##*/} Failed to start < $1 >
	_e4_1) cat << ENDOFMSG
   Failed to detect a VM process for < $1 > within 3 sec of launch.
	_e4_2) cat << ENDOFMSG
   Can't configure network for < $1 >. Timeout, waiting for VM to launch.
   Sometimes a passthru device can delay/hang a launch if it's not responsive.
   If this VM has a PPT device (like a USB), consider rebooting.
	_e5) cat << ENDOFMSG
   < $1 > has no ZFS dataset at: < $2 >
	_e6_1) cat << ENDOFMSG
   < $1 > is a dispjail. Can't have another dispjail as its TEMPLATE
	_e6_2) cat << ENDOFMSG
   < $1 > has an invalide TEMPLATE: < $2 >
	_e7) cat << ENDOFMSG
   < $1 > is missing from $JCONF
	_e8) cat << ENDOFMSG
   < $1 > is a ROOTENV. For security, it should never be a GATEWAY.
	_e9) cat << ENDOFMSG
   quBSD.sh function: $_fn() received an invalid option. Possibly a bug.
	_e10) cat << ENDOFMSG
   < $1 > Must be true|false
	_e11) cat << ENDOFMSG
   < $1 > is not an integer
	_e12) cat << ENDOFMSG
   $1 < $2 > is not $3 $4
	_e13) cat << ENDOFMSG
   Proposed jailname < $1 > is disallowed.
	_e13_1) cat << ENDOFMSG
   Proposed names must start and end with alpha-numeric.
   It may contain non-consecutive \`-' or \`_'
   (dash or underscore), but no other special characters.
	_e13_2) cat << ENDOFMSG
   JAILNAME < $1 > has an entry in at least one of the following:
   $JCONF, $QCONF , $U_ZFS, or $R_ZFS
   Destroy/remove all occurrences with:  qb-destroy $1
	_e16) cat << ENDOFMSG
   Only comma separated intergers, range, or combo of both. man 1 cpuset
	_e16_1) cat << ENDOFMSG
   < $1 > is not among the list of valid cores. Highest core is < $2 >
	_e17) cat << ENDOFMSG
   Must have the form: <name>=<rulenum>, and be present in devfs.rules
	_e19) cat << ENDOFMSG
   Must be <integer><G|g|M|m|K|k>. See man 8 rctl
	_e20) cat << ENDOFMSG
   < $1 > exceeds host's available RAM: ${2}b
	_e21) cat << ENDOFMSG
   < none > is not permitted for VM memsize
	_e22) cat << ENDOFMSG
   Failed to attach PCI device < $1 > to VM < $2 >
	_e22_0) cat << ENDOFMSG
   PCI device < $1 > doesn't exist on the host machine.
	_e22_1) cat << ENDOFMSG
   Cant access PCI < $1 >. Is it attached to another VM or in use?
   Some PCI devices arent dynamic, and must be designated PPT at boottime.
	_e22_2) cat << ENDOFMSG
   Unable to change < $1 > to PPT.
	_e22_3) cat << ENDOFMSG
	Failed to attach PCI device < $1 > with devctl.
	_e23) cat << ENDOFMSG
   < $1 > is an invalid CLASS for a ROOTENV.
	_e24) cat << ENDOFMSG
   < $1 > is an invalid SECLVL. Must be: <-1|0|1|2|3>
	_e25) cat << ENDOFMSG
   < $1 > is an invalid SCHG. Must be: <none|sys|all>
	_e26) cat << ENDOFMSG
   < $1 > must be less-than the number of CPUs cores on
   the host ($2), and less than bhyve limit of 16.
	_e27) cat << ENDOFMSG
   Invalid VNC. Must be: <true|false|640x480|800x600|1024x768|1920x1080>
   (A value of 'true' will default to a resolution of 1920x1080)
	_e28) cat << ENDOFMSG
   Couldnt connect client < $1 > to gateway < $2 >
   because the gateway was off. 
	_e29) cat << ENDOFMSG
	_e30) cat << ENDOFMSG
   Couldn't find open IP for < $1 > in the range: < $2 >
	_e31) cat << ENDOFMSG
   No jails to start. Please specify [-a|-A|-f <file>],
   or < jail list > at the end of the command.
	_e31_1) cat << ENDOFMSG
   [-e] can only be used with [-a|-A|-f <file>], because
   the positional params are assumed to be jail starts.
	_e31_2) cat << ENDOFMSG
   The file < $_SOURCE > doesn't exist.
	_e31_3) cat << ENDOFMSG
   [-e] requires a < jail list > as positional parameters.
	_e31_4) cat << ENDOFMSG
   The file < $_EXFILE > doesn't exist.
	_e31_5) cat << ENDOFMSG
   $0 did not find any jails to ${0##*qb-}
	_e32) cat << ENDOFMSG
   < $1 > is not a clone (has no zfs origin).
   Likely is a ROOTENV.
	_e32_1) cat << ENDOFMSG
   < $1 > needs a ROOTENV clone. However, its
   ROOTENV < $2 > has no existing snapshots,
   and is curently running. Running ROOTENVs should
   not be snapshot/cloned until turned off.
	_e33) cat << ENDOFMSG
   ${2##*bin/} failed to ${2##*qb-} all jails/VMs
   within the allotted timeout of < $2 secs >.
	_e34) cat << ENDOFMSG
   Control jail < $_gateway > should only ever have IPV4 < auto > or < dhcp >
	_e35) cat << ENDOFMSG
   Cannot reclone zusr, because < $1 > is currently running.
	_w1) cat << ENDOFMSG
WARNING: < $1 > had to be forcibly stopped. Recommend double
   checking mounts with: mount | grep $1
   For details see log at: $QLOG
	_w2) cat << ENDOFMSG
WARNING: < $1 > could not be stopped. Forcible stop failed.
Recommend running the following commands:
   jail -R $1
   mount | grep $1
   For details see log at: $QLOG
	_w3) cat << ENDOFMSG
WARNING: < $2 > is a gateway for external traffic. Setting
   IP to < $1 > will prevent traffic to outside internet.
	_w4) cat << ENDOFMSG
WARNING: < $1 > Is already in use. Not fatal, but you
   must ensure jail/gateway/IP deconfliction. Recommend <auto>.
	_w5) cat << ENDOFMSG
WARNING: Was unable to revert PPT: < $1 > to host after VM stop.
	_w6) cat << ENDOFMSG
WARNING: Unable to ping freebsd.org. Automated rootVM installation
   requires network for update and pkg installation. 
echo -e "Continue anyways (you must manually install updates/pkgs afterwards) (Y/n): \c"
	_m1) cat << ENDOFMSG
${0##*/} is starting < $1 >
	_m2) cat << ENDOFMSG
${0##*/} is stopping < $1 >
	_m3) cat << ENDOFMSG
EXITED $0
	_m4) cat << ENDOFMSG
Waiting for < $1 > to stop. Timeout in < $2 seconds >
	_m5) cat << ENDOFMSG
ALERT: Another instance of qb-start or qb-stop is running.
   Will wait for < $1 secs > before aborting.
	_m6) cat << ENDOFMSG
ALERT: < $2 > is a gateway,
   pass external traffic for client jails. Setting IP
   to < $1 > will prevent < $2 > and its
   clients from reaching the outside internet.
	_m7) cat << ENDOFMSG
ALERT: Assigning IP to < $2 > which has no gateway.
	_m9) cat << ENDOFMSG
ALERT: < $1 > diverges from quBSD convention.
       See table below for typical assignments.
JAIL              GATEWAY        IPv4 Range
net-firewall      nicvm          External Router Dependent
net-<gateway>     net-firewall   10.255.x.2/30
serv-jails        net-firewall   10.128.x.2/30
appjails          net-<gateway>  10.1.x.2/30
cjails            none           10.99.x.2/30
< adhoc created by qb-connect >  10.88.x.2/30
	_m10) cat << ENDOFMSG
ALERT: Checking for network connection, ping timeout in $1 sec 
	_m11) cat << ENDOFMSG

< $1 > was successfully created, and can be used as a rootVM for other appVMs.

	_m12) cat << ENDOFMSG

< $1 > was successfully created, but there was no network connectivity.
   Therefore the user must update and install packages in the VM, manually.

	esac
}
