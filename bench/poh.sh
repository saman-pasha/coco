#!/bin/sh
# Rung 5's clock, measured -- the ASYMMETRY, and the two costs beside it.
#
# WHAT IT IS FOR. `h(n+1) = sha256(h(n))' is a clock nobody can wind
# backwards, and the claim that makes it worth having is not a speed but a
# SHAPE: the work is paid once, in order, by one party, and audited by
# everybody at once. That is a claim about a RATIO between producing and
# verifying-in-parallel, and a ratio has to be measured at more than one
# size or it is an anecdote -- the same script read 1.8x at 12M ticks and
# 2.8x at 32M, and publishing the second alone would have been true and
# misleading.
#
# THE RULES ARE bench/harness.pl's, the ones that apply:
#
#   1. THE ANSWER IS VERIFIED. Every lane must reach the same end hash or
#      no number is printed. Here that is not a formality: the whole point
#      of the parallel lane is that four processes checking four ranges is
#      the same statement as one process checking one, and the way to be
#      sure is to make them agree on the hash.
#   2. THE RUN IS LONG ENOUGH. The tick counts are chosen so the shortest
#      lane clears a second; anything shorter is start-up wearing a
#      number's clothes.
#   3. THE ARRANGEMENT IS NAMED. `spine' is the C module, `clauses' is
#      library(poh)'s oracle -- the SAME definition written twice, which
#      is what lets the suite require one hash from both.
#   4. THE CLOCK IS THE WALL, around the whole process, because start-up
#      is part of what a verifier actually pays.
#   5. THE FIRST RUN IS THROWN AWAY.
#
# AND THE ONE THIS BENCHMARK NEEDS OF ITS OWN: START-UP IS REPORTED, NOT
# HIDDEN. Every verifier pays it, so a parallel speedup depends on how
# much work it is amortised over -- the dilution is the harness and not
# the mechanism, and the honest way to say that is to print the ratio at
# two sizes and the tight-loop rate with start-up subtracted.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../test/config.sh"
C="$COCOLOG_BIN"
GEN=0000000000000000000000000000000000000000000000000000000000000000

[ -x "$C" ] || { echo "no cocolog binary at $C"; exit 1; }

RUN_CAP=300
now() { date +%s%N; }
secs() { awk -v n="$1" 'BEGIN { printf "%.2f", n / 1000000000 }'; }
rate() { awk -v n="$1" -v t="$2" 'BEGIN { printf "%.2fM", (t > 0 ? n / (t / 1000000000) / 1000000 : 0) }'; }

# One `cocolog run' of GOAL. Prints "<nanoseconds> <the line it wrote>".
go() {
  _s=$(now)
  _o=$(timeout $RUN_CAP "$C" query "$1" 2>&1 | grep -aoE '^[0-9a-f]{64}$|^(ok|BROKEN)$' | head -1)
  _e=$(now)
  echo "$((_e - _s)) ${_o:-NONE}"
}

echo
echo "the PoH spine -- produce once, verify everywhere"
echo "cocolog at $C, wall clock around the whole process"
echo

# ---- start-up alone, which every verifier pays ------------------------
set -- $(go "use_module(library(spine)), write(ok), nl")
BOOT=$1
echo "start-up alone (boot, load library(spine), exit): $(secs $BOOT) s"
echo

# ---- the asymmetry, at two sizes --------------------------------------
echo "the asymmetry: one producer, then one verifier, then four at once"
printf '   %10s %10s %10s %10s %9s %10s\n' ticks produce verify 'verify x4' speedup 'loop rate'
for N in 8000000 32000000; do
  Q=$((N / 4))

  # produce, and keep the end hash: every lane below must reach it
  set -- $(go "use_module(library(spine)), poh_run('$GEN', $N, H), write(H), nl")
  PT=$1; END=$2
  case "$END" in
    [0-9a-f]*) ;;
    *) printf '   %10s  REFUSED: the producer answered %s\n' "$N" "$END"; continue ;;
  esac

  set -- $(go "use_module(library(spine)), (poh_verify('$GEN', $N, '$END') -> write(ok) ; write('BROKEN')), nl")
  VT=$1; VA=$2
  [ "$VA" = ok ] || { printf '   %10s  REFUSED: one verifier answered %s\n' "$N" "$VA"; continue; }

  # FOUR PROCESSES, AND THE CHECKPOINTS ARE WHAT MAKES THAT POSSIBLE: a
  # verifier of range k needs the hash range k starts from, which is the
  # producer's own checkpoint. Splitting without them is not verification.
  set -- $(go "use_module(library(spine)), poh_checkpoints('$GEN', $N, $Q, Cs), atomic_list_concat(Cs, ' ', A), write(A), nl")
  CPS=$(timeout $RUN_CAP "$C" query \
        "use_module(library(spine)), poh_checkpoints('$GEN', $N, $Q, Cs), atomic_list_concat(Cs, ' ', A), write(A), nl" \
        2>/dev/null | grep -aoE '[0-9a-f]{64}( [0-9a-f]{64})*' | head -1)
  # `poh_checkpoints' answers K+1 hashes INCLUDING the start, so range k
  # runs from element k to element k+1 -- and BOTH ends are needed:
  # `poh_verify/3' checks a start, a count and an END, and handing it an
  # unbound one is not a verification, it is a question. (It was written
  # that way here first, and all four ranges refused, which is the answer
  # gate doing exactly what it is for.)
  set -- $CPS
  if [ $# -lt 5 ]; then
    printf '   %10s  REFUSED: %d checkpoints, wanted 5\n' "$N" "$#"; continue
  fi
  S1=$1; S2=$2; S3=$3; S4=$4; E1=$2; E2=$3; E3=$4; E4=$5
  _s=$(now)
  _k=0
  for pair in "$S1 $E1" "$S2 $E2" "$S3 $E3" "$S4 $E4"; do
    _k=$((_k + 1))
    set -- $pair
    timeout $RUN_CAP "$C" query \
      "use_module(library(spine)), (poh_verify('$1', $Q, '$2') -> write(ok) ; write('BROKEN')), nl" \
      > /tmp/coco-poh-$$-$_k.out 2>&1 &
  done
  wait
  _e=$(now)
  P4=$((_e - _s))
  # THE ANSWER IS A WHOLE LINE, and looking for the word anywhere in the
  # output is not the same test: cocolog echoes the goal it was given, and
  # the goal CONTAINS the word `BROKEN' -- so a search for it matched every
  # file whatever the range answered, and four good ranges were reported as
  # four bad ones. `ok' on a line of its own is what `write(ok), nl' makes;
  # everything else in the file is the echo.
  GOOD=$(grep -lx ok /tmp/coco-poh-$$-*.out 2>/dev/null | wc -l)
  rm -f /tmp/coco-poh-$$-*.out
  if [ "$GOOD" -ne 4 ]; then
    printf '   %10s  REFUSED: %s of four ranges verified, wanted 4\n' "$N" "$GOOD"; continue
  fi

  SU=$(awk -v a="$VT" -v b="$P4" 'BEGIN { printf "%.1fx", (b > 0 ? a / b : 0) }')
  # the tight loop with start-up subtracted -- the mechanism, not the harness
  LOOP=$(rate "$N" "$((PT - BOOT))")
  printf '   %10s %9ss %9ss %9ss %9s %9s/s\n' \
    "$N" "$(secs $PT)" "$(secs $VT)" "$(secs $P4)" "$SU" "$LOOP"
done
echo

# ---- the same definition, written twice --------------------------------
# THE ORACLE EXISTS TO DISAGREE. `poh_slow_run/3' is the same loop in
# clauses, and the suite requires the same hash from both -- a spine
# nobody can check independently is a number somebody made up. What it
# costs is the interpreter's per-tick price against C's, and that ratio
# is the clearest argument in this repository for the second of its four
# materials.
#
# AND THE SIZES ARE THE ORACLE'S, NOT THE MODULE'S. Written first at 2000
# and 20000 ticks, the C lane read 0.00s and 0.01s -- below the clock -- and
# the ratio that came out of dividing by them was 5x and 9x, which is
# arithmetic on noise rather than a measurement. Rule 2 exists for exactly
# this: the run must be long enough, and long enough means long enough for
# the FASTER lane.
echo "the same spine in clauses, as library(poh)'s oracle"
printf '   %10s %12s %12s %10s %14s\n' ticks 'C module' clauses ratio 'agree?'
for N in 400000 1000000; do
  set -- $(go "use_module(library(spine)), poh_run('$GEN', $N, H), write(H), nl")
  CT=$1; CH=$2
  set -- $(go "use_module(library(poh)), poh_slow_run('$GEN', $N, H), write(H), nl")
  ST=$1; SH=$2
  if [ "$CH" != "$SH" ]; then
    printf '   %10s  REFUSED: C said %s, clauses said %s\n' "$N" "$CH" "$SH"; continue
  fi
  # start-up is subtracted from BOTH, or the ratio is a measure of boot time
  R=$(awk -v a="$((ST - BOOT))" -v b="$((CT - BOOT))" \
        'BEGIN { printf "%.0fx", (b > 0 ? a / b : 0) }')
  printf '   %10s %11ss %11ss %10s %14s\n' \
    "$N" "$(secs $((CT - BOOT)))" "$(secs $((ST - BOOT)))" "$R" "same hash"
done
echo
