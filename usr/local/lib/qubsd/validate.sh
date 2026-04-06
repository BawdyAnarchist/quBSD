#!/bin/sh

validate_param_autostart() {
    local _fn="validate_param_autostart"
    [ -z "$_value" ] && return 0  # Not critical
    assert_bool_tf $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_autosnap() {
    local _fn="validate_param_autosnap"
    [ -z "$_value" ] && return 0  # Not critical
    assert_bool_tf $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_backup() {
    local _fn="validate_param_backup"
    [ -z "$_value" ] && return 0  # Not critical
    assert_bool_tf $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_bhyveopts() {
    local _fn="validate_param_bhyveopts"
    [ -z "$_value" ] && return 0  # Not critical
    assert_bhyveopts $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_bhyve_custm() {
    local _fn="validate_param_bhyve_custm"
    [ -z "$_value" ] && return 0  # Not critical
    assert_bhyve_custm $_value || eval $(THROW $? _invalid "$_param" "$_value")
    return 0
}

validate_param_class() {
    local _fn="validate_param_class"
    assert_class $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_control() {
    local _fn="validate_param_control"

    [ "$_value" = "none" ] && return 0

    assert_cellname "$_value" || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 1 ] && return 0

    ctx_bootstrap_cell $_value "val_" || eval $(THROW 147 _invalid "$_param" "$_value")
    return 0
}

validate_param_cpuset() {
    local _fn="validate_param_cpuset"
    [ -z "$_value" ] && return 0  # Not critical
    [ "$_value" = "none" ] && return 0  # Must come first or will THROW cpuset

    assert_cpuset "$_value" || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 2 ] && return 0

    quiet cpuset -l "$_value" || eval $(THROW 148 $_fn "$_param" "$_value")
    return 0
}

validate_param_devfs_rule() {
    local _fn="validate_devfs_rule"
    assert_devfs_rule $_value || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 1 ] && return 0

    grep -Eqs "^\[.*=$_value\]" $DEVFS || eval $(THROW 171 $_fn "$_param" "$_value" $DEVFS)

    return 0
}

validate_param_envsync() { ##########  STUB  FOR  NOW  #############
    local _fn="validate_param_envsync"
    # [some test] || eval $(THROW 149 $_fn)
}

validate_param_gateway() {
    local _fn="validate_param_gateway"

    [ -z "$_value" ] && return 0  # Not critical
    [ "$_value" = "none" ] && return 0

    assert_cellname "$_value" || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 1 ] && return 0

    ctx_bootstrap_cell $_value "val_" || eval $(WARN _invalid "$_param" "$_value")
}

validate_param_ipv4() {
    local _fn="validate_param_ipv4" _type _gw _gw_type _cli_confs

    case $_value in
        ''|none|auto|DHCP) return 0 ;;
        *) assert_ipv4 $_value || eval $(THROW $? _invalid "$_param" "$_value") ;;
    esac
    [ "$_level" -le 1 ] && return 0

    # VM with CIDR is harmless, but warn user to prevent belief that it can be set like this
    _type=$(ctx_get ${_pfx}TYPE)
    [ "$_type" = "VM" ] && eval $(WARN $_fn) && return 0  # No addtl checks for impotent IPV4

    # Jails only. Pull relevant gateway information required for config/runtime guarantees
    _gw=$(query_cell_param "$_cell" GATEWAY) || eval $(THROW 151 _invalid "$_param" "$_value")
    _gw_type=$(query_cell_type $_gw) || eval $(THROW 151 _invalid "$_param" "$_value")
    _cli_confs=$(query_gw_client_configs $_gw | sed -E "s|$D_CELLS/$_cell||")

    # Static config checks
    [ "$_gw" = "none" ] && return 0   # Nothing further to check
    [ "$_gw_type" = "VM" ] && eval $(WARN ${_fn}_2 $_gw) # VM-gw normally has DHCP (but not always)
    [ "$_cli_confs" ] && grep -Eqs "$_value" $_cli_confs \
        && eval $(THROW 151 ${_fn}_3 "$_cell" "$_value" "$_gw")  # Direct config collision
    [ "$_level" -le 2 ] && return 0

    # Runtime collisions
    if is_cell_running $_gw ; then
        is_route_available $_gw $_value || eval $(THROW 151 ${_fn}_4 "$_cell" "$_value" "$_gw")
    fi
}

validate_param_jconf() {
    local _fn="validate_param_jconf" _type
    _type=$(ctx_get ${_pfx}TYPE)
    [ "$_type" = "VM" ] && return 0
    is_path_exist -f $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_maxmem() {
    local _fn="validate_param_maxmem"

    [ -z "$_value" ] && return 0  # Not critical
    [ "$_value" = "none" ] && return 0  # Must come first or will THROW bytesize

    assert_bytesize $_value || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 2 ] && return 0

    query_sysmem
    _bytes=$(normalize_bytesize $_value)
    assert_int_comparison -l "$SYSMEM" -- $_bytes \
        || eval $(WARN $_fn $_bytes "$_param" "$_value" $SYSMEM)
}

validate_param_memsize() {
    local _fn="validate_param_memsize" _bytes

    assert_bytesize $_value || eval $(THROW $? "$_param" "$_value")
    [ "$_level" -le 2 ] && return 0

    query_sysmem
    _bytes=$(normalize_bytesize $_value)
    assert_int_comparison -l "$SYSMEM" -- $_bytes \
        || eval $(THROW 153 $_fn "$_bytes" "$_param" "$_value" "$SYSMEM")
}

validate_param_mtu() {
    local _fn="validate_param_mtu"

    [ -z "$_value" ] && return 0  # Not critical
    assert_integer "$_value" || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 1 ] && return 0

    # THROW for IPv4 spec violations. WARN for IPv6 spec violation and > typical jumbo packet size
    assert_int_comparison -g 68 -l 65535 -- "$_value" || eval $(THROW 154 $_fn "$_value" 68 65535)
    assert_int_comparison -g 1280 -l 9000 -- "$_value" || eval $(WARN ${_fn}_2 "$_value" 1280 9000)
}

validate_param_no_destroy() {
    local _fn="validate_param_no_destroy"
    [ -z "$_value" ] && return 0  # Not critical
    assert_bool_tf $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_ppt() {
    local _fn="validate_param_ppt"

    [ -z "$_value" ] && return 0  # Not critical
    [ "$_value" = "none" ] && return 0

    assert_ppt "$_value" || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 2 ] && return 0

    _value=$(echo $_value | sed "s#/#:#g")
    for _ppt in $_value ; do
        _result=$(hush pciconf -l "pci$_ppt")
        [ "$_result" ] || eval $(THROW 156 _invalid "$_param" "$_ppt")
    done
    return 0
}

validate_param_p_dset() {
    local _fn="validate_param_p_dset"

    assert_dataset_name $_value || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 1 ] && return 0

    is_zfs_exist "$_value" || eval $(THROW 170 _missing_zfs "$_value")
}

validate_param_p_zfs() {
    local _fn="validate_param_p_zfs"
    assert_dataset_name $_value || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 1 ] && return 0

    is_zfs_exist "$_value" || eval $(THROW 170 _missing_zfs "$_value")
}

validate_param_rootenv() {
    local _fn="validate_param_rootenv"

    assert_cellname "$_value" || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 1 ] && return 0

    # Check the rootenv
    ctx_bootstrap_cell $_value "val_" || eval $(THROW 158 _invalid "$_param" "$_value")
}

validate_param_r_dset() {
    local _fn="validate_param_r_dset"

    assert_dataset_name $_value || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 1 ] && return 0

    is_zfs_exist "$_value" || eval $(THROW 169 _missing_zfs "$_value")
}

validate_param_r_zfs() {
    local _fn="validate_param_r_zfs"

    assert_dataset_name $_value || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 1 ] && return 0

    is_zfs_exist "$_value" || eval $(THROW 169 _missing_zfs "$_value")
}

validate_param_schg() {
    local _fn="validate_param_schg"
    [ -z "$_value" ] && return 0  # Not critical
    assert_schg $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_seclvl() {
    local _fn="validate_param_seclvl"
    [ -z "$_value" ] && return 0  # Not critical
    assert_seclvl $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_taps() {
    local _fn="validate_param_taps"
    [ -z "$_value" ] && return 0  # Not critical
    assert_taps $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_template() {
    local _fn="validate_param_template" _class

    [ -z "$_value" ] && return 0  # Not critical
    [ "$_value" = "none" ] && return 0

    assert_cellname "$_value" || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 1 ] && return 0

    # Pivot the check based on CLASS
    _class=$(ctx_get ${_pfx}CLASS)
    case $_class in
        disp*) ctx_bootstrap_cell $_value "val_" \
                   || eval $(THROW 163 _invalid "$_param" "$_value") ;;
        *)  : ;;  # Not a dispjail
    esac
    return 0
}

validate_param_tmux() {
    local _fn="validate_param_tmux"
    [ -z "$_value" ] && return 0  # Not critical
    assert_bool_tf $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_vcpus() {
    local _fn="validate_param_vcpus"

    assert_vcpus $_value || eval $(THROW $? _invalid "$_param" "$_value")
    [ "$_level" -le 2 ] && return 0

    query_ncpus
    # Ensure that vpcus doesnt exceed the number of system cpus or bhyve limits
    { [ "$_value" -gt "$NCPU" ] || [ "$_value" -gt 16 ] ;} && eval $(THROW 165 $_fn "$_param" "$_value" "$NCPU")
    return 0
}

validate_param_vnc() {
    local _fn="validate_param_vnc"
    [ -z "$_value" ] && return 0  # Not critical
    assert_bool_tf $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

validate_param_wiremem() {
    local _fn="validate_param_wiremem"
    [ -z "$_value" ] && return 0  # Not critical
    assert_bool_tf $_value || eval $(THROW $? _invalid "$_param" "$_value")
}

########################################  MISC VALIDATIONS  ########################################

validate_cellname() {
    local _fn="validate_cellname" _value="$1"
    assert_cellname "$_value" || eval $(THROW $?)
    [ "$_level" -le 1 ] && return 0

    is_path_exist -f $D_CELLS/$_value || eval $(THROW 181 $_fn "$_value" $D_CELLS)
}

# Validates that proposed cellname does not collide with existing cells, files, or datasets
validate_cellname_new() {
    local _fn="validate_cellname_new" _value="$_value" _r_zfs="$_cell" _u_zfs="$3"
    local _cellpath=$D_CELLS/$_value _jailpath=$D_JAILS/$_value
    assert_new_cellname $_value || eval $(THROW 182)

    # Check config file path and zfs dataset clobber.
    is_path_exist -f $_cellpath && eval $(THROW 182 $_fn "$_value" path "$_cellpath")
    is_path_exist -f $_jailpath && eval $(THROW 182 $_fn "$_value" path "$_jailpath")
    is_zfs_exist "$_r_zfs" && eval $(THROW 182 $_fn "$_value" dataset "$_r_zfs")
    is_zfs_exist "$_u_zfs" && eval $(THROW 182 $_fn "$_value" dataset "$_u_zfs")
    return 0      # No failures, cellname is available
}

