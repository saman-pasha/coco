%% mallory, a validator in good standing.
%%
%% EVERY EARLIER RUNG'S CRIMINAL WAS AN OUTSIDER. She sealed blocks
%% without being an authority, wrote contracts that were fenced out,
%% submitted models she had not trained. Here she is INSIDE: admitted to
%% the federation, holding fifteen tokens of real stake, entitled to vote
%% on every block. That is what a Byzantine fault is, and a rung about
%% tolerating faults that only tested strangers would have tested
%% nothing.
%%
%%   attack_no_stake(-V)     vote with a key that never staked
%%   attack_stuff_quorum(-V) one vote, repeated until it is a quorum
%%   attack_forge_vote(-V)   relabel a signature as a vote for another block
%%   attack_replay_phase(-V) present a prevote as a precommit
%%   attack_equivocate(-V)   sign two blocks at one height
%%   attack_unlock(-V)       vote away from a lock with no proof
%%   attack_double_qc(-V)    two certificates at one height, with accomplices
%%   attack_grind(-V)        bias the leader draw -- SUCCEEDS
%%
%% The keys below are the demonstration keys and are published in
%% federation.pl's comments; nothing here is a secret and nothing here
%% needs to be.

:- use_module(library(pos)).
:- use_module(library(bft)).
:- use_module(library(poa)).
:- use_module(library(sha256)).

alice_key('1111111111111111111111111111111111111111111111111111111111111111').
bob_key('2222222222222222222222222222222222222222222222222222222222222222').
carol_key('3333333333333333333333333333333333333333333333333333333333333333').
mallory_key('4444444444444444444444444444444444444444444444444444444444444444').
dave_key('5555555555555555555555555555555555555555555555555555555555555555').

%% The stake this rung runs on, asserted here so the attacks can be run
%% with `run' and no database at all. votes/run.sh puts the same numbers
%% on the chain and reads them back with `stake_from_chain/0'; that these
%% two agree is one of the suite's checks.
:- dynamic stake_entry/2.
demo_stake :-
    \+ stake_entry(alice, _),
    assertz(stake_entry(alice, 40)),
    assertz(stake_entry(bob, 25)),
    assertz(stake_entry(carol, 20)),
    assertz(stake_entry(mallory, 15)).
demo_stake.

%% `refused' when what she wanted does not happen.
verdict(G, refused) :- \+ call(G), !.
verdict(_, 'ACCEPTED').

block_a('aaaa000000000000000000000000000000000000000000000000000000000000').
block_b('bbbb000000000000000000000000000000000000000000000000000000000000').

%% 1. VOTE WITHOUT STAKE. dave is in the federation -- an admitted party
%% whose signature verifies perfectly -- and he never staked a token. The
%% counting rule asks for stake before it asks for a signature, so his
%% vote is not a small vote, it is not a vote.
attack_no_stake(V) :-
    demo_stake,
    block_a(B),
    dave_key(K),
    cast(K, prevote, 1, 0, B, Sig),
    verdict(valid_vote(vote(prevote, 1, 0, B, dave, Sig)), V).

%% 2. STUFF THE QUORUM. Her one genuine vote, copied until the list is
%% long enough. This is the cheapest attack in the rung and the one a
%% head count would miss entirely: four votes out of four validators,
%% every signature real. The rule sorts the voters and requires as many
%% distinct names as votes, then counts STAKE and not names.
attack_stuff_quorum(V) :-
    demo_stake,
    block_a(B),
    mallory_key(K),
    cast(K, precommit, 1, 0, B, Sig),
    Vote = vote(precommit, 1, 0, B, mallory, Sig),
    verdict(qc_valid(qc(precommit, 1, 0, B, [Vote, Vote, Vote, Vote])), V).

%% 3. RELABEL A SIGNATURE. She really did prevote block A; she presents
%% that signature as a vote for block B. The block hash is inside the
%% text that was signed, so the relabelled vote verifies against a
%% different hash and fails.
attack_forge_vote(V) :-
    demo_stake,
    block_a(A), block_b(B),
    mallory_key(K),
    cast(K, prevote, 1, 0, A, Sig),
    verdict(valid_vote(vote(prevote, 1, 0, B, mallory, Sig)), V).

%% 4. PROMOTE A PHASE. Her prevote -- "I would accept this" -- offered as
%% a precommit -- "I am bound to this". The kind is in the signed text
%% for exactly this reason: without it the two phases would be one, and
%% the lock would have nothing to bind.
attack_replay_phase(V) :-
    demo_stake,
    block_a(B),
    mallory_key(K),
    cast(K, prevote, 1, 0, B, Sig),
    verdict(valid_vote(vote(precommit, 1, 0, B, mallory, Sig)), V).

%% 5. EQUIVOCATE. Two precommits, same height, same round, different
%% blocks, both signed with her own key. BOTH VOTES ARE VALID -- there is
%% nothing malformed about either one, and no checker looking at one vote
%% could say a thing.
%%
%% What she cannot do is stop the pair existing. Her aim is to be
%% unidentifiable; `equivocation/3' is a search anyone can run over the
%% votes they hold, and it returns her name and the two documents her key
%% signed. Nothing has to be corroborated and nobody has to be believed,
%% which is what makes this the one fault that proves itself.
attack_equivocate(V) :-
    demo_stake,
    block_a(A), block_b(B),
    mallory_key(K),
    cast(K, precommit, 1, 0, A, S1),
    cast(K, precommit, 1, 0, B, S2),
    Votes = [vote(precommit, 1, 0, A, mallory, S1),
             vote(precommit, 1, 0, B, mallory, S2)],
    verdict(\+ equivocation(Votes, mallory, _), V).

%% 6. VOTE AWAY FROM A LOCK. She precommitted block A at round 0 and
%% wants block B at round 1, with no quorum of prevotes for B to point
%% at. The lock rule refuses, and it refuses BEFORE anything is written:
%% in `do_precommit/3' the check and the two writes are one goal, so
%% there is no state in which she has voted and is not yet bound.
attack_unlock(V) :-
    demo_stake,
    block_a(A), block_b(B),
    verdict(locked_ok(lock(1, 0, A), 1, 1, B, []), V).

%% 7. TWO CERTIFICATES AT ONE HEIGHT. She cannot do this alone and the
%% attack does not pretend she can: fifteen tokens is nowhere near
%% sixty-seven, and even her best pairing reaches fifty-five. So she buys
%% alice and carol, and the coalition signs both sides.
%%
%% The certificates are REAL -- both pass `qc_valid/1', and a node
%% holding either one is not being deceived about anything. What the
%% arithmetic guarantees is that the two of them cannot exist without an
%% overlap heavier than a third of the stake, and `culprits/3' returns
%% exactly who that was. Safety is not "this cannot happen"; it is "when
%% it happens it names the validators who did it", and a name is what a
%% slashing rule needs.
attack_double_qc(V) :-
    demo_stake,
    block_a(A), block_b(B),
    alice_key(KA), bob_key(KB), carol_key(KC), mallory_key(KM),
    cast(KA, precommit, 2, 0, A, SA1),
    cast(KB, precommit, 2, 0, A, SB1),
    cast(KC, precommit, 2, 0, A, SC1),
    cast(KA, precommit, 2, 0, B, SA2),
    cast(KC, precommit, 2, 0, B, SC2),
    cast(KM, precommit, 2, 0, B, SM2),
    QC1 = qc(precommit, 2, 0, A, [vote(precommit, 2, 0, A, alice, SA1),
                                  vote(precommit, 2, 0, A, bob, SB1),
                                  vote(precommit, 2, 0, A, carol, SC1)]),
    QC2 = qc(precommit, 2, 0, B, [vote(precommit, 2, 0, B, alice, SA2),
                                  vote(precommit, 2, 0, B, carol, SC2),
                                  vote(precommit, 2, 0, B, mallory, SM2)]),
    qc_valid(QC1), qc_valid(QC2),
    %% she wanted the two certificates and no attribution
    verdict(( \+ ( culprits(QC1, QC2, Names),
                   Names \== [],
                   findall(S, (member(N, Names), stake_of(N, S)), Ss),
                   sum_list(Ss, Heavy),
                   total_stake(T), fault_bound(T, F),
                   Heavy > F ) ), V).

%% What the culprit set actually is, for the choreography to print.
double_qc_culprits(Names, Heavy) :-
    demo_stake,
    block_a(A), block_b(B),
    alice_key(KA), bob_key(KB), carol_key(KC), mallory_key(KM),
    cast(KA, precommit, 2, 0, A, SA1),
    cast(KB, precommit, 2, 0, A, SB1),
    cast(KC, precommit, 2, 0, A, SC1),
    cast(KA, precommit, 2, 0, B, SA2),
    cast(KC, precommit, 2, 0, B, SC2),
    cast(KM, precommit, 2, 0, B, SM2),
    QC1 = qc(precommit, 2, 0, A, [vote(precommit, 2, 0, A, alice, SA1),
                                  vote(precommit, 2, 0, A, bob, SB1),
                                  vote(precommit, 2, 0, A, carol, SC1)]),
    QC2 = qc(precommit, 2, 0, B, [vote(precommit, 2, 0, B, alice, SA2),
                                  vote(precommit, 2, 0, B, carol, SC2),
                                  vote(precommit, 2, 0, B, mallory, SM2)]),
    culprits(QC1, QC2, Names),
    findall(S, (member(N, Names), stake_of(N, S)), Ss),
    sum_list(Ss, Heavy).

%% 8. GRIND THE DRAW -- AND THIS ONE WORKS.
%%
%% The leader is a function of the head's hash and the height, and the
%% head's hash is a function of the payload of the block that made it. So
%% a proposer tries payloads until the draw at the next height comes out
%% in her favour. With fifteen per cent of the stake she expects to
%% succeed in about seven attempts; in this demonstration the first
%% payload that worked was the twenty-fourth. There is nothing to detect
%% either way: every payload she tried was a legitimate payload, and the
%% one she published is a legitimate block.
%%
%% THIS IS NOT A BUG, IT IS THE PRICE OF A SCHEDULE ANYONE CAN
%% RECOMPUTE FROM ROWS. Inside a certificate-gated federation, where
%% every validator is a named party who had to be admitted and can be
%% removed, biasing your own turn is a cost worth paying for a draw with
%% no beacon, no committee and no extra round of messages. Outside one it
%% is not, and it would want a VRF or an unbiasable beacon. The trade is
%% stated where it is made, in library(pos), and it is in the suite as
%% a SUCCESS because pretending otherwise would be the easy lie here.
attack_grind(V) :-
    demo_stake,
    verdict(grind(200, _, _), V).

grind(Limit, Payload, Seed) :-
    between(1, Limit, N),
    atomic_list_concat(['proposal-', N], Payload),
    sha256(Payload, Seed),
    leader(Seed, 3, mallory),
    !.

%% For the choreography: how many payloads she had to try.
grind_cost(N) :-
    demo_stake,
    between(1, 200, N),
    atomic_list_concat(['proposal-', N], Payload),
    sha256(Payload, Seed),
    leader(Seed, 3, mallory),
    !.
