#!/bin/sh

############################################  HELPERS  #############################################

echo_grep() {
    echo "$1" | grep -E "(^|[[:blank:]])$2([[:blank:]]|\$)"
}

###################################  BOOLEAN RESPONSE QUERIES  #####################################

is_path_exist() {
    local _fn="is_path_exist"
    assert_args_set 2 $1 $2 || eval $(THROW 1)
    [ $1 $2 ] && return 0 || return 1
}

is_zfs_exist() {
    local _fn="is_zfs_exist"
    assert_args_set 1 $1 || eval $(THROW 1)
    quiet echo_grep "$DATASETS" "$1" && return 0  # First check DATASETS
    query_datasets "$1"                           # Query if missing
    quiet echo_grep "$DATASETS" "$1" && return 0 || return 1
}

is_cell_running() {
    local _fn="is_cell_running" _cell="$1"
    assert_args_set 1 $_cell || eval $(THROW 1)

    [ "$_cell" = "host" ] && return 0
    query_onjails
    query_onvms
    quiet echo_grep "$ONJAILS" "$_cell" && return 0
    quiet echo_grep "$ONVMS" "bhyve: $_cell" && return 0
    return 1
}

# Method of discovering an IP collision in a gateway jail
is_route_available() {
    local _fn="is_route_available"
    assert_args_set 2 $1 $2 || eval $(THROW 1)
    route -nj "$1" get "${2%/*}" | grep -Eqs 'destination: (0|128.0.0.0)' && return 0 || return 1
}

# Determine if process is detached, but Xorg is running (needs a popup)
is_needpop() {
    ! ps -p $$ -o state | grep -qs -- '+' && pgrep -fq Xorg && return 0 || return 1
}

# return 0 for "Y/y". Optional $1=`severe` for a hard-typed `yes` required from the user
is_user_response() {
    local _fn="query_user_response" _response

    read _response
    _response=$(echo $_response | tr '[:upper:]' '[:lower:]')

    case "$1:$_response" in
        severe:yes) return 0 ;; # Positional param `severe` requires full `yes'
        :y|:yes) return 0 ;;
        *) return 1 ;;
    esac
}

########################################  GET CELL CONFIG  #########################################

# Return [JAIL|VM] based on $1 CLASS. Bootstraps parameter sourcing
query_cell_type() {
    local _fn="query_cell_type" _cell _type
    assert_args_set 1 $1 && _cell="$1" || eval $(THROW 1)
    is_path_exist -f $D_CELLS/$_cell || eval $(THROW 1 $_fn $_cell $D_CELLS)

    # This function is used for bootstrap. Do not rely on external functions. Hardcode CLASS
    _type=$(sed -En "s/CLASS=\"(.*)\"/\1/p" $D_CELLS/$_cell)
    case $_type in
        *jail) echo "JAIL" ;;
        *VM) echo "VM" ;;
        *) eval $(THROW 1 ${_fn}2 $_cell $_type) ;;
    esac

    return 0
}

# Single parameter extraction from cell config
query_cell_param() {
    local _fn="query_cell_param" _cell="$1" _param="$2" _val _type _def_type
    assert_args_set 2 $_cell $_param || eval $(THROW 1)

    # Happy path -> parameter found immediately in the cell conf
    _val=$(sed -En "s/^[ \t]*$_param=\"(.*)\"[ \t]*/\1/p" $D_CELLS/$_cell)
    [ "$_val" ] && echo "$_val" && return 0

    # Backup path -> check the defaults
    _type=$(query_cell_type $_cell) || eval $(THROW 1)
    eval _def_type=\${DEF_${_type}}

    # _type defaults are prioritized over base defaults
    _val=$(sed -En "s/^[ \t]*$_param=\"(.*)\"[ \t]*/\1/p" $_def_type)
    [ "$_val" ] && echo "$_val" && return 0

    _val=$(sed -En "s/^[ \t]*$_param=\"(.*)\"[ \t]*/\1/p" $DEF_BASE)
    [ "$_val" ] && echo "$_val" && return 0

    # Failed to find a value for the parameter
    eval $(THROW 1 ${_fn} $_param $_cell)
}

# All clients that a gateway serves
query_gw_clients() {
    local _fn="query_gw_clients" _val
    assert_args_set 1 $1 || eval $(THROW 1)
    _val=$(grep -Eo "GATEWAY=\"$1\"" $D_CELLS/* | sed -En "s|$D_CELLS/(.*):.*|\1|p")
    [ "$_val" ] && echo $_val && return 0 || return 1  # Not quoted -> returns single-line list
}

# Return the filenames of all the qubsd configs of a particular gateway
query_gw_client_configs() {
    local _fn="query_gw_client_configs" _val
    assert_args_set 1 $1 || eval $(THROW 1)
    _val=$(query_gw_clients $1 | sed "s|^|$D_CELLS/|; s| | $D_CELLS/|g")
    [ "$_val" ] && echo $_val && return 0 || return 1  # Not quoted -> returns single-line list
}

# Provide either the explicit cell shell from /overlay, or use the 0env default
query_cell_shell() {
    local _fn="query_cell_shell" _cell="$1" _user="$2" _val
    assert_args_set 2 $_cell $_user || eval $(THROW 1)

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

#####################################  SYSTEM STATE QUERIES  #######################################
# ZFS queries may be passed $1 optionally to toggle pulling ALL datasets or only some

query_datasets() {
    local _fn="query_datasets" _dsets="$1" _pull

    # For each dataset passed, see if it's present. Assemble list of non-present datasets
    [ "$_dsets" ] && for _dset in $_dsets ; do
        quiet echo_grep "$DATASETS" $_dset || _pull="$_pull $_dset"
        [ -z "$_pull" ] && return 0   # All datasets already present (no duplicate pull)
    done

    # Either add to the existing, or generate new DATASETS
    if [ "$DATASETS" ] ; then
        DATASETS=$(echo "$DATASETS" ; zfs list -rHo name,mountpoint,mounted,origin,encryption $_pull)
    else
        DATASETS=$(zfs list -rHo name,mountpoint,mounted,origin $_pull)
    fi
    return $?
}

query_rootsnaps() {
    local _fn="query_rootsnaps" _dsets="$1" _pull

    # For each snapshot passed, see if it's present. Assemble list of non-present snapshot
    [ "$_dsets" ] && for _dset in $_dsets ; do
        quiet echo_grep "$DATASETS" $_dset || _pull="$_pull $_dset"
        [ -z "$_pull" ] && return 0    # All snapshots already present (no duplicate pull)
    done

    # Either add to the existing, or generate new ROOTSNAPS
    if [ "$ROOTSNAPS" ] ; then
        ROOTSNAPS=$(echo "$ROOTSNAPS" ; zfs list -Hrt snapshot -o name,written,creation $1)
    else
        ROOTSNAPS=$(zfs list -Hrt snapshot -o name,written,creation $1)
    fi
    return $?
}

query_prstsnaps() {
    local _fn="query_prstsnaps"
    if [ "$PRSTSNAPS" ] ; then
        PRSTSNAPS=$(echo "$PRSTSNAPS" ; zfs list -Hrt snapshot -o name,written,creation $1)
    else
        PRSTSNAPS=$(zfs list -Hrt snapshot -o name,written,creation $1)
    fi
    return $?
}

query_zfs_mountpoint() {
    local _fn="query_zfs_mountpoint"
    assert_args_set 1 "$1"
    echo_grep "$DATASETS" "$1" | awk '{print $2}' && return 0 || return 1
}

query_onjails() {
    local _fn="query_onjails" _onjails
    if [ "$ONJAILS" ] ; then
        _onjails=$(jls | sed "1 d" | awk '{print $2}')
        ONJAILS=$(echo "$ONJAILS" ; echo "$_onjails")
    else
        ONJAILS=$(jls | sed "1 d" | awk '{print $2}')
    fi
    return $?
}

query_onvms() {
    local _fn="query_onvms"
    ONVMS=$(pgrep -fl "daemon: bhyve:" | sed "s/\[.*]\$//")
    return 0
}

query_sysmem() {
    local _fn="query_sysmem"
    [ -z "$SYSMEM" ] && SYSMEM=$(grep -s "avail memory" /var/run/dmesg.boot \
                                | sed "s/.* = //" | sed "s/ (.*//" | tail -1)
    return 0
}

query_num_cpus() {
    local _fn="query_ncpu"
    [ -z "$NCPU" ] && NCPU=$(sysctl -n hw.ncpu)
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
    [ "$_val" ] && echo $_val && return 0 || return 1  # Not quoted -> returns single-line list
}


##########################################  X11 QUERIES  ###########################################

query_net_active_xid() {
    local _fn="query_net_active_xid" _val
    _val=$(xprop -root _NET_ACTIVE_WINDOW | sed "s/.*window id # //") \
        || eval $(THROW 1 xfail XID)
    [ "$_val" ] && echo "$_val" && return 0 || return 1
}

query_xwin_name() {
    local _fn="query_xwin_name" _xid _val
    _xid=$(query_net_active_xid) || return 1
    _val=$(xprop -id "$_xid" WM_NAME _NET_WM_NAME WM_CLASS) || return 1
    [ "$_val" ] && echo "$_val" && return 0 || return 1
}

query_xwin_socket() {
    local _fn="query_xwin_socket" _xid _val
    _xid=$(query_net_active_xid) || return 1
    _val=$(xprop -id $_xid | sed -En "s/^WM_NAME.*:([0-9]+)\..*/\1/p") || return 1
    [ "$_val" ] && echo "$_val" && return 0 || return 1
}

query_xwin_pid() {
    local _fn="query_xwin_pid" _xid _val
    _xid=$(query_net_active_xid) || eval $(THROW 1)
    _val=$(xprop -id $_xid _NET_WM_PID | grep -Eo "[[:alnum:]]+$") || return 1
    [ "$_val" ] && echo "$_val" && return 0 || return 1
}

query_xwin_cellname() {
    local _fn="query_xwin_cellname" _xid _xsock _val

    _xid=$(query_net_active_xid) || return 1
    if [ "$_xid" = "0x0" ] || echo "$_xid" | grep -Eq "not found" \
                           || xprop -id $_xid WM_CLIENT_MACHINE | grep -Eq $(hostname) ; then
        _val=host
    else
        _xsock=$(xprop -id $_xid | sed -En "s/^WM_NAME.*:([0-9]+)\..*/\1/p")
        _val=$(pgrep -fl "X11-unix/X${_xsock}" | head -1 | sed -En \
              "s@.*var/run/qubsd/X11/(.*)/.X11-unix/X${_xsock},.*@\1@p")
    fi
    [ "$_val" ] && echo "$_val" && return 0 || return 1
}

# Use vertical res to derive popup dimensions.
_resolve_popup_dimensions() {
    local _fn="_resolve_popup_dimensions" _h=.25 _w=2.5 _res

    # Adjust _res that based on inputs from the caller
    local _res=$(xrandr | sed -En "s/.*connected primary.*x([0-9]+).*/\1/p") || eval $(THROW 1 $_fn)
    [ "$_res" ] || eval $(THROW 1 $_fn)

    _h=$(echo "scale=0 ; $_res * $_h" | bc | cut -d. -f1) || eval $(THROW 1 $_fn)
    _w=$(echo "scale=0 ; $_h * $_w" | bc | cut -d. -f1)   || eval $(THROW 1 $_fn)
    [ "${_w}${_h}" ] && echo "$_w $_h" || return 1
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


