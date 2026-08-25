#!/bin/sh
# Build The Coco's crypto modules into shared objects on the library
# path. Each is a Cicili module against cocolog's lib/sdk.cicili, which
# is symlinked in beside the sources so the `./sdk.cicili' imports
# resolve -- the same trick cocolog's embed/build.sh uses for the
# engine. Nothing of cocolog is modified; the .so's are The Coco's.
#
# WHERE THE MODULE LIST COMES FROM: coco.yaml, under `modules.crypto',
# and nowhere else. The checkouts (CICILI, COCOLOG) come from the same
# file unless the environment already names them. Adding a module means
# adding a line there -- a build script that carries its own list is a
# second copy of a fact, and the second copy is the one that goes stale.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../../test/config.sh"

ln -sfn "$COCOLOG/lib/sdk.cicili" "$HERE/sdk.cicili"

OUT="$COCOLOG_LIBRARY"
mkdir -p "$OUT"

for mod in $COCO_MODULES_CRYPTO; do
  ( cd "$CICILI" && sbcl --script cicili.lisp "$HERE/$mod.cicili" )
  gcc -shared -fPIC -O2 -o "$OUT/$mod.so" "$HERE/$mod.c"
  echo "built $OUT/$mod.so"
done
