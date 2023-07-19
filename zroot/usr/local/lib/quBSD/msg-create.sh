#!/bin/sh

get_msg_create() { 

	local _message="$1"
	local _pass_cmd="$2"
	local _respvar="$3"

	case "$_message" in

	_e1) cat << ENDOFMSG

ERROR: [-z] can only be <dupl|clone|sys|none|empty>
ENDOFMSG
	;;
	_e2) 

cat $_TMP_WARN

	;;
	_e3) cat << ENDOFMSG

ERROR: When creating a jail of class:  [-c $CLASS],
       it must be accompanied with option [-t <template>].
ENDOFMSG
	;;
	_e4) cat << ENDOFMSG

ERROR: [-Z] not valid when creating <appjail|dispjail>. Their
       root filesystem is always cloned at start/stop, from a 
       limited set of on-disk rootjails, as a security measure.

       It would imply a clone of a clone, making <newjail>
       ephemeral, destroyed at <template> stop or start.

       Either create a new on-disk rootjail to serve appjails: 
          qb-create [-c rootjail] [-Z] [-t ${TEMPLATE}] $NEWJAIL
	    OR	
       Create an ephemeral jail with qb-disp. 
          qb-disp $TEMPLATE 

ENDOFMSG
	;;
	_e5) cat << ENDOFMSG
ENDOFMSG
	;;
	_e6) cat << ENDOFMSG

ERROR: Cannot [-z clone] for < $TEMPLATE >. It's a dispjail,
       so its zusr dataset is already a clone; meaning the
       new appjail would be dependent on the dispjail.
      
       All other [-z] <dupl|sys|none|empty> are valid, as an 
       independent zusr dataset is created.
ENDOFMSG
	;;
	_e7) cat << ENDOFMSG

ERROR: Attempted to create a new appjail from template.
       However, < $TEMPLATE >, is a dispjail with no zusr 
       dataset for the new appjail to copy from.
ENDOFMSG
	;;
	_e8) cat << ENDOFMSG

ERROR: User specified [-c rootjail] which will create a new 
       ondisk rootjail from [-t ${TEMPLATE}] which isn't a
       rootjail. It's an edge usecase operation that creates 
       a full, ondisk duplicate from a snapshot of the clone:
       ${JAILS_ZFS}/${TEMPLATE}

       Please run command again with [-Z] option, to confirm.
ENDOFMSG
	;;
	_e9) cat << ENDOFMSG

ERROR: The root dataset for < $NEWJAIL > is invalid:
       $R_ZPARENT 
ENDOFMSG
	;;
	_e10) cat << ENDOFMSG

ERROR: Conflicting opts. Creating dispjail with [-t $TEMPLATE]
       which is a rootjail. However, user also specified
       [-r $ROOTJAIL], which is in conflict with the template.
ENDOFMSG
	;;

	_w1) cat << ENDOFMSG

FINAL CONFIRMATION
$NEWJAIL will be created with the following parameters:

`cat "$_TMP_PARAMS" | column -t`

ENDOFMSG
	;;

	_w2) cat << ENDOFMSG
Will consume disk space:  `zfs send -nv "${R_SNAP}" | tail -1 | grep -oE '[^[:blank:]]+$'`
Duplicated from dataset:  ${R_ZPARENT}

ENDOFMSG
	;;

	_w3) cat << ENDOFMSG
Will consume disk space:  `zfs send -nv "${U_SNAP}" | tail -1 | grep -oE '[^[:blank:]]+$'`
Duplicated from dataset:  ${U_ZPARENT}

ENDOFMSG
	;;

	_w4) cat << ENDOFMSG
Some jail parameters above have warnings. New jail can be
created, but it might not function properly. Errors below:

ENDOFMSG
;;

	_w5)
echo -e "   FINAL CONFIRMATION. Proceed? (Y/n): \c"
;;

	_w6) cat << ENDOFMSG
ALERT: No valid template was specified for appjail.
       Creating an empty zusr for the jail. 
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

quBSD offers 3 classes of jails:  rootjail | appjail | dispjail

   rootjail - Contains a full FreeBSD installation and pkgs.
              These are pristine root environments which serve
              zfs clones to dependent jails. No workstation
              activity or command execution should ever take 
              place here, except updates and pkg installation.

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

ENDOFMSG
	;;

	_m2) cat << ENDOFMSG

[-r <rootjail>]

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

At the command line, a new rootjail requires a template,
to prevent accidental creation of an ondisk rootjail. Here
we'll assume you want to use < $ROOTJAIL > as the template.

Here are the jailmap.conf settings for:  $ROOTJAIL
ENDOFMSG
		qb-list -j $ROOTJAIL

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
1. "#default" Jail Parameters in jailmap.conf are used. 
2. The zusr template associated with the rootjail is duplicated.
   (These have baseline files associated with their purpose).
   0base-template, 0net-template, 0gui-template, 0serv-template
   If no ROOTJAIL-template is found, an empty zusr is created.

Command line parameters override template parameters, and zero
or more CL params can be used in combination with the template.

Use qb-edit to change #default. Current #default parameters:
ENDOFMSG
		qb-list -j '#default' | grep -Ev "[[:blank:]]+ROOTJAIL[[:blank:]]+" \
								  	 | grep -Ev "[[:blank:]]+CLASS[[:blank:]]+" \
								  	 | grep -Ev "[[:blank:]]+TEMPLATE[[:blank:]]+"
cat << ENDOFMSG
WOULD YOU LIKE TO:
   1. Use ${ROOTJAIL}-template for zusr dataset operations,
      and the above #default parameter values
   2. Use this template for zusr dataset operations, but
      see info and input prompts to change each parameter 
   3. Select a different <template>

ENDOFMSG
	;;

	_m7) cat << ENDOFMSG

[-t <template>]

Dispjails require a template. You selected ROOTJAIL=${ROOTJAIL},
so it'd make sense to choose a template with the same rootjail.
If not, it will still launch, but might not have the expected
functionality/packages to match zusr files of the template.

Any valid jail can be used as a template. If a rootjail is used,
then no zusr dataset will be created. If an existing dispjail is
used as the template for a new dispjail, the new jail will use 
the same template as the existing dispjail. 

ENDOFMSG
	;;

	_m9) cat << ENDOFMSG

Here's the settings from $TEMPLATE to be used for the new jail:
ENDOFMSG
		qb-list -j $TEMPLATE | grep -Ev "[[:blank:]]+ROOTJAIL[[:blank:]]+" \
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

          However, /usr/home , /usr/etc/ , and any directories
          inside of /zusr/<jail>/usr/ , are skipped.

   all  - All directories and files, including those in /usr,
          receive schg flag.

ENDOFMSG
	;;
	_examples) cat << ENDOFMSG

QUICK and EASY USAGE 
Appjail from #default:  qb-create <newjail>
From Template:          qb-create -t <template> <newjail>
Standard GUI jail:      qb-create -t 0gui-template <newjail>
Dispjail:               qb-create -c dispjail -t <template> <newjail>
Rootjail:               qb-create -t <existing_rootjail> <newjail>

If no opts or <template> are specified, jailmap \'#default' are used. 
  #default can be viewed with:   qb-list -j #default
  #default can be changed with:  qb-edit #default <PARAM> <value> 

ENDOFMSG
	;;
	_resp1)
			local _PARAM="$_respvar"
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

Usage: qb-create [-e|-h|-G] [-a <true|false>] [-c <class>] [-C <cpuset>]
                 [-g <gateway>] [-i <IPv4>] [-m <maxmem>] [-M <MTU>]
                 [-n <true|false>] [-r <rootjail>] [-s <all|sys|none>]
                 [-S <-1|0|1|2|3>] [-t <template>] 
                 [-z <dupl|none|empty>] [-Z] <newjail>

   -e: (e)examples. Print examples of how to use qb-create
   -h: (h)elp: Shows this message
   -G: (G)uided: Informative messages guide user via input prompts to
        create <newjail>. All other command line options are ignored.
   -t: (t)emplate:
       1. JAIL PARAMETERS are copied from <template>, except those
          specified at the command line. If no <template> and no
          command line args, #default is used from jailmap.conf
       2. The zusr dataset of the <template> will be duplicated. 
          Use [-z] to specify zusr dataset handling. 
       -note- [-c dispjail] and [-c rootjail] requires [-t <template>]
   -y: (y)es: Assume "Y" for warnings/confirmations before proceeding. 
   -z: (z)usropt: How to handle <newjail> zusr dataset. Only applies
       to appjails. <dupl> is the default behavior.
       <dupl>  Duplicate template zusr dataset. Consumes disk space.
       <none>  Copy directory paths from <template> but with no files. 
       <empty> Create an empty zusr dataset.
   -Z: (Z)rootopt: Creates a new rootjail with an independent on-disk
       dataset, from snapshot of:  ${JAILS_ZFS}/<template> 

JAIL PARAMETERS - Stored at /usr/local/etc/quBSD/jailmap.conf
   -a: (a)autostart: Autostart jail on boot. <true|false>.
   -A: (A)autosnap: Include <newjail> in autosnap cronjob. 
   -c: (c)lass:  < appjail | rootjail | dispjail >.
   -C: (C)puset: Limit <newjail> to specified CPUs.
   -g: (g)ateway: <newjail> receives network from <gateway> jail.
   -i: (i)pv4: Override IP auto-assignment. Use CIDR notation.
   -m: (m)axmem:  <integer><G|M|K>  
   -M: (M)TU: Can be tuned for individual jails. 
   -n: (n)o_destroy: Protection against accidenal destruction. 
   -r: (r)ootjail: <newjail> depends on clone of <rootjail> for
        root operating system & packages. Cloned at every start/stop.
   -s: (s)ecurelevel:  kern.securelevel <-1|0|1|2|3> for <newjail>.
   -S: (S)chg: chflags schg is applied to groups of files.
       < all | sys | none > (quBSD convention, see docs for more).
ENDOFUSAGE
}
