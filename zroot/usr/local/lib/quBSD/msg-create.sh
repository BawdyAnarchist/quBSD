#!/bin/sh

get_msg_create() {

	local _message="$1"
	local _pass_cmd="$2"
	local _passvar="$3"

	case "$_message" in

	_e0) cat << ENDOFMSG

ERROR: < $_param > is not a valid quBSD PARAMETER.
ENDOFMSG
	;;
	_e1) cat <<ENDOFMSG

ERROR: There was a problem when trying to assign < $_passvar >
ENDOFMSG
	;;
	_e2) cat << ENDOFMSG

ERROR: Cant mix jail/VM between vital PARAMETERS and/or options:
       [-c] CLASS < $CLASS > was assigned to < $NEWJAIL >
       [-R] ROOTENV < $ROOTENV > has CLASS < $root_cl >
ENDOFMSG
[ ! "$TEMPLATE" = "none" ] \
	&& echo "       [-t] TEMPLATE < $TEMPLATE > has CLASS < $temp_cl >"
	;;
	_e3) cat << ENDOFMSG
ENDOFMSG
	;;
	_e4) cat << ENDOFMSG

ERROR: < $_VAL > was an invalid value for < $_PAR >
ENDOFMSG
	;;
	_e5) cat << ENDOFMSG

ERROR: For jail, [-z] must be one of: <dupl|dirs|empty>
       For VM, [-z] must be one of: <dupl|empty>
ENDOFMSG
	;;
	_e5_1) cat << ENDOFMSG

ERROR: Invalid format for [-z]. For VM, it can either be <dupl>,
       or <integer><K|M|G|T>, for a zfs block device.
ENDOFMSG
	;;
	_e5_2) cat << ENDOFMSG

ERROR: A zfs block device must be greater than 80M
ENDOFMSG
	;;
	_e5_3) cat << ENDOFMSG

ERROR: Specified size < $U_ZOPT > for new zfs block device,
       is greater than available < $U_ZFS > space: < $(zfs list -Ho available $U_ZFS) >
ENDOFMSG
	;;
	_e5_4) cat << ENDOFMSG

ERROR: [-z empty] for a new VM ${U_ZFS} block device,
       must specify [-v <volsize>].
ENDOFMSG
	;;
	_e6) cat << ENDOFMSG

ERROR: When creating a jail of class:  [-c $CLASS],
       it must be accompanied with option [-t <template>].
ENDOFMSG
	;;
	_e7) cat << ENDOFMSG

ERROR: [-Z] not valid when creating <appjail/VM|dispjail>. Their
       ROOTENV filesystem is always cloned at start/stop, from a
       limited set of on-disk ROOTENVs, as a security measure.

       It would imply a clone of a clone, making <newjail>
       ephemeral, destroyed at <template> stop or start.

       Either create a new on-disk ROOTENV to serve appjails:
          qb-create [-c rootjail/VM] [-Z] [-t ${TEMPLATE}] $NEWJAIL
	    OR
       Create an ephemeral jail with qb-disp.
          qb-disp $TEMPLATE
ENDOFMSG
	;;

## [-i] INSTALLATION MESSAGES
	_e8) cat << ENDOFMSG

ERROR: The only CLASS allowable with [-i] is < rootVM >
ENDOFMSG
	;;
	_e8_1) cat << ENDOFMSG

ERROR: [-i] implies < $NEWJAIL > will be the ROOTENV. Thus [-r]
       is redundant, but at least it should equal < $NEWJAIL >
ENDOFMSG
	;;
	_e8_2) cat << ENDOFMSG

ERROR: [-i] requires [-v <volsize>] for the new rootVM volume.
ENDOFMSG
	;;
	_e8_3) cat << ENDOFMSG

ERROR: [-i < $INSTALL >] Must specify the ISO to be installed,
       but there is currently no file at that path.
ENDOFMSG
	;;
	_e8_4) cat << ENDOFMSG

ERROR: [-i] zfs already exists at < ${R_ZFS}/${NEWJAIL} >. For safety
       reasons, qb-create will not overwrite existing volumes.
       To use this location run qb-destroy, to eliminate
       possible conflicts with what might be another jail/VM.
ENDOFMSG
	;;
	_e9) cat << ENDOFMSG

ERROR: Conflicting opts. Creating dispjail with [-t $TEMPLATE]
       which is a ROOTENV. However, user also specified
       [-R $ROOTENV], which is in conflict with the template.
ENDOFMSG
	;;
	_e10) cat << ENDOFMSG

ERROR: User specified [-c rootjail/VM] which will create a new
       ondisk ROOTENV from [-t ${TEMPLATE}] which isn't a
       ROOTENV. It's an edge usecase operation that creates a
       full, ondisk duplicate from a snapshot of the clone:
       ${R_ZFS}/${TEMPLATE}

       Please run command again with [-Z] option, to confirm.
ENDOFMSG
	;;
	_e11) cat << ENDOFMSG

ERROR: The ROOTENV dataset for < $NEWJAIL > is invalid:
       $R_ZPARENT
ENDOFMSG
	;;
	_w0) cat << ENDOFMSG

FINAL CONFIRMATION FOR < $NEWJAIL >
ENDOFMSG
	;;
	_w1) cat << ENDOFMSG
New ROOTENV will consume:  $(zfs list -Ho used "${R_ORIGIN}")
Duplicated from dataset:   ${R_ZPARENT}
ENDOFMSG
	;;
	_w1_1) cat << ENDOFMSG
New disk space consumed:  $(zfs list -Ho used "${U_ZPARENT}")
Duplicated from dataset:  ${U_ZPARENT}
ENDOFMSG
	;;
	_w1_2) cat << ENDOFMSG
New disk space consumed:  $VOLSIZE
New block storage device: ${U_ZFS}/${NEWJAIL}
ENDOFMSG
	;;
	_w1_3) cat << ENDOFMSG
Creating $CLASS from:  ${U_ZFS}/${NEWJAIL}
ENDOFMSG
	;;
	_w1_4) cat << ENDOFMSG
New rootVM will consume: $VOLSIZE
Installed to new dataset: ${R_ZPARENT}
ENDOFMSG
	;;
	_w1_5) cat << ENDOFMSG
${U_ZFS}/${NEWJAIL} WILL BE ENCRYPTED (password input later)
ENDOFMSG
	;;
	_w2) cat << ENDOFMSG
ALERT: ${U_ZFS}/${NEWJAIL} will be unmounted and locked for
       security. If you need access, either start
       the jail/VM, or manually unlock and mount it.
ENDOFMSG
	;;
	_w3) cat << ENDOFMSG

UNIQUE PARAMETERS TO BE ADDED:
$(cat "$_TMP_PARAMS" | column -t | sort | grep -E "^$NEWJAIL" \
	| grep -Ev "BHYVE_CUSTM[[:blank:]]+-s[[:blank:]]+#,ahci-cd,${INSTALL}")

PARAMETERS EQUAL TO DEFAULTS:
$(cat "$_TMP_PARAMS" | column -t | sort | grep -E "^#default")

ENDOFMSG
	;;
	_w4) cat << ENDOFMSG
WARNING: User has specified neither vncviewer nor tmux for this
         install. VM will launch, but there will be no interface.
ENDOFMSG
;;
	_w5)
echo -e "     PROCEED? (Y/n): \c"
;;
	_w6) cat << ENDOFMSG
ALERT: No template was specified or found for the new appjail.
       Creating an empty $U_ZFS dataset for < $NEWJAIL >
ENDOFMSG
	;;
	_w7) cat << ENDOFMSG
ALERT: No valid template was specified or found for the new VM.
       Creating empty and unformatted $VOLSIZE $U_ZFS block device
       for < $NEWJAIL >, which will be attached to VM at boot;
       but the VM will not have custom script to execute at start.
ENDOFMSG
	;;

	_m0) cat << ENDOFMSG

########################  GUIDED  MODE  #########################

User will be presented with a series of informative messages
and input prompts, which explain the main options/parameters,
and minimal description of how quBSD functions.

Only the basic usage is presented. Additional usage/options
combinations can be leveraged at the command line.

ctrl-c will exit the script at any point.
{ENTER} to continue ...

#################################################################
ENDOFMSG
	;;

	_m1) cat << ENDOFMSG

[-c <class>]

quBSD classes:  rootjail | cjail | appjail | dispjail | appVM | rootVM

   rootjail - Contains a full FreeBSD installation and pkgs.
              These are pristine root environments which serve
              zfs clones to dependent jails. No workstation
              activity or command execution should ever take
              place here, except updates and pkg installation.

   cjail   -  Control Jail connects via SSH to all jails/VMs.
              Default is 0control, but this can be changed
              with the CONTROL parameter in qmap.

   appjail -  These are the actual workstation jails. The root
              filesystem is cloned from a designated rootjail,
              every time the appjail is started or stopped.
              Persistent unprivileged user storage lives on a
              separate zfs dataset called 'zusr'.

   dispjail - Disposable. They have no persistent data of their
              own, and thus, need an existing jail to act as a
              "template," which is cloned for the dispjail at
              start (including zusr), destroyed when stopped.

              Use for insecure activities like random surfing
              and untrusted files. quBSD pre-installs the jail:
              disp1, which is based on template: 0gui-template.

   appVM    - Like an appjail, an appVM is launch from a zfs
              clone of a designated rootVM. Persistent storage
              is accomplished via corresponding zusr dataset.

   rootVM   - Like rootjail, a rootVM is a full VM installation,
              which serves ROOTENV zfs clones to dependent VMs.
              No workstation activity or program execution should
              take place here, except updates and pkg installs.

ENDOFMSG
	;;

	_m2) cat << ENDOFMSG

[-R <rootenv>]

quBSD comes with the following rootjails pre-installed:

   0base - A plain FreeBSD installation with no pkgs installed.

   0net  - A nearly plain installation, but with wireguard-go
           and jq. Use this for gateways like a VPN.

   0gui  - Comes with Xorg, and your graphics card should've
           been auto-detected and installed. This is where you
           would install other graphical pkgs, like a browser,
           office suite, and media programs.

   0serv - Apache24, php81, Syncthing, Nextcloud, and mariadb

ENDOFMSG
	;;

	_m3) cat << ENDOFMSG
While qb-create doesn't support bootstrapping new rootjails,
[use \`bsdinstall\` for that], any existing rootjail can be
duplicated on disk (zfs send). That could be any of the above,
or another rootjail that you already created.

ENDOFMSG
	;;

	_m4) cat << ENDOFMSG
The above are simply the quBSD pre-installed rootjails. Any
others you might've installed/created, could also be used here.

ENDOFMSG
	;;

	_m5) cat << ENDOFMSG

[-t <template>]

At the command line, a new ROOTENV requires a template,
to prevent accidental creation of an ondisk ROOTENV. Here
we'll assume you want to use < $ROOTENV > as the template.

Here are the qubsdmap.conf settings for:  $ROOTENV
ENDOFMSG
		qb-list -j $ROOTENV

cat << ENDOFMSG
WOULD YOU LIKE TO:
   1. Use this as the template and create a new jail
   2. Use this as the template for zroot operations, but
      see info and input prompts to change each parameter

ENDOFMSG
	;;
	_m6) cat << ENDOFMSG

[-t <template>]

A TEMPLATE ACCOMPLISHES TWO DISTINCT FUNCITONS
1. Jail Parameters are copied from the template to new jail.
2. Its zusr dataset is duplicated on disk (default behavior),
   or use [-z] to copy only its directory structure (no files).

IF NO TEMPLATE IS SPECIFIED
1. "#default" Jail Parameters in qubsdmap.conf are used.
2. The zusr template associated with the ROOTENV, is duplicated.
   (These have baseline files associated with their purpose).
   0base-template, 0net-template, 0gui-template, 0serv-template
   If no ROOTENV-template is found, an empty zusr is created.

Command line parameters override template parameters, and zero
or more CL params can be used in combination with the template.

Use qb-edit to change #default. Current #default parameters:
ENDOFMSG
		qb-list -j '#default' | grep -Ev "[[:blank:]]+ROOTENV[[:blank:]]+" \
								  	 | grep -Ev "[[:blank:]]+CLASS[[:blank:]]+" \
								  	 | grep -Ev "[[:blank:]]+TEMPLATE[[:blank:]]+"
cat << ENDOFMSG
WOULD YOU LIKE TO:
   1. Use ${ROOTENV}-template for zusr dataset operations,
      and the above #default parameter values
   2. Use this template for zusr dataset operations, but
      see info and input prompts to change each parameter
   3. Select a different <template>

ENDOFMSG
	;;

	_m7) cat << ENDOFMSG

[-t <template>]

Dispjails require a template. You selected ROOT=${ROOTENV},
so it'd make sense to choose a template with the same ROOTENV.
If not, it will still launch, but might not have the expected
functionality/packages to match zusr files of the template.

Any valid jail can be used as a template. If a ROOTENV is used,
then no zusr dataset will be created. If an existing dispjail is
used as the template for a new dispjail, the new jail will use
the same template as the existing dispjail.

ENDOFMSG
	;;

	_m9) cat << ENDOFMSG

Here's the settings from $TEMPLATE to be used for the new jail:
ENDOFMSG
		qb-list -j $TEMPLATE | grep -Ev "[[:blank:]]+ROOTENV[[:blank:]]+" \
									| grep -Ev "[[:blank:]]+CLASS[[:blank:]]+"
cat << ENDOFMSG
WOULD YOU LIKE TO:
   1. Use this template and these parmeters for the new jail
   2. Use this template for zusr dataset operations, but
      see info and input prompts to change each parameter
   3. Select a different template

ENDOFMSG
	;;

	_m11) cat << ENDOFMSG

AUTOSTART
[-a <true|false>]

Starts the jail when the system boots. Make sure that
qb_autostart="YES" is set in rc.conf.

ENDOFMSG
	;;
	_m12) cat <<ENDOFMSG

AUTOSNAP
[-A <true|false>]

Sets the zfs custom property "qubsd:autosnap=true", for the
jail's dataset. Used in combination with qb-autosnap and
/etc/crontab , for periodic / rolling snapshots of the jail.
See:  qb-autosnap -h for more info.

ENDOFMSG
	;;
	_m13) cat <<ENDOFMSG

CPUSET
[-c <cpuset>]

Limitations can be placed on the CPUs a jail has access to.
By default, 'none' means that no restrictions will be placed.
Listing CPU number(s), will limit the jail to only those CPUs.
Comma separated for invidual CPUs, or dash-separated to
indicate a range. See man 1 cpuset for more info.

For reference, here are the CPUs numbers on this machine:
ENDOFMSG
cpuset -g | sed "s/pid -1 mask: //" | sed "s/pid -1 domain.*//"
	;;
	_m14) cat <<ENDOFMSG

GATEWAY
[-g <jail>]

The network interface card is isolated inside a VM (nicvm),
and can only be accessed through a gateway jail called
"net-firewall", which uses pf for firewall implementation.

For immediate network access, jails can be connected to
net-firewall. You can also string multiple gateway jails in
series, for well isolated, fail-closed tunnel connections
(VPN, Tor, etc). Enter "none" to keep the jail offline.

ENDOFMSG
	;;
	_m15) cat <<ENDOFMSG

IPV4
[-i <IPv4 address>]

quBSD manages IP addresses automatically. It's recommended
to enter "auto" for most/all jails for the IPV4 parameter.
However, you can enter a persistent address for any jail.
It must be in CIDR notation.

'none' is also a valid entry, for an offline jail.

Additionally, quBSD has an IP numbering scheme for jails
of differing purposes. While it's not an error, an alert
will show, if user-selected IP falls outside the convention.
IP assignment conventions are as follows:

JAIL              GATEWAY          Jails' IPv4 Range
net-firewall      nicvm            Router Dependent
net-<gateway>     net-firewall     10.255.x.2/30
serv-jails        net-firewall     10.128.x.2/30
appjails          net-<gateway>    10.1.x.2/30
cjails            none             10.99.x.2/30
usbvm             variable         10.88.88.1/30
< adhoc created with qb-connect >  10.99.x.2/30

ENDOFMSG
	;;
	_m16) cat <<ENDOFMSG

MAXMEM
[-m <maxmem>]

Place a limitation on the jail's RAM usage. 'none' means no
restrictions. Valid input format:  <integer><G|M|K>  For
example, 4G is the same as 4000k. See man 1 rctl for details.

ENDOFMSG
	;;
	_m17) cat <<ENDOFMSG

MTU
[-M <MTU>]

Mean Transmission Unit for jail's network interface.
Unless you have a compelling reason to change it, keep
this at the system #default of 1500. Must be an integer.

ENDOFMSG
	;;
	_m18) cat <<ENDOFMSG

NO_DESTROY
[-n <true|false>]

This flag prevents accidental destruction of a jail, because
once the dataset is gone, there's no getting it back. If you
care about the jail recommend setting this to true.

ENDOFMSG
	;;
	_m19) cat <<ENDOFMSG

SECLVL (secure level)
[-s <-1|0|1|2|3>]

This sets sysctl kern.securelevel inside the jail, immediately
after launch. Value of 1 or higher, makes it impossible to
remove schg flag from any file (including root user), making
file modification impossible. See: man 7 security for details.

ENDOFMSG
	;;
	_m20) cat << ENDOFMSG

SCHG
[-s <none|sys|all>]

Implements schg flag for selected jail files, which, in combo
with SECLVL 1 or higher, can prevent intruders from modifying
files and gaining a permanent hold inside the jail.

   none - No schg flags are applied after jail launch.

   sys  - schg is applied recursively to directories such as:
          /bin /sbin /boot /etc /lib /libexec /root /usr/bin
          /usr/lib /usr/libexec /usr/sbin /usr/local/bin
          ... and other select /usr files.

          However, /home , /usr/etc/ , and any directories
          inside of /zusr/<jail>/usr/ , are skipped.

   all  - All directories and files, including those in /usr,
          receive schg flag.

ENDOFMSG
	;;
	_examples) cat << ENDOFMSG

QUICK and EASY USAGE
From qmap #defaut:  qb-create <newjail/VM>
From Template:      qb-create -t <template> <newjail/VM>
Specific PARAMS:    qb-create -t <template> -p GATEWAY=<gateway> -p CPUSET=<size> <newjail/VM>
Basic GUI jail:     qb-create -t 0gui-template <newjail>
Dispjail:           qb-create -c dispjail -t <template> <newjail>
Duplicate ROOTENV:  qb-create -t <existing_rootenv> <newjail/VM>
Install rootVM:     qb-create -i /usr/local/share/ISOs/<ISOfile> -v <size> <newVM>

If no opts or <template> are specified, qubsdmap \'#default' are used.
  #default can be viewed with:   qb-list -j #default
  #default can be changed with:  qb-edit #default <PARAM> <value>

ENDOFMSG
	;;
	_resp1)
			local _PARAM="$_passvar"
			local _lowparam=$(echo $_PARAM | tr '[:upper:]' '[:lower:]')

			while : ; do
				eval read -p \"ENTER ${_PARAM}:  \" $_PARAM
				eval "chk_valid_${_lowparam}" \"\${$_PARAM}\" && break
			done
	;;

	_resp2)
         while : ; do
				read -p "RESPONSE: " _RESPONSE
				echo $_RESPONSE | grep -Eqs "^[123]\$" && break
			done
	;;

	esac

	case $_pass_cmd in
		usage_0) usage ; exit 0 ;;
		usage_1) usage ; exit 1 ;;
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		*) : ;;
	esac
}

usage() { cat << ENDOFUSAGE

qb-create: Creates new jails/VMs. Can duplicate from <template>, or
           create new jail/VM by specificing individual parameters.

           If insuffient options <newjail/VM> are specified, script
           will attempt to substitute #defaults from quBSD.conf.

Usage: qb-create [-e|-h|-G] [-y] [-Z] [-c <class>] [-r <rootenv>]
                 [-t <template>] [-v <volsize>] [-z <dupl|none|empty]
                 [-p <PARAMETER>=<value>] <newjail/VM>
       qb-create -i <ISO_filepath> -v <volsize> <newVM>

   -c: (c)lass: <appjail|rootjail|cjail|dispjail|appVM|rootVM> is a
       critical parameter for new jail/VM. Can also defined with [-p]
   -e: (e)examples. Print examples of how to use qb-create
   -G: (G)uided: Informative messages guide user via input prompts.
        All other command line options are ignored. For <jail> only.
   -h: (h)elp: Shows this message
   -i: (i)nstall a new rootVM based on the ISO provided. Recommend to
       store ISOs at: /usr/local/share/ISOs
   -p: (p)arameter. Multiple [-p] can be used in the same command to
       specify values for valid parameters listed in:  qb-help params
   -r: (r)ootenv. Designates the <rootenv> for <newjail/VM>
   -t: (t)template <jail/VM> can be specified, and fills two functions:
       1. PARAMETERS are copied from <template>, except those specified
          at the command line. If neither <template> nor command line
          args are given, #default are substituted from quBSD.conf
       2. The zusr dataset of the <template> will be copied in one
          form or another. Use [-z] to specify zusr dataset handling.
          Note! [-c <rootjail|rootVM>] requires [-t <template>]
   -v: (v)olsize for: rootVM at ${R_ZFS}; or appVM at ${U_ZFS}
       Use same convention as MEMSIZE.
   -y: (y)es: Assume "Y" for warnings/confirmations before proceeding.
   -z: (z)usropt: How to handle <newjail/VM> zusr dataset. Only applies
       to appjail/VM, not disp. Default behavior is <dupl>.
       <dupl>  Jail/VM. Duplicate dataset/block device. Consumes disk.
       <dirs>  Jail only. Copy <template> empty directories, no files.
       <empty> Jail/VM. Create empty dataset/block device on $U_ZFS
               If VM, must specify [-v], and it will be unformatted.
   -E: (E)ncrypt. Encrypt the new ${U_ZFS} dataset.
   -Z: (Z)rootopt: Creates a new ROOTENV with an independent on-disk
       dataset, from snapshot of:  ${R_ZFS}/<template>

FOR [-p <PARAMETERS>] LIST AND DETAILS, RUN:  qb-help params
ENDOFUSAGE
}
