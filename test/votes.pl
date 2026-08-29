%% Rung 6: proof of stake and BFT votes.
%%
%% WHAT IT IS CHECKING.
%%
%%   STAKE IS A QUERY, NOT A ROSTER. Rung 2's federation is a file handed
%%   to every node; a validator's weight here is read off blocks the node
%%   already holds. The first checks seal nothing and trust nothing --
%%   they put payloads on a chain and ask the stake rule what it makes of
%%   them, including a payload that is not a stake entry at all.
%%
%%   A QUORUM IS COUNTED BY WEIGHT. Two validators out of four can be
%%   short and three can be enough; a head count would get both wrong.
%%   And one validator's vote repeated four times is the cheapest attack
%%   in the rung, so the rule requires as many distinct voters as votes.
%%
%%   THE ARITHMETIC IS THE SAFETY ARGUMENT. With quorum = 2T/3 + 1, two
%%   certificates at one height must share more than T/3 of the stake.
%%   `culprits/3' is that intersection, and the suite checks it is
%%   heavier than the fault bound rather than merely non-empty.
%%
%%   MALLORY IS AN INSIDER. Every earlier rung's criminal was a stranger.
%%   She holds real stake and votes on every block, which is what a
%%   Byzantine fault IS -- and one of her eight attacks succeeds, because
%%   a hash-seeded draw is grindable and saying otherwise would be a lie.
%%
%% NOTHING HERE SPAWNS AND NOTHING NEEDS A SERVER: every rule is a
%% function of its arguments. What the checks DO need is a fresh store
%% each -- half of them assert a chain of blocks and read the stake off
%% it, and `stake_from_chain/0' counting one block twice is a check in
%% this very file -- so each is one `run_isolated/2' proof, which is what
%% the .sh was paying a whole cocolog process per check to get. The
%% cross-process half (stake sealed by one invocation and read back by
%% another, finality beating length across two knowledge bases) is
%% votes/run.sh, and stays there.
%%
%% Run:  cocolog -s test/votes.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

votes_program :-
    use_module(library(pos)), use_module(library(bft)),
    use_module('votes/federation.pl'), use_module('ledger/node.pl'),
    use_module('votes/node.pl'), use_module('votes/mallory.pl').

%% A chain with the stake entries on it, and one payload that is not one.
%% The signatures are not checked by `stake_from_chain/0' and must not be:
%% a block only reaches a node's store through `ledger_seal/1' or
%% `ledger_sync/1', and both have verified it already. Re-verifying here
%% would be a second answer to a question already answered.
chain :-
    votes_program,
    assertz(block(0, p,  alice, 'stake(alice,40)',   s, h0)),
    assertz(block(1, h0, alice, 'stake(bob,25)',     s, h1)),
    assertz(block(2, h1, alice, 'stake(carol,20)',   s, h2)),
    assertz(block(3, h2, alice, 'stake(mallory,15)', s, h3)),
    assertz(block(4, h3, alice, 'a payload that is not a stake entry', s, h4)),
    stake_from_chain.

zero('0000000000000000000000000000000000000000000000000000000000000000').

%% Two chains from one parent: a finalised block at height 2, and a fork
%% from the same parent that grows to height 4. Nothing about the longer
%% chain is malformed -- it is simply not a candidate.
fork :-
    votes_program, zero(Z),
    assertz(block(0, Z,   alice,   'stake(alice,40)', s, h0)),
    assertz(block(1, h0,  alice,   'stake(bob,25)',   s, h1)),
    assertz(block(2, h1,  alice,   honest,            s, hA)),
    assertz(block(2, h1,  mallory, fork,              s, hM)),
    assertz(block(3, hM,  mallory, longer,            s, hM3)),
    assertz(block(4, hM3, mallory, 'longer still',    s, hM4)),
    assertz(final(2, hA)).

%% ---- stake is a query over the chain ------------------------------------

set_half :-
    section('the validator set, derived from blocks'),
    iso('four validators come off the chain',
        ( chain, validators(V), length(V, N), want(N, 4) )),
    iso('and they are the ones that staked',
        ( chain, validators(V), want(V, [alice, bob, carol, mallory]) )),
    iso('the weights are the ones on the chain',
        ( chain, stake_table(T),
          want(T, [alice-40, bob-25, carol-20, mallory-15]) )),
    iso('a payload that is not a stake entry is skipped',
        ( chain, total_stake(T), want(T, 100) )),
    iso('dave is in the federation and is not a validator',
        ( chain, ( has_stake(dave) -> W = 'VOTES' ; W = no_stake ),
          want(W, no_stake) )).

%% ---- the thresholds -----------------------------------------------------

%% one certificate, signed for real by the validators named
qc_of(Who, B, QC) :-
    findall(vote(precommit, 1, 0, B, N, S),
            ( member(N, Who), authority_key(N, K), cast(K, precommit, 1, 0, B, S) ),
            Vs),
    QC = qc(precommit, 1, 0, B, Vs).

authority_key(alice, K)   :- alice_key(K).
authority_key(bob, K)     :- bob_key(K).
authority_key(carol, K)   :- carol_key(K).
authority_key(mallory, K) :- mallory_key(K).

threshold_half :-
    section('counted by weight, never by head'),
    iso('quorum of 100 is 67',
        ( votes_program, quorum(100, Q), want(Q, 67) )),
    iso('fault bound of 100 is 33',
        ( votes_program, fault_bound(100, F), want(F, 33) )),
    iso('two of four validators can be short (alice+mallory = 55)',
        ( chain, block_a(B), qc_of([alice, mallory], B, QC),
          ( qc_valid(QC) -> W = 'QUORUM' ; W = short ), want(W, short) )),
    iso('three of four are enough (alice+bob+carol = 85)',
        ( chain, block_a(B), qc_of([alice, bob, carol], B, QC),
          ( qc_valid(QC) -> W = quorum ; W = 'SHORT' ), want(W, quorum) )),
    iso("dave's signature is good; his vote still is not",
        ( chain, dave_key(K), block_a(B), cast(K, prevote, 1, 0, B, S),
          vote_hash(prevote, 1, 0, B, H), authority(dave, P),
          (   secp256k1_verify(H, S, P)
          ->  (   valid_vote(vote(prevote, 1, 0, B, dave, S))
              ->  W = 'COUNTED' ; W = signed_but_unstaked )
          ;   W = 'SIG_BAD' ),
          want(W, signed_but_unstaked) )).

%% ---- the draw -----------------------------------------------------------

draw_half :-
    section('the leader draw: a function of chain state'),
    iso('the same seed and height give the same leader',
        ( chain, leader(deadbeef, 7, A), leader(deadbeef, 7, B),
          ( A == B -> W = deterministic ; W = 'WANDERS' ),
          want(W, deterministic) )),
    iso('every height draws somebody',
        ( chain, findall(W, ( between(1, 50, I), leader(deadbeef, I, W) ), L),
          length(L, N), want(N, 50) )),
    %% 400 heights against 40/25/20/15: the ORDER is the claim, not the
    %% counts. Exact counts are a property of sha256 and would make this a
    %% test of the hash rather than of the draw.
    iso('the draw tracks stake: alice drawn most, mallory least',
        ( chain, zero(Z),
          findall(C-W,
                  ( member(W, [alice, bob, carol, mallory]),
                    findall(1, ( between(1, 400, I), leader(Z, I, W) ), L),
                    length(L, C) ),
                  Ps),
          keysort(Ps, S), last(S, _-Top), S = [_-Bottom|_],
          want(Top-Bottom, alice-mallory) )).

%% ---- the proposer -------------------------------------------------------

proposer_half :-
    section("a voter checks who proposed, from the block's own parent"),
    %% The leader is worked out from the block's PARENT hash, so the answer
    %% is the same on every node and stays the same forever. Both
    %% directions are checked against whoever the draw actually names,
    %% rather than against a name written down here -- a test that
    %% hardcodes the winner is a test of sha256.
    iso('a block from the drawn leader is prevotable',
        ( chain, leader(h4, 5, W),
          assertz(block(5, h4, W, 'a proposal', s, h5)),
          ( proposal_ok(5, h5) -> R = ok ; R = 'REFUSED' ), want(R, ok) )),
    iso('a block from anyone else is not',
        ( chain, leader(h4, 5, W),
          member(X, [alice, bob, carol, mallory]), X \== W,
          assertz(block(5, h4, X, 'a proposal', s, h5x)),
          ( proposal_ok(5, h5x) -> R = 'ACCEPTED' ; R = refused ),
          want(R, refused) )).

%% ---- finality -----------------------------------------------------------

final_half :-
    section('finality beats length'),
    iso('the finalised tip is a candidate',
        ( fork, ( extends_final(hA) -> W = candidate ; W = 'REFUSED' ),
          want(W, candidate) )),
    iso('the longer tip that omits it is not',
        ( fork, ( extends_final(hM4) -> W = 'CANDIDATE' ; W = refused ),
          want(W, refused) )),
    iso('and fork choice alone would have preferred the longer one',
        ( fork, chain_from(hM4, L1), length(L1, N1),
          chain_from(hA, L2), length(L2, N2),
          ( N1 > N2 -> W = longer ; W = 'NOT_LONGER' ), want(W, longer) )),
    section('a block is counted once'),
    iso('reading the chain twice does not double the stake',
        ( chain, stake_from_chain, stake_from_chain,
          total_stake(T), want(T, 100) )).

%% ---- the lock -----------------------------------------------------------

lock_half :-
    section('the lock, and the only thing that releases it'),
    iso('an unlocked validator may precommit anything',
        ( votes_program, block_a(A),
          ( locked_ok(none, 1, 0, A, []) -> W = free ; W = 'BOUND' ),
          want(W, free) )),
    iso('a locked validator may repeat its own block',
        ( votes_program, block_a(A),
          ( locked_ok(lock(1, 0, A), 1, 1, A, []) -> W = same_block ; W = 'REFUSED' ),
          want(W, same_block) )),
    iso('and may not move to another with no proof',
        ( votes_program, block_a(A), block_b(B),
          ( locked_ok(lock(1, 0, A), 1, 1, B, []) -> W = 'MOVED' ; W = bound ),
          want(W, bound) )),
    iso('a later prevote quorum releases it',
        ( votes_program, block_a(A), block_b(B),
          ( locked_ok(lock(1, 0, A), 1, 2, B, [pol(1, 1, B)])
            -> W = released ; W = 'STUCK' ),
          want(W, released) )),
    iso('an EARLIER quorum does not',
        ( votes_program, block_a(A), block_b(B),
          ( locked_ok(lock(1, 5, A), 1, 6, B, [pol(1, 2, B)])
            -> W = 'MOVED' ; W = bound ),
          want(W, bound) )),
    iso('a lock at one height does not bind the next',
        ( votes_program, block_a(A), block_b(B),
          ( locked_ok(lock(1, 0, A), 2, 0, B, []) -> W = free ; W = 'BOUND' ),
          want(W, free) )).

%% ---- evidence -----------------------------------------------------------

evidence_half :-
    section('the fault that proves itself'),
    iso('equivocation names the validator and both documents',
        ( chain, block_a(A), block_b(B), mallory_key(K),
          cast(K, precommit, 1, 0, A, S1), cast(K, precommit, 1, 0, B, S2),
          (   equivocation([vote(precommit, 1, 0, A, mallory, S1),
                            vote(precommit, 1, 0, B, mallory, S2)],
                           W, evidence(_, _))
          ->  true ; W = 'UNSEEN' ),
          want(W, mallory) )),
    iso('an honest validator voting once is not equivocation',
        ( chain, block_a(A), alice_key(K), cast(K, precommit, 1, 0, A, S),
          ( equivocation([vote(precommit, 1, 0, A, alice, S)], _, _)
            -> W = 'ACCUSED' ; W = clean ),
          want(W, clean) )),
    iso('two certificates at one height name their culprits',
        ( votes_program, double_qc_culprits(N, _), want(N, [alice, carol]) )),
    iso('and the culprits are heavier than the fault bound',
        ( chain, double_qc_culprits(_, H), total_stake(T), fault_bound(T, F),
          ( H > F -> W = accountable ; W = 'BELOW_BOUND' ),
          want(W, accountable) )).

%% ---- mallory ------------------------------------------------------------

attack(A, L, Want) :-
    iso(L, ( votes_program, G =.. [A, V], call(G), want(V, Want) )).

mallory_half :-
    section('mallory, from inside the validator set'),
    attack(attack_no_stake,     'voting with a key that never staked',              refused),
    attack(attack_stuff_quorum, 'one vote repeated until it is a quorum',           refused),
    attack(attack_forge_vote,   'relabelling a signature as a vote for another block', refused),
    attack(attack_replay_phase, 'presenting a prevote as a precommit',              refused),
    attack(attack_equivocate,   'signing two blocks at one height',                 refused),
    attack(attack_unlock,       'voting away from a lock with no proof',            refused),
    attack(attack_double_qc,    'two certificates, bought with a third of the stake', refused),
    attack(attack_grind,        'grinding the leader draw -- SUCCEEDS, and must',   'ACCEPTED').

main :-
    set_half, threshold_half, draw_half, proposer_half,
    final_half, lock_half, evidence_half, mallory_half,
    nl, checks_done.
