%% An aggregator node: many chains, none of them known in advance.
%%
%%   publish_rules(+Chain)          seal a chain's rules onto that chain
%%   learn_rules(+Chain)            read them back, fence them, install them
%%   rules_at(+Chain, +Height, -Cs) the rules IN FORCE at a height
%%   verify_foreign(+Chain, +Block) call the chain's own validity rule
%%   best_foreign(+Chain, +Heads, -Best)   and its own fork choice
%%
%%   take_checkpoint(-Root)         merkle root over every member head
%%   checkpoint_proof(+Chain, -I, -Leaf, -Path, -Root)
%%
%%   import(+Chain, +Fact)          a fact from another chain, tagged
%%   provenance_across(+Key, -Rows) and the join over all of them
%%
%% WHAT THE HOST KNOWS ABOUT A MEMBER CHAIN IS NOTHING. It holds a name
%% and some blocks. Everything else -- what a valid block is, which head
%% is better, what counts as final -- it reads off the chain and runs.
%% Two chains under regimes that flatly disagree are verified here by the
%% same code, because the difference between them is DATA.

:- use_module(library(hub)).
:- use_module(library(contract)).
:- use_module(library(poa)).
:- use_module(library(sha256)).
:- use_module(library(lists)).

:- dynamic member_head/3.     % member_head(Chain, Height, Hash)
:- dynamic imported/2.        % imported(Chain, Fact)
:- dynamic rules_installed/1.

%% ---- rules as entries ------------------------------------------------
%%
%% Publishing is sealing. A chain's rules are a payload, so they are
%% hash-committed, signed by whoever was entitled to seal, gossiped like
%% anything else, and identical on every node that holds the block. There
%% is no rule-distribution mechanism because there did not need to be
%% one.
publish_rules(Chain) :-
    chain_source(Chain, Clauses),
    rules_payload(Chain, Clauses, Payload),
    ledger_seal(Payload).

%% READING THEM BACK IS THE LIGHT CLIENT. Fence first, install second,
%% and if the fence says no then this node simply does not know how to
%% verify that chain -- which is the correct outcome and not an error.
learn_rules(Chain) :-
    \+ rules_installed(Chain),
    latest_rules(Chain, Clauses),
    rules_admit(Chain, Clauses, admitted),
    contract_install(Chain, Clauses),
    assertz(rules_installed(Chain)).

latest_rules(Chain, Clauses) :-
    findall(H-Cs,
            ( block(H, _, _, Payload, _, _),
              rules_of_payload(Payload, Chain, Cs) ),
            Rs),
    Rs \== [],
    keysort(Rs, Sorted),
    last(Sorted, _-Clauses).

%% THE RULES ARE PINNED TO A HEIGHT. A block at height 4 is judged by the
%% rules that were on the chain at height 4, never by the rules published
%% at height 9.
%%
%% Without this a chain could publish permissive rules today and make
%% last year's invalid blocks valid, retroactively -- which is
%% `attack_rules_swap', and it is the difference between a chain that may
%% CHANGE its rules (which any chain may) and a chain that may REWRITE
%% what its old blocks meant (which none may). Both readings are
%% defensible until you write one down; this is the one written down.
rules_at(Chain, Height, Clauses) :-
    findall(H-Cs,
            ( block(H, _, _, Payload, _, _),
              H =< Height,
              rules_of_payload(Payload, Chain, Cs) ),
            Rs),
    Rs \== [],
    keysort(Rs, Sorted),
    last(Sorted, _-Clauses).

%% ---- verifying under somebody else's rules ---------------------------

verify_foreign(Chain, Block) :-
    atom_concat(Chain, '_valid', Pred),
    Goal =.. [Pred, Block],
    call(Goal).

best_foreign(Chain, [X], X) :- !, atom(Chain).
best_foreign(Chain, [A, B|T], Best) :-
    atom_concat(Chain, '_better', Pred),
    Cmp =.. [Pred, A, B],
    ( call(Cmp) -> best_foreign(Chain, [A|T], Best)
    ;             best_foreign(Chain, [B|T], Best) ).

final_foreign(Chain, Head, Arg) :-
    atom_concat(Chain, '_final', Pred),
    Goal =.. [Pred, Head, Arg],
    call(Goal).

%% ---- the anchor chain ------------------------------------------------
%%
%% One hash for the whole federation. Every member head becomes a leaf,
%% the leaves are sorted so two nodes taking the same checkpoint get the
%% same root, and the root is sealed onto the anchor chain as an ordinary
%% payload.
take_checkpoint(Root) :-
    checkpoint_leaves(Leaves),
    Leaves \== [],
    merkle_root(Leaves, Root).

checkpoint_leaves(Leaves) :-
    findall(Chain-Height-Hash, member_head(Chain, Height, Hash), Raw),
    sort(Raw, Sorted),
    findall(L, ( member(C-H-X, Sorted), checkpoint_leaf(C, H, X, L) ), Leaves).

%% The proof that one member was at one height when the checkpoint was
%% taken: the leaf, its index, and the siblings on the way up. Nobody has
%% to be handed the whole federation to check one member.
checkpoint_proof(Chain, I, Leaf, Path, Root) :-
    findall(C-H-X, member_head(C, H, X), Raw),
    sort(Raw, Sorted),
    findall(L, ( member(C2-H2-X2, Sorted), checkpoint_leaf(C2, H2, X2, L) ), Leaves),
    nth0(I, Sorted, Chain-Ht-Hash),
    checkpoint_leaf(Chain, Ht, Hash, Leaf),
    merkle_path(Leaves, I, Path),
    merkle_root(Leaves, Root).

%% ---- the join --------------------------------------------------------
%%
%% CROSS-CHAIN PROVENANCE IS A QUERY, and the translation layer is
%% unification. A fact imported from a chain keeps the chain's name
%% beside it; asking where something came from is one `findall' whose
%% shared variable does the joining. There is no schema mapping and no
%% adapter, because two facts that mention the same digest already agree
%% about it.
import(Chain, Fact) :- assertz(imported(Chain, Fact)).

provenance_across(Key, Rows) :-
    findall(Chain-Fact,
            ( imported(Chain, Fact),
              mentions(Fact, Key) ),
            Rows).

mentions(Fact, Key) :- Fact =.. [_|Args], memberchk(Key, Args).

%% Two trivial verifiers, so that a test of the bridge's GUARDS is a test
%% of the guards. A check that could pass for two reasons has tested
%% neither, and the chain-and-height guard is the half worth pinning --
%% what counts as final is the foreign chain's business, and it supplies
%% its own goal for that.
verify_always(_).
verify_never(_) :- fail.

%% The real one: ask the FOREIGN chain whether its own rule calls this
%% final. The certificate's weight and the chain's total travel in the
%% proof, because what those numbers mean is that chain's business --
%% zeta counts depth and omega counts stake, and the host does not have
%% to know which.
verify_final(proof(Chain, Height, Hash, cert(S, T))) :-
    final_foreign(Chain, head(Height, Hash, S), T).

%% ---- the bridge as a suspended machine -------------------------------
%%
%% Rung 3's gas mechanism, doing a job it was not built for. A bridge
%% that waits for a proof is not a process, not a timer and not a poll
%% loop: it is a frozen machine in a table, and any node at all can thaw
%% it and go on. `--steps' bounds each thaw, so a bridge nobody ever
%% releases costs the node nothing but a row.
:- dynamic bridge_open/1.

bridge_wait(Id) :- bridge_open(Id), !.
bridge_wait(Id) :- bridge_wait(Id).

%% Releasing is the guard plus the foreign chain's own finality rule, and
%% the write is what the frozen machine is waiting to see.
bridge_release(Bridge, Proof) :-
    Bridge = bridge(Id, _, _, _),
    bridge_ready(Bridge, Proof, verify_final),
    assertz(bridge_open(Id)).

%% ---- reporting -------------------------------------------------------

hub_report :-
    findall(C, rules_installed(C), Cs),
    sort(Cs, Sorted),
    length(Sorted, N),
    format("chains ~w ~w~n", [N, Sorted]).

heads_report :-
    forall(member_head(C, H, X),
           ( sub_atom(X, 0, 8, _, S), format("head ~w ~w ~w~n", [C, H, S]) )).
