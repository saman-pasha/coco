%% library(hub) -- the aggregator: many chains, one node.
%%
%%   rules_payload(+Chain, +Clauses, -Payload) / rules_of_payload/3
%%   rules_admit(+Chain, +Clauses, -Verdict)   the fence, plus a namespace
%%   rules_scoped(+Chain, +Head)
%%
%%   merkle_root(+Leaves, -Root)               the anchor's accumulator
%%   merkle_path(+Leaves, +I, -Path)
%%   merkle_verify(+Leaf, +I, +Path, +Root)
%%   checkpoint_leaf(+Chain, +Height, +Hash, -Leaf)
%%
%%   proof_signable(+Chain, +Height, +Hash, -Text)
%%   bridge_ready(+Bridge, +Proof, +Verify)    thaw, or do not
%%
%% A CHAIN IS A KNOWLEDGE BASE, so one node hosts many of them the way
%% one server hosts many databases: `--kb zeta', `--kb omega'. Nothing
%% about that is new. What is new is that the chains do not have to agree
%% about anything -- not their consensus, not their block shape, not
%% their idea of what makes a head better -- because each one PUBLISHES
%% ITS OWN RULES AS ENTRIES ON ITSELF.
%%
%% THE CHAIN CARRIES ITS OWN LIGHT CLIENT. To verify a foreign chain a
%% node reads the rules off that chain, admits them, and calls them. It
%% does not need to have been compiled with knowledge of that chain, and
%% two chains under entirely different regimes are verified by the same
%% host with the same code -- because the difference between them is
%% DATA.
%%
%% AND FOREIGN RULES ARE UNTRUSTED CODE, which is a problem rung 3
%% already solved. `rules_admit/3' is `contract_admit/3' -- the same
%% fence, the same vocabulary, the same three outright refusals -- with
%% one rule added, below. A chain that publishes a "validity rule" which
%% reads NODE_KEY is refused by the machinery that refuses a contract for
%% doing it, and nothing here had to be written twice.

:- use_module(library(contract)).
:- use_module(library(sha256)).
:- use_module(library(lists)).

%% ---- rules as a payload ----------------------------------------------

rules_payload(Chain, Clauses, Payload) :-
    term_to_atom(rules(Chain, Clauses), Payload).

%% What comes back is a VARIANT, not the identical term: a payload is
%% text, and a clause's variables are local to the clause, so reading it
%% makes fresh ones. That is right rather than a defect -- two nodes
%% reading the same payload get clauses that mean the same thing, which
%% is the only sense in which rules can be "the same" across processes.
%% The suite checks the round trip by INSTALLING what comes back and
%% asking it about a real signed block, because a term comparison would
%% have been testing the writer.
rules_of_payload(Payload, Chain, Clauses) :-
    catch(term_to_atom(T, Payload), _, fail),
    nonvar(T),
    T = rules(Chain, Clauses).

%% ---- the fence, plus one rule ----------------------------------------
%%
%% THE NAMESPACE RULE. Every predicate a chain defines must be named for
%% that chain: `zeta' may define `zeta_valid/1' and nothing else.
%%
%% Without it the aggregator has a hole the contract fence never had to
%% think about, because a contract is alone in its own state and a chain
%% is not: two chains would both define `valid/1', and whichever was
%% installed second would answer for both. Worse, a hostile chain could
%% define `zeta_valid/1' on purpose and become the authority on somebody
%% else's chain -- which is `attack_namespace_squat', and it is refused
%% here rather than noticed later.
%%
%% The fence is UNCHANGED. Its vocabulary already carries exactly what a
%% validity rule needs -- sha256, keccak256, secp256k1_verify,
%% ed25519_verify, block_hash/5, valid_block/6, in_turn/2, the list and
%% atom builtins -- and already refuses exactly what a validity rule must
%% not have: assertz, getenv, files, the clock, call/1, =.. and a
%% variable in goal position. That it fits without alteration is not a
%% coincidence; a validity rule and a contract are the same KIND of
%% thing, which is a function of the chain.
rules_admit(Chain, Clauses, Verdict) :-
    (   contract_admit(Chain, Clauses, admitted),
        forall(member(C, Clauses),
               ( rules_head(C, H), rules_scoped(Chain, H) ))
    ->  Verdict = admitted
    ;   Verdict = refused
    ).

rules_head((H :- _), H) :- !.
rules_head(H, H).

rules_scoped(Chain, Head) :-
    nonvar(Head),
    functor(Head, Name, _),
    atom_concat(Chain, '_', Prefix),
    atom_concat(Prefix, _, Name).

%% ---- the anchor chain's accumulator ----------------------------------
%%
%% A binary Merkle tree over the member heads, so the anchor chain can
%% carry ONE hash for the whole federation and still answer "was chain
%% zeta at this height when the checkpoint was taken" with a proof
%% logarithmic in the number of members.
%%
%% A fold would have been shorter and would have given the same root.
%% What it would not give is an INCLUSION PROOF: with a fold, showing a
%% member's head is in the root means handing over every other member's
%% head, and a checkpoint that can only be verified by replaying the
%% whole federation is a checkpoint nobody will verify.
%%
%% An odd level PROMOTES its last leaf rather than duplicating it. The
%% duplicate is the classic Bitcoin flaw -- two different leaf lists that
%% hash to one root -- and it costs nothing to not have.
merkle_root([L], L) :- !.
merkle_root(Leaves, Root) :-
    Leaves = [_, _|_],
    pair_up(Leaves, Next),
    merkle_root(Next, Root).

pair_up([], []).
pair_up([X], [X]) :- !.
pair_up([A, B|T], [P|R]) :-
    node_hash(A, B, P),
    pair_up(T, R).

node_hash(A, B, H) :-
    atomic_list_concat([A, B], '|', Text),
    sha256(Text, H).

%% The sibling hashes from a leaf up to the root, each tagged with the
%% side it sits on -- `l(H)' when the sibling is on the left. Without the
%% side, a verifier cannot know which order to hash in, and two different
%% trees would verify against one root.
merkle_path([_], _, []) :- !.
merkle_path(Leaves, I, Path) :-
    Leaves = [_, _|_],
    length(Leaves, N),
    (   I >= N - 1, 1 is N mod 2
    ->  Step = [],  J is I // 2          % promoted: no sibling at this level
    ;   0 is I mod 2
    ->  K is I + 1, nth0(K, Leaves, S), Step = [r(S)], J is I // 2
    ;   K is I - 1, nth0(K, Leaves, S), Step = [l(S)], J is I // 2
    ),
    pair_up(Leaves, Next),
    merkle_path(Next, J, Rest),
    append(Step, Rest, Path).

merkle_verify(Leaf, _, [], Root) :- !, Leaf == Root.
merkle_verify(Leaf, I, [S|T], Root) :-
    (   S = l(H) -> node_hash(H, Leaf, Up)
    ;   S = r(H) -> node_hash(Leaf, H, Up)
    ),
    J is I // 2,
    merkle_verify(Up, J, T, Root).

%% A member's head, as a leaf. The CHAIN NAME is in the leaf, so a
%% checkpoint for zeta at height 4 cannot be presented as a checkpoint
%% for omega at height 4 -- the same discipline as `block_signable/5' and
%% `vote_signable/5', for the same reason.
checkpoint_leaf(Chain, Height, Hash, Leaf) :-
    atomic_list_concat([cp, Chain, Height, Hash], '|', Text),
    sha256(Text, Leaf).

%% ---- the bridge ------------------------------------------------------
%%
%% A bridge is an escrow that thaws when, and only when, a block on
%% another chain is FINAL. What "final" means is that chain's own
%% business -- rung 6's certificate on one, a depth rule on another --
%% so the proof is checked by a goal the CALLER supplies, and this
%% predicate's job is everything around it:
%%
%%   1. the proof is about the chain the bridge names. A perfectly good
%%      finality proof for the wrong chain is `attack_wrong_chain', and
%%      it is the shape of a real bridge hack rather than a hypothetical.
%%   2. the proof is about the height and block the bridge names.
%%   3. and only then is the chain's own verifier run.
%%
%% `Verify' is a goal, and this library is not fenced -- calling it here
%% is the same seam `contract_call/2' is, in the same place: one library
%% predicate whose entire job is to be the door.
bridge_ready(bridge(_Id, Chain, Height, Hash), proof(PChain, PHeight, PHash, _Cert), _Verify) :-
    ( PChain \== Chain ; PHeight \== Height ; PHash \== Hash ),
    !,
    fail.
bridge_ready(bridge(_Id, _Chain, _Height, _Hash), Proof, Verify) :-
    call(Verify, Proof).

%% What a finality proof commits to, when a chain wants to sign one
%% rather than carry a certificate.
proof_signable(Chain, Height, Hash, Text) :-
    atomic_list_concat([final, Chain, Height, Hash], '|', Text).
