#!/bin/sh

# Lazy loading is extremely fast/convenient. Use prefix ($2) to modify assigned PARAM names
resolve_cell_parameters() {
    local _fn="resolve_cell_parameters" _prefix="$2" _cell _PARAMS _val _def_type
    chk_args_set 1 $1 && _cell="$1" || eval $(THROW 1)  # Safety assurance
    is_path_exist -f $D_CELLS/$_cell   || eval $(THROW 1)

    # Rare loading of new global in subshell. Derived from CLASS, important across boundaries
    _TYPE=$(query_cell_type $_cell) || eval $(THROW 1)  # JAIL vs VM

    # Assemble all PARAM names. $_PARAMS isnt global, but CAPS separates [:upper:] vs [:lower:]
    eval _PARAMS=\"\${PARAMS_COMN} \${PARAMS_${_TYPE}}\"
    if [ "$_prefix" ] ; then 
        eval local $_PARAMS            # Protect globals against clobber
        eval unset "$_prefix$_PARAMS"  # Protect against stale _prefix_params assignments 
        eval $_prefix=$_cell           # Record the name of the cell associated to the prefix
    else
        eval unset "$_PARAMS"          # Protect against stale global PARAMS assignments
    fi

    # Source defaults and _cell conf
    eval _def_type=\${DEF_${_TYPE}}
    . $DEF_BASE
    . $_def_type 
    . $D_CELLS/$_cell

    # Assign the correct variable name based on _prefix, and render global: _PARAMS
    for _PARAM in $_PARAMS ; do
        eval _val=\${$_PARAM}
        [ "$_val" ] && eval ${_prefix}${_PARAM}='${_val}'
    done

    # Complete the ZFS mountpoints, as they are structurally indispensible to resolution
    R_MNT=$(hush zfs list -Ho mountpoint "$R_ZFS") 
    U_MNT=$(hush zfs list -Ho mountpoint "$U_ZFS") 

    return 0
}

# Requires $1 (cellname). Optional prefix [-p] and PARAM_LIST [-P]; or defaults to global constants
validate_cell_parameters() {
    local _fn="validate_cell_parameters" _cell _opts _prefix _cell _PARAMS _params _funct
    chk_args_set 1 $1 || eval $(THROW 1)  # Safety assurance
    
    while getopts :p:P: _opts ; do case $_opts in
        p) _prefix="$OPTARG" ; eval _cell=\${$_prefix} ;;
        P) _PARAMS="$OPTARG" ;;
        *) eval $(THROW 1 internal) ;;
    esac  ;  done  ;  shift $(( OPTIND - 1 ))

    # Check that the positional $1 cellname matches what's stored in the prefix designator
    [ "$_cell" = "$1" ] || eval $(THROW 1 internal2 $_prefix $1 $_cell)

    # Assemble all PARAM names. $_PARAMS isnt global, but CAPS separates [:upper:] vs [:lower:]
    [ -z "$_PARAMS" ] && eval _PARAMS=\"\${PARAMS_COMN} \${PARAMS_${_TYPE}}\"

    for _PARAM in $_PARAMS ; do
        _param=$(echo "$_PARAM" | tr '[:upper:]' '[:lower:]')
        _funct="validate_param_$_param"
        quiet type $_funct || eval $(THROW 1 ${_fn} $_PARAM $_funct)  # Verify exist before call
        eval $_funct \${${_prefix}${_PARAM}} $_cell || eval $(THROW 1)
    done
}


##################################################################################################
####################################  OLD  FUNCTIONS  ############################################
##################################################################################################


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

