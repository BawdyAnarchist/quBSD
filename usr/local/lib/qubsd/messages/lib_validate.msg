
:w:memwarn:
Failed to find "avail memory" in dmesg.boot. Couldn't validate that cell < %s > memory is below sys resources.
/END/

:w:validate_param_maxmem:
Cell < %s > MAXMEM < %s > (%s bytes)
is greater than avail memory < %s bytes > 
/END/

:w:validate_param_memsize:
Cell < %s > MEMSIZE < %s > (%s bytes)
is greater than avail memory < %s bytes > 
/END/

:validate_param_mtu:
Cell < %s > MTU < %s > is outside of sanity bounds: %s to %s
/END/

:validate_param_ipv4:
Cell < %s > IPV4 < %s > conflicts with running config of gateway < %s >
/END/

:w:validate_param_ipv4:
IPV4 assignment has no effect for VM < %s >. You must modify internal VM config
/END/

:w:validate_param_ipv42:
Cell < %s > IPV4 < %s > collides with sibling client of gateway < %s >
/END/

:w:validate_param_ipv43:
GATEWAY < %s > is a VM. Most VM-gateways serve DHCP to clients, not static IP
/END/

:validate_param_cpuset:
Cell < %s >, invalid cpuset < %s >. Valid cores are < %s > 
/END/

:validate_param_vcpus:
Cell < %s >, invalid VCPUS < %s >
Must be less than cores on the host < %s >, and less than bhyve limit of 16
/END/

:validate_cell_dependency:
Cell < %s > has dependency on cell < %s >, but is missing config < %s >
/END/

:missing_zfs:
Cell < %s > has dependency on cell < %s >, but missing dataset < %s >
/END/

:validate_cellname:
Cellname < %s > collides with existing %s < %s >
/END/

