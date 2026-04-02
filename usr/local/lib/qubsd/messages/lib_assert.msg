
:_invalid:
Invalid %s < %s >
/END/

:_invalid2:
Invalid %s < %s >. %s
/END/

:assert_optarg:
User Error: Bad options usage
/END/

:assert_args_set:
Argument missing or blank
/END/

:assert_bool_tf:
Boolean string required: [true|false]
/END/

:assert_bhyve_custm:
PARAM bhyve_custm may contain only the following characters: < a-Z 0-9 -_:,.=+ >
/END/

:assert_bhyveopts1:
%s < %s > contains an invalid option. Permissible: <AaCDeHhPSuWwxY>.
/END/

:assert_bhyveopts2:
%s < %s > contains a duplicate character.
/END/

:assert_cellname:
Invalid cellname < %s >. Must start/end with alpha-numeric.
May contain '-' or '_', but not consecutively.
/END/

:assert_cpuset:
Invalid cpuset format < %s >. Must be comma separated intergers, a range, or combination. See man 1 cpuset
/END/

:assert_dataset_name:
Invalid dataset name < %s >. See man 8 zpool-create for valid naming rules
/END/

:assert_integer:
Invalid input: < %s >. Integer required.
/END/

:assert_int_comparison:
%s %s %s
/END/

:assert_ipv4:
%s < %s > is not CIDR. Use CIDR notation for IPV4 addr, or <none|DHCP|auto>.
/END/

:assert_ipv4_2:
IPaddr: < %s > is CIDR; however, quBSD reserves the '.1' ending for the gateway.
   If you MUST use '.1', then use IPV4="none" , and configure a persistent rc.conf.local
/END/

:assert_param:
< %s > is not a valid tunable qubsd PARAMETER
/END/

:assert_ppt:
Invalid PPT format < %s >. See `man 4 vmm` for correct pptdevs formatting
/END/

:assert_time_format:
< %s > is an invalid time format. Must be: <integer><s|m|H|D|W|Y>. eg: '30m'
/END/
