
:_invalid:
Parameter: < %s > has invalid value: < %s >
/END/

:validate_cellname:
Cell < %s > has no config in %s
/END/

:validate_cellname_new:
Cellname < %s > collides with existing %s < %s >
/END/

:validate_param_cpuset:
Invalid %s: < %s >. One or more listed cores was not found.
  For a list of available CPUs run: cpuset -g
/END/

:validate_param_devfs_rule:
Invalid %s. Rule number < %s > was not found in %s
/END/

:validate_param_ipv4:
IPV4 CIDR assignment has no effect on VMs. You must modify internal VM config
/END/

:validate_param_ipv4_2:
GATEWAY < %s > is a VM. Most VM-gateways serve DHCP. Ensure GATEWAY is configured for this IP addr
/END/

:validate_param_ipv4_3:
Cell < %s > IPV4 < %s > collides with sibling client of gateway < %s >
/END/

:validate_param_ipv4_4:
Cell < %s > IPV4 < %s > conflicts with running config of gateway < %s >
/END/

:validate_param_maxmem:
< %s > (%s < %s >) is greater than avail memory:
  %s
/END/

:validate_param_memsize:
< %s > (%s < %s >) is greater than avail memory:
  %s
/END/

:validate_param_mtu:
MTU < %s > is outside of IPv4 spec boundaries: %s to %s
/END/

:validate_param_mtu_2:
MTU < %s > is outside of normal boundaries: %s to %s (IPv6 min to jumbo packet normal max)
/END/

:validate_param_vcpus:
Invalid %s: < %s >.  Must be less than cores on host (%s), and less than bhyve limit (16)
/END/

:missing_zfs:
Dataset: < %s > could not be found
/END/
