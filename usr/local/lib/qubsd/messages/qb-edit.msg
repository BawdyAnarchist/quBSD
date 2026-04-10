
:extra_args:
Extra (useless) args provided. Double check your usage
/END/

:cell_missing:
Must provide either [-c <cell>] or [-d <base|jail|VM>] default file to act upon
/END/

:param_missing:
Must provide [-p <PARAMETER>] to change
/END/

:value_missing:
Must provide a <VALUE> for %s
/END/

:mutual_exclusive:
[-d] and [-c] are mutually exclusive. Either modify the defaults, or modify a cell
/END/

:host:
The only modifiable PARAMS for host are: <%s>
/END/

:ptype:
Invalid usage of [-d <default>]
/END/

:type:
Type mismatch. PARAM < %s > is for %s, but target < %s > is %s
/END/

:default_invalid:
[-d] is incompatible with PARAMETER < %s >. May only be applied to a specific cell.
/END/

:delete_class:
CLASS is a hard requirement for each individual cell config.
  Defaults are for convenience, not config/fallback guarantees
/END/

:delete_nothing:
PARAM < %s > is already not present in file:
  %s
/END/

:no_change:
New value is equal to the old
/END/

:ipv4:
Do not assign a unique CIDR to %s. This will cause networking breakage.
  IPV4 defaults can only be one of the following:  <none|auto|DHCP>
/END/

:mtu:
Recommend no default MTU. System already defaults to 1500. Focus on gateways, especially
wireguard. Clients receive auto adjustment downwards to never exceed the gateway MTU.
/END/

:use_force:
  \n  PROPOSED CHANGES WOULD CAUSE CONFIG/RUNTIME ERRORS. Use [-F] to override
/END/

:deletion_errors:
%s
Deleting PARAM: < %s > breaks the following cells:
%s
/END/

:warning_header:
The change was completed, but be advised of the following warnings:
/END/

:usage:

qb edit: Edit the parameters of a cell, or defaults files

Usage:
  qb edit [-c <cell>|-d <base|jail|vm>] [-D] [-p <param>] <value>

  # Can generally use positionals instead of options. In this order:
  qb edit [-D] [-d <base|jail|vm>]|<cell> <param> <value>

  -c: (c)ell: Cell to edit. Mutually exclusive with [-d]
  -d: (d)efault: Default file to change <base|jail|vm>
  -D: (D)elete: Remove the specified <param> from <cell>|<default>
      Specify <value> to delete only that. Othewise entirely removed
  -h: (h)elp: Outputs this help message
  -p: (p)aram: Parameter to operate on
/END/
