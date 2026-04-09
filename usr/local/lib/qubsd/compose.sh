#!/bin/sh

####################################################################################################
############################################  HELPERS  #############################################


# Require $1,$2,$3. Search for available IPaddr using the form: _ip0._ip1._ip2._ip3/_sub
  # _ip0 is always '10', while _ip1._ip2 comprise the search space
  # _ip3/_sub convention is '.2/30' for client-side of epair, and '.1/30' for gw side of epair
  # _reserve ($4) is optional, creating the side-effect up reserving the new IP in global USED_IPS
_resolve_available_ipv4() {
    local _fn="_resolve_available_ipv4" _ip1="$1" _ip3="$2" _sub="$3" _reserve="$4"
    local _config_ips _used _newIP
    assert_int_comparison -g 0 -L 255 "$_ip1" || eval $(THROW $? _generic "Invalid _ip1")
    assert_int_comparison -g 0 -L 255 "$_ip3" || eval $(THROW $? _generic "Invalid _ip3")
    assert_int_comparison -g 0 -L 31  "$_sub" || eval $(THROW $? _generic "Invalid _sub")

    # Assemble the full list of used IPs for the comparison
    query_runtime_ips   # Sets global $RT_IPS
    _config_ips="$(query_param_values IPV4 | awk '{ print $3 }' | sort -u)"
    _used="$(printf "%b" "$_config_ips" "\n$RT_IPS")"

    # A bit of awk magic guarantees this runs fast instead of nested while-loops + echo|grep (slow)
    _newIP=$(printf '%s\n' $_used | awk -F '[./]' -v _ip1="$_ip1" -v ip3="$_ip3" -v _sub="$_sub" '
        $1 == "10" { used[$2, $3] = 1 }            # Parse the input
        END {                                      # Search the space
            for (i = _ip1; i <= 255; i++) {
                for (j = 1; j <= 255; j++) {
                    if (!((i, j) in used)) {       # Success. Address not found in hash map
                        printf "10.%d.%d.%d/%d\n", i, j, ip3, _sub
                        exit 0
                    }
                }
            }
            exit 1                                 # Failure. Exhausted the search space
        }
    ') || eval $(THROW 213 $_fn $_ip1 $_ip3)

    # If _reserve was passed, then update the RT_IPS, excluding _newIP from future use
    [ "$_reserve"  ] && RT_IPS="$(printf "%b" "$RT_IPS" "\n$_newIP" | sed '/^$/d')"

    echo "$_newIP"
}

# Finds an unused epair
_resolve_available_epair() {
    local _fn="_resolve_available_epair" _reserve="$1" _int=0 _newEP

    query_runtime_epairs   # Sets global $RT_EPAIRS

    # A bit of awk magic guarantees this runs fast instead of nested while-loops + echo|grep (slow)
    _newEP=$(printf '%s\n' $RT_EPAIRS | awk -v _int="$_int" '
        /^epair[0-9]/ { sub(/^epair/, ""); used[$0+0] = 1 }  # Parse the input
        END {
            for (i = _int; i <= 999; i++) {       # Search the space
                if (!(i in used)) {
                    printf "epair%d\n", i         # Success. Address not found in hash map
                    exit 0
                }
            }
            exit 1                                # Failure. Exhausted the search space
        }
    ') || eval $(THROW 213 $_fn)

    # If _reserve was passed, then update the RT_EPAIRS, excluding _newEP from future use
    [ "$_reserve"  ] && RT_EPAIRS="$(printf "%b" "$RT_EPAIRS" "\n$_newEP" | sed '/^$/d')"

    echo "$_newEP"
}

# Finds an unused tap
_resolve_available_taps() {
    local _fn="_resolve_available_taps" _reserve="$1" _int=0 _newTAP

    query_runtime_taps     # Sets global $RT_TAPS. `quiet` because fstat can be noisy

    # A bit of awk magic guarantees this runs fast instead of nested while-loops + echo|grep (slow)
    _newTAP=$(printf '%s\n' $RT_TAPS | awk -v _int="$_int" '
        /^tap[0-9]/ { sub(/^tap/, ""); used[$0+0] = 1 }  # Parse the input
        END {
            for (i = _int; i <= 999; i++) {     # Search the space
                if (!(i in used)) {
                    printf "tap%d\n", i         # Success. tap not found in hash map
                    exit 0
                }
            }
            exit 1                              # Failure. Exhausted the search space
        }
    ') || eval $(THROW 213 $_fn)

    # If _reserve was passed, then update the RT_EPAIRS, excluding _newEP from future use
    [ "$_reserve"  ] && RT_TAPS="$(printf "%b" "$RT_TAPS" "\n$_newTAP" | sed '/^$/d')"

    echo "$_newTAP"
}
compose_remove_interface_cmds() {
    local _fn="compose_remove_interface_cmds" _intfs="$1" _cell="$2"

    for _intf in $_intfs ; do
        # First check if it's already on host
        if quiet ifconfig $_intf ; then
            _CMD_RM_INTFS="ifconfig $_intf destroy ; $_CMD_RM_INTFS"

        # If a jail type cell was passed, check that as the first possibility to find/remove tap
        elif quiet ifconfig -j "$_cell" "$_intf" ; then
            _CMD_RM_INTFS="$(printf "%b" \
                "ifconfig $_intf -vnet $_cell\n" \
                "ifconfig $_intf destroy\n" \
                "$_CMD_RM_INTFS")"

        # If the above fails, then check each jail one by one
        else
           for _j in $(query_onjails ; echo $ONJAILS) ; do
              quiet ifconfig -j "$_j" "$_intf" && _CMD_RM_INTFS="$(printf "%b" \
                  "ifconfig $_intf -vnet $_j\n" \
                  "ifconfig $_intf destroy")"
           done
        fi
    done
    return 0
}

compose_vif_cmds() {
    local _fn="compose_vif_cmds"
    local _ip_search _cli_ip _gw_ip

    # With no gw, there are no vifs to configure
    { [ -z "$_gw" ] || [ "$_gw" = "none" ] || ! is_cell_running "$_gw" ;} && return 0

    # Grab the IP context and resolve the final IPs of cli/gw
    [ "$_cli_isgw" ] && _ip_search="99 1 30" || _ip_search="1 1 30"

    case $_ipv4 in
        ''|none) ;; ###### TBD. Not sure how I want to handle this yet. ########
        DHCP) # For client DHCP, we only need the _gw IP (if jail).
            _groupmod="group DHCPD"
            [ "$_gw_type" = "JAIL" ] && _gw_ip=$(_resolve_available_ipv4 $_ip_search true)
            ;;
        auto) # Assign both cl and gw IPs
            _gw_ip=$(_resolve_available_ipv4 $_ip_search true)
            _cl_ip=${_gw_ip%.*/*}.2/30
            ;;
        *) # Specifically designated IPaddr in the qconf
            _cl_ip=$_ipv4
            _gw_ip=${ipv4%.*/*}.1/${ipv4#*/}
            ;;
    esac

    # Command modifiers for simplified command construction
    [ "$_cell"  = "JAIL" ]   && _cl_mod="-j $_cell"
    [ "$_gw_type" = "JAIL" ] && _gw_mod="-j $_gw"
}

# These helpers are needed so that the primary cmd functions can used downward-scoped variables
# and for clean designation of when the CELL is a gateway, vs when it is a client.
_resolve_cl_context() {
    local _fn="_resolve_cl_context" _cli="$1" _pfx="$2"
    _type=$(ctx_get ${_pfx}TYPE)
    _ipv4=$(ctx_get ${_pfx}IPV4)
    _mtu=$(ctx_get ${_pfx}MTU)
    _vifs=$(ctx_get ${_pfx}VIFS)
    _gw=$(ctx_get ${_pfx}GATEWAY)
    quiet query_gw_clients $_cli && _cli_isgw=true  # Needed for vif IP resolution conventions
}

# Full composition of the network stack commands for a single ell, and between its gw and clients
compose_network_construction_cmds() {
    local _fn="compose_network_construction_cmds" _cell="$1" _pfx="$2"
    local _caller _client _type _ipv4 _mtu _gw _gw_type
    assert_args_set 1 "$_cell" || eval $(THROW $?)
    assert_pfx "$_pfx" || eval $(THROW $?)

    # Grab all relevant cli and gw context elements. These will downward scope to prevent drilling
    _caller=$(ctx_get ${_pfx}CALLER)  # Switches gw services restart (deconflict potential races)
    _clients=$(query_gw_clients "$_cell")

    # Compose the connection commands from CELL to _gw. CELL starts out as the client
    _resolve_cl_context $_pfx      # Dynamically scoped variables (available for use in this func)
    _gw_type=$(query_cell_type $_gw)
    _CMD_NETWORK_VIF=$(compose_vif_cmds)
    _CMD_NETWORK_CONFIG=$(compose_config_cmds)
    _CMD_NETWORK_SERVICE=$(compose_service_cmds)

    # CELL now becomes the gw_, and the downstream client commands are constructed
    _gw_type=$(ctx_get ${_pfx}TYPE)
    for _client in $clients ; do
        _is_cell_running $_client || continue
        ctx_load_runtime "$_client" "cl_" || continue
        _resolve_cl_context "$_client" "cl_"

        _CMD_NETWORK_VIF="$(printf "%b" "$_CMD_NETWORK_VIF" "\n$(compose_vif_cmds)")"
        _CMD_NETWORK_CONFIG="$(printf "%b" "$_CMD_NETWORK_VIF" "\n$(compose_config_cmds)")"
        _CMD_NETWORK_SERVICE="$(printf "%b" "$_CMD_NETWORK_VIF" "\n$(compose_service_cmds)")"
    done
}

# Return the most recent rootenv snapshot possible. Must avoid running rootenv and stale data
_resolve_snapname_rootenv() {
    local _fn="_resolve_snapname_rootenv" _dset="$1"
    local _rootsnaps _psmod _lstart _line _snap _creation _crea_unix _written

    # Try existing ROOTSNAPS. If unavail, grab _dset snaps. Then rev order for while/read loop
    [ "$ROOTSNAPS" ] && _rootsnaps=$(echo "$ROOTSNAPS" | grep $_dset)
    if [ -z "$_rootsnaps" ] ; then
        unset ROOTSNAPS
        query_rootsnaps $_dset || eval $(THROW $?)
    fi

    _rootsnaps=$(echo "$ROOTSNAPS" | grep $_dset \
                | awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}')

    # For safety, running ROOTENV snapshot should be taken from before it was started
    if _psmod="-p $(hush pgrep -f "bhyve: $ROOTENV")" || _psmod="-J $(hush jls -j $ROOTENV jid)" ; then
        _lstart=$(ps -o lstart $_psmod | tail -1 | xargs -I@ date -j -f "%a %b %d %T %Y" @ +"%s")

        while IFS= read -r _line ; do
            # Extract snapshot, date string, and covert the timestamp
            _snap=$(echo "$_line" | awk '{print $1}')
            _creation=$(echo "$_line" | awk '{print $3, $4, $5, $6, $7}')
            _crea_unix=$(date -j -f "%a %b %d %H:%M %Y" "$_creation" +"%s")

            # Compare data, continue or break
            [ "$_lstart" -gt "$_crea_unix" ] && echo $_snap && return 0
        done << EOF
$_rootsnaps
EOF
    else
        # Ensure against stale rootenv snapshot by checking 'written@'
        _snap=$(echo "$_rootsnaps" | head -1 | awk '{print $1}')
        _written=$(zfs get -Hpo value written@${_snap##*@} $_dset)  # Most recent snap vs HEAD
        [ "$_written" = "0" ] && echo $_snap && return 0

        # Last avail rootenv snap is in fact stale (or non-existent). Prepare a new one.
        echo "$_dset@$(date +%s)" && return 2   # '2' tells caller to perform a new snapshot
    fi
}

# Return the most recent rootenv snapshot possible. Must avoid running rootenv and stale data
_resolve_snapname_persist() {
    local _fn="_resolve_snapname_persist" _dset="$1" _persistsnaps _snap _written

    # Try existing PERSISTSNAPS. If unavail, grab _dset snaps. Then rev order for while/read loop
    [ "$PERSISTSNAPS" ] && _persistsnaps=$(echo "$PERSISTSNAPS" | grep $_dset)
    if [ -z "$_persistsnaps" ] ; then
        unset PERSISTSNAPS
        query_persistsnaps $_dset || eval $(THROW $?)
    fi
    _persistsnaps=$(echo "$PERSISTSNAPS" | grep $_dset \
                | awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}')

    # Persist dataset can tolerate running ROOTENV. But ensure it's not stale, via 'written@'
    _snap=$(echo "$_persistsnaps" | head -1 | awk '{print $1}')
    _written=$(zfs get -Hpo value written@${_snap##*@} $_dset)  # Most recent snap vs HEAD
    [ "$_written" = "0" ] && echo $_snap && return 0

    # Last avail rootenv snap is in fact stale (or non-existent). Prepare a new one.
    echo "$_dset@$(date +%s)" && return 2   # '2' tells caller to perform a new snapshot
}

# Caller should be careful if deconfliction via $1 (_pfx) is necessary
compose_reclone_root_cmds() {
    local _fn="compose_reclone_root_cmds" _pfx="$3" _pfxloc="rrc_"
    local  _cell _rt_ctx _rootenv _snap _die _r_mnt _r_dset _r_zfs_mnt
    assert_args_set 2 "$1" "$2" && _cell="$1" _rt_ctx="$2" || eval $(THROW $?)

    # Compose the local vars based on their prefixes
    _rootenv=$(ctx_get ${_pfx}ROOTENV)
    _r_zfs=$(ctx_get ${_pfx}R_ZFS)
    _r_dset=$(ctx_get ${_pfx}R_DSET)
    _r_mnt=$(ctx_get ${_pfx}R_MNT)

    # Need the root dataset of the rootenv, to choose the snapshot
    ctx_bootstrap_cell $_rootenv $_pfxloc || eval $(THROW $? _generic "< $_rootenv > bootstrap failed")

    _snap=$(_resolve_snapname_rootenv $(ctx_get ${_pfxloc}R_DSET))
    case $? in
        0)  : ;;
        2) _CMD_SNAPSHOT_ROOT="zfs snapshot -o qb:ttl=1m $_snap" ;;
        *)  eval $(THROW $? _generic "failed to get root snapshot name") ;;
    esac

    # R_MNT is null, then RT_CTX needs updated after clone. Otherwise, RT_CTX is fine, just destroy/reclone
    if [ "$_r_mnt" ] ; then
        _CMD_DESTROY_ROOT="zfs destroy -rRf $_r_dset"
    else
        _r_zfs_mnt="$(query_zfs_mountpoint $_r_zfs)/$_cell"
        _CMD_UPDATE_R_MNT_RTCTX="sed -i '' -E \"s|^(R_MNT=\\\")|\1$_r_zfs_mnt|\" $_rt_ctx"
    fi
    _CMD_CLONE_ROOT="zfs clone $_snap $_r_dset"
}

# $1 required. Caller should be careful if deconfliction via $2 (_pfx) is necessary
compose_reclone_persist_cmds() {
    local _fn="compose_reclone_persist_cmds" _pfx="$3" _pfxloc="prc_"
    local _cell _rt_ctx _snap _p_mnt _p_dset
    assert_args_set 2 "$1" "$2" && _cell="$1" _rt_ctx="$2" || eval $(THROW $?)

    # Compose the local vars based on their prefixes
    _template=$(ctx_get ${_pfx}TEMPLATE)
    _p_zfs=$(ctx_get ${_pfx}P_ZFS)
    _p_dset=$(ctx_get ${_pfx}P_DSET)
    _p_mnt=$(ctx_get ${_pfx}P_MNT)

    # Need the persist dataset of the template, to choose the snapshot
    ctx_bootstrap_cell $_template $_pfxloc || eval $(THROW $? _generic "< $_template > bootstrap failed")

    _snap=$(_resolve_snapname_persist $(ctx_get ${_pfxloc}P_DSET))
    case $? in
        0) : ;;
        2) _CMD_SNAPSHOT_PERSIST="zfs snapshot -o qb:ttl=1m $_snap" ;;
        *)  eval $(THROW $? _generic "failed to get persistent snapshot name")  ;;
    esac

    # P_MNT is null, then RT_CTX needs updated after clone. Otherwise, RT_CTX is fine, just destroy/reclone
    if [ -z "$_p_mnt" ] ; then
        _p_mnt="$(query_zfs_mountpoint $_p_zfs)/$_cell"
        _CMD_UPDATE_P_MNT_RTCTX="sed -i '' -E \"s|^(P_MNT=\\\")|\1$_p_mnt|\" $_rt_ctx"
        eval ${_pfx}P_MNT=$_p_mnt   # Update the globals with P_MNT since it will be created in _CMDS
    else
        _CMD_DESTROY_PERSIST="zfs destroy -rRf $_p_dset"
    fi
    _CMD_CLONE_PERSIST="zfs clone $_snap $_p_dset"
    _CMD_FIX_PW="fix_freebsd_pw $_cell $(ctx_get $_pfxloc) $_p_mnt"
}

