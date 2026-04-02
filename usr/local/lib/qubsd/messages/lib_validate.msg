
:validate_cellname:
Cell < %s > has no config in %s
/END/

:validate_cellname_new:
Cellname < %s > collides with existing %s < %s >
/END/

:_invalid:
Invalid %s: < %s >
/END/

:validate_param_cpuset:
Invalid cpuset: < %s >. For a list of available CPUs: cpuset -g
/END/

:validate_param_ipv4:
Cell < %s > IPV4 < %s > collides with sibling client of gateway < %s >
/END/

:validate_param_ipv4_2:
Cell < %s > IPV4 < %s > conflicts with running config of gateway < %s >
/END/

:w:validate_param_ipv4:
IPV4 CIDR assignment has no effect on VMs. You must modify internal VM config
/END/

:w:validate_param_ipv4_2:
GATEWAY < %s > is a VM. Most VM-gateways serve DHCP. Ensure GATEWAY is configured for this IP addr
/END/

:w:memwarn:
Failed to find "avail memory" in dmesg.boot. Couldn't validate that cell < %s > memory is below sys resources.
/END/

:w:validate_param_maxmem:
MAXMEM < %s > (%s bytes)
is greater than avail memory < %s bytes >
/END/

:validate_param_memsize:
MEMSIZE < %s > (%s bytes)
is greater than avail memory < %s bytes >
/END/

:validate_param_mtu:
MTU < %s > is outside of IPv4 spec boundaries: %s to %s
/END/

:w:validate_param_mtu:
MTU < %s > is outside of normal boundaries: %s to %s (IPv6 min to jumbo packet normal max)
/END/

:validate_param_vcpus:
Invalid VCPUS: < %s >.  Must be less than cores on host < %s >, and less than bhyve limit: 16
/END/

:_missing_zfs:
Dataset: < %s > could not be found
/END/
