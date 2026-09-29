"""Code shared by this project's composition functions.

Each function is built and packaged on its own, from its own directory, so a function cannot
import a sibling. This package is shared by symlink instead: every function carries a
`function/common` symlink pointing here, and `up` follows symlinks when it packages a
function's source, so each built function gets its own copy of this directory.

Keep it free of imports from any one function, and of anything a function would not want.
"""
