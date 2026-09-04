#!/bin/sh

# Daemon is designed to live in every quBSD jail, handling the full range of network configs for both
# clients and gateways. Host handles vnet, IPs, and ifconfig groups. Jail daemon sets dhclient and DNS.

cleanup_daemon() {
    trap - INT TERM HUP QUIT EXIT

    kill -15 $monitor_pid
    sleep .1
    # If pid dies fast, exit fast. Otherwise, give it a second, but then resort to kill -9
    kill -0 $monitor_pid 2>/dev/null && sleep 1
    kill -0 $monitor_pid 2>/dev/null && kill -9 $monitor_pid

    # Wait for kill, then close the FDs and rm the pipe
    wait "$monitor_pid" 2>/dev/null
    exec 3<&-
    exec 3>&-
    rm -f $FIFO

    exit 0
}

# daemon operates on internal vifs. Frequent renegotiation / quick backoff are unnecessary
stdout_dhclient_conf() {
cat << EOF
timeout 21600;
retry 1;
initial-interval 1;
backoff-cutoff 1;
EOF
}

# Prevents resolvconf from overwriting unbound forward.conf which already points at dnscrypt
stdout_dnscrypt_resolvconf() {
cat << EOF
unbound=NO
name_servers=127.0.0.1
resolv_conf_local_only=YES
EOF
}

# resolvconf will overwrite unbound forward.conf with the highest priority DNS
stdout_unbound_resolvconf() {
cat << EOF
name_servers=127.0.0.1
resolv_conf_local_only=YES
unbound_conf=/var/unbound/forward.conf
unbound_service=local_unbound
unbound_restart="service local_unbound reload"
unbound_pid=/var/run/local_unbound.pid
EOF
}

get_services() {
    [ "$(sysrc -n pf_enable             2>/dev/null)" = YES ] && pf=true
    [ "$(sysrc -n wireguard_enable      2>/dev/null)" = YES ] && wg=true
    [ "$(sysrc -n dhcpd_enable          2>/dev/null)" = YES ] && dhcpd=true
    [ "$(sysrc -n local_unbound_enable  2>/dev/null)" = YES ] && unbound=true
    [ "$(sysrc -n dnscrypt_proxy_enable 2>/dev/null)" = YES ] && dns=true
}

set_pf_wg_endpoint() {
    local _wg_ep

    { [ "$wg" ] && [ "$pf" ] ;} || return 0
    _wg_ep="$(sed -nE "s/[ \t]*Endpoint[ \t]*=[ \t]*([^ \t]+):.*/\1/p" /rw/usr/local/etc/wireguard/wg0.conf)"
    [ "$_wg_ep" ] || return 1
    pfctl -t EP -T replace "$_wg_ep" 2>/dev/null
}

push_static_dns() {
    local _addr _gw

    _addr=$(ifconfig "$_iface" inet 2>/dev/null | awk '/inet /{print $2; exit}')
    [ -n "$_addr" ] || return 0  # Safety check in case of missing IPaddr

    # Use the .2/.1 client/gw convention, and update resolvconf
    _gw="${_addr%.*}.1"
    printf 'nameserver %s\n' "$_gw" | resolvconf -a "${_iface}.qubsd"
}

add_interface() {
    local _groups _iface

    # /bin/sh preserves `local _iface` value from parent (run_startup_actions)
    : ${_iface:=$(echo "$_line" | sed -En "s|.*add/repl iface iface#[0-9]+ ([[:alnum:]]+) .*|\1|p")}
    [ "$_iface" ] || return 0

    case ",$IFACES," in
        *",$_iface,"*) return 0     ;; # _iface is already tracked. Ignore potentially duplicate signal
        *) IFACES="$IFACES,$_iface," ;; # _iface is not tracked. Add to the list
    esac

    # Interfaces are already configured. Now they're internally tracked again. No services restart.
    [ "$re_init_flag" ] && unset re_init_flag && return 0

    # The actions to take for a new vnet interface depend on the ifconfig group(s) set by host
    sleep .05  # Give host a moment to assign group (mitigate this daemon from racing the host)
    _groups=$(ifconfig $_iface | sed -En "s/groups: (.*)/\1/p")

    case " $_groups " in
        *" DHCLIENT "*)  # Must come first to prevent static DNS assignment for DHCLIENTs
            pgrep -qfl "dhclient.*$_iface" || dhclient -bc /tmp/qubsd_dhclient.conf $_iface
            [ "$dns" ] || push_static_dns
            [ "$unbound" ] && restart_unbound=true
            [ "$pf" ] && reload_pf=true
            [ "$wg" ] && restart_wg=true
        ;;
        *" STATIC_IP "*)
            # Dont push static DNS if dnscrypt is enabled (safer, in case the service dies)
            [ "$dns" ] || push_static_dns
            [ "$unbound" ] && restart_unbound=true
            [ "$pf" ] && reload_pf=true
            [ "$wg" ] && restart_wg=true
        ;;
        *" CLIENTS "*)
            [ "$dhcpd" ] && restart_dhcpd=true
            [ "$wg" ]    && restart_wg=true
            [ "$pf" ]    && reload_pf=true
    esac
}

del_interface() {
    local _iface
    _iface=$(echo "$_line" | sed -En "s|.*delete iface iface#[0-9]+ ([[:alnum:]]+).*|\1|p")

    [ "$_iface" ] || return 0
    IFACES=$(echo "$IFACES" | sed -E "s/$_iface,//g") # remove interface from global tracker

    # Keep resolvconf runtime clean by deleting old files
    resolvconf -f -d "${_iface}.qubsd" 2>/dev/null
    resolvconf -f -d "${_iface}"       2>/dev/null   # in case dhclient didn't
}

restart_services() {
    [ "$restart_dhcpd" ]   && unset restart_dhcpd   && service isc-dhcpd restart
    [ "$restart_unbound" ] && unset restart_unbound && service local_unbound restart
    [ "$restart_wg" ]      && unset restart_wg      && service wireguard restart
    [ "$restart_dns" ]     && unset restart_dns     && service dnscrypt-proxy restart
    [ "$reload_pf" ]       && unset reload_pf       && service pf reload
}

run_startup_actions() {
    local _ifaces _iface

    if [ "$init_flag" ] ; then
        set_pf_wg_endpoint # Table persists after pf reload, but is still alterable at seclvl < 3

        stdout_dhclient_conf > /tmp/qubsd_dhclient.conf  # Always written, doesnt hurt anything

        case "$dns:$unbound" in
            :) : ;; # No action. resolvconf needs no reference to dns or unbound
            true:*) # Dont let resolvconf overwrite unbound forward.conf (already points at dnscrypt)
                stdout_dnscrypt_resolvconf >> /etc/resolvconf.conf ;;
            *:true) # resolvconf will overwrite unbound forward.conf with the highest priority DNS
                stdout_unbound_resolvconf  >> /etc/resolvconf.conf ;;
        esac
    fi

    # Interfaces must be added/initialized at jail start
    _ifaces=$(ifconfig -l | tr ' ' '\n' | grep -E '^(epair[0-9]+[ab]|tap[0-9]+)$')
    for _iface in $_ifaces ; do
        add_interface
    done
}

open_fifo() {
    # Ensure there's no stale FIFO, then open FD3 for both read/write (must do both)
    FIFO=/tmp/fifo
    rm -f $FIFO
    mkfifo $FIFO
    exec 3<> $FIFO

    # Start streaming `route` output
    route -n monitor >&3 &

    # Log the background pid, and set the cleanup trap
    monitor_pid=$!
    trap "cleanup_daemon" INT TERM HUP QUIT EXIT
}

read_fifo_loop() {
    local _line

    # Keep-alive loop + 1sec read timeout, debounces service restart flags, which prevents
    # rapid-fire host vnet events from thrashing/live-locking the system on rapid service restarts
    while :; do
        if read -rt 1 _line <&3 ; then
            case "$_line" in
                *" add/repl iface iface"*) add_interface ;;
                *" delete iface iface"*)   del_interface ;;
                *) : ;;  # No action, signal not relevant
            esac
        else
            # Services only restart if there's a ~1sec gap in `route` output.
            restart_services
        fi
    done
}

# Service file launches this script once, blocking; then a second time, daemonized.
# Blocking prevents racing exec.poststart to schg files before daemon can write them
main() {
    # Enabled services recorded as globals, to generate configs and flag restarts based on events
    get_services

    # Generate the config files, track interfaces, add/initialize interfaces
    [ "$first_init" ] || re_init_flag=true
    run_startup_actions
    [ "$first_init" ] && exit 0  # Exit after first_init, to relaunch daemonized

    # Named pipe is used to monitor dynamic interface changes by the host made inside the jail
    open_fifo
    read_fifo_loop
}

first_init="$1"
main
exit 0

