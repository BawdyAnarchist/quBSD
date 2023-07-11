#!/bin/sh

get_msg_create() { 

	local _message="$1"
	local _pass_cmd="$2"

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

ERROR: Creating appjail, but no template with a valid zusr
       dataset was specified. Searched for the dataset: 
       < ${ZUSR_ZFS}/${rootjail}-template > 
       but it doesn't exist. 
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
	_m1) cat << ENDOFMSG

GUIDED MODE: User will be presented with information, options, and 
input prompts to assist in the creation of a new jail.
Choose a jail class: Valid arguments are:  appjail|rootjail|dispjail   
Rootjails contain the base FreeBSD system files, installation, and pkgs. 
Appjails / dispjails depend on their associated rootjail, because they only 
contain /usr/home and just a few system-specific files. All other system 
files are cloned from the associated rootjail at every jail start/stop. 
Selecting rootjail here, will result in an on disk, full system install 
duplicated from which ever rootjail you select at the next prompt 
Enter jail class:  

ENDOFMSG
	;;
	_m2) cat << ENDOFMSG

You selected dispjail, which operates off of a template for 
zusr data at jail start. Valid template jails are as follows:
$validtemplatejs

	Select a valid template from the above:  

ENDOFMSG
	;;
	_m3) cat << ENDOFMSG

Template jails can simplify the process of creating a new jail
For example ${ZUSR_ZFS}/rw files will be copied (like fstab, rc.conf, resolv.conf) 
and a user will be created. Otherwise enter: none , and ${M_ZUSR}/$NEWJAIL will 
be created but empty. Valid templates are as follows:

$validtemplatejs 
Select one of the above or \`none\':  

ENDOFMSG
	;;
	_m4) cat << ENDOFMSG

Would you like to also copy the /home directory  
from:  $template\nThis will duplicate 

ENDOFMSG
	;;
	_m4_1) cat << ENDOFMSG

of data on disk into the new jail.\n\tEnter (y/n):   

ENDOFMSG
	;;
	_m4_2) cat << ENDOFMSG

Since this is a dispjail, do you want to create $NEWJAIL with the same 
settings as the template; and skip the remaining input prompts?  
   - User options alread specified at command input will be preserved 
   - If applicable, an unused internal IP will be found 
     and applied to $NEWJAIL for network connectivity 
Here are the settings of the template:

ENDOFMSG
	;;
	_m4_3) cat << ENDOFMSG

Use these settings and skip to jail creation? (y/n):  

ENDOFMSG
	;;
	_m5) cat << ENDOFMSG

Choose a rootjail appropriate for the intended use of your  
appjail:
`echo $validrootjs | awk '{print $1}'` 
	Select one of the rootjails above:  

ENDOFMSG
	;;
	_m6) cat << ENDOFMSG

You selected rootjail, thus opting to duplicate an existing rootjail 
This will create a full copy, on disk. Valid rootjails are as follows:

ENDOFMSG
	;;
	_m6_1) cat << ENDOFMSG

Installation of new rootjails is unsupported (use \`bsdinstall'). However 
 \`0base' is a bare, unmodified install. You can duplicate and modify it.  
Select one of the rootjails above:  

ENDOFMSG
	;;
	_m7) cat << ENDOFMSG

The gateway_jail is the gateway by which $NEWJAIL will connect to the network 
Normally you will select a net-<jail> jail; but any appjail is valid, and 
an epair will be created at jail start. Here's a list off all net-<jails>
`egrep -o ^net[^[:blank:]]+ $JMAP` 

	Select a gateway jail (or: none):  

ENDOFMSG
	;;
	_m8) cat << ENDOFMSG

IP address should be entered as IPv4 CIDR notation 
For reference, here's what is already designated in jail.conf:$JMAPIPs 
And here's a mapping of everything that is currently in use:$usedIPs 
Based on the selected gateway, quBSD convention would be to 
assign an IP like the following:  $ip0_255   
The first available IP in this range is: $OPENIP 
	Enter IPv4. INCLUDE THE SUBNET!  (or: none):   

ENDOFMSG
	;;
	_m9) cat << ENDOFMSG

	Enter valid IPv4 (or none):  

ENDOFMSG
	;;
	_m10) cat << ENDOFMSG

schg flags can protect files from modification, even by root. This can be 
applied to just system files (like /boot /bin /lib /etc), or \`all' files,  
including /home. This is a security mechanism for security critical jails. 
	Make Selection:  none|sys|all :  

ENDOFMSG
	;;
	_m11) cat << ENDOFMSG

schg can only prevent file modification (even by root), only when  
sysctl kern.securelevel is elevated above 0. Valid arguments: -1|0|1|2|3  
	Enter one of these integers:    

ENDOFMSG
	;;
	_m12) cat << ENDOFMSG

Jail RAM usage can be limited with FreeBSD rctl. Valid arguments are:  
<integer><G|M|K>  For example: 4G or 3500M (or \`none' for no limits). 
	Enter maxmem (or: none):  

ENDOFMSG
	;;
	_m13) cat << ENDOFMSG

cpuset specifies which CPUs a jail may access. Enter comma separated
integers, or a range. For example: 0,1,2,3 is the same as 0-3. \`none' 
 permits all CPUs (default). Here's a list of all CPUs on your system: 
$validcpuset
	Enter cpuset (or: none):  

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
                 [-z <dupl|clone|sys|none|empty>] [-Z] <newjail>

   -e: (e)examples. Print examples of how to use qb-create
   -h: (h)elp: Shows this message
   -G: (G)uided: Informative messages guide user via input prompts to
        create <newjail>. All other command line options are ignored.
   -t: (t)emplate:
       1. JAIL PARAMETERS are copied from <template>, except those
          specified at the command line. If no <template> and no
          command line args, #default is used from jailmap.conf
       2. The zroot and zusr datasets of the <template> can be cloned, 
          or duplicated. Use [-z][-Z] to specify dataset handling. 
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
