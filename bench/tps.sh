#!/bin/sh
# Rung 8: the TPS harness.
#
# WHAT THIS IS FOR. Every rung before this one produced a GREEN line.
# None of them produced a number. This one prints transactions per
# second the way cocolog's hunt printed its 944ms -- and the whole
# design of it is about the ways that number can be a lie.
#
# FIVE RULES, ENFORCED IN bench/harness.pl RATHER THAN HERE:
#
#   1. the count is verified against rows actually in the store;
#   2. a run under a second is not a measurement;
#   3. the arrangement is printed on every line, always;
#   4. the clock is `date +%s.%N' -- the wall, never CPU;
#   5. the first run of every lane is discarded.
#
# A reading that breaks one of them prints REFUSED and says why. That is
# not decoration: bench/mallory.pl is eight ways to inflate a number,
# and seven of them are these rules.
#
# NO LINE HERE COMPARES THIS TO ANYTHING. The ladder's own words: no
# sentence anywhere says "competes with" until the number is on the page.
# It is on the page now, and the sentence still is not written, because
# what these lanes measure is this arrangement on this container.
#
# Needs a Zigurat server for the store lanes; the --local lanes run
# without one. SKIPs the store lanes without a server.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../test/config.sh"
C="$COCOLOG_BIN"
B="--host $ZIGURAT_HOST --port $ZIGURAT_PORT --timeout 300"
FED="$ROOT/ledger/federation.pl"
LEDGER="$ROOT/ledger/node.pl"
HARNESS="$HERE/harness.pl"
K="use_module(library(poa))"
ALICE=1111111111111111111111111111111111111111111111111111111111111111

now()  { date +%s.%N; }
secs() { python3 -c "import sys;print(f'{float(sys.argv[2])-float(sys.argv[1]):.3f}')" "$1" "$2"; }

# A reading is handed to the harness, which prints it or refuses it. The
# shell never divides, on purpose: the one place a rate is computed is
# the one place the rules live.
say() {   # lane claimed actual seconds arrangement
  timeout 120 "$C" run "$HARNESS" \
    "verify_count($2,$3,V), R = reading($1,$2,$4,$5,V),
     ( report(R) -> true ; true ),
     ( refusal(R,W), W \\== none -> format(\"   why: ~w~n\",[W]) ; true )" 2>/dev/null \
  | while IFS= read -r line; do
      case "$line" in
        # THE REASON, WHICH USED TO BE THROWN AWAY. harness.pl computes
        # `why' precisely so a person can act on a refusal, and the
        # `grep -aE "^[a-z_]+ "' that used to be here dropped it on the
        # floor -- it is indented, so it never matched. Three lanes read
        # REFUSED for three different reasons and the page said only
        # REFUSED. A rule that will not say which rule is a rule you have
        # to go and read the source for.
        '   why: '*) printf '  %s\n' "$line" ;;
        [a-z_]*' '*)
          # shellcheck disable=SC2086
          set -- $line
          if [ "$2" = "REFUSED" ]; then
            printf '  %-22s %12s   %s\n' "$1" "REFUSED" "$3"
          else
            printf '  %-22s %9s /s   %-26s %s in %ss\n' "$1" "$2" "$3" "$4" "$5"
          fi ;;
      esac
    done
}

fresh() {
  timeout 120 "$C" $B --kb "$1" forget >/dev/null 2>&1
  timeout 120 "$C" $B --kb "$1" consult "$FED" >/dev/null 2>&1
  timeout 120 "$C" $B --kb "$1" consult "$LEDGER" >/dev/null 2>&1
}
count_blocks() {
  timeout 120 "$C" $B --kb "$1" query "$K, findall(1,block(_,_,_,_,_,_),L), length(L,N), write(N), nl" \
    2>/dev/null | grep -aoE '^[0-9]+$' | head -1
}
seal_n() {   # kb n
  NODE_NAME=alice NODE_KEY=$ALICE timeout 300 "$C" $B --kb "$1" query \
    "$K, forall(between(1,$2,I), ledger_seal(I))" >/dev/null 2>&1
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi
CORES=$(nproc 2>/dev/null || echo 1)
echo "== the arrangement"
echo "   $(uname -s) $(uname -m), $CORES cores; every lane's first run discarded"
echo

echo "== lanes with no database in them at all"
echo "   these measure the ENGINE. They are not store numbers and are not"
echo "   labelled as any."
# warm-up, discarded
"$C" run "$FED" "$K, use_module(library(secp256k1)), use_module(library(sha256)), sha256(x,H), secp256k1_sign('$ALICE',H,S), authority(alice,P), forall(between(1,60,_), secp256k1_verify(H,S,P))" >/dev/null 2>&1
t0=$(now)
"$C" run "$FED" "$K, use_module(library(secp256k1)), use_module(library(sha256)), sha256(x,H), secp256k1_sign('$ALICE',H,S), authority(alice,P), forall(between(1,2000,_), secp256k1_verify(H,S,P))" >/dev/null 2>&1
t1=$(now)
say verify 2000 2000 "$(secs $t0 $t1)" local_no_database

"$C" run "$FED" "$K, seal('$ALICE',1,p,alice,pay,Sg,Hs), forall(between(1,60,_), valid_block(1,p,alice,pay,Sg,Hs))" >/dev/null 2>&1
t0=$(now)
"$C" run "$FED" "$K, seal('$ALICE',1,p,alice,pay,Sg,Hs), forall(between(1,2000,_), valid_block(1,p,alice,pay,Sg,Hs))" >/dev/null 2>&1
t1=$(now)
say validate 2000 2000 "$(secs $t0 $t1)" local_no_database
echo "     ^ both include ~0.42s of process start-up in the denominator, so"
echo "       they are floors -- less of one at 2000 than they were at 300."
echo "       The harness does not subtract it: a number you had to adjust is"
echo "       a number you have to explain, and this file explains rather"
echo "       than adjusts."
echo "     ^ THE COUNT WENT 300 -> 2000 because the harness refused the lane."
echo "       300 verifies cleared the one-second floor on the container this"
echo "       was written on and take 0.78s on a quieter one -- so rule 2 fired"
echo "       and the reading was thrown away, which is the rule working. The"
echo "       count is part of the arrangement and moves with the machine."

if ! timeout 20 "$C" $B --kb bench_probe list >/dev/null 2>&1; then
  echo
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT -- store lanes not run"
  exit 0
fi

# ---- RULE SEVEN: START FROM A KNOWN STORE ---------------------------
#
# Every store lane below wears the store out. Deleted rows are kept under
# MVCC and nothing reclaims them on its own, so a second run of this file
# walks past everything the first one left -- and `fresh' does not help,
# because `forget' DELETES, which under MVCC is a write.
#
# FOUR CONSECUTIVE RUNS ON ONE CONTAINER, no code changed between them:
#
#     seal_batched        11.46  9.18  7.13  6.03
#     parallel_own_kbs    21.00 17.63 15.45 12.53
#     parallel_one_kb     12.92  9.22  7.25  5.82
#     seal_batched_again  11.77  7.56  6.48  5.70
#
# Four lanes, four runs, monotone down every time -- and a `vacuum' put
# them back to 15.73, 28.28, 20.33 and 13.25, HIGHER than the first run.
# That is not noise. Noise does not move one direction four times in four
# lanes, and cocolog's own CLAUDE.md names it: a slow suite is the store
# ageing, and a slow benchmark is the same thing wearing a number.
#
# So the run starts from a vacuumed store, which is what test/groups.sh
# and test/ruler.sh in cocolog already do for exactly this reason. It
# does NOT make the lanes immune -- rule six still stands and the last
# lane is still the first one over again, because the store ages WITHIN a
# run too. It makes the starting point the same one every time, which is
# the difference between a reading and an anecdote.
#
# The vacuum is not timed and is not a lane. It is setup.
echo
echo "== vacuuming first, so the run starts where the last one did"
"$C" $B --kb bench_probe vacuum 2>&1 | tail -1 | sed 's/^/   /'

echo
echo "== the settlement lane: blocks onto a chain, through the store"
fresh bench_warm; seal_n bench_warm 8                       # discarded
fresh bench_batch
t0=$(now); seal_n bench_batch 30; t1=$(now)
say seal_batched 30 "$(count_blocks bench_batch)" "$(secs $t0 $t1)" server_one_kb_ONE_TURN
echo "     ^ thirty blocks, ONE transaction. Not thirty transactions."

fresh bench_turn
t0=$(now)
i=0; while [ $i -lt 30 ]; do
  NODE_NAME=alice NODE_KEY=$ALICE timeout 120 "$C" $B --kb bench_turn query "$K, ledger_seal($i)" >/dev/null 2>&1
  i=$((i+1))
done
t1=$(now)
say seal_per_turn 30 "$(count_blocks bench_turn)" "$(secs $t0 $t1)" server_one_kb_per_turn
echo "     ^ thirty transactions, thirty processes. Each pays ~0.42s of"
echo "       start-up, so most of this reading is the harness and not the"
echo "       store."
echo "     ^ TEN BECAME THIRTY for the same reason verify's 300 became 2000:"
echo "       at ten this lane read 1.04s on one run and under a second on the"
echo "       next, so it printed a rate once and REFUSED once, from the same"
echo "       code on the same machine. A lane that straddles the floor is a"
echo "       lane that reports a coin toss." 

echo
echo "== the uncoordinated lane: $CORES writers, $CORES knowledge bases"
echo "   single-appender, nothing contended -- an owned-object fast path"
echo "   that needs no coordination because there is none to need."
i=0; while [ $i -lt "$CORES" ]; do fresh "bench_p$i"; i=$((i+1)); done
t0=$(now)
i=0; while [ $i -lt "$CORES" ]; do ( seal_n "bench_p$i" 15 ) & i=$((i+1)); done
wait
t1=$(now)
tot=0; i=0
while [ $i -lt "$CORES" ]; do tot=$((tot + $(count_blocks "bench_p$i"))); i=$((i+1)); done
say parallel_own_kbs $((CORES * 15)) "$tot" "$(secs $t0 $t1)" "server_${CORES}_kbs_ONE_TURN_each"

echo
echo "== the contended lane: $CORES writers, ONE knowledge base"
fresh bench_one
t0=$(now)
i=0; while [ $i -lt "$CORES" ]; do ( seal_n bench_one 15 ) & i=$((i+1)); done
wait
t1=$(now)
say parallel_one_kb $((CORES * 15)) "$(count_blocks bench_one)" "$(secs $t0 $t1)" "server_1_kb_${CORES}_writers"
printf '     depth of the chain those blocks made: '
timeout 180 "$C" $B --kb bench_one query \
  "$K, findall(H,block(H,_,_,_,_,_),Hs), sort(Hs,U), length(U,N), format(\"~w distinct heights~n\",[N])" \
  2>/dev/null | grep -aE '^[0-9]+ distinct'
echo "     ^ AND THIS IS THE MOST HONEST LINE IN THE FILE. Every block"
echo "       committed, so rule 1 passed and the rate is real. It is also"
echo "       nearly worthless: each writer read the head independently, so"
echo "       they all sealed the SAME heights and the result is a bush four"
echo "       wide, not a chain sixty long. Fork choice will discard three"
echo "       blocks in four. A verified count is not a useful count, and no"
echo "       rule in the harness can tell you that -- only the arrangement can."


echo
echo "== the speculative lane: verification pipelined ahead of finality"
echo "   the lane the ladder aimed at and could not build until cocolog"
echo "   grew library(zigurat): one writer seals 100 blocks in ONE open"
echo "   transaction; while it is STILL UNCOMMITTED, a reader that named"
echo "   READ_UNCOMMITTED audits the staged chain -- every hash, every"
echo "   signature, every parent link -- and a reader at the default"
echo "   commit isolation, polled at the same moments, sees no chain at"
echo "   all. Speculation is a per-turn choice now, and finality is not"
echo "   what it costs."
fresh bench_spec
# 100 blocks, not fewer: incremental fork choice made sealing fast
# enough that a 40-block window closed before one poll pair -- a spawn,
# a module load and a full crypto audit -- could land inside it. The
# window has to outlast the reader, or every poll is rightly discarded.
( seal_n bench_spec 100 ) &
WPID=$!
# The record kept is the highest height whose audit came back OK --
# that is the lane's claim, a staged block fully verified before the
# commit. A poll can also catch the writer mid-edit: READ_UNCOMMITTED
# promises exactly that possibility, the audit says `broken' for that
# torn instant, and the next poll passes again. Torn polls are counted
# and printed, never folded into the claim in either direction.
SPEC_H=-1; SPEC_AUD=none; COMM_H=-1; PAIRS=0; TORN=0
t0=$(now)
while kill -0 $WPID 2>/dev/null && [ $PAIRS -lt 30 ]; do
  out=$(timeout 60 "$C" $B --kb bench_spec query \
    "zigurat_isolation(read_uncommitted), $K, ledger_height(H), ledger_audit(A), format(\"~w ~w~n\",[H,A])" 2>/dev/null \
    | grep -aE '^-?[0-9]+ (ok|broken)$' | head -1)
  cout=$(timeout 60 "$C" $B --kb bench_spec query \
    "$K, ledger_height(H), write(H), nl" 2>/dev/null | grep -aoE '^-?[0-9]+$' | head -1)
  if kill -0 $WPID 2>/dev/null; then
    h=${out% *}; a=${out#* }
    if [ -n "$out" ] && [ "$a" = ok ] && [ "$h" -gt "$SPEC_H" ] 2>/dev/null; then
      SPEC_H=$h; SPEC_AUD=ok
    fi
    [ -n "$out" ] && [ "$a" = broken ] && TORN=$((TORN+1))
    if [ -n "$cout" ] && [ "$cout" -gt "$COMM_H" ] 2>/dev/null; then COMM_H=$cout; fi
  fi
  PAIRS=$((PAIRS+1))
done
wait $WPID
t1=$(now)
AHEAD=$((SPEC_H + 1))
printf '  %-22s %9s      %-34s staged height %s, audit %s\n' \
  spec_read_ahead "$AHEAD blk" server_1kb_READ_UNCOMMITTED_reader "$SPEC_H" "$SPEC_AUD"
if [ "$TORN" -gt 0 ]; then
  printf '     %s poll(s) caught the writer mid-edit and audited broken --\n' "$TORN"
  printf '     the price READ_UNCOMMITTED names up front; the claim above is\n'
  printf '     the highest poll whose audit came back whole.\n'
fi
printf '  %-22s %9s      %-34s height %s the whole open window\n' \
  committed_beside_it "$((COMM_H + 1)) blk" server_1kb_default_isolation_reader "$COMM_H"
printf '     the writer'"'"'s one transaction held %s blocks staged for %ss; the\n' 100 "$(secs $t0 $t1)"
printf '     speculative reader audited %s of them BEFORE the commit landed,\n' "$AHEAD"
printf '     the committed reader saw none of them, and after the commit the\n'
printf '     store answers %s blocks -- rule 1, on the lane'"'"'s own terms.\n' "$(count_blocks bench_spec)"
if [ "$SPEC_H" -lt 0 ] || [ "$SPEC_AUD" != ok ]; then
  printf '  %-22s %12s   %s\n' spec_read_ahead REFUSED "no staged block was audited ahead of finality"
fi
if [ "$COMM_H" -ge 0 ]; then
  printf '  %-22s %12s   %s\n' committed_beside_it REFUSED "the default-isolation reader saw an unfinished chain"
fi

echo
echo "== the shape nobody sees in a single rate"
echo "   seconds per ten seals, as the chain grows:"
fresh bench_scale
r=0
while [ $r -lt 5 ]; do
  len=$(count_blocks bench_scale)
  t0=$(now); seal_n bench_scale 10; t1=$(now)
  printf '     chain %-5s %ss\n' "$len" "$(secs $t0 $t1)"
  r=$((r + 1))
done
echo "   -- the cost per block grows with the length of the chain, because"
echo "      ledger_head/1 re-derives fork choice from every head mark on"
echo "      every seal. A single averaged rate hides this completely."
echo "      A tip-only filter was tried and MEASURED and did not help:"
echo "      block/6 is not indexed on the parent, so the filter costs"
echo "      what it saves. It was reverted rather than shipped."

echo
echo "== the same lane again, at the end of the run"
fresh bench_again
t0=$(now); seal_n bench_again 30; t1=$(now)
say seal_batched_again 30 "$(count_blocks bench_again)" "$(secs $t0 $t1)" server_one_kb_ONE_TURN
echo "   -- THE SIXTH RULE, and it is not in harness.pl because no predicate"
echo "      can enforce it: a store reading is only comparable to another"
echo "      store reading FROM THE SAME RUN. This is the first lane over"
echo "      again, on a fresh knowledge base, minutes later -- and it does"
echo "      not read the same, because the store moved underneath it. On the"
echo "      run these comments were written from, the two lines read 4.40/s"
echo "      and 9.34/s -- the same lane, the same arrangement, 2.1x apart,"
echo "      minutes apart, and NEITHER IS WRONG. Across three runs the first"
echo "      of them read 8.11, 6.02 and 4.40. And the two --local lanes are"
echo "      not a control either: they read 181-183/s across those runs and"
echo "      233 and 249 on a later, quieter one -- from BYTE-IDENTICAL .so"
echo "      files, checked by md5. Not touching the store makes a lane immune"
echo "      to store AGEING, which is not the same as invariant, and this"
echo "      file said otherwise until a run proved it. cocolog\'s CLAUDE.md says a slow suite is"
echo "      the store ageing; a slow BENCHMARK is the same thing wearing a"
echo "      number. The scaling shape above survives it. A single headline"
echo "      rate would not have."

echo
echo "== mallory reads the benchmark"
for a in attack_count_uncommitted attack_batch_as_transactions attack_cpu_time \
         attack_local_as_database attack_first_run attack_short_run \
         attack_no_arrangement attack_choose_the_workload; do
  printf '   %-30s ' "$a"
  timeout 120 "$C" run "$HARNESS" "$HERE/mallory.pl" "$a(V), write(V), nl" 2>/dev/null \
    | grep -aoE '^(refused|ACCEPTED)$' | head -1
done
printf '   %-30s ' "and the spread she picks from"
timeout 120 "$C" run "$HARNESS" "$HERE/mallory.pl" \
  "workload_spread(Best,Worst), format(\"~2f /s down to ~2f /s, all honest~n\",[Best,Worst])" 2>/dev/null \
  | grep -aE '/s down to'
echo "   -- the last one works and no harness can stop it. A benchmark is only"
echo "      ever a statement about the workload it ran, and choosing the workload"
echo "      is upstream of every rule a harness can have. The only defence is the"
echo "      one this whole repository uses: print the table, name the arrangement"
echo "      on every line, and do not write the sentence."
