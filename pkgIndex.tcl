# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex -lazy" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded wyseman 0.40 [list tclPkgSetup $dir wyseman 0.40 {{libwyseman.so load macscan} {erd.tcl source ::erd::erd} {wmparse.tcl source {::wmparse::dropdep ::wmparse::expand ::wmparse::family ::wmparse::field ::wmparse::level ::wmparse::parse interp0}} {wmddict.tcl source {::wmddict::bootstrap ::wmddict::schema ::wmddict::tabtext}} {wmdd.tcl source {::wmdd::column ::wmdd::columns ::wmdd::columns_fk ::wmdd::errtext ::wmdd::pkey ::wmdd::table ::wmdd::table_parts ::wmdd::tables_ref ::wmdd::type ::wmdd::value}}}]
