#!/bin/sh



start_jail() {
	# Starts jail. Performs sanity checks before starting. Logs results.
	# return 0 on success ; 1 on failure.
	local _fn="start_jail" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts nqV opts ; do case $opts in
			n) local _norun="-n" ;;
			q) local _qs="-q" ; _quiet='> /dev/null 2>&1' ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	local _jail="$1"
	[ "$_jail" = "none" ] && eval $_R0
	[ -z "$_jail" ] && get_msg $_qs -m _e0 -- "jail" && eval $_R1

	# Check to see if _jail is already running
	if	! chk_isrunning "$_jail" ; then
		# If not, running, perform prelim checks
		if chk_valid_jail $_qs -- "$_jail" ; then

			# Jail or VM
			if chk_isvm "$_jail" ; then
				! exec_vm_coordinator $_norun $_qs $_jail $_quiet \
					&& get_msg $_qs -m _e4 -- "$_jail" && eval $_R1
			else
				[ "$_norun" ] && return 0

				# Have to use tmpfile to grab the error message while still allowing for user zfs -l
				get_msg -m _m1 -- "$_jail" | tee -a $QLOG ${QLOG}_${_jail}
				_jailout=$(mktemp ${QRUN}/start_jail${0##*/}.XXXX)

				if jail -vc "$_jail" | tee -a $_jailout ; then
					cat $_jailout >> ${QLOG}_${_jail}
					rm $_jailout 2>/dev/null
				else
					cat $_jailout > $ERR1
					cat $_jailout > ${QLOG}_${_jail}
					rm $_jailout 2>/dev/null
					get_msg $_qs -m _e4 -- "$_jail" && eval $_R1
				fi
			fi
		else # Jail was invalid
			return 1
		fi
	fi
	eval $_R0
}

stop_jail() {
	# If jail is running, remove it. Return 0 on success; return 1 if fail.
	local _fn="stop_jail" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts fqt:Vw opts ; do case $opts in
			f) local _force="true" ;;
			q) local _qj="-q" ;;
			V) local _V="-V" ;;
			t) local _timeout="-t $OPTARG" ;;
			w) local _wait="true" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_qj -m _e0 -- "jail" && eval $_R1

	# Check that the jail is on
	if chk_isrunning "$_jail" ; then
		# Log stop attempt, then switch by VM or jail
		get_msg -m _m2 -- "$_jail" | tee -a $QLOG ${QLOG}_${_jail}

		if chk_isvm "$_jail" ; then
			if [ -z "$_force" ] ; then
				pkill -15 -f "bhyve: $_jail"
			else
				bhyvectl --vm="$_jail" --destroy
			fi
			# If optioned, wait for the VM to stop
			[ "$_wait" ] && ! monitor_vm_stop $_qj $_timeout "$_jail" && eval $_R1

		# Attempt normal removal [-r]. If failure, then remove forcibly [-R].
		elif ! jail -vr "$_jail"  >> ${QLOG}_${_jail} 2>&1 ; then
			if chk_isrunning "$_jail" ; then
				# Manually run exec.prestop, then forcibly remove jail, and run exec.release
				/bin/sh ${QLEXEC}/exec.prestop "$_jail" > /dev/null 2>&1
				jail -vR "$_jail"  >> ${QLOG}_${_jail} 2>&1
				/bin/sh ${QLEXEC}/exec.release "$_jail" > /dev/null 2>&1

				if chk_isrunning "$_jail" ; then
					# Warning about failure to forcibly remove jail
					get_msg $_qj -m _w2 -- "$_jail" && eval $_R1
				else
					# Notify about failure to remove normally
					get_msg -m _w1 -- "$_jail"
				fi
			fi
	fi fi
	eval $_R0
}

restart_jail() {
	# Restarts jail. If a jail is off, this will start it. However, passing
	# [-h] will override this default, so that an off jail stays off.
	local _fn="restart_jail" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts hqV opts ; do case $opts in
			h) local _hold="true" ;;
			q) local _qr="-q" ;;
			V) local _V="-V" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))  ;  [ "$1" = "--" ] && shift

	# Positional parameters / check
	local _jail="$1"
	[ -z "$_jail" ] && get_msg $_qr -m _e0 -- "jail" && eval $_R1

	# If the jail was off, and the hold flag was given, don't start it.
	! chk_isrunning "$_jail" && [ "$_hold" ] && eval $_R0

	# Otherwise, cycle jail
	stop_jail $_qr "$_jail" && start_jail $_qr "$_jail"
	eval $_R0
}

reclone_zroot() {
	# Destroys the existing _rootenv clone of <_jail>, and replaces it
	# Detects changes since the last snapshot, creates a new snapshot if necessary,
	local _fn="reclone_zroot" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	_tmpsnaps="${QRUN}/.tmpsnaps"

	while getopts qV _opts ; do case $_opts in
		q) local _qz='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Variables definitions
	local _jail="$1"
		[ -z "${_jail}" ] && get_msg $_qz -m _e0 -- "Jail" && eval $_R1
	local _rootenv="$2"
		[ -z "${_rootenv}" ] && get_msg $_qz -m _e0 -- "ROOTENV" && eval $_R1
	local _jailzfs="${R_ZFS}/${_jail}"

	# Check that the _jail being destroyed/cloned has an origin (is a clone).
	chk_valid_zfs "$_jailzfs" && [ "$(zfs list -Ho origin $_jailzfs)" = "-" ] \
		&& get_msg $_qz -m _e32 -- "$_jail" && eval $_R1

	# Parallel starts create race conditions for zfs snapshot access/comparison. This deconflicts it.
	# Use _tmpsnaps if avail. Else, find/create latest rootenv snapshot.
	[ -e "$_tmpsnaps" ] \
		&& _rootsnap=$(grep -Eo "^${R_ZFS}/${_rootenv}@.*" $_tmpsnaps) \
		|| { ! _rootsnap=$(select_snapshot) && get_msg $_qz $_V -m '' && eval $_R1 ;}

   # Destroy the dataset and reclone it
	zfs destroy -rRf "${_jailzfs}" > /dev/null 2>&1
	zfs clone -o qubsd:autosnap='false' "${_rootsnap}" ${_jailzfs}

	eval $_R0
}

reclone_zusr() {
	# Destroys the existing zusr clone of <_jail>, and replaces it
	# Detects changes since the last snapshot, creates a new snapshot if necessary,
	# and destroys old snapshots when no longer needed.
	local _fn="reclone_zusr" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	# Variables definitions
	local _jail="$1"
	local _jailzfs="$U_ZFS/$_jail"
	local _template="$2"
	local _date=$(date +%s)
	local _ttl=$(( _date + 30 ))

	# Basic checks, and do not attempt this on a running container
	[ -z "$_jail" ] && get_msg $_qr -m _e0 -- "jail" && eval $_R1
	[ -z "$_template" ] && get_msg $_qr -m _e0 -- "template" && eval $_R1
	! chk_valid_zfs "$U_ZFS/$_template" && get_msg $_qr -m _e0 -- "template" && eval $_R1
	chk_isrunning "$_jail" && get_msg $_qr -m _e35 && -- "$_jail" eval $_R1

	# Destroy the existing zusr dataset. Suppress error in case the dataset doesnt exist
	zfs destroy -rRf "${_jailzfs}" > /dev/null 2>&1

	# There is no `clone recursive`. Must find all the children and clone them one by one
	local _datasets=$(zfs list -Hro name "$U_ZFS/$_template")
	for _templzfs in $_datasets ; do
		_newsnap="${_templzfs}@${_date}"                                  # Potential temporary snapshot
		_presnap=$(zfs list -t snapshot -Ho name ${_templzfs} | tail -1)  # Latest snapshot

		# Use "written" to detect any changes to the dataset since last snapshot
		if [ $(zfs list -Ho written "$_templzfs") -eq 0 ] ; then
			_source_snap="$_presnap"          # No changes, use the old snapshot
		else
			# Changes detected, create a new, short-lived snapshot
			_source_snap="$_newsnap"
			zfs snapshot -o qubsd:destroy-date="$_ttl"
				-o qubsd:autosnap='-' -o qubsd:autocreated="yes" "$_newsnap"
		fi

		# Substitute the jail/vm name for the template name
		_newclone=$(echo $_templzfs | sed -E "s|/${_template}|/${_jail}|")
		zfs clone -o qubsd:autosnap="false" $_source_snap $_newclone
	done

	# Dispjails need to adjust pw after cloning the template
	if chk_isvm ${_jail} ; then
		set_dispvm_pw
	else
		local prefix="${M_ZUSR}/${_jail}/rw"
		set_freebsd_pw
	fi

	eval $_R0
}

set_dispvm_pw() {
	local persist="$_jailzfs/persist"
	local zvol="/dev/zvol/$persist"
	local volmnt="/mnt/$persist"

	zfs set volmode=geom $persist
	fs_type=$(fstyp $zvol)
	case "$fs_type" in
		ufs)
			mkdir -p $volmnt
			mount -o rw $zvol $volmnt
			local prefix="$volmnt/overlay"
			set_freebsd_pw
			;;
		ext*)
			kldstat -qn ext2fs || kldload -n ext2fs
			mount -t ext2fs -o rw $zvol $volmnt
			set_linux_pw
			;;
		*) # INSERT ERROR MESSAGE SYSTEM HERE
			;;
	esac

	umount $volmnt
	rm -r /mnt/$U_ZFS
	zfs set volmode=dev $zvol
}

set_freebsd_pw() {
	local jailhome="${prefix%/*}/home"   # Must remove /rw or /overlay to access /home
	local etc_local="$prefix/etc"
	local pwd_local="$prefix/etc/master.passwd.local"
	local grp_local="$prefix/etc/group.local"

	# Drop the flags for the home directory and rename it from template to dispjail name
	[ -e "$jailhome/$_template" ] \
		&& chflags noschg $jailhome/$_template \
		&& mv $jailhome/$_template $jailhome/$_jail > /dev/null 2>&1

	# Change the local pwd from template name to dispjail name
	[ -e "$etc_local" ] && chflags -R noschg $etc_local
	[ -e "$pwd_local" ] && sed -i '' -E "s|^$_template:|$_jail:|g" $pwd_local
	[ -e "$pwd_local" ] && sed -i '' -E "s|/home/$_template:|/home/$_jail:|g" $pwd_local
	[ -e "$grp_local" ] && sed -i '' -E "s/(:|,)$_template(,|[[:blank:]]|\$)/\1$_jail\2/g" $grp_local
}

set_linux_pw() {
	# EMPTY FOR NOW. WILL FILL LATER WHEN THE LINUS OVERLAYFS IS A KNOWN ENTITY
	return 0
}

set_xauthority() {
	_jail="$1"
	_file="${M_ZUSR}/${_jail}/home/${_jail}/.Xauthority"
	_xauth=$(xauth list | grep -Eo ":0.*")
	[ -e "$_file" ] && rm $_file
	touch $_file && chown 1001:1001 $_file
	eval "jexec -l -U $_jail $_jail /usr/local/bin/xauth add $_xauth"
	chmod 400 $_file
}  

launch_xephyr() {
	# sysvshm cannot share Xephyr here. Some apps will fail if we dont disable it. XVideo prevents non-existent
	# GPU overlay. We MUST stop GLX entirely (even iglx), as A) Xephyr implementation sucks (<1.4), and B) even
	# if it didnt, Xephyr is launched from *host*, and the jail only sees an X socket, not the Xephyr process.
	Xephyr -extension MIT-SHM -extension XVideo -extension XVideo-MotionCompensation -extension GLX \
		-resizeable -terminate -no-host-grab :$display > /dev/null 2>&1 &

	xephyr_pid=$!  &&  sleep 0.1       # Give a moment for Xephyr session to launch, trap it
	trap "kill -15 $xephyr_pid" INT TERM HUP QUIT EXIT
	! ps -p "$xephyr_pid" > /dev/null 2>&1 && get_msg2 -Em _e8

	# The Xephyr window_id is needed for monitoring/cleanup
	winlist=$(xprop -root _NET_CLIENT_LIST | sed 's/.*# //' | tr ',' '\n' | tail -r)
	for wid in $winlist; do
		xprop -id "$wid" | grep -Eqs "WM_NAME.*Xephyr.*:$display" \
		&& window_id="$wid" && break
	done

	# Launch a simple window manager for scaling/resizing to the full Xephyr size
	jexec -l -U $_USER $_JAIL env DISPLAY=:$display bspwm -c /usr/local/etc/X11/bspwmrc &
	bspwm_pid="$!"

	# Link the sockets together
	socat \
		UNIX-LISTEN:${QRUN}/X11/${_JAIL}/.X11-unix/X${display},fork,unlink-close,mode=0666 \
		UNIX-CONNECT:/tmp/.X11-unix/X${display} &
	socat_pid="$!"
	trap "kill -15 $bspwm_pid $socat_pid $xephyr_pid" INT TERM HUP QUIT EXIT

	# Push the Xresources and DPI to the Xephyr instance
	[ -n "$_xresources" ] && env DISPLAY=:$display xrdb -merge $_xresources
	[ -n "$_DPI" ] && echo "Xft.dpi: $_DPI" | env DISPLAY=:$display xrdb -merge

	# Monitor both the window, and the existence of the jail,
	while sleep 1 ; do
		xprop -id "$window_id" | grep -Eqs ".*Xephyr.*:$display" || exit 0
		jls | grep -Eqs "[ \t]${_JAIL}[ \t]" || exit 0
	done
	exit 0
}

monitor_ephmjail() {
	# X11 windows can take a moment launch. Ineligant solution, but wait 3 secs before check-loop
	sleep 5
	
	# ps -o tt tty -> is associated with terminals/windows. Keepalive until all are gone
	while sleep 1 ; do
		ps -axJ ${_JAIL} -o tt -o command | tail -n +2 | grep -v 'dbus' | grep -qv ' -' || break
	done
	
	# Destroy sequence
	stop_jail "$_JAIL" > /dev/null 2>&1
	zfs destroy -rRf ${R_ZFS}/$_JAIL > /dev/null 2>&1
	zfs destroy -rRf ${U_ZFS}/$_JAIL > /dev/null 2>&1
	sed -i '' -E "/^${_JAIL}[[:blank:]]/d" $QCONF
	rm ${JCONF}/${_JAIL}
	rm_errfiles
	exit 0
}

monitor_startstop() {
	# PING: There's legit cases where consecutive calls to qb-start/stop could happen. [-p] handles
	# potential races via _tmp_lock; puts the 2nd call into a timeout queue; and any calls after
	# the 2nd one, are dropped. Not perfectly user friendly, but it's unclear if allowing a long
	# queue is desirable. Better to error, and let the user try again.
	# NON-PING: Give qb-start/stop until $_timeout for jails/VMs to start/stop before intervention
	local _fn="monitor_startstop" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"

	while getopts pqV _opts ; do case $_opts in
		p) local _ping="true" ;;
		q) local _q='-q' ;;
		V) local _V="-V" ;;
	esac ; done ; shift $(( OPTIND - 1))

	# Monitoring loop is predicated on main script killing this one after successful starts/stops
	if [ -z "$_ping" ] ; then
		local _timeout="$1"
		while [ "$_timeout" -ge 0 ] ; do
			echo "$_timeout" > $_TMP_TIME
			_timeout=$(( _timeout - 1 )) ; sleep 1
		done

		# Last check before kill. If self PID was removed, then main has already completed.
		if [ -e "$_TMP_LOCK" ] && [ ! "$(sed -n 1p $_TMP_LOCK)" = "$$" ] ; then
			eval $_R0
		fi

		# Timeout has passed, kill qb-start/stop
		[ -e "$_TMP_LOCK" ] && for _pid in $(cat $_TMP_LOCK) ; do
			kill -15 $_pid > /dev/null 2>&1
			# Removing the PID is how we communicate to qb-start/stop to issue a failure message
			sed -i '' -E "/^$$\$/ d" $_TMP_LOCK
		done

		eval $_R1
	fi

	# Handle the [-p] ping case
	if [ "$_ping" ] ; then
		# Resolve any races. 1st line on lock file wins. 2nd line queues up. All others fail.
		echo "$$" >> $_TMP_LOCK && sleep .1
		[ "$(sed -n 1p $_TMP_LOCK)" = "$$" ] && eval $_R0
		[ ! "$(sed -n 2p $_TMP_LOCK)" = "$$" ] && sed -i '' -E "/^$$\$/ d" && eval $_R0

		# Timeout loop, wait for _TMP_TIME to be set with a _timeout
		local _cycle=0
		while ! _timeout=$(cat $_TMP_TIME 2>&1) ; do
			# Limit to 5 secs before returning error, so that one hang doesnt cause another
			sleep .5  ;  _cycle=$(( _cycle + 1 ))
			[ "$_cycle" -gt 10 ] && eval $_R1

			# Check if self PID was promoted to the #1 spot while waiting
			[ "$(sed -n 1p $_TMP_LOCK)" = "$$" ] && eval $_R0
		done

		# Inform the user of the new _timeout, waiting for jails/VMs to start/stop before proceding
		get_msg -m _m5 -- "$_timeout"

		# Wait for primary qb-start/stop to either complete, or timeout
		while [ "$(cat $_TMP_TIME 2>&1)" -gt 0 ] 2>&1 ; do
			[ "$(sed -n 1p $_TMP_LOCK)" = "$$" ] && eval $_R0
			sleep 0.5
		done
	fi
	eval $_R0
}

select_snapshot() {
	# Generalized function to be shared across qb-start/stop, and reclone_zfs's
	# Returns the best/latest snapshot for a given ROOTENV
	local _fn="select_snapshot" ; local _fn_orig="$_FN" ; _FN="$_FN -> $_fn"
	local _jlsdate  _rootsnaps  _snapdate  _newsnap
	local _tmpsnaps="${QRUN}/.tmpsnaps"  _rootzfs="${R_ZFS}/${_rootenv}"

	# For safety, running ROOTENV snapshot should be taken from before it was started
	if chk_isrunning ${_rootenv} ; then
		# Get epoch date of ROOTENV pid, and ROOTENV snapshots
		if chk_isvm ${_rootenv} ; then
			_jlsdate=$(ps -o lstart -p $(pgrep -f "bhyve: $_rootenv") | tail -1 \
								| xargs -I@ date -j -f "%a %b %d %T %Y" @ +"%s")
		else
			_jlsdate=$(ps -o lstart -J $(jls -j $_rootenv jid) | tail -1 \
								| xargs -I@ date -j -f "%a %b %d %T %Y" @ +"%s")
		fi
		_rootsnaps=$(zfs list -t snapshot -Ho name $_rootzfs)
		_snapdate=$(echo "$_rootsnaps" | tail -1 | xargs -I@ zfs list -Ho creation @ \
											| xargs -I@ date -j -f "%a %b %d %H:%M %Y" @ +"%s")

		# Cycle from most-to-least recent until a snapshot older-than running ROOTENV pid, is found
		while chk_integer2 -q -g $_jlsdate $(( _snapdate + 59 )) ; do
			_rootsnaps=$(echo "$_rootsnaps" | sed '$ d')
			[ -n "$_rootsnaps" ] \
				&& _snapdate=$(echo "$_rootsnaps" | tail -1 | xargs -I@ zfs list -Ho creation @ \
					| xargs -I@ date -j -f "%a %b %d %H:%M %Y" @ +"%s")
		done

		# If no _rootsnap older than the rootenv pid was found, return error
		_rootsnap=$(echo "$_rootsnaps" | tail -1)
		[ -z "$_rootsnap" ] && get_msg $_qz -m _e32_1 -- "$_jail" "$_rootenv" && eval $_R1

	# Latest ROOTENV snapshot unimportant for stops, and prefer not to clutter ROOTENV snaps.
	elif [ -z "${0##*exec.release}" ] || [ -z "${0##*qb-stop}" ] ; then
		# The jail is running, meaning there's a ROOTENV snapshot available (no error/chks needed)
		local _rootsnap=$(zfs list -t snapshot -Ho name $_rootzfs | tail -1)

	# If ROOTENV is off, and jail is starting, make sure it has the absolute latest ROOTENV state
	else
		local _date=$(date +%s)
		local _newsnap="${_rootzfs}@${_date}"
		local _rootsnap=$(zfs list -t snapshot -Ho name $_rootzfs | tail -1)

		# Perform the snapshot
		zfs snapshot -o qubsd:destroy-date=$(( _date + 30 )) -o qubsd:autosnap='-' \
			-o qubsd:autocreated="yes" "${_newsnap}"

		# Use zfsprop 'written' to detect any new data. Destroy _newsnap if it has no new data.
		if [ ! "$(zfs list -Ho written $_newsnap)" = "0" ] || [ -z "$_rootsnap" ] ; then
			_rootsnap="$_newsnap"
		else
			zfs destroy $_newsnap
		fi
	fi

	# Echo the final value and return 0
	echo "$_rootsnap" && eval $_R0
}

create_popup() {
	# Handles popus to send messages, receive inputs, and pass commands
	# _h should be as a percentage of the primary screen height (between 0 and 1)
	# _w is a multiplication factor for _h
	local _fn="create_popup" _cmd _wh _input _popfile _h _w _fs _popmsg _i3mod

	while getopts c:f:h:im:qVw: opts ; do case $opts in
			c) _cmd="$OPTARG" ;;
			i) _input="true" ;;
			f) _popfile="$OPTARG" ;;
			h) _h="$OPTARG" ;;
			m) _popmsg="$OPTARG" ;;
			w) [ "$_h" ] && _wh="$_h $OPTARG" ;;
			*) get_msg -m _e9 ;;
	esac  ;  done  ;  shift $(( OPTIND - 1 ))

	# Discern if it's i3, and modify with center/floating options
	ps c | grep -qs 'i3' && local _i3mod="i3-msg -q floating enable, move position center,"

	# If a file was passed, set the msg equal to the contents of the file
	[ "$_popfile" ] && local _popmsg=$(cat $_popfile)

	# Might've been launched from quick-key or without an environment. Get the host DISPLAY
	[ -z "$DISPLAY" ] && export DISPLAY=$(pgrep -fl Xorg | grep -Eo ":[0-9]+")

	# Equalizes popup size and fonts between systems of different resolution and DPI settings.
	[ "$_wh" ] || _wh=$(_resolve_popup_dimensions)
   _fs=$(_resolve_popup_fontsize)
   _i3mod="$_i3mod, resize set $_wh"

	# Execute popup depending on if input is needed or not
	if [ "$_cmd" ] ; then
	echo $DISPLAY >> /root/temp
		xterm -fa Monospace -fs $_fs -e /bin/sh -c "eval \"$_i3mod\" ; eval \"$_cmd\" ; "
	elif [ -z "$_input" ] ; then
		# Simply print a message, and return 0
		xterm -fa Monospace -fs $_fs -e /bin/sh -c \
			"eval \"$_i3mod\" ; echo \"$_popmsg\" ; echo \"{Enter} to close\" ; read _INPUT ;"
		eval $_R0
	else
		# Need to collect a variable, and use a tmp file to pull it from the subshell, to a variable.
		local _poptmp=$(mktemp ${QRUN}/popup.XXXX)
		xterm -fa Monospace -fs $_fs -e /bin/sh -c \
			"eval \"$_i3mod\"; printf \"%b\" \"$_popmsg\"; read _INPUT; echo \"\$_INPUT\" > $_poptmp"

		# Retreive the user input, remove tmp, and echo the value back to the caller
		_input=$(cat $_poptmp)
		rm $_poptmp > /dev/null 2>&1
		echo "$_input"
	fi
}

probe_ppt() {
    _fn="probe_ppt" _val="$1"
    chk_args_set 1 $_val

    # Check all listed PPT devices from QCONF
    for _ppt in $_val ; do
        # Detach device, examine the error message
        _dtchmsg=$(devctl detach "$_pcidev" 2>&1)
        [ -n "${_dtchmsg##*not configured}" ] && eval $(THROW 1 _e22_1 _e22) ##################################

        # Switch based on status of the device after being detached
        if pciconf -l $_pcidev | grep -Eqs "^none" ; then
           # If the device is 'none' then set the driver to ppt (it attaches automatically).
           devctl set driver "$_pcidev" ppt || $(THROW 1 _e22_2 _e22) ##################################
        else
           # Else the devie was already ppt. Attach it, or error if unable
           devctl attach "$_pcidev" || eval $(THROW 1 _e22_3 _e22) ####################################
        fi
    done
}
