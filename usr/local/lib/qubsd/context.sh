#!/bin/sh

#####################################  BOOTSTRAP ENTRY POINT  ######################################

# qb / exec scripts should use this as the entry primitive for cell operations. System-related
# queries are stored in globals, preventing bottlenecks for slowers operations like ZFS querires.
# Thus, bootstrap is fast. It can be stacked, looped, or used validation side effects.
# Return codes allow for more fine tuned caller decision making regarding failures.

ctx_bootstrap_cell() {
    local _fn="ctx_bootstrap_cell" _cell="$1" _pfx="$2" _type _jconf

    ctx_unset -p "$_pfx"  # Start from blank slate

    # Bootstrap a new cell context, which comes with basic checks for crucial parameters
    ctx_initialize $_cell $_pfx   || eval $(THROW 1 $_fn $_cell)  # QCONF exists
    ctx_load_params $_cell $_pfx  || eval $(THROW 2 $_fn $_cell)  # Source QCONF and defaults
    ctx_add_zfs $_cell $_pfx      || eval $(THROW 3 $_fn $_cell)  # Cell-specific datasets

    _type=$(ctx_get ${_pfx}TYPE)
    _jconf=$(ctx_get ${_pfx}JCONF)
    if [ "$_type" = "JAIL" ] ; then
        is_path_exist -f $_jconf || eval $(THROW 4 $_fn $_cell)
    fi
    return 0
}

##################################  CONTEXT BUILDERS AND HELPERS  ##################################

# Semantic parser that reduces eval clutter
ctx_get() {
    eval echo \"\${$1}\"
}

# Unset PARAMS based on optional prefix [-p] and PARAM_LIST [-P], or defaults to global constants
ctx_unset() {
    local _fn="ctx_unset" _opts OPTARG OPTIND _pfx _PARAMS

    while getopts :p:P: _opts ; do case $_opts in
        p) _pfx="$OPTARG" ;;
        P) _PARAMS="$OPTARG" ;;
        *) eval $(THROW 8 _internal1) ;;
    esac  ;  done  ;  shift $(( OPTIND - 1 ))

    # Assemble PARAM names. $_PARAMS isnt global, CAPS distinguishes [:upper:] vs [:lower:] name
    [ -z "$_PARAMS" ] && _PARAMS="$PARAMS_BASE $PARAMS_JAIL $PARAMS_VM $CONTEXT"

    [ "$_pfx" ] && unset $_pfx
    unset $(echo "$_PARAMS" | sed "s/^/$_pfx/; s/ / $_pfx/g")

    return 0
}

# Cell-specific derived paths, mountpoints, and datasets Reduces verbosity in later references
ctx_initialize() {
    local _fn="ctx_initialize" _pfx="$2" _cell _type _caller
    assert_args_set 1 $1 && _cell="$1"  || eval $(THROW $?)

    # Cell-specific paths and datasets.
    eval ${_pfx}QCONF=$D_CELLS/$_cell            # qubsd.conf.d/cells
    eval ${_pfx}JCONF=$D_JAILS/$_cell            # jail.conf.d/jails
    eval ${_pfx}RT_CTX=$D_RUNTM/$_cell/ctx.conf  # /var/run/qubsd/cells/  # Runtime context

    # Derive the cell type and store in context (existence of QCONF path is verified here as well)
    _type=$(query_cell_type $_cell) || eval $(THROW 1 ${_fn} $_cell)  # JAIL|VM, derived from CLASS
    eval ${_pfx}TYPE=$_type

    # Store the root of the caller (qb|exec). Necessary for parsing control authority
    _caller="${0##*/}"
    eval ${_pfx}CALLER=${_caller%%[.-]*}

    # Load the cellname directly into the prefix
    [ "$_pfx" ] && eval $_pfx=$_cell

    return 0
}

# Lazy loading is fast/convenient. Use prefix ($2) to modify global variable (PARAM) assignments
ctx_load_params() {
    local _fn="ctx_load_params" _pfx="$2" _cell _type _params_type _param _val
    assert_args_set 1 $1 && _cell="$1"  || eval $(THROW 1)

    # For convenience, we also assign ALL_PARAMS and TYPE_PARAMS as global context variables
    PARAMS_ALL="$PARAMS_BASE $PARAMS_JAIL $PARAMS_VM"
    _type=$(ctx_get ${_pfx}TYPE)
    eval ${_pfx}PARAMS_TYPE=\"\${PARAMS_BASE} \${PARAMS_${_type}}\"
    _params_type=$(ctx_get ${_pfx}PARAMS_TYPE)

    # With prefix, protect globals from clobber. This MUST come first
    [ "$_pfx" ] && local $_params_type

    # Unset _ALL_PARAMS before sourcing new ones, to prevent stale accidents
    unset $(echo "$PARAMS_ALL" | sed "s/^/$_pfx/; s/ / $_pfx/g")

    # Source defaults and _cell conf. Order is important.
    . $DEF_BASE
    . $(ctx_get DEF_${_type})
    . $D_CELLS/$_cell

    # Assign the correct variable name based on _pfx
    for _param in $_params_type; do
        _val=$(ctx_get $_param)
        [ "$_val" ] && eval ${_pfx}${_param}='${_val}'
    done

    return 0
}

# Conviencience of loading a single file into context. Caller MUST manage their
# own prefixes, as no protective measures are made in the function to clear stale.
ctx_load_file() {
    local _fn="ctx_load_file" _file _pfx="$2" _params
    assert_args_set 1 $1 && _file="$1"  || eval $(THROW 1)
    is_path_exist "$_file" || eval $(THROW 1)

    # First read the file to get PARAMS, then local them to prevent clobber before pfx is assigned
    if [ "$_pfx" ] ; then
        _params=$(sed -E "s|^(.*)=.*|\1|" $_file)
        local $_params
    fi

    # Source the file
    . $_file

    # Assign the correct variable name based on _pfx
    for _param in $_params; do
        _val=$(ctx_get $_param)
        [ "$_val" ] && eval ${_pfx}${_param}='${_val}'
    done
    return 0
}


# REQUIRES: load_parameters_ctx() FIRST, due to use of R_ZFS and P_ZFS of the cell
ctx_add_zfs() {
    local _fn="ctx_add_zfs" _cell _pfx="$2" _r_dset _p_dset _rmnt _pmnt
    assert_args_set 1 $1 && _cell="$1" || eval $(THROW 1)

    # Establish cell-specific dataset names based on R_ZFS and P_ZFS
    _r_dset=$(ctx_get ${_pfx}R_ZFS)/$_cell
    _p_dset=$(ctx_get ${_pfx}P_ZFS)/$_cell

    # Set the prefix-specific global context for the datasets and mountpoints
    query_datasets "$_r_dset $_p_dset"
    eval ${_pfx}R_DSET=$_r_dset
    eval ${_pfx}P_DSET=$_p_dset
    eval ${_pfx}R_MNT=$(query_zfs_mountpoint $_r_dset)
    eval ${_pfx}P_MNT=$(query_zfs_mountpoint $_p_dset)

    # Guarantee datasets exist. Checks integrated here in zfs_ctx to avoid fragmentation
    _rmnt=$(ctx_get ${_pfx}R_MNT)
    _pmnt=$(ctx_get ${_pfx}P_MNT)
    [ "$_rmnt" ] || eval $(THROW 1 $_fn $_cell $_r_dset)  # Even zvol has "-" for mountpoint
    [ "$_pmnt" ] || eval $(THROW 1 $_fn $_cell $_p_dset)
## NOTE: We hard-define _ZFS and _DSET. Only [ "$_MNT" ] can unequivocally attest to dataset existence ##

    return 0
}

# Orchestrator to validate an arbitrary list of PARAMS. WARN behavior opts. REQUIRE $1 (cell)
ctx_validate_params() {
    local _fn="ctx_validate_params" _opts OPTIND OPTARG
    local _cell _type _pfx _PARAMS _params _funct _emit _ret _warn=0 _warn_start="$WARN_CNT"

    while getopts :p:P:w: _opts ; do case $_opts in
        p)  _pfx="$OPTARG" ;         # Specify prefix, or use the raw PARAM name from constants.sh
            eval _cell=\${$_pfx} ;;  # Get the cellname stored in the prefix designator
        P)  _PARAMS="$OPTARG" ;;     # Specify PARAM list, or use the list from constants.sh
        w)  _warn="$OPTARG" ;        # On WARN: [0->return 0 (default)] [1->return 2] [2->THROW]
            assert_int_comparison -g 0 -l 2 $_warn || eval $(THROW 1 _internal4) ;;
        *)  eval $(THROW 1 _internal1) ;;
    esac  ;  done  ;  shift $(( OPTIND - 1 ))

    # Double check the function usage by requiring $1 to be equivalent to the _pfx ctx
    assert_args_set 1 $1 || eval $(THROW 1)
    [ -z "$_pfx" ] && _cell="$1" || _cell=$(ctx_get $_pfx)
    [ "$_cell" = "$1" ] || eval $(THROW 1 _internal2 $_pfx $1 $_cell)

    # Assemble PARAM names. $_PARAMS isnt global, CAPS distinguishes [:upper:] vs [:lower:] name
    _type=$(ctx_get ${_pfx}TYPE)
    [ -z "$_PARAMS" ] && eval _PARAMS=\"\${PARAMS_BASE} \${PARAMS_${_type}}\"

    for _PARAM in $_PARAMS ; do
        _param=$(echo "$_PARAM" | tr '[:upper:]' '[:lower:]')
        _funct="validate_param_$_param"
        quiet type $_funct || eval $(THROW 1 ${_fn} $_PARAM $_funct)     # Verify _funct exists

        # Hard failures, throw fast
        eval $_funct \"\${${_pfx}${_PARAM}}\" "$_cell" "$_pfx" || eval $(THROW 1)
        [ "$_warn" = "2" ] && [ "$WARN_CNT" -gt "$_warn_start" ] && eval $(THROW 2)
    done

    # Return based on warning policy
    [ "$WARN_CNT" -gt "$_warn_start" ] && [ "$_warn" -gt 0 ] && CLEAR && return 2 || return 0
}

# Initializes a new cell runtime in /var/run. This will clobber any existing runtime file
ctx_write_runtime() {
    local _fn="ctx_write_runtime" _opts OPTIND OPTARG
    local _cell _type _pfx _PARAMS _val _line

    while getopts :p:P: _opts ; do case $_opts in
        p)  _pfx="$OPTARG" ;         # Specify prefix, or use the raw PARAM name from constants.sh
            eval _cell=\${$_pfx} ;;  # Get the cellname stored in the prefix designator
        P)  _PARAMS="$OPTARG" ;;     # Specify PARAM list, or use the list from constants.sh
        *)  eval $(THROW 1 _internal1) ;;
    esac  ;  done  ;  shift $(( OPTIND - 1 ))

    # Double check the function usage by requiring $1 to be equivalent to the _pfx ctx
    assert_args_set 1 $1 || eval $(THROW 1)
    [ -z "$_pfx" ] && _cell="$1" || _cell=$(ctx_get $_pfx)
    [ "$_cell" = "$1" ] || eval $(THROW 1 _internal2 $_pfx $1 $_cell)

    # Assemble PARAM names. $_PARAMS isnt global, CAPS distinguishes [:upper:] vs [:lower:] name
    _type=$(ctx_get ${_pfx}TYPE)
    [ -z "$_PARAMS" ] && eval _PARAMS=\"\${PARAMS_BASE} \${PARAMS_${_type}}\ \${CONTEXT}\"

    # Remove runtime context if it exists, make sure the directory exists
    rm -f $RT_CTX
    mkdir -p $D_RUNTM/$_cell

    # Write PARAMS to the runtime context file
    for _PARAM in $_PARAMS ; do
        _val=$(ctx_get ${_pfx}${_PARAM})
        _line='$_PARAM=\"$_val\"'
        eval echo $_line >> $RT_CTX
    done
}

ctx_runtime_upsert() {
    local _fn="ctx_write_runtime"
#### STUB FOR NOW ####
}

ctx_load_runtime() {
    local _fn="load_runtime_context" _pfx="$1"
    _rt_ctx=$(ctx_get ${_pfx}RT_CTX)
    [ -f "$_rt_ctx" ] || eval $(THROW 1 _missing_context $_rt_ctx)
    . $_rt_ctx   # source (load) the runtime
    return 0
}

ctx_bootstrap_runtime() {
    local _fn="ctx_bootstrap_runtime" _cell _pfx="$2"
    assert_args_set 1 "$1" && _cell="$1" || eval $(THROW 1)

    ctx_bootstrap_cell $_cell $_pfx || PASS -C 3 \
        || eval $(THROW 1 _generic "Cell < $_cell > bootstrap failed")

    # Validation and CTX can tolerate the misisng datasets without throwing
    ctx_validate_params $_cell  || eval $(THROW 1 _generic "Cell validation failed")
    ctx_write_runtime $_cell    || eval $(THROW 1 _generic "Failed to write runtime context")
    return 0
}



