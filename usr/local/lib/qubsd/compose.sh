#!/bin/sh

resolve_cell_parameters() {
    local _fn="resolve_cell_config" _prefix="$2" _cell _type _params _val

    chk_args_set 1 $1 && _cell="$1" || eval $(THROW)  # Safety assurance
    _type=$(query_cell_type $_cell) || eval $(THROW)  # JAIL vs VM

    # Get all PARAM variable names. If _prefix, protect globals from clobber with `local` 
    eval _params=\"\${PARAMS_COMN} \${PARAMS_${_type}}\"
    [ "$_prefix" ] && eval local $_params && eval unset $_params

    # Source defaults and _cell conf
    . $DEF_BASE
    eval . \${DEF_${_type}}
    . $D_CELLS/$_cell

    # Assign the correct variable name based on _prefix, and render global: _PARAMS
    for _param in $_params ; do
        eval _val=\${$_param}
        [ "$_val" ] && eval ${_prefix}${_param}='${_val}'
    done

    # Complete the ZFS mountpoints, as they are structurally indispensible to resolution
    R_MNT=$(hush zfs list -Ho mountpoint "$R_ZFS") 
    U_MNT=$(hush zfs list -Ho mountpoint "$U_ZFS") 

    return 0
}

validate_cell_parameters() {
   {}

}


##################################################################################################
####################################  OLD  FUNCTIONS  ############################################
##################################################################################################

validate_cellname() {
    # Check for collisions in proposed cellname
    local _fn="validate_cellname" ; local _FN="$_FN::$_fn"
 
    while getopts qV _opts ; do case $_opts in
       q) local _qa='-q' ;;
       V) local _V="-V" ;;
    esac ; done ; shift $(( OPTIND - 1))
 
    # Positional parmeters
    local _jail="$1"
    [ -z "$_jail" ] && get_msg $_qa -m _e0 -- "new jail name" && eval $_R1
 
    # Checks that proposed jailname isn't 'none' or 'qubsd' or starts with '#'
    echo "$_jail" | grep -Eqi "^(none|qubsd)\$" \
          && get_msg $_qa -m _e13 -- "$_jail" && eval $_R1
 
    # Jail must start with :alnum: and afterwards, have only _ or - as special chars
    ! echo "$_jail" | grep -E -- '^[[:alnum:]]([-_[:alnum:]])*[[:alnum:]]$' \
          | grep -Eqv '(--|-_|_-|__)' && get_msg $_qa -m _e13_1 -- "$_jail" && eval $_R1
 
    # Checks that proposed jailname doesn't exist or partially exist
    if chk_valid_zfs "${R_ZFS}/$_jail" || \
       chk_valid_zfs "${U_ZFS}/$_jail"  || \
       grep -Eq "^${_jail}[ \t]+" $QCONF || \
       [ -e "${JCONF}/${_jail}" ] ; then
       get_msg $_qa -m _e13_2 -- "$_jail" && eval $_R1
    fi 
 
    eval $_R0
}  


chk_valid_jail() {
   # Checks that jail has JCONF, QCONF, and corresponding ZFS dataset
   # Return 0 for passed all checks, return 1 for any failure
   local _fn="chk_valid_jail" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

   local _class= ; local _template= ; local _class_of_temp=
   while getopts c:qV opts ; do case $opts in
         c) _class="$OPTARG" ;;
         q) local _qv='-q' ;;
         V) local _V="-V" ;;
         *) get_msg -m _e9 ;;
   esac  ;  done  ;  shift $(( OPTIND - 1 )) ; [ "$1" = "--" ] && shift

   # Positional parmeters and function specific variables.
   local _value="$1"
   [ -z "$_value" ] && get_msg $_qv -m _e0 -- "jail" && eval $_R1

   # _class is a necessary element of all jails. Use it for pulling datasets
   [ -z "$_class" ] && _class=$(get_jail_parameter -eqs CLASS $_value)

   # Must have a ROOTENV in QCONF.
   ! grep -Eqs "^${_value}[ \t]+ROOTENV[ \t]+[^ \t]+" $QCONF \
      && get_msg $_qv $_V -m _e2 -- "$_value" "ROOTENV" \
      && get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1

   # Jails must have an entry in JCONF
   ! chk_isvm -c $_class "$_value" && [ ! -e "${JCONF}/${_value}" ] \
         && get_msg $_qv -m _e7 -- "$_value" && get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1

   case $_class in
      "") # Empty, no class exists in QCONF
         get_msg $_qv $_V -m _e2 -- "jail" "$_value" \
         get_msg $_qv $_V -m _e1 -- "$_value" "class" && eval $_R1
         ;;
      rootjail) # Rootjail's zroot dataset should have no origin (not a clone)
         ! zfs get -H origin ${R_ZFS}/${_value} 2> /dev/null | awk '{print $3}' | grep -Eq '^-$' \
             && get_msg $_qv -m _e5 -- "$_value" "$R_ZFS" \
             && get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1
         ;;
      appjail|cjail) # Appjails require a dataset at quBSD/zusr
         ! chk_valid_zfs ${U_ZFS}/${_value} \
            && get_msg $_qv -m _e5 -- "${_value}" "${U_ZFS}" \
            && get_msg $_qv -m _e1 -- "${U_ZFS}/${_value}" "ZFS dataset" && eval $_R1
         ;;
      dispjail) # Verify the dataset of the template for dispjail
         # Template cant be blank
         local _template=$(get_jail_parameter -deqs TEMPLATE $_value)
         [ -z "$_template" ] && get_msg $_qv -m _e2 -- "$_value" "TEMPLATE" \
            && get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1

         # Dispjails can't reference other dispjails
         local _templ_class=$(sed -nE "s/^${_template}[ \t]+CLASS[ \t]+//p" $QCONF)
         [ "$_templ_class" = "dispjail" ] \
            && get_msg $_qv -m _e6_1 -- "$_value" "$_template" && eval $_R1

         # Ensure that the template being referenced is valid
         ! chk_valid_jail $_qv -c "$_templ_class" -- "$_template" \
            && get_msg $_qv -m _e6_2 -- "$_value" "$_template" \
            && get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1
         ;;
      rootVM) # VM zroot dataset should have no origin (not a clone)
         ! zfs get -H origin ${R_ZFS}/${_value} 2> /dev/null | awk '{print $3}' \
            | grep -Eq '^-$'  && get_msg $_qv -m _e5 -- "$_value" "$R_ZFS" && eval $_R1
         ;;
      *VM) :
         ;;
      *) # Any other class is invalid
         get_msg $_qv -m _e1 -- "$_class" "CLASS" \
         get_msg $_qv -m _e1 -- "$_value" "jail" && eval $_R1
         ;;
   esac

   # One more case statement for VMs vs jails
   case $_class in
      *jail)
   esac

   eval $_R0
}

