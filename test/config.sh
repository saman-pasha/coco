#!/bin/sh
# Read coco.yaml. SOURCE this, do not run it:
#
#   HERE=$(cd "$(dirname "$0")" && pwd)
#   . "$HERE/config.sh"          # or ../test/config.sh from elsewhere
#
# Afterwards ROOT is the repository root, the well-known environment
# variables (CICILI, ZIGURATIP, ZIGURATIP_HOME, COCOLOG, COCOLOG_LIBRARY,
# ZIGURAT_HOST, ZIGURAT_PORT, ZIGURAT_TIMEOUT, ZIGURAT_KB) are set, and
# every entry in the file is available as COCO_<SECTION>_<KEY> --
# COCO_MODULES_CRYPTO and COCO_SUITE_CASES being the two lists,
# space-separated, ready for a `for'.
#
# THE ENVIRONMENT WINS. Anything already exported is left exactly as it
# is; the file only fills in what is missing. That is what lets CI point
# the hub at a scratch tree without editing a tracked file, and it is why
# the assignments below are `${VAR:-...}' and not plain sets.
#
# THE PARSER IS THIRTY LINES OF AWK and the subset is the one coco.yaml
# documents: `key: value' at two levels, `- item' lists, `#' comments
# after whitespace. It is not YAML and does not pretend to be. If a
# configuration ever needs more than this, the configuration is wrong --
# The Coco's four materials do not include a schema language.

# ROOT is found by WALKING UP from the sourcing script until coco.yaml
# appears, rather than by counting `..' -- a sourced file cannot know its
# own path portably, and a script that moves one directory deeper should
# not have to know it did.
_coco_here=$(cd "$(dirname "${0:-.}")" && pwd)
ROOT=""
_coco_up="$_coco_here"
while [ "$_coco_up" != "/" ]; do
  if [ -f "$_coco_up/coco.yaml" ]; then ROOT="$_coco_up"; break; fi
  _coco_up=$(dirname "$_coco_up")
done
if [ -z "$ROOT" ]; then
  echo "config.sh: no coco.yaml above $_coco_here" >&2
  return 1 2>/dev/null || exit 1
fi
export ROOT

_coco_yaml="$ROOT/coco.yaml"
if [ ! -f "$_coco_yaml" ]; then
  echo "config.sh: no coco.yaml at $_coco_yaml" >&2
  return 1 2>/dev/null || exit 1
fi

# Values are emitted inside double quotes and eval'd, so ${HOME} and
# ${ROOT} in the file expand the way they read.
eval "$(awk '
  function flush(t) { if (t != "" && list[t] != "") printf "COCO_%s=\"%s\"\n", toupper(t), list[t] }
  {
    line = $0
    sub(/^[ \t]*#.*$/, "", line)      # a whole comment line
    sub(/[ \t]+#.*$/,  "", line)      # a comment after a value
    if (line ~ /^[ \t]*$/) next
    match(line, /^ */); ind = RLENGTH
    gsub(/^[ \t]+|[ \t]+$/, "", line)

    if (line ~ /^- /) {               # a list item, for whatever is open
      item = substr(line, 3)
      gsub(/^[ \t]+|[ \t]+$/, "", item)
      list[target] = (list[target] == "" ? item : list[target] " " item)
      next
    }

    ci = index(line, ":"); if (ci == 0) next
    k = substr(line, 1, ci - 1); v = substr(line, ci + 1)
    gsub(/^[ \t]+|[ \t]+$/, "", k); gsub(/^[ \t]+|[ \t]+$/, "", v)

    if (ind == 0) { sec = k; target = k }
    else if (v == "") { target = sec "_" k }
    else printf "COCO_%s=\"%s\"\n", toupper(sec "_" k), v
  }
  END { for (t in list) flush(t) }
' "$_coco_yaml")"

# A path that exists comes back absolute and without `..'; one that does
# not is left as written, so the message a script prints when a pillar is
# missing still names what was looked for.
_coco_real() { ( cd "$1" 2>/dev/null && pwd ) || printf '%s\n' "$1"; }
for _v in COCO_PILLARS_CICILI COCO_PILLARS_ZIGURAT COCO_PILLARS_ZIGURAT_HOME \
          COCO_PILLARS_COCOLOG; do
  eval "$_v=\$(_coco_real \"\$$_v\")"
done
unset _v

CICILI=${CICILI:-$COCO_PILLARS_CICILI};                export CICILI
ZIGURATIP=${ZIGURATIP:-$COCO_PILLARS_ZIGURAT};         export ZIGURATIP
ZIGURATIP_HOME=${ZIGURATIP_HOME:-$COCO_PILLARS_ZIGURAT_HOME}; export ZIGURATIP_HOME
COCOLOG=${COCOLOG:-$COCO_PILLARS_COCOLOG};             export COCOLOG
# THE SEARCH PATH IS TWO DIRECTORIES: ours, then cocolog's. cocolog's
# tcp, torch, bigint and curl are loadable modules under its own library/
# now rather than builtins, so without the second entry `library(torch)'
# is not found -- which showed up as `training SKIP (no torch in this
# cocolog build)' while the runner still printed `red: 0'. A case going
# GREEN to SKIP in silence is the hazard cocolog's CLAUDE.md names.
#
# COCO_PATHS_LIBRARY stays ONE directory, and is what modules/*/build.sh
# writes into. A build script that `mkdir -p'-s a colon-separated list
# makes a directory named `library:', which is how this was found.
#
# THE ENVIRONMENT IS APPENDED TO, NOT SUBSTITUTED FOR, and this is the one
# variable in this file that works that way. Everywhere else `${VAR:-...}'
# is right: a caller who names a cocolog binary means THAT binary, and the
# file should get out of the way. But the two directories above are not a
# default anybody could have meant to replace -- they are where The Coco's
# own modules and cocolog's own libraries ARE, so a caller who set
# COCOLOG_LIBRARY to add a path of their own would have silently removed
# both and the suite would have gone SKIP with `red: 0' over it.
#
# So the answer to "how do I put my own modules on the path" is now just:
#
#     COCOLOG_LIBRARY=/opt/my/modules sh test/run.sh
#
# and it is APPENDED, behind the two that have to be there. Ours first is
# deliberate for the same reason cocolog's own test/library-path.sh puts
# its checkout first: a suite that let somebody else's `library(poa)' win
# would be green about somebody else's code.
COCOLOG_LIBRARY="$COCO_PATHS_LIBRARY:$COCO_PILLARS_COCOLOG/library${COCOLOG_LIBRARY:+:$COCOLOG_LIBRARY}"
export COCOLOG_LIBRARY
ZIGURAT_HOST=${ZIGURAT_HOST:-$COCO_ARRANGEMENT_HOST};  export ZIGURAT_HOST
ZIGURAT_PORT=${ZIGURAT_PORT:-$COCO_ARRANGEMENT_PORT};  export ZIGURAT_PORT
ZIGURAT_TIMEOUT=${ZIGURAT_TIMEOUT:-$COCO_ARRANGEMENT_TIMEOUT}; export ZIGURAT_TIMEOUT
ZIGURAT_KB=${ZIGURAT_KB:-$COCO_ARRANGEMENT_KB};        export ZIGURAT_KB

# ---- how a node dials the store ---------------------------------------
#
# ONE STRING, BUILT ONCE. Every script here used to write
# `--host $ZIGURAT_HOST --port $ZIGURAT_PORT' for itself -- twelve
# copies of one decision, which is the drift this file exists to stop,
# and twelve places to edit to try the hub over an encrypted link. They
# say `$ZIGURAT_DIAL' now.
#
# `--port' IS DEPRECATED IN COCOLOG and this is where it stopped being
# spelled: `--tcp PORT' is the same field and names the transport as
# well as the number, which is the whole point of having four of them.
#
# THE CERTIFICATES ARE OPTIONAL, and only under `tls'. A cocolog with
# neither `--cert' nor `--key' still speaks TLS -- ZiguratIP's
# `SERVER/TLS_CLIENT_AUTH' takes NONE and OPTIONAL as well as its
# REQUIRED default -- and what a certificate is MANDATORY for is
# `SECURITY/PERMISSIONS_MODE', where an uncertificated TLS peer is
# identified with an empty permission set and reaches nothing. Naming one
# without the other is a mistake cocolog refuses by name, so this refuses
# it here too, where the message can say which file is missing.
ZIGURAT_TRANSPORT=${ZIGURAT_TRANSPORT:-$COCO_ARRANGEMENT_TRANSPORT}
ZIGURAT_TRANSPORT=${ZIGURAT_TRANSPORT:-tcp};           export ZIGURAT_TRANSPORT
ZIGURAT_CACERT=${ZIGURAT_CACERT:-$COCO_ARRANGEMENT_CACERT}; export ZIGURAT_CACERT
ZIGURAT_CERT=${ZIGURAT_CERT:-$COCO_ARRANGEMENT_CERT};  export ZIGURAT_CERT
ZIGURAT_KEY=${ZIGURAT_KEY:-$COCO_ARRANGEMENT_KEY};     export ZIGURAT_KEY

case "$ZIGURAT_TRANSPORT" in
  tcp) ZIGURAT_DIAL="--host $ZIGURAT_HOST --tcp $ZIGURAT_PORT" ;;
  tls)
    ZIGURAT_DIAL="--host $ZIGURAT_HOST --tls $ZIGURAT_PORT"
    [ -n "$ZIGURAT_CACERT" ] && ZIGURAT_DIAL="$ZIGURAT_DIAL --cacert $ZIGURAT_CACERT"
    if [ -n "$ZIGURAT_CERT" ] && [ -n "$ZIGURAT_KEY" ]; then
      ZIGURAT_DIAL="$ZIGURAT_DIAL --cert $ZIGURAT_CERT --key $ZIGURAT_KEY"
    elif [ -n "$ZIGURAT_CERT$ZIGURAT_KEY" ]; then
      echo "config.sh: a client certificate needs both cert and key" >&2
      return 1 2>/dev/null || exit 1
    fi
    ;;
  *)
    echo "config.sh: arrangement.transport is tcp or tls, not '$ZIGURAT_TRANSPORT'" >&2
    return 1 2>/dev/null || exit 1
    ;;
esac
export ZIGURAT_DIAL

COCOLOG_BIN="$COCOLOG/cocolog"
unset _coco_here _coco_yaml _coco_up
