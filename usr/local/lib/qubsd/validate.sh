
##################################  SECTION 1: COMMON PARAMETERS  ################################## 

validate_param_autostart() {
    local _fn="validate_param_autostart"
    assert_bool_tf $1 || eval $(THROW 1)
}

validate_param_autosnap() {
    local _fn="validate_param_autosnap"
    assert_bool_tf $1 || eval $(THROW 1)
}

validate_param_backup() {
    local _fn="validate_param_backup"
    assert_bool_tf $1 || eval $(THROW 1)
}

validate_param_class() {
    local _fn="validate_param_class"
    assert_class $1 || eval $(THROW 1)
}

validate_param_control() {
    local _fn="validate_param_control"
    validate_cell_dependency $1 $2 && return 0 || eval $(THROW 1)
}

validate_param_envsync() { ############################################################################################
    local _fn="validate_param_envsync"
}

validate_param_gateway() {
    local _fn="validate_param_gateway"
    validate_cell_dependency $1 $2 && return 0 || eval $(THROW 1)
}

validate_param_ipv4() { 
    local _fn="validate_param_ipv4" _val="$1" _cell="$2" _type _gw _gw_class _cli_confs

    case $_val in 
        none|auto|DHCP) return 0 ;;  # Control values must return early (cant offload to checks.sh)
        *) assert_ipv4 $_val || eval $(THROW 1) ;;  # Purely checks for CIDR format
    esac

    [ "$_type" ] || _type=$(query_cell_type $_cell)  # Validation differs by TYPE. Guarantee value
    if [ "$_type" = "VM" ] ; then
        eval $(WARN $_fn $_cell)        # Assigned IPV4 is harmless, but warn user it does nothing
    else
        _gw=$(query_cell_param $_cell GATEWAY)
        _gw_type=$(query_cell_type $_gw)
        _cli_confs=$(query_gw_client_configs $_gw)

        is_route_available $_gw $_val || eval $(THROW 1 $_fn $_cell $_val $_gw)  # Runtime collision
        [ "$_cli_confs" ] && grep -Eqs "$_val" $_cli_confs \
                          && eval $(WARN ${_fn}2 $_cell $_val $_gw)              # Config collision
        [ "$_gw_type" = "VM" ] && eval $(WARN ${_fn}3 $_cell $_gw) # jail with VM-gw is usually DHCP 
    fi
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
    validate_cell_dependency $1 $2 && return 0 || eval $(THROW 1)
}

validate_param_r_zfs() {
    local _fn="validate_param_r_zfs"
    is_zfs_exist "$1" || eval $(THROW 1 missing_zfs $2 $1)
}

validate_param_template() {
    local _fn="validate_param_template" _val="$1" _cell="$2" _class

    # Pivot the check based on CLASS
    eval _class=\${${_prefix}CLASS}
    [ -z "$_class" ] && _class=$(query_cell_param $_cell CLASS)
    [ -z "$_class" ] && eval $(THROW $_fn $_cell $_val)

    case $_class in 
        disp*)  validate_cell_dependency $_val $_cell && return 0 || eval $(THROW 1) ;; # Hard dep
        *)  [ "$_class" = "none" ] && return 0
            validate_cell_dependency $_val $_cell && return 0 || eval $(WARN)
            ;;
    esac
    return 0
}

validate_param_u_zfs() {
    local _fn="validate_param_u_zfs"
    is_zfs_exist "$1" || eval $(THROW 1 missing_zfs $2 $1) 
}

###################################  SECTION 2: JAIL PARAMETERS  ################################### 

validate_param_cpuset() {
    local _fn="validate_param_cpuset" _val="$1"
    [ "$_val" = "none" ] && return 0
    assert_cpuset "$_val" || eval $(THROW 1)
    quiet cpuset -l "$_val" && return 0 || eval $(THROW 1 $_fn $2 $_val)
}

validate_param_maxmem() {
    local _fn="validate_param_maxmem" _val="$1" _sysmem
    [ "$_val" = "none" ] && return 0

    assert_bytesize $_val || eval $(THROW 1)
    _bytes=$(normalize_bytesize $_val) || { eval $(WARN memwarn $2) && return 0 ;}
    _sysmem=$(query_sysmem)            || { eval $(WARN memwarn $2) && return 0 ;}
    [ "$_bytes" -lt "$_sysmem" ] || { eval $(WARN $_fn $2 $_val $_bytes $_sysmem) && return 0 ;}
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
    assert_bhyveopts $1
}

validate_param_bhyve_custm() {
    local _fn="validate_param_bhyve_custm"
    return 0   # No validation. This is special, mostly for qb-create to launch a ISO installation
}

validate_param_memsize() {
    local _fn="validate_param_memsize" _val="$1" _bytes _sysmem
    assert_bytesize $_val || eval $(THROW 1)
    _bytes=$(normalize_bytesize $_val) || { eval $(WARN $_fn) && return 0 ;}
    _sysmem=$(query_sysmem)            || { eval $(WARN $_fn) && return 0 ;}
    [ "$_bytes" -lt "$_sysmem" ] || eval $(THROW 1 $_fn $2 $_val $_bytes $_sysmem)
}

validate_param_ppt() { #######################################################################################################
    local _fn="validate_param_ppt" _val="$1"
    [ "$_val" = "none" ] && return 0 ;
    for _ppt in $_val ; do
        quiet query_pci $_ppt || eval $(THROW 1 $_fn $2 $_ppt) ;
    done
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

    # Ensure that vpcus doesnt exceed the number of system cpus or bhyve limits
    _syscpus=$(cpuset -g | head -1 | grep -oE "[^ \t]+\$")
    : $(( _syscpus += 1 ))
    { [ "$_val" -gt "$_syscpus" ] || [ "$_val" -gt 16 ] ;} && eval $(THROW 1 $_fn $2 $1 $_syscpus)
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
    assert_cellname $_val || $(THROW 1)
    
    # Check config file path and zfs dataset clobber. MUTE because failure of `is_`, is passing.
    is_path_exist -f $_cellpath && $(THROW 1 $_fn $_val path $_cellpath)
    is_path_exist -f $_jailpath && $(THROW 1 $_fn $_val path $_jailpath)
    is_zfs_exist "$_r_zfs" && $(THROW 1 $_fn $_val dataset $_r_zfs)
    is_zfs_exist "$_u_zfs" && $(THROW 1 $_fn $_val dataset $_u_zfs)
    return 0      # No failures, cellname is available
} 


# IMPORTANT: This function depends on the parent passing _prefix and _type! 
validate_cell_dependency() {
    local _fn="validate_support_cell" _val="$1" _cellpath="$D_CELLS/$1" _jailpath="$D_JAILS/$1"
    eval local _r_zfs="${_prefix}R_ZFS" _u_zfs="${_prefix}U_ZFS"  # $_prefix must come from parents

    is_path_exist -f $_cellpath || $(THROW 1 $_fn $2 $_val $_cellpath)
    is_zfs_exist "$_r_zfs"      || $(THROW 1 missing_zfs $2 $_val dataset $_r_zfs)
    is_zfs_exist "$_u_zfs"      || $(THROW 1 missing_zfs $2 $_val dataset $_u_zfs)

    if [ "$_type" = "JAIL" ] ; then   # $_type must come from parents
        is_path_exist -f $_jailpath || $(THROW 1 $_fn $2 $_val $_jailpath)
    fi
    return 0
}

