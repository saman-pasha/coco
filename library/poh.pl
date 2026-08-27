%% library(poh) -- proof of history: the spine, and what it is worth.
%%
%% The raw primitives are `library(spine)', a compiled Cicili module: the
%% tick loop, the event fold, and a segment check. This is the layer
%% above them -- how a range is split, how it is verified, and where it
%% meets the ledger. Two names because they are two things, and because
%% cocolog resolves `Name.so' before `Name.pl': one library cannot be
%% both.
%%
%%   poh_genesis(-Hash)             where a spine starts
%%   poh_segments(+Start, +N, +K, -Segs)   split a range K ways
%%   poh_verify_segments(+Segs)     check every one (order does not matter)
%%   poh_anchor(+Prev, +BlockHash, -Next)  fold a block into the sequence
%%   poh_slow_run(+Start, +N, -End)  the Prolog loop, as an ORACLE
%%
%% A SPINE IS A CLOCK, NOT A CONSENSUS. It proves that a sequence of
%% hashes was computed IN ORDER, and that a given amount of hashing
%% happened between any two points on it. Anything mixed in at tick n is
%% provably earlier than everything after tick n, and that is a real and
%% useful thing to be able to check.
%%
%% It is not a proof of TIME. A faster machine ticks faster, so "one
%% million ticks apart" is not "one second apart" -- it is a lower bound
%% on work, not a reading of a clock. And it does not stop a fork: two
%% different spines from the same start are each perfectly valid, and
%% nothing inside the spine prefers one. That is what the LEDGER is for,
%% and `poh_anchor/3' is the seam between them.
%%
%% THE ASYMMETRY IS THE POINT. Producing the spine is sequential and
%% cannot be otherwise -- h(n+1) needs h(n), and there is no way around a
%% hash chain. Checking it is embarrassingly parallel, provided the
%% producer published checkpoints. Work is paid once, in order, by one
%% producer; it is audited by everybody at once.

:- use_module(library(spine)).
:- use_module(library(sha256)).

%% Thirty-two zero bytes, like the ledger's genesis parent -- a spine has
%% to start somewhere and the start has to be hash-shaped.
poh_genesis('0000000000000000000000000000000000000000000000000000000000000000').

%% ---- splitting a range -----------------------------------------------
%%
%% `seg(Index, Start, Ticks, End)': everything a verifier needs, and
%% nothing about the other segments. That independence is the whole
%% design -- a verifier is handed one segment and can answer about it
%% with no reference to any other, so K verifiers need no coordination.
poh_segments(Start, N, K, Segs) :-
    K > 0, N >= 0,
    Every is N // K,
    Every > 0,
    poh_checkpoints(Start, N, Every, Points),
    build_segs(Points, 0, Every, Segs).

build_segs([_], _, _, []) :- !.
build_segs([A, B|T], I, Every, [seg(I, A, Every, B)|R]) :-
    J is I + 1,
    build_segs([B|T], J, Every, R).

%% Every segment, checked. `forall/2' rather than a loop with an
%% accumulator because the answer is a conjunction and nothing is carried
%% between segments -- which is exactly the property that lets a real
%% deployment run these on different machines.
poh_verify_segments(Segs) :-
    forall(member(seg(_, A, Ticks, B), Segs),
           poh_verify(A, Ticks, B)).

%% ---- the seam with the ledger ----------------------------------------
%%
%% Fold a block's hash into the spine. After this, every tick depends on
%% that block having existed, so "block X was sealed before tick n" is
%% checkable by anyone who re-runs the spine -- and a block that claims a
%% position it did not occupy breaks the sequence from that point on.
poh_anchor(Prev, BlockHash, Next) :- poh_mix(Prev, BlockHash, Next).

%% ---- the oracle ------------------------------------------------------
%%
%% The same spine, one tick per Prolog goal, through `sha256_hex/2'. It
%% is about four thousand times slower than the module and it exists to
%% disagree: two implementations of the same definition, one in C and one
%% in clauses, and the suite requires them to produce the same hash.
%% A spine nobody can check independently is a number somebody made up.
poh_slow_run(H, 0, H) :- !.
poh_slow_run(H0, N, H) :-
    N > 0,
    M is N - 1,
    sha256_hex(H0, H1),
    poh_slow_run(H1, M, H).
