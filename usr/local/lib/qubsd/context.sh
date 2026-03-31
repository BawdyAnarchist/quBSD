#!/bin/sh


##################################  CONTEXT BUILDERS AND HELPERS  ##################################

# Dereferences a variable name (resolves the indirection to its final value)
ctx_get() {
    eval echo \"\${$1}\"
}

# Unset PARAMS based on optional prefix [-p] and PARAM_LIST [-P], or defaults to global constants
ctx_unset() {
    local _fn="ctx_unset" _opts OPTARG OPTIND _pfx="$1" _PARAMS

    while getopts :P: _opts ; do case $_opts in
        P) _PARAMS="$OPTARG" ;;
        *) eval $(THROW 8 _internal1) ;;
    esac ; done ; shift $(( OPTIND - 1 ))

    # Assemble PARAM names. $_PARAMS isnt global, CAPS distinguishes [:upper:] vs [:lower:] name
    [ -z "$_PARAMS" ] && _PARAMS="$PARAMS_ALL $CONTEXT"

    [ "$_pfx" ] && unset $_pfx
    unset $(echo "$_PARAMS" | sed "s/,/ /g; s/^/$_pfx/; s/ / $_pfx/g")

    return 0
}

# This is the heart of the global context namespace. We deconflict global PARAM assignments with
# _pfx ($2), which must be managed by callers. Lazy loading (sourcing) is fast/convenient. ~3ms.
ctx_load_params() {
    local _fn="ctx_load_params" _pfx _cell _type _caller _params_type
    assert_args_set 1 "$1" && _cell="$1" _pfx="$2" || eval $(THROW $?)

    # Derive the cell type and store in context (existence of QCONF path is verified here as well)
    _type=$(query_cell_type $_cell) || eval $(THROW $? ${_fn} $_cell)  # JAIL|VM
    _caller="${0##*/}"  # jail needs the caller (qb|exec) to determine who owns the runtime context

    # CONTEXT variables
    eval ${_pfx}TYPE=$_type
    eval ${_pfx}CALLER=${_caller%%[.-]*}
    eval ${_pfx}PARAMS_TYPE=\"$PARAMS_BASE,\${PARAMS_${_type}}\"
    eval ${_pfx}QCONF=$D_CELLS/$_cell            # qubsd.conf.d/cells
    eval ${_pfx}JCONF=$D_JAILS/$_cell            # jail.conf.d/jails
    eval ${_pfx}RT_CTX=$D_RUNTM/$_cell/ctx.conf  # /var/run/qubsd/cells/  # Runtime context

    # Convert PARAMS_TYPE to space delimited with prefixes attached. Protect globals,
    _params_type=$(ctx_get ${_pfx}PARAMS_TYPE | sed "s|^|$_pfx|; s|,| $_pfx|g")
    unset $_params_type  # Unset the prefixed params to prevent accidents on stale variables

    # Don't clobber globals during sourcing. This MUST come first
    if [ "$_pfx" ] ; then
        local $(echo $PARAMS_TYPE | sed "s/,/ /g")
        eval $_pfx=$_cell    # Simple way to get the cellname of a loaded context prefix
    fi

    # Source base defaults, type defaults, and finally cell QCONF. Order matters
    . $DEF_BASE
    . $(ctx_get DEF_${_type})
    . $D_CELLS/$_cell

    # Avoid looping over PARAMS. Sed prints a variable assignment expression, then we evaluate it
    eval $(echo $_params_type | sed -E "s|$_pfx([^[:blank:]]+)|$_pfx\1=\\\$\1|g")  # Good magic
    return 0
}

# Conviencience of loading a single file into context. Caller MUST manage their
# own prefixes, as no protective measures are made in the function to clear stale.
ctx_load_file() {
    local _fn="ctx_load_file" _file _pfx _params _params_eval
    assert_args_set 1 "$1" && _file="$1" _pfx="$2" || eval $(THROW $?)
    is_path_exist "$_file" || eval $(THROW $?)

    # First read the file to get PARAMS, then local them to prevent clobber before pfx is assigned
    if [ "$_pfx" ] ; then
        _params=$(sed -E "s|^(.*)=.*|\1|" $_file)
        local $_params
    fi

    . $_file  # Source the file

    # Avoid looping over PARAMS. Sed resolves a valid expression, then evaluate it
    eval $(echo $_params | sed -E "s|([^[:blank:]]+)|$_pfx\1=\\\$\1|g")
    return 0
}

# REQUIRES: ctx_load_parameters() FIRST, due to use of R_ZFS and P_ZFS of the cell
ctx_add_zfs() {
    local _fn="ctx_add_zfs" _cell _pfx _r_dset _p_dset _r_mnt _p_mnt
    assert_args_set 1 "$1" && _cell="$1" _pfx="$2" || eval $(THROW $?)

    # Establish cell-specific dataset names based on R_ZFS and P_ZFS
    _r_dset=$(ctx_get ${_pfx}R_ZFS)/$_cell
    _p_dset=$(ctx_get ${_pfx}P_ZFS)/$_cell

    # Set the prefix-specific global context for the datasets and mountpoints
    query_datasets "$_r_dset $_p_dset"
    eval ${_pfx}R_DSET=$_r_dset
    eval ${_pfx}P_DSET=$_p_dset
    eval ${_pfx}R_MNT=$(query_zfs_mountpoint $_r_dset)
    eval ${_pfx}P_MNT=$(query_zfs_mountpoint $_p_dset)
    # Side effect of R_MNT and P_MNT is the unequivocal attestation to dataset existence
    return 0
}

# Validation orchestrator for arbitrary set of PARAMS.
# REQUIRE: $1 (_level) [1 -> assert ; 2 -> config ; 3 -> runtime] and $2 (CELL).
# OPTIONAL: $3 (_pass) -> which validation.sh error codes to ignore failures and continue
ctx_validate_params() {
    local _fn="ctx_validate_params" _opts OPTIND OPTARG
    local _cell _pfx _level _pass _PARAMS _type _value _param _validation_function

    while getopts :l:p:P: _opts ; do case $_opts in
        l)  _level="$OPTARG" ;;
        p)  _pass="$OPTARG" ;;
        P)  _PARAMS="$OPTARG" ;;     # Specify PARAM list, or use the list from constants.sh
        *)  eval $(THROW 8 _internal1) ;;
    esac ; done ; shift $(( OPTIND - 1 ))

    # Internal assignments and sanitization
    assert_args_set 1 "$1" && _cell=$1 _pfx=$2 || eval $(THROW $?)
    assert_int_comparison -g 1 -l 3 $_level || eval $(THROW 7 _internal2 $_level $_fn)

    _type=$(ctx_get ${_pfx}TYPE)  # Multiple validations use _type as downward-scoped
    # Assemble PARAM names. $_PARAMS isnt global, CAPS distinguishes [:upper:] vs [:lower:] name
    [ -z "$_PARAMS" ] && _PARAMS="$(ctx_get ${_pfx}PARAMS_TYPE),$CTX_VALIDATE"

    for _PARAM in $(echo $_PARAMS | tr ',' ' ') ; do
        unset _value  # Unset to prevent stale values from polluting the validation
        eval  _value="\${${_pfx}$_PARAM}"

        _param=$(conv_to_lower "$_PARAM")
        _validation_function="validate_param_$_param"
        quiet type $_validation_function || eval $(THROW 6 ${_fn} $_PARAM $_funct)

        # _level _value _cell _pfx _type are downward-scoped to avoid 'param drilling' in validation
        eval $_validation_function || PASS -c $_pass || eval $(THROW $?)
    done
}

# Initializes a new cell runtime in /var/run. This will clobber any existing runtime file
ctx_write_runtime() {
    local _fn="ctx_write_runtime" _opts OPTIND OPTARG
    local _cell _pfx _rt_ctx _runtime _param _val _line _ctx

    # Double check the function usage by requiring $1 to be equivalent to the _pfx ctx
    assert_args_set 1 "$1" && _cell="$1" _pfx="$2" || eval $(THROW $?)
    [ "$_pfx" ] && { [ "$(ctx_get $_pfx)" = "$_cell" ] || eval $(THROW 7 _internal4) ;}

    # Remove runtime context if it exists, make sure the directory exists
    _rt_ctx=$(ctx_get ${_pfx}RT_CTX)
    rm -f $_rt_ctx
    mkdir -p $D_RUNTM/$_cell

    # Resolve the context values, generate the _rt_ctx lines, and write it
    _runtime="$(ctx_get ${_pfx}PARAMS_TYPE),$(ctx_get ${_pfx}CONTEXT)"
    for _param in $(echo "$_runtime" | tr ',' ' ') ; do
        _val=$(ctx_get ${_pfx}$_param)
        eval _line='$_param=\"$_val\"'
        _ctx="$(printf "%b" "$_ctx" "\n$_line")"
    done
    echo "$_ctx" > $_rt_ctx
    return 0
}

ctx_runtime_upsert() {
    local _fn="ctx_write_runtime"
#### STUB FOR NOW ####
}

ctx_load_runtime() {
    local _fn="load_runtime_context" _pfx="$1"
    _rt_ctx=$(ctx_get ${_pfx}RT_CTX)
    is_path_exist -f $_rt_ctx || eval $(THROW $? _missing_context $_rt_ctx)
    . $_rt_ctx   # source (load) the runtime
    return 0
}

#####################################  BOOTSTRAP ENTRY POINTS  #####################################

# qb/exec scripts should use these entry points. The lib framework is designed for lazy-loading.
# Return codes combined with PASS() allow for versatile load/validation turning by main callers.
# If running multiple cells use: query_datasets_recursive_defaults to preload recursive $DATASETS.
# Execution times:
    # bootstrap_cell: ~19ms.  ~17ms with $DATASETS
    # bootstrap_runtime: ~60-100ms.  ~50-75ms with $DATASETS (validation is long)

# Load a new cell context. The only THROWS here are absolutely non-negotiable, fatal for bootstrap
ctx_bootstrap_cell() {
    local _fn="ctx_bootstrap_cell" _cell _pfx
    assert_args_set 1 "$1" && _cell="$1" _pfx="$2" || eval $(THROW $?)

    ctx_unset $_pfx    # Start from blank slate
    ctx_load_params $_cell $_pfx || eval $(THROW $? $_fn $_cell)
    ctx_add_zfs $_cell $_pfx
    return 0
}

# Load the cell context, validate the parameters based on options, and write the RT_CTX
ctx_bootstrap_runtime() {
    local _fn="ctx_bootstrap_runtime" _opts OPTIND OPTARG _cell _pfx _levelopt _passopt _paramsopt

    while getopts :l:p:P: _opts ; do case $_opts in
        l)  _levelopt="-l $OPTARG" ;;
        p)  _passopt="-p $OPTARG" ;;
        P)  _paramsopt="-P $OPTARG" ;;
        *)  eval $(THROW 8 _internal1) ;;
    esac ; done ; shift $(( OPTIND - 1 ))
    assert_args_set 1 "$1" && _cell="$1" _pfx="$2" || eval $(THROW $?)

    # Validation and CTX can tolerate the missing datasets without throwing
    ctx_bootstrap_cell $_cell $_pfx || eval $(THROW $? _generic "Cell < $_cell > bootstrap failed")
    ctx_validate_params $_levelopt $_passopt $_paramsopt $_cell $_pfx \
        || eval $(THROW $? _generic "Cell validation failed")
    ctx_write_runtime $_paramsopt $_cell $_pfx \
        || eval $(THROW $? _generic "Failed to write runtime context")
    return 0
}



