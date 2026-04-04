
#########################################

:assert_args_set:
Argument missing or blank
/END/

:assert_bhyveopts_1:
Invalid BHYVE option. Permissible: <AaCDeHhPSuWwxY>
/END/

:assert_bhyveopts2:
BHYVE options contains a duplicate character
/END/

:assert_bhyve_custm:
PARAM bhyve_custm may contain only the following characters: < a-Z 0-9 -_:,.=+ >
/END/

:assert_bool_tf:
Boolean string required: [true|false]
/END/

:assert_bytesize:
Requires: <integer><size> (eg: 5g or 5G or 12k)
/END/

:assert_cellname:
Invalid cellname < %s >. Must start/end with alpha-numeric.
  May contain '-' (dash) or '_' (underscore), but not consecutively.
/END/

:assert_cellname_2:
Cellname cannot be: 'none', 'qubsd', or 'host'
/END/

:assert_class:
Must be one of: < %s >
/END/

:assert_cpuset:
Require:  comma separated: (intergers, range, or combination). See man 1 cpuset
/END/

:assert_dataset_name:
Dataset name invalid. See man 8 zpool-create for valid naming rules
/END/

:assert_devfs_rule:
Requires: Integer greater than 0
/END/

:assert_integer:
Integer required.
/END/

:assert_int_comparison:
Integer comparison failure. %s not %s %s
/END/

:assert_ipv4:
Require: CIDR IVP4 address; or one of the following: <none|auto|DHCP>
/END/

:assert_ipv4_2:
IPaddr: < %s > is CIDR; however, quBSD reserves the '.1' ending for the gateway.
  If you MUST use '.1', then use IPV4="none" , and configure a persistent rc.conf.local
/END/

:assert_optarg:
User Error: Bad options usage
/END/

:assert_param:
Invalid parameter. Valid PARAMS are: %s
/END/

:assert_ppt:
Require: pptdevs format. For correct formatting, see:  man 4 vmm
/END/

:assert_ptype:
Require: <base|BASE|jail|JAIL|vm|VM>
/END/

:assert_schg:
Require:  <none|sys|all>
/END/

:assert_seclvl:
Require:  <-1|0|1|2|3>
/END/

:assert_taps:
Require: Integer greater than 0
/END/

:assert_time_format:
< %s > is an invalid time format. Must be: <integer><s|m|H|D|W|Y>. eg: '30m or 6H or 30D'
/END/

:assert_vcpus:
Require: Integer greater than 0
/END/

