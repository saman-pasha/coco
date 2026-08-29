#!/bin/sh
# Rung 8: the TPS harness -- its RULES, checked.
#
# A TIMING IS NOT A PASS OR A FAIL. What is checkable about a benchmark
# is not the number it printed but whether it would have refused a
# dishonest one, so that is what this file checks. The numbers live in
# bench/tps.sh, where they belong, with their arrangement printed beside
# each of them.
#
# The five rules, and mallory's eight ways round them:
#
#   1. the count is verified against rows actually in the store
#   2. a run under a second is not a measurement
#   3. the arrangement is named on every line
#   4. the clock is the wall, never CPU
#   5. the first run of every lane is discarded
#
# Seven of her eight are one of those. The eighth -- choosing which
# workload to run -- succeeds, and must, because it is upstream of every
# rule a harness can have.
#
# No server: every rule here is a function of its arguments.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"
F="$ROOT/bench/harness.pl $ROOT/bench/mallory.pl"

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-54s %s\n' "$1" "$(echo "$2" | cut -c1-18)"
  else
    printf 'FAIL %-54s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi
q() { timeout 180 "$C" run $F "$1" 2>/dev/null | grep -aoE "$2" | head -1; }

# ---- the five rules ---------------------------------------------------
echo "-- a reading has to earn its way onto the page"
check "a verified count, long enough, with an arrangement, prints" \
  "$(q "( honest(reading(seal,100,4.0,server_one_kb,verified)) -> write(prints) ; write('REFUSED')), nl" '^(prints|REFUSED)$')" \
  "prints"
check "a count the rows do not back is refused" \
  "$(q "verify_count(1000,400,V), ( honest(reading(seal,1000,4.0,server_one_kb,V)) -> write('PRINTS') ; write(refused)), nl" '^(PRINTS|refused)$')" \
  "refused"
check "a count the rows DO back is verified" \
  "$(q "verify_count(400,400,V), write(V), nl" '^(verified|unverified)$')" "verified"
check "a run under a second is refused" \
  "$(q "( honest(reading(seal,5,0.2,server_one_kb,verified)) -> write('PRINTS') ; write(refused)), nl" '^(PRINTS|refused)$')" \
  "refused"
check "a rate with no arrangement is refused" \
  "$(q "( honest(reading(seal,100,40.0,none,verified)) -> write('PRINTS') ; write(refused)), nl" '^(PRINTS|refused)$')" \
  "refused"
check "and so is a rate with an unbound one" \
  "$(q "( honest(reading(seal,100,40.0,_,verified)) -> write('PRINTS') ; write(refused)), nl" '^(PRINTS|refused)$')" \
  "refused"
check "nothing happening is not a rate" \
  "$(q "( honest(reading(seal,0,40.0,server_one_kb,verified)) -> write('PRINTS') ; write(refused)), nl" '^(PRINTS|refused)$')" \
  "refused"

echo
echo "-- and there is one place a rate is computed"
check "tps/2 refuses what honest/1 refuses" \
  "$(q "( tps(reading(seal,100,0.5,server_one_kb,verified),_) -> write('RATE') ; write(refused)), nl" '^(RATE|refused)$')" \
  "refused"
check "an honest reading divides the way arithmetic does" \
  "$(q "tps(reading(seal,100,4.0,server_one_kb,verified),R), write(R), nl" '^[0-9.]+$')" "25.0"
check "report/1 prints the arrangement, not only the rate" \
  "$(q "report(reading(seal,100,4.0,server_one_kb,verified))" '^seal .*server_one_kb.*$')" \
  "seal 25.00 server_one_kb 100 4.000"
check "and says REFUSED rather than printing a number it should not" \
  "$(q "report(reading(seal,100,0.1,server_one_kb,verified))" '^seal .*$')" \
  "seal REFUSED server_one_kb"
check "a refusal says which rule it broke" \
  "$(q "refusal(reading(seal,100,0.1,server_one_kb,verified),W), write(W), nl" '^.*$')" \
  "the run was too short to mean anything"

# ---- the shape a single rate hides ------------------------------------
echo
echo "-- the shape a single averaged rate hides"
CURVE="assertz(scale_point(seal,0,0.805)), assertz(scale_point(seal,10,1.642)),
       assertz(scale_point(seal,20,2.591)), assertz(scale_point(seal,30,3.885)),
       assertz(scale_point(seal,40,5.201))"
check "the measured curve comes back in order" \
  "$(q "$CURVE, scale_shape(seal,S), length(S,N), write(N), nl" '^[0-9]+$')" "5"
check "and it is named for what it is" \
  "$(q "$CURVE, scale_verdict(seal,V), write(V), nl" '^[a-z_]+$')" "grows_with_length"
check "a cost that does not grow is called flat" \
  "$(q "assertz(scale_point(f,0,1.0)), assertz(scale_point(f,10,1.1)), assertz(scale_point(f,20,1.05)), scale_verdict(f,V), write(V), nl" '^[a-z_]+$')" \
  "flat"

# ---- mallory ----------------------------------------------------------
echo
echo "-- mallory reads the benchmark"
V='^(refused|ACCEPTED)$'
check "counting work that never committed" \
  "$(q "attack_count_uncommitted(V), write(V), nl" "$V")" "refused"
check "calling one transaction a hundred of them" \
  "$(q "attack_batch_as_transactions(V), write(V), nl" "$V")" "refused"
check "dividing by CPU time instead of the wall" \
  "$(q "attack_cpu_time(V), write(V), nl" "$V")" "refused"
check "reporting a no-database run as a store rate" \
  "$(q "attack_local_as_database(V), write(V), nl" "$V")" "refused"
check "reporting the cold run" \
  "$(q "attack_first_run(V), write(V), nl" "$V")" "refused"
check "a run too short to mean anything" \
  "$(q "attack_short_run(V), write(V), nl" "$V")" "refused"
check "a rate with nothing attached to it" \
  "$(q "attack_no_arrangement(V), write(V), nl" "$V")" "refused"
check "choosing the workload -- SUCCEEDS, and must" \
  "$(q "attack_choose_the_workload(V), write(V), nl" "$V")" "ACCEPTED"
check "the spread she is choosing from is real" \
  "$(q "workload_spread(B,W), R is B / W, ( R > 100 -> write(hundredfold) ; write('NARROW')), nl" '^(hundredfold|NARROW)$')" \
  "hundredfold"

# ---- the language comparison's own rule -------------------------------
#
# `bench/langs.sh' times cocolog against CPython on five tasks, and its
# first rule is that every lane must answer the SAME value or nothing is
# printed. That rule protects a run; it does not protect the FILES, and
# the likeliest way for this comparison to go quietly wrong is somebody
# improving one side of a pair and not the other. So the pairs are
# checked here, at a size small enough to cost nothing: same task, same
# answer, both languages -- and the sqlite implementation of the store
# task against the dict one, because those two must also stay the same
# question asked twice.
echo
echo "-- the language pairs still compute the same thing"
LB="$ROOT/bench/langs"
pair() {
  _t=$1; shift
  _pl=$(timeout 60 "$C" run "$LB/$_t.pl" "main($1,$2)" 2>/dev/null \
        | grep -aoE '^answer\([^)]*\)' | head -1)
  _py=$(timeout 60 python3 "$LB/$_t.py" "$1" "$2" 2>/dev/null \
        | grep -aoE '^answer\([^)]*\)' | head -1)
  check "$_t: cocolog and python answer the same" "${_pl:-NONE}" "${_py:-NONE}"
}
if command -v python3 >/dev/null 2>&1; then
  pair nrev 60 2
  pair queens 6 1
  pair loop 1000 1
  pair lookup 200 1
  pair sortnums 300 1
  _dict=$(timeout 60 python3 "$LB/lookup.py" 200 1 2>/dev/null \
          | grep -aoE '^answer\([^)]*\)' | head -1)
  _sq=$(timeout 60 python3 "$LB/lookup_sqlite.py" 200 1 "${TMPDIR:-/tmp}/coco-benchpair.db" 2>/dev/null \
        | grep -aoE '^answer\([^)]*\)' | head -1)
  rm -f "${TMPDIR:-/tmp}/coco-benchpair.db"
  check "lookup: the dict and the sqlite store answer the same" "${_sq:-NONE}" "${_dict:-NONE}"
else
  echo "skip no python3 -- the language pairs are not checked"
fi

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
