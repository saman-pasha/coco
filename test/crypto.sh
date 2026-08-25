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
#   ED25519 IS HELD TO RFC 8032 BYTE FOR BYTE. Ed25519 signing is
#   DETERMINISTIC -- there is no nonce -- so the published signatures
#   can be reproduced exactly, which is the strongest test a signature
#   scheme admits: every part of the scheme (SHA-512, the clamping, the
#   scalar multiply, the point encoding, the challenge hash, the
#   arithmetic mod L) has to be right or the 64 bytes differ.
#
#   THE ADDRESS OF PRIVATE KEY 1 IS PUBLIC KNOWLEDGE:
#   7e5f4552091a69125d5dfcb7b8c2659029395bdf. Nothing here computed
#   that constant -- it is the one number in this file that comes from
#   the world rather than from The Coco, and the two modules composing
#   to reach it is the end-to-end proof.
#
# SKIPs when the modules cannot be built (no sbcl, or no CICILI).

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

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

# Build anything coco.yaml names that is not on the library path yet, so
# that adding a module to the file is the whole of adding a module.
for m in $COCO_MODULES_CRYPTO; do
  if [ ! -f "$COCOLOG_LIBRARY/$m.so" ]; then
    sh "$ROOT/modules/crypto/build.sh" > "$HERE/crypto-build.log" 2>&1 || true
    break
  fi
done
if [ ! -f "$COCOLOG_LIBRARY/secp256k1.so" ]; then
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

# ---- sha512 ----------------------------------------------------------
H5="use_module(library(sha512))"
D='[0-9a-f]{128}'
check "sha512: the empty string" \
  "$(q "$H5, sha512_hex('0x', H), write(H), nl" "$D")" \
  "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
check "sha512: abc" \
  "$(q "$H5, sha512(abc, H), write(H), nl" "$D")" \
  "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
check "sha512: 200 bytes, a second block" \
  "$(q "$H5, findall(0'a, between(1,200,_), L), sha512(L, H), write(H), nl" "$D")" \
  "4b11459c33f52a22ee8236782714c150a3b2c60994e9acee17fe68947a3e6789f31e7668394592da7bef827cddca88c4e6f86e4df7ed1ae6cba71f3e98faee9f"

# ---- ed25519, against RFC 8032 ---------------------------------------
ED="use_module(library(ed25519))"
K='[0-9a-f]{64}'
S='[0-9a-f]{128}'
S1=9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60
P1=d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a
G1=e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b
S2=4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb
P2=3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c
G2=92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00

check "ed25519: RFC 8032 test 1, the public key" \
  "$(q "$ED, ed25519_pubkey('$S1', P), write(P), nl" "$K")" "$P1"
check "ed25519: RFC 8032 test 1, the signature" \
  "$(q "$ED, ed25519_sign('$S1', '', G), write(G), nl" "$S")" "$G1"
check "ed25519: RFC 8032 test 2, the public key" \
  "$(q "$ED, ed25519_pubkey('$S2', P), write(P), nl" "$K")" "$P2"
check "ed25519: RFC 8032 test 2, the signature" \
  "$(q "$ED, ed25519_sign('$S2', '72', G), write(G), nl" "$S")" "$G2"
check "ed25519: and both verify" \
  "$(q "$ED, (ed25519_verify('', '$G1', '$P1'), ed25519_verify('72', '$G2', '$P2') -> write(yes) ; write(no)), nl" '^(yes|no)$')" \
  "yes"
check "ed25519: another message does not" \
  "$(q "$ED, (ed25519_verify('73', '$G2', '$P2') -> write(yes) ; write(no)), nl" '^(yes|no)$')" \
  "no"
check "ed25519: another key does not" \
  "$(q "$ED, (ed25519_verify('72', '$G2', '$P1') -> write(yes) ; write(no)), nl" '^(yes|no)$')" \
  "no"

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

# ---- blake2b ---------------------------------------------------------
# The RFC 7693 appendix gives "abc"; the empty string is the case that
# catches an implementation which skips the block loop rather than
# compressing one all-zero block, and the 200-byte input crosses the
# 128-byte block so the counter has to be right twice.
B2="use_module(library(blake2b))"
H2='[0-9a-f]{64}'
H4='[0-9a-f]{128}'
check "blake2b-256: abc" \
  "$(q "$B2, blake2b256(abc, H), write(H), nl" "$H2")" \
  "bddd813c634239723171ef3fee98579b94964e3bb1cb3e427262c8c068d52319"
check "blake2b-256: the empty string" \
  "$(q "$B2, blake2b256_hex('0x', H), write(H), nl" "$H2")" \
  "0e5751c026e543b2e8ab2eb06099daa1d1e5df47778f7787faab45cdf12fe3a8"
check "blake2b-512: abc, the RFC 7693 vector" \
  "$(q "$B2, blake2b512(abc, H), write(H), nl" "$H4")" \
  "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923"
check "blake2b-512: the empty string" \
  "$(q "$B2, blake2b512_hex('0x', H), write(H), nl" "$H4")" \
  "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce"
check "blake2b-256: 200 bytes, a second block" \
  "$(q "$B2, findall(0'a, between(1,200,_), L), blake2b256(L, H), write(H), nl" "$H2")" \
  "6b6e59aaf00eb730cf93de53560846722184bbd92f8368c21ffa95380c2f9fe6"

# ---- ripemd160 and sha256 -------------------------------------------
# The three RIPEMD-160 vectors from the original paper, and SHA-256's
# two. "message digest" is the one that crosses no boundary and still
# catches a wrong round constant, because every round runs.
RM="use_module(library(ripemd160))"
SH="use_module(library(sha256))"
A20='[0-9a-f]{40}'
check "ripemd160: the empty string" \
  "$(q "$RM, ripemd160_hex('0x', H), write(H), nl" "$A20")" \
  "9c1185a5c5e9fc54612808977ee8f548b2258d31"
check "ripemd160: abc" \
  "$(q "$RM, ripemd160(abc, H), write(H), nl" "$A20")" \
  "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
check "ripemd160: message digest" \
  "$(q "$RM, ripemd160('message digest', H), write(H), nl" "$A20")" \
  "5d0689ef49d2fae572b881b123a85ffa21595f36"
check "sha256: the empty string" \
  "$(q "$SH, sha256_hex('0x', H), write(H), nl" "$H2")" \
  "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
check "sha256: abc" \
  "$(q "$SH, sha256(abc, H), write(H), nl" "$H2")" \
  "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
check "sha256: 200 bytes, a second block" \
  "$(q "$SH, findall(0'a, between(1,200,_), L), sha256(L, H), write(H), nl" "$H2")" \
  "c2a908d98f5df987ade41b5fce213067efbcc21ef2240212a41e54b5e7c28ae5"

# ---- library(btc): the second Prolog library over compiled modules ---
# hash160 is RIPEMD-160 over SHA-256, and the hash160 of private key 1's
# COMPRESSED public key is 751e76e8199196d454941c45d1b3a323f1433bd6 --
# which is the payload of 1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH, an address
# anyone can look up. Nothing here computed that constant.
#
# And then the transaction that starts the chain: the Bitcoin genesis
# coinbase, 204 bytes, 3 January 2009. Its txid is
# 4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b --
# SHA-256 twice and READ BACKWARDS, which is the step everybody gets
# wrong once. It is also 408 hex characters of input, and until cocolog's
# reader stopped truncating names at 255 it could not be asked at all.
BT="use_module(library(btc))"
check "btc: hash160 of the compressed key for secret 1" \
  "$(q "$BT, btc_hash160('$GXY', H), write(H), nl" "$A20")" \
  "751e76e8199196d454941c45d1b3a323f1433bd6"
check "btc: the compressed form picks its prefix from y" \
  "$(q "$BT, btc_compress('$GXY', C), write(C), nl" '[0-9a-f]{66}')" \
  "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
GEN=0100000001000000000000000000000000000000000000000000000000000000000000000\
0ffffffff4d04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616\
e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f72206\
2616e6b73ffffffff0100f2052a01000000434104678afdb0fe5548271967f1a67130b7105cd6a\
828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4\
c702b6bf11d5fac00000000
check "btc: the genesis coinbase transaction, 204 bytes" \
  "$(q "$BT, btc_txid('$GEN', T), write(T), nl" "$H2")" \
  "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
