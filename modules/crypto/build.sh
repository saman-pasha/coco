#!/bin/sh
# Build The Coco's crypto modules into shared objects on the library
# path. Each is a Cicili module against cocolog's lib/sdk.cicili, which
# is symlinked in beside the sources so the `./sdk.cicili' imports
# resolve -- the same trick cocolog's embed/build.sh uses for the
# engine. Nothing of cocolog is modified; the .so's are The Coco's.
#
#   CICILI   a Cicili checkout       (default $HOME/cicili)
#   COCOLOG  a cocolog checkout      (default a sibling ../cocolog)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
CICILI=${CICILI:-$HOME/cicili}
COCOLOG=${COCOLOG:-$ROOT/../cocolog}

ln -sfn "$COCOLOG/lib/sdk.cicili" "$HERE/sdk.cicili"

OUT="$ROOT/library"
mkdir -p "$OUT"

for mod in keccak secp256k1 sha512 ed25519; do
  ( cd "$CICILI" && sbcl --script cicili.lisp "$HERE/$mod.cicili" )
  gcc -shared -fPIC -O2 -o "$OUT/$mod.so" "$HERE/$mod.c"
  echo "built $OUT/$mod.so"
done
