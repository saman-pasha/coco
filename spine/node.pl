%% A spine node: produce sequentially, verify in parallel, anchor blocks.
%%
%%   spine_produce(+N, +K)      make N ticks, publish K segments
%%   verify_one(+I)             check segment I and record the verdict
%%   spine_report               how many segments checked out
%%   anchor_block(+BlockHash)   fold a block into the sequence
%%   anchor_order(-Pairs)       which block came first, from the spine alone
%%
%% THE SEGMENTS ARE ROWS, so a verifier is an ordinary cocolog invocation
%% that reads one row, does its arithmetic, and writes a verdict. There is
%% no coordinator and no message passing: K verifiers touch K disjoint
%% rows and never need to hear about each other, which is what lets them
%% run on K machines as easily as in K processes.

:- use_module(library(poh)).
:- use_module(library(lists)).

:- dynamic spine_seg/4.
:- dynamic spine_head/2.
:- dynamic spine_ok/2.
:- dynamic spine_anchor/3.

%% ---- producing -------------------------------------------------------
%%
%% One process, one long loop, no way to hurry it. Publishing the
%% checkpoints is what turns the result into something others can check
%% without repeating the whole thing in order.
spine_produce(N, K) :-
    poh_genesis(G),
    poh_segments(G, N, K, Segs),
    forall(member(seg(I, A, T, B), Segs),
           assertz(spine_seg(I, A, T, B))),
    last(Segs, seg(_, _, _, End)),
    assertz(spine_head(N, End)).

%% ---- verifying -------------------------------------------------------
%%
%% Segment I, and nothing else. A verifier does not read the head, the
%% other segments, or who produced them -- it re-runs its own range and
%% says whether the two ends match. Wrong segments fail; they do not
%% throw, because a bad segment is an ordinary answer.
verify_one(I) :-
    spine_seg(I, A, T, B),
    ( poh_verify(A, T, B) -> V = ok ; V = broken ),
    assertz(spine_ok(I, V)).

spine_report :-
    findall(I, spine_ok(I, ok), Good),
    findall(I, spine_ok(I, broken), Bad),
    length(Good, NG), length(Bad, NB),
    format("verified ~w broken ~w~n", [NG, NB]).

%% THE WHOLE SPINE IS SOUND when every segment is sound AND the segments
%% chain: segment i's end is segment i+1's start. Checking the segments
%% alone would let a verifier pass a set of perfectly good pieces that
%% were never part of one sequence.
spine_sound :-
    findall(seg(I, A, T, B), spine_seg(I, A, T, B), Raw),
    sort(Raw, Segs),
    Segs \== [],
    forall(member(seg(_, A, T, B), Segs), poh_verify(A, T, B)),
    chains(Segs).

chains([_]) :- !.
chains([seg(_, _, _, B), seg(J, A2, T2, B2)|R]) :-
    B == A2,
    chains([seg(J, A2, T2, B2)|R]).

%% ---- anchoring a block ----------------------------------------------
%%
%% Fold a block hash into the sequence at the current head. Everything
%% after this tick depends on the block having existed, so the ORDER of
%% two anchored blocks is checkable by anyone who re-runs the spine --
%% and nobody has to be trusted about when they saw what.
anchor_block(BlockHash) :-
    current_head(Tick, H),
    poh_anchor(H, BlockHash, Next),
    T2 is Tick + 1,
    ( assertz(spine_anchor(T2, BlockHash, Next)),
      assertz(spine_head(T2, Next)) ).

current_head(Tick, H) :-
    findall(T-X, spine_head(T, X), Ps),
    Ps \== [],
    keysort(Ps, Sorted),
    last(Sorted, Tick-H).

%% Which block came first, read off the spine and nothing else.
anchor_order(Pairs) :-
    findall(T-B, spine_anchor(T, B, _), Raw),
    keysort(Raw, Pairs).

%% An anchor is genuine when folding that block at that point really does
%% give the hash on the record. A backdated anchor fails here.
anchor_genuine(Tick) :-
    spine_anchor(Tick, Block, Claimed),
    Prev is Tick - 1,
    ( spine_anchor(Prev, _, PrevH) -> true ; head_at(Prev, PrevH) ),
    poh_anchor(PrevH, Block, Recomputed),
    Recomputed == Claimed.

head_at(T, H) :- spine_head(T, H), !.
