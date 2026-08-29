%% Rung 7: many chains, one node, none of them known in advance.
%%
%% THE HOST RUNS CODE IT DID NOT WRITE, which is the whole rung and the
%% whole danger. A foreign chain PUBLISHES its own validity rule as
%% clauses in a block, and the host installs and runs it to judge that
%% chain's blocks. Everything below is about making that safe:
%%
%%   THE RULES GO THROUGH THE CONTRACT FENCE. The same vocabulary that
%%   admits a contract admits a validity rule, and the last eight checks
%%   are mallory publishing rules that read the host's signing key, write
%%   onto the host, or build a goal at run time. Refused, by the fence
%%   that was already there.
%%
%%   A CHAIN MAY ONLY NAME ITS OWN PREDICATES. `rules_scoped/2' is the
%%   one rule the contract fence never needed: zeta may define
%%   `zeta_valid/1' and may not define `omega_valid/1' or a bare
%%   `valid/1'. Without it, publishing rules is a way to take over
%%   somebody else's chain.
%%
%%   AND NEW RULES DO NOT REACH BACK. A block at height 4 is judged by
%%   the rules that were published at height 1, not by whatever is
%%   current -- otherwise a chain could rewrite its own history by
%%   publishing a rule that approves of it.
%%
%% ONE ATTACK SUCCEEDS AND MUST. If a chain's own authorities are all
%% mallory's, her blocks are valid ON THAT CHAIN and nothing the host can
%% check says otherwise -- the host is judging by the chain's rules, and
%% the chain is hers. A suite where every attack fails has not found the
%% boundary.
%%
%% Run:  cocolog -s test/hub.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

hub_program :-
    use_module(library(hub)), use_module(library(contract)),
    use_module('hub/chains.pl'), use_module('ledger/node.pl'),
    use_module('hub/node.pl'), use_module('hub/mallory.pl').

%% zeta's rules, admitted and installed, and a block alice really signed
sealed(S, H) :-
    chain_source(zeta, Cs), rules_admit(zeta, Cs, admitted),
    contract_install(zeta, Cs),
    block_hash(1, 'p0', alice, 'a payload', H),
    node_key(alice, K), secp256k1_sign(K, H, S).

%% two chains that disagree about what a better head is
both(Heads) :-
    chain_source(zeta, CZ), rules_admit(zeta, CZ, admitted), contract_install(zeta, CZ),
    chain_source(omega, CO), rules_admit(omega, CO, admitted), contract_install(omega, CO),
    Heads = [head(9, aaa, 10), head(4, bbb, 90)].

%% rules published at height 1 and again at height 9
pinned :- rules_payload(zeta, [zeta_a(1)], P1),
          rules_payload(zeta, [zeta_b(2)], P9),
          assertz(block(1, p0, alice, P1, s, h1)),
          assertz(block(9, p8, alice, P9, s, h9)).

%% a four-member federation, and its root
leaves(Ls, Root) :-
    checkpoint_leaf(zeta, 4, aaaa, L1), checkpoint_leaf(omega, 7, bbbb, L2),
    checkpoint_leaf(psi, 2, cccc, L3), checkpoint_leaf(tau, 5, dddd, L4),
    Ls = [L1, L2, L3, L4], merkle_root(Ls, Root).

imported :- import(zeta, trained(d1, alice, 0.99)),
            import(omega, paid(d1, carol, 100)),
            import(psi, unrelated(d2, mallory, 7)).

main :- hub_program, checks.

checks :-
    section('a chain publishes its own rules, and they survive a round trip'),
    iso('the chain name survives the round trip',
        ( chain_source(zeta, Cs), rules_payload(zeta, Cs, P),
          rules_of_payload(P, Ch, _), want(Ch, zeta) )),
    iso('so does every clause',
        ( chain_source(zeta, Cs), rules_payload(zeta, Cs, P),
          rules_of_payload(P, _, Cs2), length(Cs, A), length(Cs2, B),
          want(A-B, 6-6) )),
    iso('and the rules still work when installed FROM the payload',
        ( chain_source(zeta, Cs), rules_payload(zeta, Cs, P),
          rules_of_payload(P, _, Cs2), rules_admit(zeta, Cs2, admitted),
          contract_install(zeta, Cs2),
          block_hash(1, 'p0', alice, 'a payload', H),
          node_key(alice, K), secp256k1_sign(K, H, S),
          verify_foreign(zeta, block(1, 'p0', alice, 'a payload', S, H)) )),
    iso('a payload that is not rules is not mistaken for some',
        ( refuses(rules_of_payload('just a payload', _, _)) )),

    section('the same fence contracts run under'),
    forall(member(Ch, [zeta, omega, psi]), fence_check(Ch)),
    iso('the vocabulary a validity rule needs is already in it',
        ( allowed(block_hash/5), allowed(secp256k1_verify/3), allowed(sha256/2) )),
    iso('and what it must not have is already out',
        ( refuses(allowed(getenv/2)), refuses(allowed(assertz/1)),
          refuses(allowed(call/1)) )),

    section('one rule the contract fence never needed'),
    iso('a chain may name its own predicates',
        ( rules_scoped(zeta, zeta_valid(_)) )),
    iso("and may not name somebody else's",
        ( refuses(rules_scoped(zeta, omega_valid(_))) )),
    iso("a bare name is not in any chain's namespace",
        ( refuses(rules_scoped(zeta, valid(_))) )),

    section("the host judges a foreign block by the foreign chain's rule"),
    iso('a block alice really signed is valid on zeta',
        ( sealed(S, H), verify_foreign(zeta, block(1, 'p0', alice, 'a payload', S, H)) )),
    iso('the same block with the payload changed is not',
        ( sealed(S, H),
          refuses(verify_foreign(zeta, block(1, 'p0', alice, 'another payload', S, H))) )),
    iso("and a block from someone not on zeta's roster is not",
        ( sealed(_, _), block_hash(1, 'p0', dave, 'a payload', H2),
          node_key(alice, K), secp256k1_sign(K, H2, S2),
          refuses(verify_foreign(zeta, block(1, 'p0', dave, 'a payload', S2, H2))) )),

    section('two chains that disagree about what a better head is'),
    iso('zeta takes the longest head',
        ( both(Hs), best_foreign(zeta, Hs, head(H, _, _)), want(H, 9) )),
    iso('omega takes the heaviest, from the same list',
        ( both(Hs), best_foreign(omega, Hs, head(H, _, _)), want(H, 4) )),
    iso('both rule sets are installed in the one process',
        ( both(_), clause(zeta_better(_, _), _), clause(omega_better(_, _), _) )),

    section('new rules do not reach back over old blocks'),
    iso('a block at height 4 is judged by the height-1 rules',
        ( pinned, rules_at(zeta, 4, Cs), want(Cs, [zeta_a(1)]) )),
    iso('a block at height 9 is judged by the height-9 rules',
        ( pinned, rules_at(zeta, 9, Cs), want(Cs, [zeta_b(2)]) )),
    iso('and the latest is what a new block gets',
        ( pinned, latest_rules(zeta, Cs), want(Cs, [zeta_b(2)]) )),

    section('one hash for the whole federation, with proofs'),
    iso('one member is a root of itself',
        ( checkpoint_leaf(zeta, 4, aaaa, L), merkle_root([L], R), want(R, L) )),
    iso('an inclusion proof verifies for every member',
        ( leaves(Ls, Root),
          forall(between(0, 3, I),
                 ( nth0(I, Ls, Lf), merkle_path(Ls, I, Pa),
                   merkle_verify(Lf, I, Pa, Root) )) )),
    iso('an odd federation proves too',
        ( checkpoint_leaf(zeta, 4, aaaa, A), checkpoint_leaf(omega, 7, bbbb, B),
          checkpoint_leaf(psi, 2, cccc, Cc), Ls = [A, B, Cc], merkle_root(Ls, R),
          forall(between(0, 2, I),
                 ( nth0(I, Ls, Lf), merkle_path(Ls, I, Pa),
                   merkle_verify(Lf, I, Pa, R) )) )),
    iso('moving any member changes the root',
        ( leaves([_, L2, L3, L4], Root), checkpoint_leaf(zeta, 40, aaaa, M),
          merkle_root([M, L2, L3, L4], R2),
          ( R2 \== Root -> true ; format("     the root did not move~n"), fail ) )),
    iso('a checkpoint names its chain, so it cannot be moved sideways',
        ( checkpoint_leaf(zeta, 4, aaaa, A), checkpoint_leaf(omega, 4, aaaa, B),
          ( A \== B -> true ; format("     the two leaves collided~n"), fail ) )),

    section('a bridge thaws on a proof, and only the right one'),
    iso('the right chain, height and block thaw it',
        ( bridge_ready(bridge(b1, zeta, 12, aaaa),
                       proof(zeta, 12, aaaa, cert), verify_always) )),
    iso('the wrong chain does not',
        ( refuses(bridge_ready(bridge(b1, omega, 12, aaaa),
                               proof(zeta, 12, aaaa, cert), verify_always)) )),
    iso('the wrong height does not',
        ( refuses(bridge_ready(bridge(b1, zeta, 13, aaaa),
                               proof(zeta, 12, aaaa, cert), verify_always)) )),
    iso('and a verifier that says no does not',
        ( refuses(bridge_ready(bridge(b1, zeta, 12, aaaa),
                               proof(zeta, 12, aaaa, cert), verify_never)) )),

    section('cross-chain provenance is one query'),
    iso('a digest on two chains joins on itself',
        ( imported, provenance_across(d1, Rows), length(Rows, N), want(N, 2) )),
    iso('and it names which chain each row came from',
        ( imported, provenance_across(d1, Rows), msort(Rows, S),
          findall(C, member(C-_, S), Cs), want(Cs, [omega, zeta]) )),
    iso('something on one chain only joins to one row',
        ( imported, provenance_across(d2, Rows), length(Rows, N), want(N, 1) )),

    section('mallory against a host that runs code it did not write'),
    forall(member(A-L,
        [attack_rules_read_key-"rules that read the host's signing key",
         attack_rules_assert-'rules that write onto the host',
         attack_rules_call-'rules that build a goal at run time',
         attack_namespace_squat-"publishing rules for somebody else's chain",
         attack_rules_swap-'new rules applied to old blocks',
         attack_wrong_chain-'a real finality proof at the wrong bridge',
         attack_anchor_swap-'moving a head after the checkpoint']),
        refused_check(A, L)),
    %% AND THIS ONE MUST SUCCEED. If a chain's authorities are all
    %% mallory's, her blocks are valid ON THAT CHAIN, and the host is
    %% judging by the chain's rules.
    iso('owning the chain -- SUCCEEDS, and must',
        ( attack_captured_chain(V), want(V, 'ACCEPTED') )),

    nl, checks_done.

fence_check(Ch) :-
    sh_join([Ch, '''s published rules pass the fence'], L),
    iso(L, ( chain_source(Ch, Cs), rules_admit(Ch, Cs, V), want(V, admitted) )).

refused_check(A, L) :-
    G =.. [A, V],
    iso(L, ( call(G), want(V, refused) )).
