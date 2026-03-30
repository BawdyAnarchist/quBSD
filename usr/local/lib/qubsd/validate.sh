#!/bin/sh

validate_param_autostart() {
    local _fn="validate_param_autostart"
    assert_bool_tf $_value || eval $(THROW 141)
}

validate_param_autosnap() {
    local _fn="validate_param_autosnap"
    assert_bool_tf $_value || eval $(THROW 142)
}

validate_param_backup() {
    local _fn="validate_param_backup"
    assert_bool_tf $_value || eval $(THROW 143)
}

validate_param_bhyveopts() {
    local _fn="validate_param_bhyveopts"
    assert_bhyveopts $_value || eval $(THROW 144)
}

validate_param_bhyve_custm() {
    local _fn="validate_param_bhyve_custm"
    assert_bhyve_custm $_value || eval $(THROW 145)
    return 0
}

validate_param_class() {
    local _fn="validate_param_class"
    assert_class $_value || eval $(THROW 146)
}

validate_param_control() {
    local _fn="validate_param_control"

    [ "$_value" = "none" ] && return 0

    assert_cellname "$_value" || eval $(THROW 147)
    [ "$_level" -le 1 ] && return 0

    ctx_bootstrap_cell $_value "val_" || eval $(THROW 147 _cellref $_cell CJAIL $_value)
    return 0
}

validate_param_cpuset() {
    local _fn="validate_param_cpuset"

    [ "$_value" = "none" ] && return 0  # Must come first or will THROW cpuset

    assert_cpuset "$_value" || eval $(THROW 148)
    [ "$_level" -le 2 ] && return 0

    quiet cpuset -l "$_value" || eval $(THROW 148 $_fn $_cell $_value)
    return 0
}

validate_param_envsync() { ##########  STUB  FOR  NOW  ################################################################
    local _fn="validate_param_envsync"
    # [some test] || eval $(THROW 149 $_fn)
}

validate_param_gateway() {
    local _fn="validate_param_gateway"

    [ "$_value" = "none" ] && return 0

    assert_cellname "$_value" || eval $(THROW 150)

#COMMENTING THIS FOR NOW. Not sure if gateway problems should prevent a jail start.
#[ "$_level" -le 1 ] && return 0
#ctx_bootstrap_cell $_value "val_" || eval $(THROW 150 _cellref $_cell GATEWAY $_value)
}

validate_param_ipv4() {
    local _fn="validate_param_ipv4" _type _gw _gw_type _cli_confs

    case $_value in
        none|auto|DHCP) return 0 ;;
        *) assert_ipv4 $_value "true" || eval $(THROW 151) ;;
    esac
    [ "$_level" -le 1 ] && return 0

    # Validation differs by TYPE
    [ -z "$_type" ] && { _type=$(query_cell_type $_cell) || eval $(THROW 151) ;}

    # VM with CIDR is harmless, but warn user to prevent belief that it can be set like this
    [ "$_type" = "VM" ] && eval $(WARN $_fn $_cell) && return 0  # No addtl checks for impotent IPV4

    # Jails only. Pull relevant gateway information required for config/runtime guarantees
    _gw=$(query_cell_param $_cell GATEWAY) || eval $(THROW 151)
    _gw_type=$(query_cell_type $_gw) || eval $(THROW 151)
    _cli_confs=$(query_gw_client_configs $_gw)

    # Static config checks
    [ "$_gw" = "none" ] && return 0   # Nothing further to check
    [ "$_gw_type" = "VM" ] && eval $(WARN ${_fn}_2 $_gw) # VM-gw normally has DHCP (but not always)
    [ "$_cli_confs" ] && grep -Eqs "$_value" $_cli_confs \
        && eval $(THROW ${_fn} $_cell $_value $_gw)  # Direct config collision
    [ "$_level" -le 2 ] && return 0

    # Runtime collisions
    if is_cell_running $_gw ; then
        is_route_available $_gw $_value || eval $(THROW 151 ${_fn}_2 $_cell $_value $_gw)
    fi
}

validate_param_jconf() {
    local _fn="validate_param_jconf"

    # There is no JCONF for VMs. Return early
    [ -z "$_type" ] && { _type=$(query_cell_type $_cell) || eval $(THROW 151) ;}
    [ "$_type" = "VM" ] && return 0

    is_path_exist -f $_value || eval $(THROW 168)
}

validate_param_maxmem() {
    local _fn="validate_param_maxmem"

    [ "$_value" = "none" ] && return 0  # Must come first or will THROW bytesize

    assert_bytesize $_value || eval $(THROW 152)
    [ "$_level" -le 2 ] && return 0

    query_sysmem
    _bytes=$(normalize_bytesize $_value)
    assert_int_comparison -l "$SYSMEM" -- $_bytes || eval $(WARN $_fn $_cell $_value $_bytes $SYSMEM)
}

validate_param_memsize() {
    local _fn="validate_param_memsize" _bytes

    assert_bytesize $_value || eval $(THROW 153)
    [ "$_level" -le 2 ] && return 0

    query_sysmem
    _bytes=$(normalize_bytesize $_value)
    assert_int_comparison -l "$SYSMEM" -- $_bytes || eval $(WARN $_fn $_cell $_value $_bytes $SYSMEM)
}

validate_param_mtu() {
    local _fn="validate_param_mtu"
    assert_integer "$_value" || eval $(THROW 154)
    # THROW for IPv4 spec violations. WARN for IPv6 spec violation and > typical jumbo packet size
    assert_int_comparison -g 68 -l 65535 -- "$_value" || eval $(THROW 154 $_fn $_cell $_value 68 65535)
    assert_int_comparison -g 1280 -l 9000 -- "$_value" || eval $(WARN $_fn $_cell $_value 1280 9000)
}

validate_param_no_destroy() {
    local _fn="validate_param_no_destroy"
    assert_bool_tf $_value || eval $(THROW 155)
}

validate_param_ppt() {
    local _fn="validate_param_ppt"

    [ "$_value" = "none" ] && return 0

    assert_ppt "$_value" || eval $(THROW 156)
    [ "$_level" -le 2 ] && return 0

    _value=$(echo $_value | sed "s#/#:#g")
    for _ppt in $_value ; do
        _result=$(hush pciconf -l "pci$_ppt")
        [ "$_result" ] || eval $(THROW 156 $_fn $_cell $_ppt)
    done
    return 0
}

validate_param_p_dset() {
    local _fn="validate_param_p_dset"
    validate_dataset_generic || eval $(THROW 170)
}

validate_param_p_zfs() {
    local _fn="validate_param_p_zfs"
    validate_dataset_generic || eval $(THROW 157)
}

validate_param_rootenv() {
    local _fn="validate_param_rootenv"

    assert_cellname "$_value" || eval $(THROW 158)
    [ "$_level" -le 1 ] && return 0

    # Check the rootenv
    ctx_bootstrap_cell $_value "val_" || eval $(THROW 158 _cellref $_cell ROOTENV $_value)
}

validate_param_r_dset() {
    local _fn="validate_param_r_dset"
    validate_dataset_generic || eval $(THROW 169)
}

validate_param_r_zfs() {
    local _fn="validate_param_r_zfs"
    validate_dataset_generic || eval $(THROW 159)
}

validate_param_schg() {
    local _fn="validate_param_schg"
    assert_schg $_value || eval $(THROW 160)
}

validate_param_seclvl() {
    local _fn="validate_param_seclvl"
    assert_seclvl $_value || eval $(THROW 161)
}

validate_param_taps() {
    local _fn="validate_param_taps"
    assert_taps $_value || eval $(THROW 162)
}

# NOTES: _pfx ($3) isnt required, but speeds validation.
validate_param_template() {
    local _fn="validate_param_template" _class

    [ "$_value" = "none" ] && return 0

    assert_cellname "$_value" || eval $(THROW 163)
    [ "$_level" -le 1 ] && return 0

    # Pivot the check based on CLASS
    _class=$(ctx_get ${_pfx}CLASS)

    [ -z "$_class" ] && { _class=$(query_cell_param $_cell CLASS) || eval $(THROW 163) ;}

    case $_class in
        disp*) ctx_bootstrap_cell $_value "val_" \
                   || eval $(THROW 163 _cellref $_cell TEMPLATE $_value) ;;
        *)  : ;;  # Not a dispjail
    esac
    return 0
}

validate_param_tmux() {
    local _fn="validate_param_tmux"
    assert_bool_tf $_value || eval $(THROW 164)
}

validate_param_vcpus() {
    local _fn="validate_param_vcpus"

    assert_vcpus $_value || eval $(THROW 165)
    [ "$_level" -le 2 ] && return 0

    query_ncpus
    # Ensure that vpcus doesnt exceed the number of system cpus or bhyve limits
    { [ "$_value" -gt "$NCPU" ] || [ "$_value" -gt 16 ] ;} && eval $(THROW 165 $_fn $_cell $_value $NCPU)
    return 0
}

validate_param_vnc() {
    local _fn="validate_param_vnc"
    assert_bool_tf $_value || eval $(THROW 166)
}

validate_param_wiremem() {
    local _fn="validate_param_wiremem"
    assert_bool_tf $_value || eval $(THROW 167)
}

########################################  MISC VALIDATIONS  ########################################

validate_dataset_generic() {
    local _fn="validate_dataset_generic"

    assert_dataset_name $_value || eval $(THROW $?)
    [ "$_level" -le 1 ] && return 0

    is_zfs_exist "$_value" || eval $(THROW $? _missing_zfs $_cell $_value)
    return 0
}

validate_cellname() {
    local _fn="validate_cellname" _value="$1"
    assert_cellname "$_value" || eval $(THROW $?)
    [ "$_level" -le 1 ] && return 0

    is_path_exist -f $D_CELLS/$_value || eval $(THROW 181 $_fn $_value $D_CELLS)
}

# Validates that proposed cellname does not collide with existing cells, files, or datasets
validate_cellname_new() {
    local _fn="validate_cellname_new" _value="$_value" _r_zfs="$_cell" _u_zfs="$3"
    local _cellpath=$D_CELLS/$_value _jailpath=$D_JAILS/$_value
    assert_new_cellname $_value || eval $(THROW 182)

    # Check config file path and zfs dataset clobber.
    is_path_exist -f $_cellpath && eval $(THROW 182 $_fn $_value path $_cellpath)
    is_path_exist -f $_jailpath && eval $(THROW 182 $_fn $_value path $_jailpath)
    is_zfs_exist "$_r_zfs" && eval $(THROW 182 $_fn $_value dataset $_r_zfs)
    is_zfs_exist "$_u_zfs" && eval $(THROW 182 $_fn $_value dataset $_u_zfs)
    return 0      # No failures, cellname is available
}

