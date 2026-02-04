
##################################  SECTION 1: COMMON PARAMETERS  ################################## 

validate_param_autostart() {
    local _fn="validate_param_autostart"
    chk_bool_tf $1 || eval $(THROW)
}

validate_param_autosnap() {
    local _fn="validate_param_autosnap"
    chk_bool_tf $1 || eval $(THROW)
}

validate_param_backup() {
    local _fn="validate_param_backup"
    chk_bool_tf $1 || eval $(THROW)
}

validate_param_class() { ############
    local _fn="validate_param_class"
    chk_class $1 || eval $(THROW)
}

validate_param_control() { ############
    local _fn="validate_param_control"
 
}

validate_param_envsync() { ############
    local _fn="validate_param_envsync"
    
}

validate_param_gateway() { ############
    local _fn="validate_param_gateway"
    
}

validate_param_ipv4() { ############
    local _fn="validate_param_ipv4"
    chk_ipv4 $1
}

validate_param_mtu() { ############
    local _fn="validate_param_mtu" _val="$1"
    chk_integer "$_val" || eval $(THROW)
    normalize_integer -g 1200 -l 1600 -- "$_val" || eval $(THROW $_fn MTU $_val 1200 1600)
}

validate_param_no_destroy() {
    local _fn="validate_param_no_destroy"
    chk_bool_tf $1 || eval $(THROW)
}

validate_param_rootenv() {
    local _fn="validate_param_rootenv"
    
}

validate_param_template() {
    local _fn="validate_param_template"
    
}

validate_param_r_zfs() {
    local _fn="validate_param_r_zfs"
    
}

validate_param_u_zfs() {
    local _fn="validate_param_u_zfs"
    
}

###################################  SECTION 2: JAIL PARAMETERS  ################################### 

validate_param_cpuset() {
    local _fn="validate_param_cpuset"
    
}

validate_param_maxmem() {
    local _fn="validate_param_maxmem" _val="$1" _sysmem
    chk_bytesize $_val || eval $(THROW)
    _bytes=$(normalize_bytesize $_val) || eval $(THROW)
    _sysmem=$(query_sysmem) || eval $(THROW)
    [ "$_bytes" -lt "$_sysmem" ] || eval $(THROW $_fn $_val $_bytes $_sysmem)
}

validate_param_schg() {
    local _fn="validate_param_schg"
    
}

validate_param_seclvl() {
    local _fn="validate_param_seclvl"
    
}

##################################  SECTION 3: BHYVE PARAMETERS  ################################### 

validate_param_bhyveopts() {
    local _fn="validate_param_bhyveopts"
    chk_bhyveopts $1
}

validate_param_bhyve_custm() {
    local _fn="validate_param_bhyve_custm"
    
}

validate_param_memsize() {
    local _fn="validate_param_memsize" _val="$1" _bytes _sysmem
    chk_bytesize $_val || eval $(THROW)
    _bytes=$(normalize_bytesize $_val) || eval $(THROW)
    _sysmem=$(query_sysmem) || eval $(THROW)
    [ "$_bytes" -lt "$_sysmem" ] || eval $(THROW $_fn $_val $_bytes $_sysmem)
}

validate_param_ppt() {
    local _fn="validate_param_ppt"
    
}

validate_param_taps() {
    local _fn="validate_param_taps"
    
}

validate_param_tmux() {
    local _fn="validate_param_tmux"
    
}

validate_param_vcpus() {
    local _fn="validate_param_vcpus"
    
}

validate_param_vnc() {
    local _fn="validate_param_vnc"
    chk_bool_tf $1 || eval $(THROW)
}

validate_param_wiremem() {
    local _fn="validate_param_wiremem"
    chk_bool_tf $1 || eval $(THROW)
}
