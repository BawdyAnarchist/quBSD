
:validate_cellname:
Cell < %s > has no config in %s
/END/

:validate_cellname_new:
Cellname < %s > collides with existing %s < %s >
/END/

:_cellref:
Cell < %s > has an invalid %s < %s >
/END/

:w:_cellref:
Cell < %s > %s < %s > is an invalid cell
/END/

:validate_param_cpuset:
Cell < %s >, invalid cpuset < %s >. `cpuset -g` for list of available CPUs
/END/

:validate_param_ipv4:
Cell < %s > IPV4 < %s > collides with sibling client of gateway < %s >
/END/

:validate_param_ipv4_2:
Cell < %s > IPV4 < %s > conflicts with running config of gateway < %s >
/END/

:w:validate_param_ipv4:
IPV4 assignment has no effect for VM < %s >. You must modify internal VM config
/END/

:w:validate_param_ipv4_2:
GATEWAY < %s > is a VM. Most VM-gateways serve DHCP. Ensure GATEWAY is configured for this IP addr
/END/

:w:memwarn:
Failed to find "avail memory" in dmesg.boot. Couldn't validate that cell < %s > memory is below sys resources.
/END/

:w:validate_param_maxmem:
Cell < %s > MAXMEM < %s > (%s bytes)
is greater than avail memory < %s bytes > 
/END/

:validate_param_memsize:
Cell < %s > MEMSIZE < %s > (%s bytes)
is greater than avail memory < %s bytes > 
/END/

:validate_param_mtu:
Cell < %s > MTU < %s > is outside of sanity bounds: %s to %s
/END/

:validate_param_ppt:
Cell < %s > has invalid PPT < %s >
/END/

:validate_param_template:
Cell < %s > CLASS not found. Could not validate TEMPLATE < %s >
/END/

:validate_param_vcpus:
Cell < %s >, invalid VCPUS < %s >
Must be less than cores on the host < %s >, and less than bhyve limit of 16
/END/

:_missing_zfs:
Cell < %s > is missing dataset < %s >
/END/
