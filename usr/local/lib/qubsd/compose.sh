#!/bin/sh

# Return the most recent rootenv snapshot possible. Must avoid running rootenv and stale data
_resolve_rootenv_snapname() {
    local _fn="_resolve_rootenv_snapname" _dset="$1"
    local _rootsnaps _psmod _lstart _line _snap _date _timestamp _written

    # Try existing ROOTSNAPS. If unavail, grab _dset snaps. Then rev order for while/read loop
    [ $ROOTSNAPS ] && _rootsnaps=$(echo "$ROOTSNAPS" | grep $_dset)
    if [ -z "$_rootsnaps" ] && unset ROOTSNAPS ; then
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
            _date=$(echo "$_line" | awk '{print $3, $4, $5, $6, $7}')
            _timestamp=$(date -j -f "%a %b %d %H:%M %Y" "$_date" +"%s")

            # Compare data, continue or break
            [ "$_lstart" -gt "$_timestamp" ] && echo $_snap && return 0
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
_resolve_persist_snapname() {
    local _fn="_resolve_persist_snapname" _dset="$1"
    local _persistsnaps _psmod _lstart _line _snap _date _timestamp _written

    # Try existing PERSISTSNAPS. If unavail, grab _dset snaps. Then rev order for while/read loop
    [ $PERSISTSNAPS ] && _persistsnaps=$(echo "$PERSISTSNAPS" | grep $_dset)
    if [ -z "$_persistsnaps" ] && unset $PERSISTSNAPS ; then
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
compose_root_reclone_cmds() {
    local _fn="compose_root_reclone_cmds" _pfx="$3" _pfxloc="rrc_"
    local  _cell _rt_ctx _rootenv _snap _die _r_mnt _r_dset _r_zfs_mnt
    assert_args_set 2 "$1" "$2" && _cell="$1" _rt_ctx="$2" || $(THROW $?)

    # Compose the local vars based on their prefixes
    _rootenv=$(ctx_get ${_pfx}ROOTENV)
    _r_zfs=$(ctx_get ${_pfx}R_ZFS)
    _r_dset=$(ctx_get ${_pfx}R_DSET)
    _r_mnt=$(ctx_get ${_pfx}R_MNT)

    # Need the root dataset of the rootenv, to choose the snapshot
    ctx_bootstrap_cell $_rootenv $_pfxloc || eval $(THROW $? _generic "< $_rootenv > bootstrap failed")

    _snap=$(_resolve_rootenv_snapname $(ctx_get ${_pfxloc}R_DSET))
    case $? in
        0)  : ;;
        2)  _die=$(( $(date +%s) + 30 ))
            _CMD_SNAPSHOT_ROOT="zfs snapshot -o qb:destroy_date=$_die -o qb:autosnap=- -o qb:autocreated=yes $_snap"
            ;;
        *)  eval $(THROW $? _generic "failed to get root snapshot name") ;;
    esac

    # R_MNT is null, then RT_CTX needs updated after clone. Otherwise, RT_CTX is fine, just destroy/reclone
    if [ "$_r_mnt" ] ; then
        _CMD_DESTROY_ROOT="zfs destroy -rRf $_r_dset"
    else
        _r_zfs_mnt="$(query_zfs_mountpoint $_r_zfs)/$_cell"
        _CMD_UPDATE_R_MNT_RTCTX="sed -i '' -E \"s|^(R_MNT=\\\")|\1$_r_zfs_mnt|\" $_rt_ctx"
    fi
    _CMD_CLONE_ROOT="zfs clone -o qb:autosnap=false $_snap $_r_dset"
}

# $1 required. Caller should be careful if deconfliction via $2 (_pfx) is necessary
compose_persist_reclone_cmds() {
    local _fn="compose_persist_reclone_cmds" _pfx="$3" _pfxloc="prc_"
    local _cell _rt_ctx _snap _die _p_mnt _p_dset _p_zfs_mnt
    assert_args_set 2 "$1" "$2" && _cell="$1" _rt_ctx="$2" || $(THROW $?)

    # Compose the local vars based on their prefixes
    _template=$(ctx_get ${_pfx}TEMPLATE)
    _p_zfs=$(ctx_get ${_pfx}P_ZFS)
    _p_dset=$(ctx_get ${_pfx}P_DSET)
    _p_mnt=$(ctx_get ${_pfx}P_MNT)

    # Need the persist dataset of the template, to choose the snapshot
    ctx_bootstrap_cell $_template $_pfxloc || eval $(THROW $? _generic "< $_template > bootstrap failed")

    _snap=$(_resolve_persist_snapname $(ctx_get ${_pfxloc}P_DSET))
    case $? in
        0) : ;;
        2)  _die=$(( $(date +%s) + 30 ))
            _CMD_SNAPSHOT_PERSIST="zfs snapshot -o qb:destroy_date=$_die -o qb:autosnap=- -o qb:autocreated=yes $_snap"
            ;;
        *)  eval $(THROW $? _generic "failed to get persistent snapshot name")  ;;
    esac

    # P_MNT is null, then RT_CTX needs updated after clone. Otherwise, RT_CTX is fine, just destroy/reclone
    if [ -z "$_p_mnt" ] ; then
        _p_zfs_mnt="$(query_zfs_mountpoint $_p_zfs)/$_cell"
        _CMD_UPDATE_P_MNT_RTCTX="sed -i '' -E \"s|^(P_MNT=\\\")|\1$_p_zfs_mnt|\" $_rt_ctx"
    else
        _CMD_DESTROY_PERSIST="zfs destroy -rRf $_p_dset"
    fi
    _CMD_CLONE_PERSIST="zfs clone -o qb:autosnap=false $_snap $_p_dset"
    _CMD_FIX_PW="fix_freebsd_pw $_cell $(ctx_get $_pfxloc) $_p_mnt"
}

