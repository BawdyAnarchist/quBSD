#!/bin/sh

# Lazy loading is fast/convenient. Use prefix ($2) to modify global variable (PARAM) assignments
resolve_cell_parameters() {
    local _fn="resolve_cell_parameters" _prefix="$2" _cell _type _PARAMS _ALL_PARAMS _val _def_type
    chk_args_set 1 $1 && _cell="$1"  || eval $(THROW 1)
    is_path_exist -f $D_CELLS/$_cell || eval $(THROW 1 $_fn $_cell $D_CELLS)

    # Rare loading of new global in subshell. Derived from CLASS, important across boundaries
    _type=$(query_cell_type $_cell) || eval $(THROW 1)  # JAIL vs VM

    # _CAPS here does not denote global, but that the [:upper:] case PARAM names are stored
    _ALL_PARAMS="$PARAMS_COMN $PARAMS_JAIL $PARAMS_VM"
    eval _PARAMS=\"\${PARAMS_COMN} \${PARAMS_${_type}}\"

    if [ "$_prefix" ] ; then 
        eval local $_PARAMS    # Protect globals from clobber. This MUST come first

        # Unset all prefix_PARAMS, including ones from a different _type to prevent stale accidents
        unset $(echo "$_ALL_PARAMS" | sed "s/^/$_prefix/; s/ / $_prefix/g")

        eval $_prefix=$_cell          # Record the name of the cell associated to the prefix
        eval "${_prefix}TYPE"=$_type  # Record the TYPE associated to the cell
    else
        eval unset "$_ALL_PARAMS"  # No stale global PARAMs
        TYPE=$_type
    fi

    # Source defaults and _cell conf
    eval _def_type=\${DEF_${_type}}
    . $DEF_BASE
    . $_def_type 
    . $D_CELLS/$_cell

    # ZFS mountpoints are indispensible to resolution. Quoted for edgecase of mountpoint path spaces
    eval ${_prefix}R_MNT=\"$(hush zfs list -Ho mountpoint "$R_ZFS")\"
    eval ${_prefix}U_MNT=\"$(hush zfs list -Ho mountpoint "$U_ZFS")\"

    # Assign the correct variable name based on _prefix, and render global: _PARAMS
    for _PARAM in $_PARAMS ; do
        eval _val=\${$_PARAM}
        [ "$_val" ] && eval ${_prefix}${_PARAM}='${_val}'
    done

    return 0
}

# Unset PARAMS based on optional prefix [-p] and PARAM_LIST [-P], or defaults to global constants
unset_cell_parameters() {
    local _fn="unset_cell_parameters" _opts OPTARG OPTIND _prefix _PARAMS
 
    while getopts :p:P: _opts ; do case $_opts in
        p) _prefix="$OPTARG" ;;
        P) _PARAMS="$OPTARG" ;;
        *) eval $(THROW 1 _internal) ;;
    esac  ;  done  ;  shift $(( OPTIND - 1 ))

    # Assemble PARAM names. $_PARAMS isnt global, CAPS distinguishes [:upper:] vs [:lower:] name
    [ -z "$_PARAMS" ] && _PARAMS="$PARAMS_COMN $PARAMS_JAIL $PARAMS_VM"
    [ "$_prefix" ] && eval unset $_prefix
    unset $(echo "$_PARAMS" | sed "s/^/$_prefix/; s/ / $_prefix/g")
    return 0
}

# Orchestrator to validate an arbitrary list of PARAMS. WARN behavior opts. Require $1 (cell)
validate_cell_parameters() {
    local _fn="validate_cell_parameters" _opts OPTIND OPTARG
    local _cell _type _prefix _PARAMS _params _funct _emit _ret _warn=0 _warn_start="$WARN_CNT"
    
    while getopts :ep:P:w: _opts ; do case $_opts in
        p)  _prefix="$OPTARG" ;        # Specify prefix, or use the raw PARAM name from constants.sh
            eval _cell=\${$_prefix} ;; # Get the cellname stored in the prefix designator
        P)  _PARAMS="$OPTARG" ;;       # Specify PARAM list, or use the list from constants.sh 
        e)  _emit=true ;;              # If no THROW occurred, then print any warnings before return
        w)  _warn="$OPTARG" ;          # On WARN: [0->return 0 (default)] [1->return 2] [2->THROW]
            assert_int_comparison -g 0 -l 2 $_warn || eval $(THROW 1 _internal4) ;;
        *)  eval $(THROW 1 _internal) ;;
    esac  ;  done  ;  shift $(( OPTIND - 1 ))

    # Handle $1 and _cell (post getopts). We also double check caller usage, for bug prevention
    chk_args_set 1 $1 || eval $(THROW 1)
    [ -z "$_prefix" ] && _cell="$1"                          # Use $1 if prefix wasnt specified 
    [ "$_cell" = "$1" ] || eval $(THROW 1 _internal2 $_prefix $1 $_cell)

    eval _type=\${${_prefix}TYPE}

    # Assemble PARAM names. $_PARAMS isnt global, CAPS distinguishes [:upper:] vs [:lower:] name
    [ -z "$_PARAMS" ] && eval _PARAMS=\"\${PARAMS_COMN} \${PARAMS_${_type}}\"

    for _PARAM in $_PARAMS ; do
        _param=$(echo "$_PARAM" | tr '[:upper:]' '[:lower:]')
        _funct="validate_param_$_param"
        quiet type $_funct || eval $(THROW 1 ${_fn} $_PARAM $_funct)     # Verify _funct exists

        # Hard failures, throw fast
        eval $_funct \"\${${_prefix}${_PARAM}}\" $_cell || eval $(THROW 1)
        [ "$_warn" = "2" ] && [ "$WARN_CNT" -gt "$_warn_start" ] && eval $(THROW 2)
    done

    # Print warnings and return based on warning policy
    is_path_exist -s $ERR && cat $ERR && CLEAR
    [ "$WARN_CNT" -gt "$_warn_start" ] && [ "$_warn" -gt 0 ] && return 2 || return 0
}

