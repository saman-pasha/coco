%% mallory against an aggregator.
%%
%% A hub that verifies foreign chains is the richest target on the ladder,
%% because it RUNS CODE IT DID NOT WRITE. Every earlier rung could refuse
%% a stranger; this one has to read a stranger's rules and then do what
%% they say.
%%
%%   attack_rules_read_key(-V)   publish rules that read NODE_KEY
%%   attack_rules_assert(-V)     rules that write onto the host
%%   attack_rules_call(-V)       rules that build a goal at run time
%%   attack_namespace_squat(-V)  publish rules for somebody else's chain
%%   attack_rules_swap(-V)       new rules, applied to old blocks
%%   attack_wrong_chain(-V)      a real finality proof, the wrong bridge
%%   attack_anchor_swap(-V)      move a head after the checkpoint
%%   attack_captured_chain(-V)   own the chain -- SUCCEEDS
%%
%% The last one succeeds and is the most important line in this rung.

:- use_module(library(hub)).
:- use_module(library(contract)).
:- use_module(library(poa)).
:- use_module(library(sha256)).
:- use_module(library(secp256k1)).
:- use_module(library(lists)).

mallory_key('4444444444444444444444444444444444444444444444444444444444444444').

verdict(G, refused) :- \+ call(G), !.
verdict(_, 'ACCEPTED').

%% 1. RULES THAT READ THE HOST'S KEY. A validity rule is a function of
%% the chain; a node's signing key is not on any chain. `getenv' is not
%% in the vocabulary, and it is not in the vocabulary for exactly this
%% reason -- the same reason `thief' was refused in rung 3, answered by
%% the same clauses.
attack_rules_read_key(V) :-
    Cs = [ ( psi_valid(_B) :- getenv('NODE_KEY', _K) ) ],
    verdict(rules_admit(psi, Cs, admitted), V).

%% 2. RULES THAT WRITE. A light client that installs a foreign chain's
%% rules and then lets them assert onto the host is not a light client,
%% it is a remote code execution with extra steps.
attack_rules_assert(V) :-
    Cs = [ ( psi_valid(B) :- assertz(member_head(zeta, 99, B)) ) ],
    verdict(rules_admit(psi, Cs, admitted), V).

%% 3. RULES THAT BUILD A GOAL. `call/1' is refused outright rather than
%% whitelisted, because a static check cannot see what `call(X)' will
%% call. `=../2' is the other way in and is refused too.
attack_rules_call(V) :-
    Cs = [ ( psi_valid(B) :- call(B) ) ],
    verdict(rules_admit(psi, Cs, admitted), V).

%% 4. SQUAT ANOTHER CHAIN'S NAMESPACE. This is the attack the contract
%% fence never had to think about: a contract is alone in its own state,
%% and a chain is not. mallory publishes rules that define `zeta_valid/1'
%% -- perfectly well behaved, entirely inside the vocabulary -- and if
%% they installed she would be the authority on zeta.
attack_namespace_squat(V) :-
    Cs = [ zeta_valid(_) ],
    verdict(rules_admit(psi, Cs, admitted), V).

%% 5. SWAP THE RULES UNDER OLD BLOCKS. A chain may change its rules;
%% every chain may. What it may not do is change what its OLD blocks
%% meant. Here the strict rules are on the chain at height 1 and a
%% permissive `zeta_valid(_)' arrives at height 9, and the question is
%% which one judges the block at height 4.
%%
%% She wants the permissive one. `rules_at/3' pins to the height being
%% judged, so she gets the strict one.
attack_rules_swap(V) :-
    Strict = [ ( zeta_valid(block(H,P,A,Pay,S,X)) :-
                   block_hash(H,P,A,Pay,X), zeta_authority(A,K),
                   secp256k1_verify(X,S,K) ),
               zeta_authority(alice, 'ff') ],
    Loose  = [ zeta_valid(_) ],
    rules_payload(zeta, Strict, P1),
    rules_payload(zeta, Loose,  P9),
    assertz(block(1, p0, alice, P1, s, h1)),
    assertz(block(9, p8, alice, P9, s, h9)),
    verdict(( rules_at(zeta, 4, Cs), memberchk(zeta_valid(_), Cs) ), V).

%% 6. A REAL PROOF, THE WRONG BRIDGE. Nothing is forged: the finality
%% proof for zeta is genuine and would verify. It is presented to a
%% bridge that names omega.
%%
%% The verifier here always succeeds, on purpose -- so that what refuses
%% this is the chain-and-height guard and not something else. A test that
%% could pass for two reasons has tested neither.
attack_wrong_chain(V) :-
    Bridge = bridge(b1, omega, 12, 'aaaa'),
    Proof  = proof(zeta, 12, 'aaaa', cert),
    verdict(bridge_ready(Bridge, Proof, verify_always), V).

%% 7. MOVE A HEAD AFTER THE CHECKPOINT. The anchor chain carries one hash
%% for the whole federation. She takes a genuine inclusion proof for
%% zeta at height 4 and re-presents it for zeta at height 40.
attack_anchor_swap(V) :-
    checkpoint_leaf(zeta,  4, 'aaaa', L1),
    checkpoint_leaf(omega, 7, 'bbbb', L2),
    checkpoint_leaf(psi,   2, 'cccc', L3),
    Leaves = [L1, L2, L3],
    merkle_root(Leaves, Root),
    merkle_path(Leaves, 0, Path),
    checkpoint_leaf(zeta, 40, 'aaaa', Moved),
    verdict(merkle_verify(Moved, 0, Path, Root), V).

%% 8. OWN THE CHAIN -- AND THIS ONE WORKS.
%%
%% psi's published rules are impeccable. They pass the fence, they are
%% correctly namespaced, the signature check is real, and the finality
%% threshold is the same two-thirds rung 6 uses. The host reads them,
%% admits them, installs them and runs them exactly as it runs zeta's.
%%
%% And every validator on psi is mallory. So a block she signed is a
%% valid block, a head she alone voted for carries all of psi's stake,
%% psi's own `psi_final/2' says it is final, and the bridge thaws.
%%
%% NOTHING WENT WRONG HERE. The host verified correctly, under the
%% correct rules, and reached the correct answer to the question it was
%% asked -- which was "is this final ON PSI", not "is psi honest". An
%% aggregator cannot be stronger than the chains it aggregates, and every
%% bridge that has ever been drained was drained through this door rather
%% than through a broken signature check. Saying so here is worth more
%% than one more refusal.
attack_captured_chain(V) :-
    chain_source(psi, Cs),
    rules_admit(psi, Cs, admitted),
    contract_install(psi, Cs),
    mallory_key(K),
    block_hash(3, 'p2', mallory, 'her payload', Hash),
    secp256k1_sign(K, Hash, Sig),
    Block = block(3, 'p2', mallory, 'her payload', Sig, Hash),
    verdict(( psi_valid(Block),
              chain_total(psi, T),
              psi_final(head(3, Hash, T), T) ), V).

%% For the choreography: how the host describes what it just accepted.
captured_report :-
    chain_source(psi, Cs),
    rules_admit(psi, Cs, Verdict),
    format("psi rules ~w, namespaced, fenced; every psi validator is mallory~n",
           [Verdict]).
