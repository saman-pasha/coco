#!/bin/sh
# Rung 4: training as settlement -- proof of USEFUL work.
#
# WHAT IT IS CHECKING.
#
#   THE CLAIM IS NEVER READ. Every worker in this suite claims accuracy
#   0.99 -- the honest ones and the liar alike -- and settlement reaches
#   different verdicts, because it measures. That is the whole rung in
#   one sentence: a worker's word about its own model is not evidence,
#   and proof of USEFUL work means the chain pays for a model that
#   performs rather than for cycles burned.
#
#   TRAIN FREELY, VERIFY DETERMINISTICALLY. Two honest workers train
#   from different seeds and land on DIFFERENT weights. Both are
#   accepted. Settlement cannot and does not compare a submission to what
#   the verifier would have got -- it loads the weights and measures
#   them, which is the only step in the whole business that is
#   reproducible.
#
#   THE HOLDOUT IS COMMITTED BEFORE ANY WORKER EXISTS. A settler who
#   looked at the submissions and then chose a range would leave no trace
#   in the result -- the accuracy would be real, measured honestly, on
#   the wrong points. The task carries sha256 of its holdout and
#   settle/4 re-checks it on every submission.
#
#   AND THE ROWS MUST HASH BACK. A block commits a digest; the weights
#   travel as separate rows because a row must fit in a page and a model
#   does not. Rows that do not hash to the committed digest are refused
#   before anything is loaded.
#
# SKIPs without a Zigurat server for the second half.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

BASE="$ZIGURAT_DIAL --timeout 60"
F="$ROOT/ledger/federation.pl $ROOT/ledger/node.pl $ROOT/training/task.pl $ROOT/training/worker.pl $ROOT/training/mallory.pl"
K="use_module(library(poa)), use_module(library(settle))"
OUT=$(mktemp -d "${TMPDIR:-/tmp}/coco-tr-XXXXXX")
trap 'rm -rf "$OUT"' EXIT INT TERM

ALICE=1111111111111111111111111111111111111111111111111111111111111111
BOB=2222222222222222222222222222222222222222222222222222222222222222
CAROL=3333333333333333333333333333333333333333333333333333333333333333
key_of() { case "$1" in alice) echo "$ALICE";; bob) echo "$BOB";; carol) echo "$CAROL";; esac; }

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
if ! "$C" query "use_module(library(torch)), torch_seed(1)" >/dev/null 2>&1; then
  echo "SKIP (no library(torch) -- sh modules/torch/build.sh in cocolog)"; exit 0
fi

# Anchored, always: cocolog echoes the goal, so an unanchored search for
# `accepted' would match the goal text and agree with anything.
V='^(accepted\([0-9.]+\)|rejected\([a-z_]+(\([0-9.a-z, ]*\))?\))$'
loc() { who=$1; shift; NODE_NAME=$who NODE_KEY=$(key_of "$who") \
          timeout 300 "$C" run $F "$K, $*" 2>/dev/null; }
verdict() { loc "$1" "$2" | grep -aoE "$V" | head -1; }

# ---- part one: the acceptance predicate ------------------------------
echo "-- what settlement measures, and what it ignores"
SUB="submission(rings,W,D,claim(accuracy,0.99),N)"
check "an honest model is accepted on its MEASURED accuracy" \
  "$(verdict alice "the_task(T), train_params(honest,P), params_digest(P,D), length(P,N), W=alice, settle(T, $SUB, P, V), write(V), nl")" \
  "accepted(1.0)"
check "a liar claiming 0.99 is judged on what it delivers" \
  "$(verdict carol "the_task(T), train_params(liar,P), params_digest(P,D), length(P,N), W=carol, settle(T, $SUB, P, V), write(V), nl" | sed 's/accuracy(0\.[0-9]*)/accuracy(measured)/')" \
  "rejected(accuracy(measured))"
check "untrained weights, same claim, same treatment" \
  "$(verdict carol "the_task(T), train_params(junk,P), params_digest(P,D), length(P,N), W=carol, settle(T, $SUB, P, V), write(V), nl" | sed 's/accuracy(0\.[0-9]*)/accuracy(measured)/')" \
  "rejected(accuracy(measured))"
check "weights for a different architecture will not load" \
  "$(verdict carol "the_task(T), train_params(shapeshifter,P), params_digest(P,D), length(P,N), W=carol, settle(T, $SUB, P, V), write(V), nl")" \
  "rejected(shape(arch))"
check "rows that do not hash to the committed digest" \
  "$(verdict carol "the_task(T), train_params(honest,G), params_digest(G,D), train_params(junk,B), length(B,N), W=carol, settle(T, $SUB, B, V), write(V), nl")" \
  "rejected(digest_mismatch)"
check "a settler who moves the holdout after the fact" \
  "$(verdict alice "train_params(honest,P), params_digest(P,D), length(P,N), W=alice, attack_moved_holdout(T), settle(T, $SUB, P, V), write(V), nl")" \
  "rejected(holdout_moved)"

echo
echo "-- the two properties settlement rests on"
check "the task's holdout commitment is the real hash of its holdout" \
  "$(loc alice "the_task(task(_,_,holdout(A,B),holdout_commit(HC),_,_,_)), term_to_atom(holdout(A,B), T2), sha256(T2, H2), ( H2 == HC -> write(commitment_holds) ; write('FORGED') ), nl" \
     | grep -aoE '^(commitment_holds|FORGED)$' | head -1)" "commitment_holds"
# Two honest workers, two seeds, two different models -- and this is the
# NORMAL case, not a curiosity. It is why settlement cannot judge by
# re-running the training and comparing.
A1=$(loc alice "train_params(honest,P), params_digest(P,D), write(D), nl" | grep -aoE '^[0-9a-f]{64}$' | head -1)
B1=$(loc bob   "train_params(honest,P), params_digest(P,D), write(D), nl" | grep -aoE '^[0-9a-f]{64}$' | head -1)
check "two honest workers land on different weights" \
  "$( [ -n "$A1" ] && [ "$A1" != "$B1" ] && echo different || echo "same [$A1]" )" "different"
check "and training is repeatable for the same worker" \
  "$(loc alice "train_params(honest,P), params_digest(P,D), ( D == '$A1' -> write(repeatable) ; write('DRIFTED') ), nl" \
     | grep -aoE '^(repeatable|DRIFTED)$' | head -1)" "repeatable"

# ---- the server half -------------------------------------------------
if ! timeout 20 "$C" $BASE --kb training_test list >/dev/null 2>&1; then
  echo
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT (the chain half)"
  echo
  if [ "$failures" -eq 0 ]; then echo "GREEN: 0 failure(s)"; exit 0
  else echo "RED: $failures failure(s)"; exit 1; fi
fi

KB="$BASE --kb training_test"
srv() { who=$1; shift; NODE_NAME=$who NODE_KEY=$(key_of "$who") \
          timeout 120 "$C" $KB query "$K, $*" 2>/dev/null; }

timeout 60 "$C" $KB forget >/dev/null 2>&1
for f in $F; do timeout 60 "$C" $KB consult "$f" >/dev/null 2>&1; done

echo
echo "-- through the chain: train local, publish rows, seal, settle"
for w in alice:honest bob:honest carol:liar; do
  who=${w%%:*}; how=${w##*:}
  NODE_NAME=$who NODE_KEY=$(key_of "$who") \
    timeout 300 "$C" run $F "$K, train_and_export($how)" 2>/dev/null \
    | grep -aE '^(param_chunk|submission_ready)' > "$OUT/$who.pl"
  timeout 60 "$C" $KB consult "$OUT/$who.pl" >/dev/null 2>&1
  eval "DG_$who=$(grep -a '^submission_ready' "$OUT/$who.pl" | sed "s/.*'\([0-9a-f]*\)'.*/\1/")"
  eval "srv $who \"submit_ready('\$DG_$who', 0.99)\"" >/dev/null
done
check "eight rows of weights per worker reached the store" \
  "$(srv alice "findall(1, param_chunk(_,_,_), L), length(L,N), format(\"~w~n\",[N])" | grep -aoE '^[0-9]+$' | head -1)" \
  "24"

srv alice "settle_submissions" >/dev/null
R=$(srv alice "settlement_report" | grep -aE '^[a-z]+ [0-9a-f]{8} ')
check "alice, who trained honestly, is accepted" \
  "$(echo "$R" | grep -ac '^alice .* accepted(1.0)$')" "1"
check "bob, who trained honestly from another seed, is accepted too" \
  "$(echo "$R" | grep -ac '^bob .* accepted(1.0)$')" "1"
check "carol, who claimed the same 0.99, is rejected on the measurement" \
  "$(echo "$R" | grep -ac '^carol .* rejected(accuracy(')" "1"

echo
echo "-- plagiarism, and provenance"
# carol submits alice's accepted digest as her own. The weights are real
# and they work -- that is the point. She did not produce them.
eval "srv carol \"submit_ready('\$DG_alice', 0.99)\"" >/dev/null
srv alice "settle_submissions" >/dev/null
check "a second worker claiming an accepted digest is a duplicate" \
  "$(srv alice "settlement_report" | grep -acE '^carol .* rejected\(duplicate\)$')" "1"
check "provenance names two models, their workers and their blocks" \
  "$(srv alice "provenance_report" | grep -ac '^model ')" "2"
check "and names the authority that sealed each one" \
  "$(srv alice "provenance_report" | grep -acE 'sealed by (alice|bob)$')" "2"

echo
echo "-- and a second node settles to the same verdicts"
# Settlement is deterministic, so a node that did none of the training
# and consulted nothing reaches identical answers from the chain alone.
check "an independent settler agrees, verdict for verdict" \
  "$(srv bob "findall(V, (block(_,_,_,P,_,_), submission_of_payload(P, S), S = submission(rings,W2,D2,_,_), fetch_params(D2,Ps), the_task(T), settle(T,S,Ps,V)), Vs), sort(Vs, Sorted), length(Sorted, NK), ( NK =:= 2 -> write(two_kinds) ; write(NK) ), nl" \
     | grep -aoE '^(two_kinds|[0-9]+)$' | head -1)" "two_kinds"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
