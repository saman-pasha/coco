%% A game's units as NFTs on the COCO ledger -- and the caller without
%% which a contract owns nothing.
%%
%% WHAT THIS RUNG FOUND, and it is the more interesting half: NO CONTRACT
%% IN THIS REPOSITORY COULD OWN ANYTHING. Every ownership predicate took
%% its owner as an ARGUMENT, which is safe only while the node is the
%% only caller -- and that stopped being true the moment a transaction
%% could reach a contract. `caller/1' is the fix, it is in the fence's
%% vocabulary, and the ONLY thing that supplies it is `coco_apply/5', out
%% of the signature it verified over the whole transaction.
%%
%% SO THE FIRST THREE CHECKS ARE THE RUNG. A direct call reports `nobody'
%% and an owning action refuses it; through a transaction the caller IS
%% the sender; and a contract that tries to set its own caller does not
%% pass the fence.
%%
%% A GAME'S RULES ARE NOT A TOKEN'S. This collection deliberately breaks
%% ERC-721 where a game must: production MINTS without asking anyone,
%% CAPTURE transfers without the holder's consent, and a KILL burns
%% forever -- a burnt id is never reissued, and the dead cannot be
%% captured or killed twice. What stays is the part that makes it a
%% token: one holder per id, and every move is somebody's.
%%
%% AND AN ATTEMPT STILL PAYS. A stranger's mint fails and is charged for
%% the attempt, because gas is the engine's inference count and the
%% inferences happened. That is the line between "refused" and "free".
%%
%% SKIPs without a server for the chain half, where a unit's whole life
%% is read back out of the blocks by a process that consulted nothing.
%%
%% Run:  cocolog -s test/units.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

units_program :-
    use_module(library(poa)), use_module(library(contract)), use_module(library(coco)),
    use_module('ledger/federation.pl'), use_module('ledger/node.pl'),
    use_module('ledger/gas.pl'), use_module('contracts/sources.pl'),
    use_module('contracts/token/units.pl'), use_module('contracts/node.pl').

units_files(['ledger/federation.pl', 'ledger/node.pl', 'ledger/gas.pl',
             'contracts/sources.pl', 'contracts/token/units.pl',
             'contracts/node.pl']).

ref_key('5555555555555555555555555555555555555555555555555555555555555555').
str_key('6666666666666666666666666666666666666666666666666666666666666666').
one('1000000000000000000').

%% THE FOUR PARTIES, as addresses rather than names: the referee and the
%% stranger are keys that sign, and the two authority accounts are where
%% a fee goes and where a unit is held.
who(R, ST, AU, PB) :-
    ref_key(RK), str_key(SK),
    secp256k1_pubkey(RK, RP), eth_address(RP, R),
    secp256k1_pubkey(SK, SP), eth_address(SP, ST),
    coco_authority_account(alice, AU), coco_authority_account(bob, PB).

pubs(RP, SP) :-
    ref_key(RK), str_key(SK),
    secp256k1_pubkey(RK, RP), secp256k1_pubkey(SK, SP).

%% funded, and the collection installed
world(R, ST, AU, PB) :-
    who(R, ST, AU, PB), one(ONE),
    coco_genesis([R-ONE, ST-ONE]),
    contract_source(units, Cs), contract_install(units, Cs).

%% ONE TRANSACTION, SIGNED AND APPLIED. The .sh built these with a shell
%% function that pasted generated VARIABLE NAMES -- T0, S0, O0 -- into
%% the goal text, because shell has no other way to keep two transactions
%% apart. Here they are just arguments.
tx(Key, Pub, Nonce, Action, AU, Outcome, Fee) :-
    T = tx(Pub, Nonce, Action, 200000),
    coco_tx_seal(Key, T, S),
    coco_apply(T, S, AU, Nonce, receipt(_, Outcome, _, Fee)).

ref(N, Action, AU, O) :- ref_key(K), pubs(RP, _), tx(K, RP, N, Action, AU, O, _).
str(N, Action, AU, O) :- str_key(K), pubs(_, SP), tx(K, SP, N, Action, AU, O, _).
str(N, Action, AU, O, F) :- str_key(K), pubs(_, SP), tx(K, SP, N, Action, AU, O, F).

main :- units_program, checks.

checks :-
    section('the caller, without which a contract owns nothing'),
    iso('a direct call is nobody, and an owning action refuses it',
        ( world(_, _, _, _),
          refuses(contract_call(units, unit_open_match(m1))) )),
    iso('through a transaction the caller IS the sender',
        ( world(R, _, AU, _),
          ref(0, call(units, unit_open_match(m1)), AU, O),
          contract_enter(units), unit_referee(m1, Rf),
          want(O-Rf, ok-R) )),
    iso('a contract that tries to set its own caller is refused',
        ( contract_admit(sneak, [(go :- contract_enter(units, me))], V),
          want(V, refused) )),
    iso('a match has one referee: the second to ask is refused',
        ( world(R, _, AU, _),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          str(0, call(units, unit_open_match(m1)), AU, XO),
          contract_enter(units), unit_referee(m1, Rf),
          want(XO-Rf, failed-R) )),

    section("production is the referee's, and an attempt still pays"),
    iso('the referee mints, and the unit is what it was minted as',
        ( world(_, _, AU, PB),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          ref(1, call(units, unit_mint(u1, 'Warrior', m1, PB)), AU, O),
          contract_enter(units),
          unit_holder(u1, H), unit_kind(u1, Kd), unit_home(u1, Hm),
          want(O-H-Kd-Hm, ok-PB-'Warrior'-m1) )),
    iso("a stranger's mint fails -- and is charged for the attempt",
        ( world(_, ST, AU, _),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          str(0, call(units, unit_mint(u9, 'Warrior', m1, ST)), AU, XO, XF),
          contract_enter(units),
          want(XO, failed), refuses(unit_alive(u9)),
          u256_cmp(XF, '0', C), want(C, >) )),
    iso('one id, once: the second mint of u1 changes nothing',
        ( world(R, _, AU, PB),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          ref(1, call(units, unit_mint(u1, 'Warrior', m1, PB)), AU, _),
          ref(2, call(units, unit_mint(u1, 'Settler', m1, R)), AU, O2),
          contract_enter(units), unit_holder(u1, H), unit_kind(u1, Kd),
          want(O2-H-Kd, failed-PB-'Warrior') )),

    section('capture is taken, a gift is given, and a kill is forever'),
    iso('the referee captures it: the holder did not agree and it moved',
        ( world(R, _, AU, PB),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          ref(1, call(units, unit_mint(u1, 'Warrior', m1, PB)), AU, _),
          ref(2, call(units, unit_capture(u1, R)), AU, O2),
          contract_enter(units), unit_holder(u1, H),
          want(O2-H, ok-R) )),
    iso('a stranger cannot capture it',
        ( world(_, ST, AU, PB),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          ref(1, call(units, unit_mint(u1, 'Warrior', m1, PB)), AU, _),
          str(0, call(units, unit_capture(u1, ST)), AU, XO),
          contract_enter(units), unit_holder(u1, H),
          want(XO-H, failed-PB) )),
    iso('and neither can the referee of another match',
        ( world(_, ST, AU, PB),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          ref(1, call(units, unit_mint(u1, 'Warrior', m1, PB)), AU, _),
          str(0, call(units, unit_open_match(m2)), AU, _),
          str(1, call(units, unit_capture(u1, ST)), AU, XO1),
          contract_enter(units), unit_holder(u1, H),
          want(XO1-H, failed-PB) )),
    iso('the holder may give it away; a non-holder may not',
        ( world(R, ST, AU, _),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          ref(1, call(units, unit_mint(u1, 'Warrior', m1, ST)), AU, _),
          str(0, call(units, unit_give(u1, R)), AU, XO0),
          str(1, call(units, unit_give(u1, ST)), AU, XO1),
          contract_enter(units), unit_holder(u1, H),
          want(XO0-XO1-H, ok-failed-R) )),
    iso('a kill burns it: not alive, and dead is a fact',
        ( world(_, _, AU, PB),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          ref(1, call(units, unit_mint(u1, 'Warrior', m1, PB)), AU, _),
          ref(2, call(units, unit_kill(u1)), AU, O2),
          contract_enter(units),
          want(O2, ok), refuses(unit_alive(u1)), unit_dead(u1) )),
    iso('the dead do not move, and cannot die twice',
        ( world(R, _, AU, PB),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          ref(1, call(units, unit_mint(u1, 'Warrior', m1, PB)), AU, _),
          ref(2, call(units, unit_kill(u1)), AU, _),
          ref(3, call(units, unit_capture(u1, R)), AU, O3),
          ref(4, call(units, unit_kill(u1)), AU, O4),
          want(O3-O4, failed-failed) )),
    iso('and a burnt id is never reissued',
        ( world(R, _, AU, PB),
          ref(0, call(units, unit_open_match(m1)), AU, _),
          ref(1, call(units, unit_mint(u1, 'Warrior', m1, PB)), AU, _),
          ref(2, call(units, unit_kill(u1)), AU, _),
          ref(3, call(units, unit_mint(u1, 'Archer', m1, R)), AU, O3),
          contract_enter(units), unit_kind(u1, Kd),
          want(O3, failed), refuses(unit_alive(u1)), want(Kd, 'Warrior') )),

    (   server_up
    ->  chain_half
    ;   nl, skip('no Zigurat server (the chain half)')
    ),
    nl, checks_done.

%% ---- the chain half --------------------------------------------------
%%
%% A UNIT'S WHOLE LIFE, read back out of the blocks by a process that
%% consulted nothing. That is the claim, and it is why this half spawns.
chain_half :-
    KB = coco_units_test,
    wire_forget(KB),
    units_files(Fs),
    forall(member(F, Fs), wire_consult(KB, F)),

    section('the collection arrives as a block, and a unit lives on the chain'),
    one(ONE),
    node(KB, ['who(R, ST, _, _), coco_seal_genesis([R-''', ONE, ''', ST-''', ONE, '''])']),
    node(KB, 'deploy(units)'),
    node(KB, 'install_from_chain, coco_settle_chain'),
    iso('the units contract is installed off the chain that carried it',
        ( bare_answer(coco_units_test,
              '( contract_clause(units, _) -> W = installed ; W = ''ABSENT'' ), write(answer(W)), nl',
              A), want(A, 'answer(installed)') )),

    submit(KB, ref, 0, 'call(units, unit_open_match(m1))'),
    submit(KB, ref, 1, 'call(units, unit_mint(u1, ''Warrior'', m1, PB))'),
    %% refused: not the referee -- and it is still a block
    submit(KB, str, 0, 'call(units, unit_mint(u2, ''Archer'', m1, ST))'),
    submit(KB, ref, 2, 'call(units, unit_capture(u1, R))'),
    submit(KB, ref, 3, 'call(units, unit_kill(u1))'),
    node(KB, 'coco_settle_chain'),

    iso('a bare process finds the unit lived and died',
        ( bare_answer(coco_units_test,
              ['contract_enter(units), unit_kind(u1, Kd), unit_home(u1, Hm), ',
               '( unit_dead(u1) -> D = dead ; D = ''ALIVE'' ), write(answer(Kd-Hm-D)), nl'],
              A), want(A, 'answer(Warrior-m1-dead)') )),
    iso('and reads its whole life out of the chain, in order',
        ( bare_answer(coco_units_test,
              ['coco_unit_history(u1, Es), findall(G, member(event(_, _, G), Es), Gs), ',
               'length(Gs, N), findall(F, ( member(Gg, Gs), functor(Gg, F, _) ), Fs), ',
               'write(answer(N-Fs)), nl'],
              A), want(A, 'answer(3-[unit_mint,unit_capture,unit_kill])') )),
    iso('the refused mint is in the blocks and not in a history',
        ( bare_answer(coco_units_test,
              ['coco_unit_history(u2, Es), length(Es, N), ',
               'findall(1, ( block(_, _, _, P, _, _), coco_payload(P, T), ',
               'T = coco_send(tx(_,_,call(units,unit_mint(u2,_,_,_)),_), _) ), Bs), ',
               'length(Bs, B), write(answer(N-B)), nl'],
              A), want(A, 'answer(0-1)') )),
    iso('every transaction is on the record, refusals included',
        ( bare_answer(coco_units_test,
              ['findall(O, coco_receipt(_, receipt(_, O, _, _)), Os), msort(Os, S), ',
               'write(answer(S)), nl'],
              A), want(A, 'answer([failed,ok,ok,ok,ok,ok])') )).

%% THE SPAWNED PROCESS LOADS THIS FILE, not just the prelude: `who/4'
%% and `pubs/2' -- the four parties, as addresses -- are defined here, and
%% a goal that names them in another process needs them there. Loading a
%% case as a MODULE is safe: `main/0' comes with it and nothing calls it.
units_prefix('use_module(library(poa)), use_module(library(contract)), use_module(library(coco)), use_module(''test/units.pl''), ').

units_goal(G0, G) :-
    units_prefix(P),
    ( is_list(G0) -> sh_join(G0, G1) ; G1 = G0 ),
    sh_join([P, G1], G).

node(KB, G0) :-
    units_goal(G0, G),
    ( wire_as(alice, KB, G, '.', _) -> true ; true ).

%% a bare process -- nobody's identity, nothing consulted
bare_answer(KB, G0, A) :-
    units_goal(G0, G),
    ( wire(KB, G, '^answer\\(.*\\)$', A0) -> A = A0 ; A = none ).

submit(KB, Who, Nonce, Action) :-
    ( Who == ref -> ref_key(K), Pub = 'RP' ; str_key(K), Pub = 'SP' ),
    units_goal(['who(R, ST, _, PB), pubs(RP, SP), T = tx(', Pub, ', ', Nonce, ', ',
                Action, ', 200000), coco_tx_seal(''', K, ''', T, S), coco_submit(T, S)'], G),
    ( wire_as(alice, KB, G, '.', _) -> true ; true ).
