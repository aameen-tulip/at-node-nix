#! /usr/bin/env bash
set -eu;

URL="https://docs.npmjs.com/cli/v6/using-npm/config";

: "${CURL:=curl}";
: "${CAT:=cat}";
: "${SED:=sed}";
: "${HXNORMALIZE:=hxnormalize}";
: "${HXREMOVE:=hxremove}";
: "${HXSELECT:=hxselect}";

fetchPage() {
  $CURL -sL "$URL";
}

# First phase of filtering.
# Removes any hyperlinks, and yanks H3 tags ( used to identify config block ),
# and preserves elements that we will pull information from.
scrapeUsedElements() {
  $HXNORMALIZE -x </dev/stdin            \
    |$HXREMOVE a                         \
    |$HXSELECT -s '\n' 'h3, h4, ul, p';
}

# Drop anything before or after the "Config Settings" ( H3 ) section.
yankConfigSettingsSection() {
  $SED -e '/id="config-settings"/,$!d'  \
       -e '/id="see-also"/,$d'          \
    </dev/stdin;
}

# I know what you're thinking, "use an \(a\|b\) group" - we can't because
# "<" preceding a capture group has a special meaning, and for whatever reason
# I can't seem to escape it even with "[<]\(...\)".
stripProperties() {
  $SED -e 's/<h\([34]\)[[:space:]][^>]*>/<h\1>/g'  \
       -e 's/<p[[:space:]][^>]*>/<p>/g'            \
       -e 's/<ul[[:space:]][^>]*>/<ul>/g'          \
       -e 's/<li[[:space:]][^>]*>/<li>/g'          \
       -e 's/<code[[:space:]][^>]*>/<code>/g'      \
    </dev/stdin;
}

dropH3() {
  $HXNORMALIZE -x </dev/stdin|$HXREMOVE h3;
}

runnit() {
  fetchPage                     \
    |scrapeUsedElements         \
    |yankConfigSettingsSection  \
    |stripProperties            \
    |dropH3                     \
    ;
}


# Reference: ----------------------------------------------------------------- #
#
# # scrape h4 and ul
# # FIXME: you need `<code>' blocks as well.
# cat ./npm-config-v6-settings.html    \
#   |hxnormalize -x                    \
#   |hxremove a                        \
#   |hxselect -s '\n' 'h4, ul'         \
#   > npm-config-v6-settings-hx.html;
#
# # strip class tags
# sed -e 's/<h4 [^>]*>/<h4>/'                     \
#     -e 's/<ul [^>]*>/<ul>/'                     \
#     ./npm-config-v6-settings-hx.html            \
#   |hxnormalize -x                               \
#   > ./npm-config-v6-settings-stripped-hx.html;
#
#
# # collect tag names quoted
# cat ./npm-config-v6-settings-stripped-hx.html  \
#   |hxselect -c -s '" "' h4                     \
#   |sed -e 's/ "$//'                            \
#        -e 's/^/"/'                             \
#        -e 's/" /"/g'                           \
#        -e 's/""/" "/g'                         \
#   ;
#
# # FIXME: Handle "Alias:" tags
# cat ./npm-config-v6-settings-stripped-hx.html                   \
#   |hxselect -s '\n' -c 'h4, li'                                 \
#   |sed -e 's/^ \([^ :]*\)$/}; \1 = {/'                          \
#        -e 's/^Type: \(.*\)$/  type = "\1";/'                    \
#        -e 's/^[[:space:]]*Default: \(.*\)$/  default = "\1";/'  \
#   > npm-config-v6-settings.nix;
#
#
# ---------------------------------------------------------------------------- #
