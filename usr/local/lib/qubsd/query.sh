#!/bin/sh

############################################  HELPERS  #############################################

# Simplify common `echo | grep` operations, while still providing a quiet and delimiter option
echo_grep() {
    local _opts OPTARG OPTIND _delim _quiet

    while getopts :d:q _opts ; do case $_opts in
        d)  _delim="$OPTARG" ;;
        q)  _quiet="-qs" ;;
        *)  eval $(THROW 8 _internal1) ;;
    esac ; done ; shift $(( OPTIND - 1 ))

    if [ -z "$_delim" ] ; then
        echo "$1" | grep -E $_quiet "(^|[[:blank:]])$2([[:blank:]]|\$)"
    else
        echo "$1" | grep -E $_quiet "(^|$_delim)$2($_delim|\$)"
    fi
}

conv_to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

conv_to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

###################################  BOOLEAN RESPONSE QUERIES  #####################################

is_path_exist() {
    local _fn="is_path_exist"
    assert_args_set 2 "$1" "$2" || eval $(THROW $?)
    [ $1 $2 ] && return 0 || return 11
}

is_zfs_exist() {
    local _fn="is_zfs_exist"
    assert_args_set 1 "$1" || eval $(THROW $?)
    echo_grep -q "$DATASETS" "$1" && return 0  # First check DATASETS
    query_datasets "$1"  || eval $(THROW 121)     # Query if missing
    echo_grep -q "$DATASETS" "$1" && return 0 || return 121
}

is_cell_running() {
    local _fn="is_cell_running" _cell
    assert_args_set 1 "$1" && _cell="$1" || eval $(THROW $?)

    [ "$_cell" = "host" ] && return 0
    [ -z "$ONJAILS" ] && query_onjails
    [ -z "$ONVMS" ] && query_onvms
    echo_grep -q "$ONJAILS" "$_cell" && return 0
    echo_grep -q "$ONVMS" "bhyve: $_cell" && return 0
    return 200
}

# Method of discovering an IP collision in a gateway jail
is_route_available() {
    local _fn="is_route_available"
    assert_args_set 2 "$1" "$2" || eval $(THROW $?)
    route -nj "$1" get "${2%/*}" | grep -Eqs 'destination: (0|128.0.0.0)' && return 0 || return 211
}

# Determine if process is detached, but Xorg is running (needs a popup)
is_needpop() {
    ! ps -p $$ -o state | grep -qs -- '+' && pgrep -fq Xorg && return 0 || return 2
}

# Query the user for continuation. Optional $1='-s' to require a hard-type `yes' to continue
query_user_continue() {
    local _fn="query_user_response" _response
    [ "$1" ] && [ ! "$1" = '-s' ] && eval $(THROW _internal2 $1 $_fn)

    printf "%b" "    CONTINUE? (Y/n): "
    read _response
    case "$1:$_response" in
        '-s':yes|'-s':YES) return 0 ;;
        :y|:yes|:Y|:YES) return 0 ;;
        *) return 2 ;;
    esac
}

########################################  GET CELL CONFIG  #########################################

# Simple function for grepping the PARAM="..." convention in config files
query_file_param() {
    local _fn="query_file_param" _param _file _val
    assert_args_set 2 "$1" "$2" && _param="$1" _file="$2" || eval $(THROW $?)

    _val=$(sed -En "s/^[ \t]*$_param=\"(.*)\"[ \t]*/\1/p" $_file)
    [ "$_val" ] && echo $_val && return 0
    return 1
}

# Return [JAIL|VM] based on $1 CLASS. Bootstraps parameter sourcing
query_cell_type() {
    local _fn="query_cell_type" _cell _type
    assert_args_set 1 "$1" && _cell="$1" || eval $(THROW $?)
    is_path_exist -f $D_CELLS/$_cell || eval $(THROW 112 $_fn "$_cell" "$D_CELLS")

    # This function is used for bootstrap. Do not rely on external functions, direct `sed`
    _type=$(sed -En "s/CLASS=\"(.*)\"/\1/p" $D_CELLS/$_cell)
    case $_type in
        *jail) echo "JAIL" ;;
        *VM) echo "VM" ;;
        *) eval $(THROW 18 ${_fn}2 "$_cell") ;;
    esac

    return 0
}

# Single parameter extraction from cell config
query_cell_param() {
    local _fn="query_cell_param" _cell _param _val _type _def_type
    assert_args_set 2 "$1" "$2" && _cell="$1" _param="$2" || eval $(THROW $?)

    # Happy path -> parameter found immediately in the cell conf
    query_file_param $_param $D_CELLS/$_cell && return 0

    # Backup path -> check the defaults. type defaults prioritized over base defaults
    _type=$(query_cell_type $_cell) || eval $(THROW $?)
    eval _def_type=\${DEF_${_type}}
    query_file_param $_param $_def_type && return 0
    query_file_param $_param $_def_base && return 0

    # Failed to find a value for the parameter
    eval $(THROW 131 ${_fn} "$_param" "$_cell")
}

# Takes $1 PARAM and returns base|jail|vm, depending on where the highest level default lies
query_param_type() {
    local _fn="query_param_type"
    assert_args_set 1 "$1" || eval $(THROW $?)
    echo_grep -qd , "$PARAMS_BASE" "$1" && echo "base" && return 0
    echo_grep -qd , "$PARAMS_JAIL" "$1" && echo "jail" && return 0
    echo_grep -qd , "$PARAMS_VM"   "$1" && echo "vm"   && return 0
    return 132
}

# All clients that a gateway serves
query_gw_clients() {
    local _fn="query_gw_clients" _val
    assert_args_set 1 "$1" || eval $(THROW $?)
    _val=$(grep -Eo "GATEWAY=\"$1\"" $D_CELLS/* | sed -En "s|$D_CELLS/(.*):.*|\1|p")
    [ "$_val" ] && echo $_val && return 0 || return 133  # Not quoted -> returns single-line list
}

# Return the filenames of all the qubsd configs of a particular gateway
query_gw_client_configs() {
    local _fn="query_gw_client_configs" _val
    assert_args_set 1 "$1" || eval $(THROW $?)
    _val=$(grep -Eo "GATEWAY=\"$1\"" $D_CELLS/* | sed -En "s|^($D_CELLS/.*):.*|\1|p")
    [ "$_val" ] && echo $_val && return 0 || return 133  # Not quoted -> returns single-line list
}

# Provide either the explicit cell shell from /overlay, or use the 0env default
query_cell_shell() {
    local _fn="query_cell_shell" _cell _user _val
    assert_args_set 2 "$1" "$2" && _cell="$1" _user="$2" || eval $(THROW $?)

    # First check $_user at the source
    if [ "$_user" = "root" ] ; then
        _val=$(pw -V $R_MNT/$_cell/etc usershow -n root | awk -F':' '{print $10}')
    else
        _val=$(awk -F':' '{print $10}' $P_MNT/$_cell/$PW_LOC)
    fi

    # Fallback to the 0env default, or if not found, use hardcoded
    [ -z "$_val" ] && _val=$(awk -F':' '{print $10}' $P_MNT/0env/$PW_LOC)
    [ -z "$_val" ] && _val="/bin/csh"
    echo "$_val" && return 0
}

# All cells in the qconf. Newline delimited
query_qconf_cells_and_paths() {
    local _fn="query_qconf_filepaths"
    [ "$CELLS" ] && [ "$CELLS_QPATHS" ] && return 0  # No need to re-query
    CELLS="$(ls -1 $D_CELLS | grep -v "^host\$")"
    CELLS_QPATHS="$(ls -1 $D_CELLS | sed "s|^|$D_CELLS/|; s| | $D_CELLS/|g")"
}

# List the $1 (PARAM) value for all cells in $D_CELLS, with individual default-value resolution
query_param_values() {
    local _fn="query_param_values"
    local _param _param_type _defval_base _defval_jail _defval_vm _nomatch _jails _vms _sub
    assert_args_set 1 "$1" && _param="$1" || eval $(THROW $?)

    query_qconf_cells_and_paths  # Get list of all cells and their qconf paths
    _param_type=$(query_param_type $_param) || eval $(THROW $?)

    # Prepare default values for individual cell resolution
    _defval_base=$(sed -En "s|^$_param=\"(.*)\"|\1|p" $DEF_BASE)
    _defval_jail=$(sed -En "s|^$_param=\"(.*)\"|\1|p" $DEF_JAIL)
    _defval_vm=$(  sed -En "s|^$_param=\"(.*)\"|\1|p" $DEF_VM)

    # Cells without _param in qconf, need to be assigned to the default
    _nomatch=$(grep -EL "^$_param=" $CELLS_QPATHS)
    _jails=$(grep -E "^CLASS=\".*jail" $_nomatch)
    _vms=$(grep -E "^CLASS=\".*VM" $_nomatch)

    # Substitution priority: DEF_JAIL/VM -> DEF_BASE -> '#NULL'
    [ "$_jails" ]  && _sub=$_defval_jail
    [ -z "$_sub" ] && _sub=$_defval_base
    [ -z "$_sub" ] && _sub='#NULL'
    _jails=$(echo "$_jails" | tr -d '"' | sed -E "s|^$D_CELLS/||; s|:CLASS=.*| $_param $_sub|")
    unset _sub
    [ "$_vms" ]    && _sub=$_defval_vm
    [ -z "$_sub" ] && _sub=$_defval_base
    [ -z "$_sub" ] && _sub='#NULL'
    _vms=$(echo "$_vms" | tr -d '"' | sed -E "s|^$D_CELLS/||; s|:CLASS=.*| $_param $_sub|")

    # Echo the results back to caller
    grep -E "^$_param=" $CELLS_QPATHS | sed -E "s|^$D_CELLS/||; s|:$_param=| $_param |" | tr -d '"'
    [ "$_jails" ] && echo "$_jails"
    [ "$_vms" ]   && echo "$_vms"
}


#####################################  SYSTEM STATE QUERIES  #######################################
# ZFS queries may be passed $1 optionally to toggle pulling ALL datasets or only some

query_datasets() {
    local _fn="query_datasets" _dsets="$1" _pull

    # For each dataset passed, see if it's present. Assemble list of non-present datasets
    [ "$_dsets" ] && for _dset in $_dsets ; do
        echo_grep -q "$DATASETS" $_dset || _pull="$_pull $_dset"
    done
    [ -z "$_pull" ] && return 0   # All datasets already present (no duplicate pull)

    # Either add to the existing, or generate new DATASETS
    if [ "$DATASETS" ] ; then
        DATASETS=$(echo "$DATASETS" ; hush zfs list -Ho $DSET_PROPS $_pull) \
            || eval $(THROW 121)
    else
        DATASETS=$(hush zfs list -Ho $DSET_PROPS $_pull) || eval $(THROW 121)
    fi
    return 0
}

# Optimizes zfs queries when operating on multiple cells, by invoking just *one* zfs call.
# List recursive datasets of defaults parents. Will clobber old GLOBAL.
# OPTIONAL $1 [-s]: Pull and populate recursive SNAPSHOTS instead of DATASETS
query_zfs_recursive_defaults() {
    local _fn="query_datasets_recursive_defaults" _dsets _snaps
    [ "$1" = "-s" ] && _snaps_only='true'

    _dsets=$(query_file_param R_ZFS $DEF_BASE \
            ;query_file_param P_ZFS $DEF_BASE \
            ;query_file_param R_ZFS $DEF_JAIL \
            ;query_file_param P_ZFS $DEF_JAIL \
            ;query_file_param R_ZFS $DEF_VM   \
            ;query_file_param P_ZFS $DEF_VM)
    _dsets=$(echo "$_dsets" | sort | uniq)

    if [ -z "$_snaps_only" ] ; then
        DATASETS=$(hush zfs list -Hro $DSET_PROPS $_dsets) || eval $(THROW 120)
    else
        SNAPSHOTS=$(hush zfs list -t snapshot -Hro $SNAP_PROPS $_dsets) || eval $(THROW 120)
    fi
    return 0
}

query_rootsnaps() {
    local _fn="query_rootsnaps" _dsets="$1" _pull

    # For each snapshot passed, see if it's present. Assemble list of non-present snapshot
    [ "$_dsets" ] && for _dset in $_dsets ; do
        echo_grep -q "$ROOTSNAPS" $_dset || _pull="$_pull $_dset"
        [ -z "$_pull" ] && return 0    # All snapshots already present (no duplicate pull)
    done

    # Either add to the existing, or generate new ROOTSNAPS
    if [ "$ROOTSNAPS" ] ; then
        ROOTSNAPS=$(echo "$ROOTSNAPS" ; hush zfs list -Ht snapshot -o $SNAP_PROPS $1) \
            || eval $(THROW 122)
    else
        ROOTSNAPS=$(hush zfs list -Ht snapshot -o $SNAP_PROPS $1) \
            || eval $(THROW 122)
    fi
    return 0
}

query_persistsnaps() {
    local _fn="query_persistsnaps"
    if [ "$PERSISTSNAPS" ] ; then
        PERSISTSNAPS=$(echo "$PERSISTSNAPS" ; hush zfs list -Ht snapshot -o $SNAP_PROPS $1) \
            || eval $(THROW 123)
    else
        PERSISTSNAPS=$(zfs list -Ht snapshot -o $SNAP_PROPS $1) || eval $(THROW 123)
    fi
    return $?
}

query_zfs_mountpoint() {
    local _fn="query_zfs_mountpoint"
    assert_args_set 1 "$1" || eval $(THROW $?)
    echo_grep "$DATASETS" "$1" | awk '{print $2}' && return 0 || return 121
}

query_onjails() {
    local _fn="query_onjails" _onjails
    if [ "$ONJAILS" ] ; then
        _onjails=$(jls | sed "1 d" | awk '{print $2}') || eval $(THROW 201)
        ONJAILS=$(echo "$ONJAILS" ; echo "$_onjails")
    else
        ONJAILS=$(jls | sed "1 d" | awk '{print $2}') || eval $(THROW 201)
    fi
    return 0
}

query_onvms() {
    local _fn="query_onvms"
    ONVMS=$(pgrep -fl "daemon: bhyve:" | sed "s/\[.*]\$//") || eval $(THROW 202)
    return 0
}

query_sysmem() {
    local _fn="query_sysmem"
    [ -z "$SYSMEM" ] && SYSMEM=$(grep -s "avail memory" /var/run/dmesg.boot \
                                | sed "s/.* = //" | sed "s/ (.*//" | tail -1)
    [ -z "$SYSMEM" ] && eval $(THROW 221)
    return 0
}

query_num_cpus() {
    local _fn="query_ncpu"
    [ -z "$NCPU" ] && NCPU=$(sysctl -n hw.ncpu)
    [ -z "$NCPU" ] && eval $(THROW 222)
}

# With $1 < cell>, all active IPaddr of a running jail. Without $1, active IPs of all running jails
query_running_ips() {
    local _fn="query_used_ips" _cell="$1" _val _onjails _jail_ips

    if [ "$_cell" ] ; then
        _val=$(ifconfig -j $_cell -a inet | awk '/inet / {print $2}')
    else
        query_onjails
        for _jail in $ONJAILS ; do
            _jail_ips=$(ifconfig -j $_jail -a inet | awk '/inet / {print $2}')
            _val=$(printf "%b" "$_val" "\n" "$_jail_ips")
        done
    fi
    [ "$_val" ] && echo $_val && return 0 || return 212  # Not quoted -> returns single-line list
}


##########################################  X11 QUERIES  ###########################################

query_net_active_xid() {
    local _fn="query_net_active_xid" _val
    _val=$(xprop -root _NET_ACTIVE_WINDOW | sed "s/.*window id # //") \
        || eval $(THROW 231 xfail XID)
    [ "$_val" ] && echo "$_val" && return 0 || eval $(THROW 231 xfail XID)
}

query_xwin_name() {
    local _fn="query_xwin_name" _xid _val
    _xid=$(query_net_active_xid) || eval $(THROW $?)
    _val=$(xprop -id "$_xid" WM_NAME _NET_WM_NAME WM_CLASS) || eval $(THROW 232)
    [ "$_val" ] && echo "$_val" && return 0 || eval $(THROW 232)
}

query_xwin_socket() {
    local _fn="query_xwin_socket" _xid _val
    _xid=$(query_net_active_xid) || eval $(THROW $?)
    _val=$(xprop -id $_xid | sed -En "s/^WM_NAME.*:([0-9]+)\..*/\1/p") || eval $(THROW 233)
    [ "$_val" ] && echo "$_val" && return 0 || eval $(THROW 233)
}

query_xwin_pid() {
    local _fn="query_xwin_pid" _xid _val
    _xid=$(query_net_active_xid) || eval $(THROW $?)
    _val=$(xprop -id $_xid _NET_WM_PID | grep -Eo "[[:alnum:]]+$") || eval $(THROW 234)
    [ "$_val" ] && echo "$_val" && return 0 || $(THROW 234)
}

query_xwin_cellname() {
    local _fn="query_xwin_cellname" _xid _xsock _val

    _xid=$(query_net_active_xid) || eval $(THROW $?)
    if [ "$_xid" = "0x0" ] || echo "$_xid" | grep -Eq "not found" \
                           || xprop -id $_xid WM_CLIENT_MACHINE | grep -Eq $(hostname) ; then
        _val=host
    else
        _xsock=$(xprop -id $_xid | sed -En "s/^WM_NAME.*:([0-9]+)\..*/\1/p")
        _val=$(pgrep -fl "X11-unix/X${_xsock}" | head -1 | sed -En \
              "s@.*var/run/qubsd/X11/(.*)/.X11-unix/X${_xsock},.*@\1@p")
    fi
    [ "$_val" ] && echo "$_val" && return 0 || eval $(THROW 235)
}

# Use vertical res to derive popup dimensions.
_resolve_popup_dimensions() {
    local _fn="_resolve_popup_dimensions" _h=.25 _w=2.5 _res

    # Adjust _res that based on inputs from the caller
    local _res=$(xrandr | sed -En "s/.*connected primary.*x([0-9]+).*/\1/p") || eval $(THROW 236 $_fn)
    [ "$_res" ] || eval $(THROW 1 $_fn)

    _h=$(echo "scale=0 ; $_res * $_h" | bc | cut -d. -f1) || eval $(THROW 236 $_fn)
    _w=$(echo "scale=0 ; $_h * $_w" | bc | cut -d. -f1)   || eval $(THROW 236 $_fn)
    [ "${_w}${_h}" ] && echo "$_w $_h" || eval $(THROW 236)
}

# Intelligently calculate fontsize for popups based on monitor vs system DPI
_resolve_popup_fontsize() {
    local _fn="_resolve_popup_fontsize" _val _dpi_mon _dpi_sys

    # If there's a system font size set, use that at .75 size factor.
    _fs=$(appres XTerm xterm | sed -En "s/XTerm.*faceSize:[ \t]+([0-9]+).*/\1/p")

    if [ -z "$_fs" ] ; then
        # If no fs, use the ratio of monitor DPI to system DPI to scale font size
        local _dpi_mon=$(xdpyinfo | sed -En "s/[ \t]+resolution.*x([0-9]+).*/\1/p")
        local _dpi_sys=$(xrdb -query | sed -En "s/.*Xft.dpi:[ \t]+([0-9]+)/\1/p")
        [ -z "$_dpi_sys" ] && _dpi_sys=96  # Fallback default
        # fs of 15 is a sane value when both monitor and system DPI is at default of 96
        _val=$(echo "scale=0 ; ($_dpi_mon / $_dpi_sys) * 15" | bc | cut -d. -f1)
    else
        _val=$(echo "scale=0 ; $_fs * .75" | bc | cut -d. -f1)
    fi
    [ -z "$_val" ] && _val=15   # Last resort hard coded backup
    echo "$_val"
}


