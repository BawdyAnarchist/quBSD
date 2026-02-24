#!/bin/sh

# Return the most recent rootenv snapshot possible. Must avoid running rootenv and stale data
resolve_rootenv_snapname() {
    local _fn="resolve_rootenv_snapname" _dset="$1"
    local _rootsnaps _psmod _lstart _line _snap _date _timestamp _now

    # Try existing ROOTSNAPS. If unavail, grab _dset snaps. Then rev order for while/read loop
    [ $ROOTSNAPS ] && _rootsnaps=$(echo "$ROOTSNAPS" | grep $_dset)
    [ -z "$_rootsnaps" ] && unset $ROOTSNAPS && query_rootsnaps $_dset
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
        # Ensure against stale rootenv snapshot by checking 'written'
        _snap=$(echo "$_rootsnaps" | head -1 | awk '{print $1}')
        [ "$(echo $_rootsnaps | head -1 | awk '{print $2}')" = "0" ] && echo $_snap && return 0

        # Last avail rootenv snap is in fact stale (or non-existent). Prepare a new one.
        _now=$(date +%s)
        echo "$_dset@${_now}" && return 2   # '2' tells caller to perform a new snapshot
    fi
}

# Return the most recent rootenv snapshot possible. Must avoid running rootenv and stale data
resolve_persist_snapname() {
    local _fn="resolve_persist_snapname" _dset="$1"
    local _persistsnaps _psmod _lstart _line _snap _date _timestamp _now

    # Try existing PERSISTSNAPS. If unavail, grab _dset snaps. Then rev order for while/read loop
    [ $PERSISTSNAPS ] && _persistsnaps=$(echo "$PERSISTSNAPS" | grep $_dset)
    [ -z "$_persistsnaps" ] && unset $PERSISTSNAPS && query_persistsnaps $_dset
    _persistsnaps=$(echo "$PERSISTSNAPS" | grep $_dset \
                | awk '{a[NR]=$0} END{for(i=NR;i>=1;i--) print a[i]}')

    # Persist dataset can tolerate running ROOTENV. But ensure it's not stale, via 'written'
    _snap=$(echo "$_persistsnaps" | head -1 | awk '{print $1}')
    [ "$(echo $_persistsnaps | head -1 | awk '{print $2}')" = "0" ] && echo $_snap && return 0

    # Last avail rootenv snap is in fact stale (or non-existent). Prepare a new one.
    _now=$(date +%s)
    echo "$_dset@$_now" && return 2   # '2' tells caller to perform a new snapshot
}

# Caller should be careful if deconfliction via $1 (_pfx) is necessary
compose_root_reclone_cmds() {
    local _fn="compose_root_reclone_cmds" _pfx="$1" _rootenv _snap _die _r_mnt _r_dset _pfxloc="rrc_"

    # Compose the local vars based on their prefixes
    _rootenv=$(ctx_get ${_pfx}ROOTENV)
    _r_mnt=$(ctx_get ${_pfx}R_MNT)
    _r_dset=$(ctx_get ${_pfx}R_DSET)

    # Need the root dataset of the rootenv, to choose the snapshot
    ctx_bootstrap_cell $_rootenv $_pfxloc || eval $(THROW 1 _generic "< $_rootenv > bootstrap failed")

    _snap=$(resolve_rootenv_snapname $(ctx_get ${_pfxloc}R_DSET))
    case $? in
        0)  : ;;
        1)  eval $(THROW 1 _generic "failed to get root snapshot name") ;;
        2)  _die=$(( $(date +%s) + 30 ))
            _CMD_SNAPSHOT_ROOT="zfs snapshot -o qb:dest_date=$_die -o qb:autosnap=- -o qb:autocreated=yes $_snap"
            ;;
    esac

    [ "$_r_mnt" ] && _CMD_DESTROY_ROOT="zfs destroy -rRf $_r_dset"
    _CMD_CLONE_ROOT="zfs clone -o qb:autosnap=false $_snap $_r_dset"
}

# $1 required. Caller should be careful if deconfliction via $2 (_pfx) is necessary
compose_persist_reclone_cmds() {
    local _fn="compose_persist_reclone_cmds" _cell _pfx="$2" _snap _die _p_mnt _p_dset _pfxloc="prc_"
    assert_args_set 1 "$1" && _cell="$1" || $(THROW 1)

    # Compose the local vars based on their prefixes
    _template=$(ctx_get ${_pfx}TEMPLATE)
    _p_mnt=$(ctx_get ${_pfx}P_MNT)
    _p_dset=$(ctx_get ${_pfx}P_DSET)

    # Need the persist dataset of the template, to choose the snapshot
    ctx_bootstrap_cell $_template $_pfxloc || eval $(THROW 1 _generic "< $_template > bootstrap failed")

    _snap=$(resolve_persist_snapname $(ctx_get ${_pfxloc}P_DSET))
    case $? in
        1)  eval $(THROW 1 _generic "failed to get persistent snapshot name")  ;;
        2)  _die=$(( $(date +%s) + 30 ))
            _CMD_SNAPSHOT_PERSIST="zfs snapshot -o qb:dest_date=$_die -o qb:autosnap=- -o qb:autocreated=yes $_snap"
            ;;
    esac

    [ "$_p_mnt" ] && _CMD_DESTROY_PERSIST="zfs destroy -rRf $_p_dset"
    _CMD_CLONE_PERSIST="zfs clone -o qb:autosnap=false $_snap $_p_dset"
    _CMD_FIX_PW="fix_freebsd_pw $_cell $(ctx_get $_pfxloc) $_p_mnt"
}

