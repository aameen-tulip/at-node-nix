/**
 * REGEX with named components ( for reference ):
 * ^(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)(?:-(?P<prerelease>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?P<buildmetadata>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
 *
 * REGEX with regular capture components:
 * ^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$
 *
 *
 *
 * Range comparators:
 *   =   Used if no qualifier is stated ( "foo@1.0" is really "foo@=1.0" )
 *   <=, >=, <, > allow two version specs but do latest/min are assumed when only one is given.
 *  || separate comparator expressions.
 *
 *  x - y  "ranges" are syntactic sugar for ">=x <=y"
 *
 *  With subversions there's a special caveat:
 *  1.2.3 - 2.3  :=  >=1.2.3 <2.4.0-0
 *  1.2.3 - 2    :=  >=1.2.3 <3.0.0-0
 */

# FIXME
null
