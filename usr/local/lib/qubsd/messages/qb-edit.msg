
:val_missing:
Must propose a value 
/END/

:mutual_exclusive:
[-d] and [-c] are mutually exclusive. Either modify the defaults, or modify a cell
/END/

:cell_missing:
Must provide either [-c <cell>] or [-d <base|jail|VM>] as target to act upon
/END/

:param_missing:
Must provide [-p <PARAMETER>] to change
/END/

:defaults_mismatch:
[-d] is incompatible with PARAMETER < %s >. May only be applied to a specific cell.
/END/

:defaults:
[-d] < %s > is invalid. Must be one of: < jail|vm|all >
/END/

:delete:
PARAM < %s > may not be deleted. Only: BHYVE_CUSTM and PPT may be deleted
/END/

:delete2:
Cannot use [-D] without -c <cell> to operate on
/END/

:delete3:
PARAM < %s > is already not present in cell < %s > config
/END/

:no_change:
New value is equal to the old
/END/

:param_invalid:
PARAM < %s > is invalid
/END/

:param_warn:
PARAM < %s >. Use [-f] to force dangerous value (will throw on jail launc
/END/

:defaults_base:
PARAM < %s > is not part of the allowable defaults.base.conf params
/END/

:w:usage:

qb list: List parameters of a cell 

Usage:
  qb edit [-z] [-c <cell>] [-p <param>]
  qb edit [-s][-z] [-c <cell>]
  qb edit <cell>
  qb edit <cell> <param>
  # Will generally work without [-c][-p]

  -h: (h)elp: Outputs this help message
  -c: (c)ell: Show settings for <cell>
  -p: (p)aram: Show values for all cells of <param> 
  -s: (s)napshots: Show zfs snapshots for <cell>. This will
      suppress bulk params, and print only snapshots.
  -z: (z)fs: Show zfs datasets for <cell> 
/END/
