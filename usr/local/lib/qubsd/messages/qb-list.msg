
:blank_cell:
[-s]|[-z] requires a cell to operate on for zfs
/END/

:missing_cell:
< %s > doesnt exist in %s
/END/

:w:usage:

qb list: List parameters or datasets associated with a cell

Usage:
  qb list [-z] [-c <cell>] [-p <param>]
  qb list [-s][-z] [-c <cell>]
  qb list <cell>
  qb list <cell> <param>
  # Will generally work without [-c][-p]

  -h: (h)elp: Outputs this help message
  -c: (c)ell: Show settings for <cell>
  -p: (p)aram: Show values for all cells of <param>
  -s: (s)napshots: Show zfs snapshots for <cell>. This will
      suppress bulk params, and print only snapshots.
  -z: (z)fs: Show zfs datasets for <cell>
/END/
