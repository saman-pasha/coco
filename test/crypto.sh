#!/bin/sh
# The chains' primitives: keccak256 and secp256k1, as loadable Cicili
# modules, and library(eth) composing them.
#
# WHAT IT IS CHECKING, and why each part is there:
#
#   KECCAK IS ETHEREUM'S, NOT NIST'S. Two published vectors (the empty
#   string and "abc") pin the permutation and the 0x01 domain padding;
#   a 200-byte input crosses the 136-byte rate so the absorb loop is
#   exercised more than once; and keccak256_hex proves the hex-input
#   path a chain needs, because RLP is arbitrary bytes.
#
#   THE CURVE IS THE CURVE. secp256k1_pubkey(1) must be G and
#   secp256k1_pubkey(2) must be 2G -- two constants anyone can look up,
#   and between them they exercise every piece of the field and point
#   arithmetic: multiply, reduce, invert, double, add, and the Jacobian
#   conversion back to affine.
#
#   SIGNATURES VERIFY, AND FORGERIES DO NOT. A good signature succeeds;
#   the same signature against a different hash FAILS -- fails, not
#   throws, because an invalid signature is an ordinary answer.
#
#   RECOVERY ANSWERS THE KEY THAT SIGNED. Which is the whole question an
#   EVM chain asks, and `eth_signer' takes it the last step to an
#   address.
#
#   THE ADDRESS OF PRIVATE KEY 1 IS PUBLIC KNOWLEDGE:
#   7e5f4552091a69125d5dfcb7b8c2659029395bdf. Nothing here computed
#   that constant -- it is the one number in this file that comes from
#   the world rather than from The Coco, and the two modules composing
#   to reach it is the end-to-end proof.
#
# SKIPs when the modules cannot be built (no sbcl, or no CICILI).

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
C="${COCOLOG:-$ROOT/../cocolog}/cocolog"
export COCOLOG_LIBRARY="$ROOT/library"

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-46s %s\n' "$1" "$(echo "$2" | cut -c1-24)"
  else
    printf 'FAIL %-46s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi

if [ ! -f "$ROOT/library/secp256k1.so" ] || [ ! -f "$ROOT/library/keccak.so" ]; then
  ( cd "$ROOT" && CICILI="${CICILI:-$HOME/cicili}" COCOLOG="${COCOLOG:-$ROOT/../cocolog}" \
      sh modules/crypto/build.sh ) > "$HERE/crypto-build.log" 2>&1 || true
fi
if [ ! -f "$ROOT/library/secp256k1.so" ]; then
  echo "SKIP (the crypto modules would not build -- no sbcl or CICILI checkout)"
  exit 0
fi

q() { timeout 120 "$C" query "$1" 2>/dev/null | grep -aoE "$2" | head -1; }

# ---- keccak256 -------------------------------------------------------
K="use_module(library(keccak))"
H='[0-9a-f]{64}'
check "keccak: the empty string" \
  "$(q "$K, keccak256_hex('0x', H), write(H), nl" "$H")" \
  "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
check "keccak: abc" \
  "$(q "$K, keccak256(abc, H), write(H), nl" "$H")" \
  "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"
check "keccak: the same, as hex bytes in" \
  "$(q "$K, keccak256_hex('616263', H), write(H), nl" "$H")" \
  "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"
check "keccak: 200 bytes, across the rate" \
  "$(q "$K, findall(0'a, between(1,200,_), L), keccak256(L, H), write(H), nl" "$H")" \
  "96ea54061def936c4be90b518992fdc6f12f535068a256229aca54267b4d084d"

# ---- secp256k1 -------------------------------------------------------
S="use_module(library(secp256k1))"
P='[0-9a-f]{128}'
GXY=79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8
check "secp256k1: private key 1 is the generator" \
  "$(q "$S, secp256k1_pubkey('01', P), write(P), nl" "$P")" "$GXY"
check "secp256k1: private key 2 is 2G" \
  "$(q "$S, secp256k1_pubkey('02', P), write(P), nl" "$P")" \
  "c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee51ae168fea63dc339a3c58419466ceaeef7f632653266d0e1236431a950cfe52a"

D=1111111111111111111111111111111111111111111111111111111111111111
PUB=4f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859ab0f0b704075871aa385b6b1b8ead809ca67454d9683fcf2ba03456d6fe2c4abe2b07f0fbdbb2f1c1
Z=4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45
SIG=466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f275ae07fee4307d1463bdae06d383eeff912ae0db208dd20d37998bcd19b5f6316
BAD=0000000000000000000000000000000000000000000000000000000000000001

check "secp256k1: a key derives from its secret" \
  "$(q "$S, secp256k1_pubkey('$D', P), write(P), nl" "$P")" "$PUB"
check "secp256k1: a good signature verifies" \
  "$(q "$S, (secp256k1_verify('$Z','$SIG','$PUB') -> write(yes) ; write(no)), nl" '^(yes|no)$')" \
  "yes"
check "secp256k1: the same signature, another hash" \
  "$(q "$S, (secp256k1_verify('$BAD','$SIG','$PUB') -> write(yes) ; write(no)), nl" '^(yes|no)$')" \
  "no"
check "secp256k1: the uncompressed 04 spelling" \
  "$(q "$S, (secp256k1_verify('$Z','$SIG','04$PUB') -> write(yes) ; write(no)), nl" '^(yes|no)$')" \
  "yes"
check "secp256k1: recovery answers the signing key" \
  "$(q "$S, secp256k1_recover('$Z','$SIG',0,P), write(P), nl" "$P")" "$PUB"
check "secp256k1: the wrong recovery id does not" \
  "$(q "$S, (secp256k1_recover('$Z','$SIG',1,P), P == '$PUB' -> write(same) ; write(other)), nl" '^(same|other)$')" \
  "other"

# ---- library(eth): a Prolog library over two compiled modules --------
E="use_module(library(eth))"
A='[0-9a-f]{40}'
check "eth: the address of private key 1" \
  "$(q "$E, eth_address('$GXY', A), write(A), nl" "$A")" \
  "7e5f4552091a69125d5dfcb7b8c2659029395bdf"
check "eth: an address from the 04 spelling too" \
  "$(q "$E, eth_address('04$GXY', A), write(A), nl" "$A")" \
  "7e5f4552091a69125d5dfcb7b8c2659029395bdf"
check "eth: who signed this -- recover to an address" \
  "$(q "$E, eth_signer('$Z', '$SIG', 0, A), write(A), nl" "$A")" \
  "19e7e376e7c213b7e7e7e46cc70a5dd086daff2a"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
