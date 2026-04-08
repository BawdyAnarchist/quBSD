#!/bin/sh

####################################################################################################
############################################  HELPERS  #############################################


# Require $1,$2,$3. Search for available IPaddr using the form: _ip0._ip1._ip2._ip3/_sub
  # _ip0 is always '10', while _ip1._ip2 comprise the search space
  # _ip3/_sub convention is '.2/30' for client-side of epair, and '.1/30' for gw side of epair
  # _allocated is optional $4. Caller can supplement "used IPs" with their own adhoc list
resolve_open_ipv4() {
    local _fn="_resolve_open_ipv4" _ip1="$1" _ip3="$2" _sub="$3" _allocated="$4"
    local _used _ip_test
    assert_int_comparison -g 0 -L 255 "$_ip1" || eval $(THROW $? _generic "Invalid _ip1")
    assert_int_comparison -g 0 -L 255 "$_ip3" || eval $(THROW $? _generic "Invalid _ip3")
    assert_int_comparison -g 0 -L 31  "$_sub" || eval $(THROW $? _generic "Invalid _sub")

    # Assemble the full list of used IPs for the comparison
    _used="$(printf "%b" "$_allocated\n" "$(query_running_ips)\n" \
           "$(query_param_values IPV4 | awk '{ print $3 }' | sort -u)")"

    # A bit of awk magic guarantees this runs fast instead of nested while-loops + echo|grep (slow)
    printf '%s\n' $_used | awk -F'[./]' -v _ip1="$_ip1" -v ip3="$_ip3" -v _sub="$_sub" '
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
    ' || eval $(THROW 213 $_fn $_ip1 $_ip3)
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

