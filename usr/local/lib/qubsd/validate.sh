
##################################  SECTION 1: COMMON PARAMETERS  ##################################

validate_param_autostart() {
    local _fn="validate_param_autostart"
    assert_bool_tf $1 || eval $(THROW $?)
}

validate_param_autosnap() {
    local _fn="validate_param_autosnap"
    assert_bool_tf $1 || eval $(THROW $?)
}

validate_param_backup() {
    local _fn="validate_param_backup"
    assert_bool_tf $1 || eval $(THROW $?)
}

validate_param_bhyve_custm() {
    local _fn="validate_param_bhyve_custm"
    # There is no validation. This option is so users aren't limited in their VMs.
    # But we can't at all validate the possibilities here.
    return 0
}

validate_param_class() {
    local _fn="validate_param_class"
    assert_class $1 || eval $(THROW 1)
}

validate_param_control() {
    local _fn="validate_param_control"

    [ "$1" = "none" ] && return 0
    [ "$_val_lvl" -le 1 ] && return 0  # Level 1 validation (assert

    ctx_bootstrap_cell $1 "val_" && return 0 || eval $(THROW 1 _cellref $2 CJAIL $1)
}

validate_param_envsync() { ##########  STUB  FOR  NOW  ################################################################
    local _fn="validate_param_envsync"
}

validate_param_gateway() {
    local _fn="validate_param_gateway"

    [ "$1" = "none" ] && return 0
    [ "$_val_lvl" -le 1 ] && return 0  # Level 1 validation (assert

    ctx_bootstrap_cell $1 "val_" && return 0 || eval $(THROW 1 _cellref $2 GATEWAY $1)
}

validate_param_ipv4() {
## Must integrate this line, doesnt belong in assert
## Reserve a.b.c.1 (ending in .1) for the gateway  
#[ "$_a3" = "1" ] && eval $(THROW 1 $_fn IPV4 $_val) || return 0

    local _fn="validate_param_ipv4" _val="$1" _cell="$2" _type _gw _gw_type _cli_confs

    case $_val in
        none|auto|DHCP) return 0 ;;  # Control values must return early (cant offload to checks.sh)
        *) assert_ipv4 $_val || eval $(THROW 1) ;;  # Purely checks for CIDR format
    esac

    # Validation differs by TYPE. Guarantee value
    [ -z "$_type" ] && { _type=$(query_cell_type $_cell) || eval $(THROW 1) ;}

    # VM with CIDR is harmless, but warn user to prevent belief that it can be set like this
    if [ "$_type" = "VM" ] ; then
        eval $(WARN $_fn $_cell)
        return 0
    fi

    # Jails only. Check for collisions against both config, and runtime (if there is one)
    _gw=$(query_cell_param $_cell GATEWAY) || eval $(THROW 1)
    [ "$_gw" = "none" ] && return 0
    _gw_type=$(query_cell_type $_gw) || eval $(THROW 1)
    _cli_confs=$(query_gw_client_configs $_gw)

    if is_cell_running $_gw ; then
        is_route_available $_gw $_val || eval $(THROW 1 $_fn $_cell $_val $_gw)  # Runtime collision
    fi

    # Config collision
    [ "$_cli_confs" ] && grep -Eqs "$_val" $_cli_confs && eval $(WARN ${_fn}2 $_cell $_val $_gw)

    # Jails with a VM-gateway should usually be DHCP (but could have valid config with static CIDR)
    [ "$_gw_type" = "VM" ] && eval $(WARN ${_fn}3 $_gw)
}

validate_param_mtu() {
    local _fn="validate_param_mtu" _val="$1"
    assert_integer "$_val" || eval $(THROW 1)
    assert_int_comparison -g 1200 -l 1600 -- "$_val" || eval $(THROW 1 $_fn $2 $_val 1200 1600)
}

validate_param_no_destroy() {
    local _fn="validate_param_no_destroy"
    assert_bool_tf $1 || eval $(THROW 1)
}

validate_param_rootenv() {
    local _fn="validate_param_rootenv"
    ctx_bootstrap_cell $1 "val_" && return 0 || eval $(THROW 1 _cellref $2 ROOTENV $1)
}

validate_param_r_zfs() {
    local _fn="validate_param_r_zfs"
    is_zfs_exist "$1" || eval $(THROW 1 _missing_zfs $2 $1)
}

# NOTES: _pfx ($3) isnt required, but speeds validation.
validate_param_template() {
    local _fn="validate_param_template" _val="$1" _cell="$2" _pfx="$3" _class

    # Pivot the check based on CLASS
    _class=$(ctx_get ${_pfx}CLASS)
    [ -z "$_class" ] && _class=$(query_cell_param $_cell CLASS)
    [ -z "$_class" ] && eval $(THROW 1 $_fn $_cell $_val)

    case $_class in
        disp*)  ctx_bootstrap_cell $_val "val_" \
                    && return 0 || eval $(THROW 1 _cellref $_cell TEMPLATE $_val)
            ;;
        *)  : ;;  # Not a dispjail
    esac
    return 0
}

validate_param_p_zfs() {
    local _fn="validate_param_p_zfs"
    is_zfs_exist "$1" || eval $(THROW 1 _missing_zfs $2 $1)
}

###################################  SECTION 2: JAIL PARAMETERS  ###################################

validate_param_cpuset() {
    local _fn="validate_param_cpuset" _val="$1"
    [ "$_val" = "none" ] && return 0
    assert_cpuset "$_val" || eval $(THROW 1)
    quiet cpuset -l "$_val" && return 0 || eval $(THROW 1 $_fn $2 $_val)
}

validate_param_maxmem() {
    local _fn="validate_param_maxmem" _val="$1"
    [ "$_val" = "none" ] && return 0

    assert_bytesize $_val || eval $(THROW 1)
    query_sysmem
    _bytes=$(normalize_bytesize $_val) || { eval $(WARN memwarn $2) && return 0 ;}
    [ "$_bytes" -lt "$SYSMEM" ] || { eval $(WARN $_fn $2 $_val $_bytes $SYSMEM) && return 0 ;}
    return 0
}

validate_param_schg() {
    local _fn="validate_param_schg"
    assert_schg $1 || eval $(THROW 1)
}

validate_param_seclvl() {
    local _fn="validate_param_seclvl"
    assert_seclvl $1 || eval $(THROW 1)
}

##################################  SECTION 3: BHYVE PARAMETERS  ###################################

validate_param_bhyveopts() {
    local _fn="validate_param_bhyveopts"
    assert_bhyveopts $1 || eval $(THROW 1)
}

validate_param_bhyve_custm() {
    local _fn="validate_param_bhyve_custm"
    return 0   # No validation. This is special, mostly for qb-create to launch a ISO installation
}

validate_param_memsize() {
    local _fn="validate_param_memsize" _val="$1" _bytes
    assert_bytesize $_val || eval $(THROW 1)
    query_sysmem
    _bytes=$(normalize_bytesize $_val)
    [ "$_bytes" -lt "$SYSMEM" ] || eval $(THROW 1 $_fn $2 $_val $_bytes $SYSMEM)
}

validate_param_ppt() {
    local _fn="validate_param_ppt" _val="$1"
    [ "$_val" = "none" ] && return 0 ;
    _val=$(echo $_val | sed "s#/#:#g")
    for _ppt in $_val ; do
        _result=$(hush pciconf -l "pci$_ppt")
        [ "$_result" ] || eval $(THROW 1 $_fn $2 $_ppt)
    done
    return 0
}

validate_param_taps() {
    local _fn="validate_param_taps"
    assert_taps $1 || eval $(THROW 1)
}

validate_param_tmux() {
    local _fn="validate_param_tmux"
    assert_bool_tf $1 || eval $(THROW 1)
}

validate_param_vcpus() {
    local _fn="validate_param_vcpus" _val="$1"
    assert_vcpus $_val || eval $(THROW 1)
    query_ncpus
    # Ensure that vpcus doesnt exceed the number of system cpus or bhyve limits
    { [ "$_val" -gt "$NCPU" ] || [ "$_val" -gt 16 ] ;} && eval $(THROW 1 $_fn $2 $_val $NCPU)
    return 0
}

validate_param_vnc() {
    local _fn="validate_param_vnc"
    assert_bool_tf $1 || eval $(THROW 1)
}

validate_param_wiremem() {
    local _fn="validate_param_wiremem"
    assert_bool_tf $1 || eval $(THROW 1)
}

##################################  SECTION 4: MISC VALIDATIONS  ###################################

# Validates that proposed cellname does not collide with existing cells, files, or datasets
validate_cellname() {
    local _fn="validate_cellname" _val="$1" _r_zfs="$2" _u_zfs="$3"
    local _cellpath=$D_CELLS/$1 _jailpath=$D_JAILS/$1
    assert_cellname $_val || eval $(THROW 1)

    # Check config file path and zfs dataset clobber. MUTE because failure of `is_`, is passing.
    is_path_exist -f $_cellpath && eval $(THROW 1 $_fn $_val path $_cellpath)
    is_path_exist -f $_jailpath && eval $(THROW 1 $_fn $_val path $_jailpath)
    is_zfs_exist "$_r_zfs" && eval $(THROW 1 $_fn $_val dataset $_r_zfs)
    is_zfs_exist "$_u_zfs" && eval $(THROW 1 $_fn $_val dataset $_u_zfs)
    return 0      # No failures, cellname is available
}

