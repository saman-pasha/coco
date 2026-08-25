%% A ledger node: seal, adopt, sync, audit.
%%
%% Consulted into a knowledge base that IS this node's chain. Blocks are
%% clauses; the head mark is a clause; nothing is ever retracted. A node
%% is a cocolog process with a `--kb' and a private key, and there is no
%% daemon anywhere -- a node exists for the length of one turn and its
%% state is entirely in the database, which is the family's whole claim
%% arriving in a new place.
%%
%%   ledger_seal(+Payload)     seal the next block and commit it
%%   ledger_sync(+PeerBlocks)  take a peer's blocks, keep the valid ones
%%   ledger_head(-Head)        this node's current head
%%   ledger_audit(-Status)     re-verify the whole chain from genesis
%%
%% ONE TURN, ONE TRANSACTION. `ledger_seal/1' asserts the block and its
%% head mark in a single goal, so they commit together or not at all. A
%% block visible without its head mark would be a chain whose tip nobody
%% agreed to; a head mark without its block would be a tip that does not
%% exist. Neither is reachable, and that is a property of the store
%% rather than of care taken here.

:- use_module(library(poa)).
:- use_module(library(lists)).

:- dynamic block/6.
:- dynamic head_mark/2.

%% ---- reading the chain ----------------------------------------------

%% A HEAD MARK IS A CANDIDATE, NOT AN ANSWER. Every block this node
%% accepts gets one, marks are appended and never removed, and the head
%% is whatever FORK CHOICE says about the set of them.
%%
%% That distinction is the whole of how a reorg works here. A node does
%% not decide it was wrong and go back: it accumulates tips, and the rule
%% -- the same rule on every node -- reads the same set and returns the
%% same answer. Nothing is retracted, so what this node believed and when
%% is still on the record, and two nodes that hold the same blocks agree
%% on the head no matter what order the blocks arrived in.
ledger_head(Best) :-
    findall(head(H, Hash, T),
            ( head_mark(H, Hash),
              chain_from(Hash, Blocks),
              chain_in_turn(Blocks, 0, T) ),
            Cands),
    Cands \== [],
    !,
    best_head(Cands, Best).

ledger_head(head(-1, Genesis, 0)) :-
    genesis_prev(Genesis).

best_head([X], X) :- !.
best_head([A, B|T], Best) :-
    ( better_head(A, B) -> best_head([A|T], Best) ; best_head([B|T], Best) ).

%% The chain ending at HASH, youngest first, by walking parents. A chain
%% that cannot be walked to genesis is not a chain, and `chain_from/2'
%% failing is how a node notices.
chain_from(Hash, []) :- genesis_prev(Hash), !.
chain_from(Hash, [block(H, Prev, A, P, S, Hash)|T]) :-
    block(H, Prev, A, P, S, Hash),
    chain_from(Prev, T).

ledger_height(H) :- ledger_head(head(H, _, _)).

%% ---- sealing ---------------------------------------------------------
%%
%% The next height, the current head as parent, this node's name and key.
%% NODE_KEY is the one secret and it arrives from the environment: a
%% private key in a consulted file is a private key in a database row.
node_identity(Name, Priv) :-
    getenv('NODE_NAME', Name),
    getenv('NODE_KEY', Priv).

ledger_seal(Payload) :-
    node_identity(Name, Priv),
    ledger_head(head(H0, PrevHash, _)),
    H is H0 + 1,
    ( H0 < 0 -> genesis_prev(Prev) ; Prev = PrevHash ),
    seal(Priv, H, Prev, Name, Payload, Sig, Hash),
    %% ONE GOAL, so one transaction: the block and the mark that says it
    %% is the tip commit together.
    ( assertz(block(H, Prev, Name, Payload, Sig, Hash)),
      assertz(head_mark(H, Hash)) ).

%% ---- adopting a peer's blocks ----------------------------------------
%%
%% Every block is re-verified here. A peer is not trusted to have
%% verified anything -- it may be lying, or running an older rule, or
%% have been fed a bad block itself. `valid_block/6' is cheap next to
%% the cost of believing a peer.
%%
%% Blocks are offered OLDEST FIRST so that a parent is present before its
%% child is judged; an orphan is skipped rather than refused, because its
%% parent may be in the next batch.
ledger_sync([]).
ledger_sync([block(H, Prev, A, P, S, Hash)|T]) :-
    (   block(H, _, _, _, _, Hash)
    ->  true                                   % already have it
    ;   valid_block(H, Prev, A, P, S, Hash),
        extends_known(H, Prev)
    ->  assertz(block(H, Prev, A, P, S, Hash)),
        maybe_advance(H, Hash)
    ;   true                                   % invalid or orphan: skip
    ),
    ledger_sync(T).

%% A block extends what this node has when its parent is genesis at
%% height 0, or a block it holds at exactly one less.
extends_known(0, Prev) :- genesis_prev(Prev), !.
extends_known(H, Prev) :-
    H > 0,
    P is H - 1,
    block(P, _, _, _, _, Prev).

%% Every accepted block is a candidate tip, so it gets a mark. Whether it
%% is THE head is not decided here and must not be: `ledger_head/1' asks
%% the rule, over the whole set, every time. Deciding at adoption time
%% would make the answer depend on arrival order, which is exactly what
%% differs between nodes and exactly what fork choice exists to remove.
maybe_advance(H, Hash) :- assertz(head_mark(H, Hash)).

%% ---- auditing --------------------------------------------------------
%%
%% Re-verify the whole chain from genesis: every hash recomputed, every
%% signature checked, every parent link followed, every author a member.
%% This is what a Zeytun reader does with no write path at all, and what
%% a joining node does before believing anything.
ledger_audit(ok) :-
    ledger_head(head(H, Hash, _)),
    (   H < 0
    ->  true
    ;   chain_from(Hash, Blocks),
        length(Blocks, N),
        N =:= H + 1,
        all_valid(Blocks)
    ),
    !.
ledger_audit(broken).

all_valid([]).
all_valid([block(H, Prev, A, P, S, Hash)|T]) :-
    valid_block(H, Prev, A, P, S, Hash),
    all_valid(T).

%% ---- reporting, for the choreography ---------------------------------

ledger_report :-
    ledger_head(head(H, Hash, T)),
    ledger_audit(Status),
    format("head ~w ~w in_turn ~w audit ~w~n", [H, Hash, T, Status]).

%% Every block this node holds, oldest first -- what a peer fetches.
ledger_export :-
    findall(block(H, Prev, A, P, S, Hash),
            block(H, Prev, A, P, S, Hash), Bs),
    sort_by_height(Bs, Sorted),
    export_lines(Sorted).

sort_by_height(Bs, Sorted) :-
    findall(H-B, (member(B, Bs), B = block(H, _, _, _, _, _)), Keyed),
    keysort(Keyed, KS),
    findall(B, member(_-B, KS), Sorted).

%% `~q' AND NOT `~w' AROUND THE PAYLOAD. What is exported is goal text a
%% peer will read back, so every atom has to come out quoted the way the
%% reader expects -- and a payload that itself contains a quote has to
%% come out with that quote DOUBLED. Hand-written quotes around `~w' do
%% neither, and the failure is silent in the worst way: the peer's reader
%% stops early, `ledger_sync/1' is handed a shorter term than was sent,
%% and blocks vanish with nothing logged.
%%
%% Rung 2's payloads were prose and never showed it. Rung 7's are source
%% code -- a chain publishing its own rules -- and the first one broke
%% every gossip hop in the aggregator.
export_lines([]).
export_lines([block(H, Prev, A, P, S, Hash)|T]) :-
    format("block(~w,~q,~q,~q,~q,~q).~n", [H, Prev, A, P, S, Hash]),
    export_lines(T).
