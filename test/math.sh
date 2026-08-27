#!/bin/sh
# library(u256): the width an exchange needs, and the refusals that make
# it worth having.
#
# WHY THIS CASE EXISTS, and it is not a hypothetical. cocolog's integers
# are 64 bits and they WRAP IN SILENCE. The first check below asserts
# that -- it asks cocolog's own `is/2' for the first product a Uniswap
# swap computes at ordinary token scale (one token is 10^18) and pins the
# WRONG ANSWER it gives. That check passing is the reason every other
# check here exists, and if a future cocolog grows wide integers it will
# fail and this file should be read again rather than patched.
#
# WHAT IS BEING PINNED, beyond the arithmetic:
#
#   NOTHING WRAPS. Every operation that cannot represent its answer
#   raises instead: over 2^256-1, below zero, a zero divisor, a quotient
#   too wide, a value too big for a cocolog integer. Solidity 0.8 made
#   overflow revert for this reason, and a wrapped balance is a lie that
#   spends.
#
#   MULDIV KEEPS THE MIDDLE. floor(A*B/C) where A*B does not fit 256
#   bits and the answer does -- the shape of every price an exchange
#   quotes. The check uses 2^255 * 4 / 8, whose intermediate is 2^257.
#
#   THE SQUARE ROOT IS THE FLOOR, exactly, including at the top of the
#   range where sqrt(2^256-1) must be 2^128-1 and not one more.
#
#   AND THE ARITHMETIC ADDS UP TO UNISWAP. The last block computes v2's
#   getAmountOut at pool scale and requires 996006981039903216 -- a
#   number this repository did not invent; it is what the constant
#   product formula with a 0.3% fee pays for one token into a 1000/1000
#   pool, and anyone can recompute it. Then it swaps back and requires
#   the input to return exactly, and requires k to have GROWN, which is
#   what the fee is.
#
# SKIPs when the module cannot be built (no sbcl, or no CICILI).

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-44s %s\n' "$1" "$(echo "$2" | cut -c1-30)"
  else
    printf 'FAIL %-44s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi

for m in $COCO_MODULES_MATH; do
# OURS, not the SEARCH PATH. COCOLOG_LIBRARY is colon-separated now --
# this repository's library/ and then cocolog's, because torch, tcp,
# bigint and curl are loadable modules under cocolog's own library/
# rather than builtins. `"$COCOLOG_LIBRARY/u256.so"' was a real path
# when it was one directory and is nonsense now, so every probe below
# uses COCO_PATHS_LIBRARY, which is still the single directory The
# Coco's own modules are built into.
  if [ ! -f "$COCO_PATHS_LIBRARY/$m.so" ]; then
    sh "$ROOT/modules/math/build.sh" > "$HERE/math-build.log" 2>&1 || true
    break
  fi
done
if [ ! -f "$COCO_PATHS_LIBRARY/u256.so" ]; then
  echo "SKIP (the math modules would not build -- no sbcl or CICILI checkout)"
  exit 0
fi

U="use_module(library(u256))"
D='[0-9]+'
q()  { timeout 120 "$C" query "$1" 2>/dev/null | grep -aoE "$2" | head -1; }
# What kind of refusal, rather than what number: an error is the answer.
err() { timeout 120 "$C" query "$U, $1" 2>&1 \
        | grep -aoE 'u256 [a-z ]+|does not fit an integer' | head -1; }

MAX=115792089237316195423570985008687907853269984665640564039457584007913129639935

# ---- the reason this module exists -----------------------------------
# Not a straw man: this is cocolog's own arithmetic, asked for the first
# product a swap computes, answering a number that is simply not it.
check "cocolog's 64-bit is/2 wraps, silently" \
  "$(q "X is 1000000000000000000*997, write(X), nl" "$D")" \
  "875820019684212736"
check "u256 gets it right" \
  "$(q "$U, u256_mul('1000000000000000000', 997, X), write(X), nl" "$D")" \
  "997000000000000000000"

# ---- the four operations, and their refusals -------------------------
check "add" "$(q "$U, u256_add('$MAX', 0, X), write(X), nl" "$D")" "$MAX"
check "add past the top raises"      "$(err "u256_add('$MAX', 1, X)")"  "u256 overflow"
check "sub"  "$(q "$U, u256_sub(1000, 1, X), write(X), nl" "$D")" "999"
check "sub below zero raises"        "$(err "u256_sub(0, 1, X)")"       "u256 underflow"
check "mul past the top raises"      "$(err "u256_mul('$MAX', 2, X)")"  "u256 overflow"
check "div is the floor" "$(q "$U, u256_div(7, 2, X), write(X), nl" "$D")" "3"
check "mod" "$(q "$U, u256_mod(7, 2, X), write(X), nl" "$D")" "1"
check "div by zero raises"           "$(err "u256_div(5, 0, X)")"  "u256 division by zero"

# ---- muldiv: the product is never narrowed ---------------------------
# 2^255 * 4 / 8. The intermediate is 2^257 -- two bits wider than the
# type -- and the answer is 2^254, which fits comfortably. A muldiv that
# multiplied first and stored the result would be wrong here, and this
# is exactly the shape every AMM price has.
check "muldiv: 2^255*4/8 = 2^254, middle 2^257" \
  "$(q "$U, u256_muldiv('57896044618658097711785492504343953926634992332820282019728792003956564819968', 4, 8, X), write(X), nl" "$D")" \
  "28948022309329048855892746252171976963317496166410141009864396001978282409984"
check "muldiv quotient too wide raises" \
  "$(err "u256_muldiv('$MAX', '$MAX', 1, X)")" "u256 overflow"

# ---- the square root, floored exactly --------------------------------
check "sqrt(0)" "$(q "$U, u256_sqrt(0, X), write(X), nl" "$D")" "0"
check "sqrt(1)" "$(q "$U, u256_sqrt(1, X), write(X), nl" "$D")" "1"
check "sqrt(10^36) is 10^18 exactly" \
  "$(q "$U, u256_sqrt('1000000000000000000000000000000000000', X), write(X), nl" "$D")" \
  "1000000000000000000"
check "sqrt(10^36 - 1) is one less" \
  "$(q "$U, u256_sqrt('999999999999999999999999999999999999', X), write(X), nl" "$D")" \
  "999999999999999999"
check "sqrt(2^256-1) is 2^128-1" \
  "$(q "$U, u256_sqrt('$MAX', X), write(X), nl" "$D")" \
  "340282366920938463463374607431768211455"

# ---- how a number is spelled -----------------------------------------
check "the top of the range round-trips" \
  "$(q "$U, u256_dec('$MAX', X), write(X), nl" "$D")" "$MAX"
check "hex in, decimal out" "$(q "$U, u256_dec('0xff', X), write(X), nl" "$D")" "255"
check "decimal in, hex out" \
  "$(q "$U, u256_hex(255, X), write(X), nl" '[0-9a-f]{64}')" \
  "00000000000000000000000000000000000000000000000000000000000000ff"
check "hex and decimal agree at the top" \
  "$(q "$U, u256_hex('$MAX', X), write(X), nl" '[0-9a-f]{64}')" \
  "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
check "an integer comes back an integer" \
  "$(q "$U, u256_int('42', X), write(X), nl" "$D")" "42"
check "2^64 will not fit one, and says so" \
  "$(err "u256_int('18446744073709551616', X)")" "u256 does not fit an integer"
check "cmp <" "$(q "$U, u256_cmp(1, 2, X), write(X), nl" '^[<=>]$')" "<"
check "cmp =" "$(q "$U, u256_cmp('$MAX', '$MAX', X), write(X), nl" '^[<=>]$')" "="
check "cmp > across the 64-bit line" \
  "$(q "$U, u256_cmp('18446744073709551616', '18446744073709551615', X), write(X), nl" '^[<=>]$')" ">"

# ---- and it adds up to Uniswap ---------------------------------------
# getAmountOut, at the scale a real pool holds: one token into a
# thousand-for-a-thousand pool, 0.3% fee. 996006981039903216 is not this
# repository's number -- it is what the formula pays, and it is quoted
# wherever the formula is explained.
GO="u256_mul(Ain, 997, F), u256_muldiv(F, Rout, Den, Out)"
DEN="u256_mul(Rin, 1000, T), u256_add(T, F, Den)"
POOL="Rin = '1000000000000000000000', Rout = '1000000000000000000000', Ain = '1000000000000000000'"
check "v2 getAmountOut at pool scale" \
  "$(q "$U, $POOL, u256_mul(Ain, 997, F), $DEN, u256_muldiv(F, Rout, Den, Out), write(Out), nl" "$D")" \
  "996006981039903216"
# And back the other way: the input needed for that exact output is the
# input we started with. A formula that is not its own inverse here is
# a formula that leaks value on every round trip.
check "v2 getAmountIn returns the input" \
  "$(q "$U, $POOL, Out = '996006981039903216', u256_muldiv(Rin, Out, 1, N0), u256_mul(N0, 1000, N), u256_sub(Rout, Out, R2), u256_mul(R2, 997, D2), u256_div(N, D2, Q), u256_add(Q, 1, Ain2), write(Ain2), nl" "$D")" \
  "1000000000000000000"
# The invariant, which is the only thing a pool really promises: after a
# swap the product of the reserves has GROWN, and the growth is the fee.
check "k grows across the swap -- that is the fee" \
  "$(q "$U, $POOL, Out = '996006981039903216', u256_add(Rin, Ain, R1), u256_sub(Rout, Out, R2), u256_mul(R1, R2, K1), u256_mul(Rin, Rout, K0), u256_cmp(K1, K0, C), write(C), nl" '^[<=>]$')" \
  ">"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
