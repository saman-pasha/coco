#!/bin/sh
# Rung 5: the PoH spine -- a clock nobody can wind backwards.
#
# WHAT IT IS CHECKING.
#
#   THE SPINE IS THE SPINE. Three independent implementations of the same
#   definition must agree: the C module's loop, a Prolog loop that does
#   one tick per goal through library(sha256), and -- in the vectors
#   below -- a number computed outside this project entirely. A spine
#   nobody can check independently is a number somebody made up.
#
#   PRODUCTION IS SEQUENTIAL, VERIFICATION IS PARALLEL. That asymmetry is
#   the only reason a spine is worth having, and the suite checks the
#   half that is checkable: that a range split K ways verifies segment by
#   segment with no segment knowing about any other. The measured speedup
#   is in spine/run.sh, where it belongs -- a timing is not a pass/fail.
#
#   SEGMENTS MUST ALSO CHAIN. Every segment verifying is not enough: a
#   set of perfectly good pieces that were never one sequence would pass
#   that test. `spine_sound/0' checks the joins too, and the splice
#   attack is what happens when nobody does.
#
#   AND ONE ATTACK SUCCEEDS. Two spines from the same start both verify.
#   Nothing inside a hash chain prefers one, and no amount of hashing
#   will make it -- that is what a clock IS, and the ledger is what
#   answers it.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"
F="$ROOT/spine/node.pl $ROOT/spine/mallory.pl"
K="use_module(library(spine))"
Z=0000000000000000000000000000000000000000000000000000000000000000

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-50s %s\n' "$1" "$(echo "$2" | cut -c1-22)"
  else
    printf 'FAIL %-50s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi
if [ ! -f "$COCOLOG_LIBRARY/poh.so" ]; then
  sh "$ROOT/modules/crypto/build.sh" >/dev/null 2>&1 || true
fi
if [ ! -f "$COCOLOG_LIBRARY/poh.so" ]; then
  echo "SKIP (the poh module would not build -- no sbcl or CICILI)"; exit 0
fi

loc() { timeout 300 "$C" run $F "$K, $1" 2>/dev/null | grep -aoE "$2" | head -1; }
H='^[0-9a-f]{64}$'

# ---- the spine is the spine ------------------------------------------
echo "-- three implementations of one definition"
# Computed outside this project: 2000 iterations of sha256 over 32 zero
# bytes. Nothing here produced this constant.
check "2000 ticks from genesis" \
  "$(loc "poh_genesis(G), poh_run(G, 2000, X), write(X), nl" "$H")" \
  "4aa241482140ae279432edae9365b656b054a9598a28b670340b72545068c117"
check "the Prolog loop reaches the same hash" \
  "$(loc "poh_genesis(G), poh_slow_run(G, 2000, X), write(X), nl" "$H")" \
  "4aa241482140ae279432edae9365b656b054a9598a28b670340b72545068c117"
# sha256 of 64 zero bytes -- the event fold with a zero event at genesis.
check "the event fold matches a published sha256" \
  "$(loc "poh_genesis(G), poh_mix(G, G, X), write(X), nl" "$H")" \
  "f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b"
check "one tick is one sha256, not two" \
  "$(loc "poh_genesis(G), poh_run(G, 1, X), write(X), nl" "$H")" \
  "66687aadf862bd776c8fc18b8e9f8e20089714856ee233b3902a591d0d5f2925"
check "zero ticks is where you started" \
  "$(loc "poh_genesis(G), poh_run(G, 0, X), (X == G -> write(same) ; write('MOVED')), nl" '^(same|MOVED)$')" \
  "same"

# ---- splitting and checking ------------------------------------------
echo
echo "-- a range split, and every piece checkable alone"
check "1000 ticks split four ways gives four segments" \
  "$(loc "poh_genesis(G), poh_segments(G, 1000, 4, S), length(S, N), write(N), nl" '^[0-9]+$')" "4"
check "and every segment verifies on its own" \
  "$(loc "poh_genesis(G), poh_segments(G, 1000, 4, S), (poh_verify_segments(S) -> write(all_verify) ; write('BROKEN')), nl" '^(all_verify|BROKEN)$')" \
  "all_verify"
check "the segments chain end to start" \
  "$(loc "spine_produce(1000, 4), (spine_sound -> write(sound) ; write('BROKEN')), nl" '^(sound|BROKEN)$')" \
  "sound"
check "a segment's end is the whole run's end" \
  "$(loc "poh_genesis(G), poh_segments(G, 800, 4, S), last(S, seg(_,_,_,E)), poh_run(G, 800, W), (E == W -> write(joins) ; write('DIVERGES')), nl" '^(joins|DIVERGES)$')" \
  "joins"

# ---- ordering ---------------------------------------------------------
echo
echo "-- what the spine is actually for: order"
check "two anchored blocks come back in the order they went in" \
  "$(loc "use_module(library(sha256)), spine_produce(200, 2), sha256(first, B1), anchor_block(B1), sha256(second, B2), anchor_block(B2), anchor_order([T1-_, T2-_]), (T1 < T2 -> write(ordered) ; write('SCRAMBLED')), nl" '^(ordered|SCRAMBLED)$')" \
  "ordered"
check "an anchor recomputes to the hash on the record" \
  "$(loc "use_module(library(sha256)), spine_produce(200, 2), sha256(only, B), anchor_block(B), anchor_order([T-_]), (anchor_genuine(T) -> write(genuine) ; write('FORGED')), nl" '^(genuine|FORGED)$')" \
  "genuine"

# ---- mallory ----------------------------------------------------------
echo
echo "-- mallory attacks the clock"
V='^(refused|ACCEPTED)$'
check "claiming a tick count without doing the ticks" \
  "$(loc "attack_skip(V), write(V), nl" "$V")" "refused"
check "doing fewer ticks than claimed" \
  "$(loc "attack_shorten(V), write(V), nl" "$V")" "refused"
check "backdating a block to an earlier tick" \
  "$(loc "attack_backdate(V), write(V), nl" "$V")" "refused"
check "splicing a segment from another spine" \
  "$(loc "attack_splice(V), write(V), nl" "$V")" "refused"
check "forking the clock -- SUCCEEDS, and must" \
  "$(loc "attack_fork(V), write(V), nl" "$V")" "ACCEPTED"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
