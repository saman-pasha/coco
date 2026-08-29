%% THE STAKE IS THE COIN, and the evidence bites.
%%
%% Rung 6 built proof of stake and left one thing out, and said so: stake
%% was a NUMBER read off a block -- a block said alice weighs 40, so alice
%% weighed 40 -- and "nobody is SLASHED (the evidence is produced; burning
%% a bond is a policy question)". The evidence was real; there was simply
%% nothing to take. COCO is what there is to take, and this case is the
%% join.
%%
%% WHAT IT IS CHECKING, in four parts.
%%
%%   A WEIGHT IS MONEY THAT CAN BE LOST. `stake_entry/2' -- the table
%%   `library(pos)' asks for and refuses to own -- is now a RULE over
%%   bonded coin, so `stake_of/2', `total_stake/1', `quorum/2' and the
%%   leader draw all go on working with nothing changed, over numbers
%%   somebody actually put up. Weight is whole COCO because the safety
%%   arithmetic is integer arithmetic and money is u256; the consequence
%%   is checked rather than hidden -- a bond under one coin weighs
%%   nothing and is still slashable.
%%
%%   LEAVING IS SLOW, AND THAT IS THE POINT. An unbonding matures after
%%   `coco_unbonding_delay/1' BLOCKS -- the chain's height is the only
%%   clock here -- and the money is at risk the whole way. The check that
%%   matters is the attack: equivocate, unbond everything in the same
%%   breath, and the slash still lands.
%%
%%   WEIGHT FOLLOWS THE RISK, NOT THE REQUEST, and reading `library(bft)'
%%   is what found it. `valid_vote/1' opens with `has_stake(Who)', so a
%%   validator with no weight cannot cast a vote anybody will look at --
%%   which means that if weight dropped when a validator ASKED for its
%%   money back, unbonding would make the evidence against it unreadable
%%   while the money was still there. Weight is `coco_at_risk/2' for
%%   exactly that reason, and the case pins both halves.
%%
%%   AND A SLASH CANNOT BE FABRICATED. `culprits/3' intersects two lists
%%   of NAMES and takes no position on whether either certificate is
%%   real, so both are put through `qc_valid/1' before a name is read --
%%   every signature, every vote matching its certificate, a quorum
%%   behind each. Two made-up certificates rob nobody.
%%
%% THE MONEY IS WHY EVERY LOCAL CHECK IS AN ISOLATED PROOF. Twenty-one of
%% them fund a genesis and bond against it; without a fresh store per
%% check the second would inherit the first's balances, and a slash would
%% land on a bond some earlier check had already taken. The chain half
%% still spawns -- an unbonding matures against the CHAIN's height, which
%% is a claim about a knowledge base two processes share -- and SKIPs
%% without a Zigurat server.
%%
%% Run:  cocolog -s test/bond.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

bond_program :-
    use_module(library(poa)), use_module(library(coco)),
    use_module(library(pos)), use_module(library(bft)),
    use_module('ledger/federation.pl'), use_module('ledger/node.pl'),
    use_module('ledger/gas.pl'), use_module('votes/bond.pl').

bond_files(['ledger/federation.pl', 'ledger/node.pl', 'ledger/gas.pl',
            'votes/bond.pl']).

%% The federation's own keys: a validator bonds from the key it votes
%% with, which is the whole of "who does the work and who holds the bond
%% are one key". node_key/2 in the prelude has alice, bob and carol.
ann_key('5555555555555555555555555555555555555555555555555555555555555555').

c400(  '400000000000000000000').        %% 400 COCO
c300(  '300000000000000000000').
c100(  '100000000000000000000').
c50(    '50000000000000000000').
c5(      '5000000000000000000').        %% a tenth of fifty: the reporter's
c45(    '45000000000000000000').        %% and the nine tenths burnt
c10(    '10000000000000000000').        %% a tenth of a hundred
c90(    '90000000000000000000').
supply('1000000000000000000000').       %% 1000 COCO
fee(              '1200000000000').     %% (1000 + 200) * 10^9, one native move

%% The three validators, their accounts, and a reporter who is not one of
%% them -- all derived, none pasted.
whob(A, B, CA, N) :-
    coco_authority_account(alice, A),
    coco_authority_account(bob, B),
    coco_authority_account(carol, CA),
    ann_key(AK), secp256k1_pubkey(AK, NP), eth_address(NP, N).

fundb(A, B, CA) :-
    c400(F4), c300(F3), coco_genesis([A-F4, B-F3, CA-F3]).

bonds(A, B, CA) :-
    c100(H), c50(FF), coco_bond(A, H), coco_bond(B, FF), coco_bond(CA, FF).

%% funded and bonded, which is where most of this file starts
world(A, B, CA, N) :- whob(A, B, CA, N), fundb(A, B, CA), bonds(A, B, CA).

%% ---- part one: a weight is money that can be lost -----------------------

table_half :-
    section('the stake table, as a query over bonded coin'),
    iso('bonding moves the money out of the balance and into the bond',
        ( bond_program, whob(A, B, CA, _), fundb(A, B, CA),
          c400(F4), c100(H), coco_bond(A, H),
          coco_bond_of(A, Bd), coco_balance(A, Bal), u256_sub(F4, Bal, Gone),
          want(Bd-Gone, H-H) )),
    iso('and the weight is what it bonded, in whole COCO',
        ( bond_program, whob(A, B, CA, _), fundb(A, B, CA),
          c100(H), coco_bond(A, H), stake_of(alice, W), want(W, 100) )),
    iso('three validators: the table, the total and the quorum',
        ( bond_program, world(_, _, _, _),
          stake_table(P), total_stake(T), quorum(T, Q),
          want(P-T-Q, [alice-100, bob-50, carol-50]-200-134) )),
    %% The rounding, stated rather than hidden: the safety arithmetic is
    %% integer arithmetic and money is u256, so weight is whole coins.
    iso('a bond under one whole COCO weighs nothing, and is still at risk',
        ( bond_program, whob(A, B, CA, _), fundb(A, B, CA),
          coco_bond(A, '500000000000000000'),
          ( stake_of(alice, W) -> R = W ; R = no_weight ),
          coco_at_risk(A, Risk),
          want(R-Risk, no_weight-'500000000000000000') )),
    iso('conservation holds across every bond',
        ( bond_program, world(_, _, _, _), supply(S0),
          ( coco_conservation -> W = conserved ; W = 'BROKEN' ),
          coco_supply(S), want(W-S, conserved-S0) )).

%% ---- bonding as a transaction -------------------------------------------

tx_half :-
    section('bonding is a transaction, and it is refused like any other'),
    iso('a bond arrives as a signed transaction and pays its fee',
        ( bond_program, whob(A, B, CA, N), fundb(A, B, CA),
          node_key(alice, AK), secp256k1_pubkey(AK, AP),
          c100(H), fee(FE),
          Tx = tx(AP, 0, bond(H), 5000), coco_tx_seal(AK, Tx, Sig),
          coco_apply(Tx, Sig, N, 0, receipt(_, O, _, F)),
          coco_bond_of(A, Bd), want(O-Bd-F, ok-H-FE) )),
    iso('you cannot bond what you do not have',
        ( bond_program, whob(A, B, CA, N), fundb(A, B, CA),
          node_key(alice, AK), secp256k1_pubkey(AK, AP), c400(F4),
          Tx = tx(AP, 0, bond('900000000000000000000'), 5000),
          coco_tx_seal(AK, Tx, Sig),
          coco_apply(Tx, Sig, N, 0, receipt(_, O, _, _)),
          coco_balance(A, Bal), want(O-Bal, refused(funds)-F4) )),
    iso('and you cannot unbond more than you bonded',
        ( bond_program, whob(A, B, CA, N), fundb(A, B, CA),
          node_key(alice, AK), secp256k1_pubkey(AK, AP),
          c50(FF), c100(H), coco_bond(A, FF),
          Tx = tx(AP, 0, unbond(H), 5000), coco_tx_seal(AK, Tx, Sig),
          coco_apply(Tx, Sig, N, 0, receipt(_, O, _, _)),
          coco_bond_of(A, Bd), want(O-Bd, refused(funds)-FF) )).

%% ---- part two: leaving is slow ------------------------------------------

%% alice bonds a hundred and asks for all of it back at height 7
leaving(A) :-
    whob(A, B, CA, _), fundb(A, B, CA),
    c100(H), coco_bond(A, H), coco_unbond(A, H, 7).

slow_half :-
    section('leaving is slow, and the money is at risk the whole way'),
    iso('unbonding empties the bond without paying anybody yet',
        ( bond_program, leaving(A), c400(F4), c100(H),
          coco_bond_of(A, Bd), coco_unbonding_of(A, U), coco_balance(A, Bal),
          u256_sub(F4, Bal, Gone), want(Bd-U-Gone, '0'-H-H) )),
    %% THE ESCAPE HATCH THAT IS NOT ONE: weight follows the risk, so a
    %% validator on its way out still votes -- and is still slashable.
    iso('and the weight stays, because the money is still takeable',
        ( bond_program, leaving(_), stake_of(alice, W), want(W, 100) )),
    iso('the money does not come home one block early',
        ( bond_program, leaving(A), c400(F4), c100(H),
          coco_mature(9), coco_balance(A, Bal), coco_unbonding_of(A, U),
          u256_sub(F4, Bal, Gone), want(Gone-U, H-H) )),
    iso('and it does at the height the unbonding named',
        ( bond_program, leaving(A), c400(F4),
          coco_mature(10), coco_balance(A, Bal), coco_unbonding_of(A, U),
          ( stake_of(alice, W) -> R = W ; R = no_weight ),
          want(Bal-U-R, F4-'0'-no_weight) )).

%% ---- part three: the evidence bites -------------------------------------

%% The votes are REAL: `cast/6' signs with bob's own key and
%% `equivocation/3' verifies both signatures before it names anybody.
equivocated(Votes) :-
    node_key(bob, BK),
    cast(BK, prevote, 1, 0, aaaa, S1),
    cast(BK, prevote, 1, 0, bbbb, S2),
    Votes = [vote(prevote, 1, 0, aaaa, bob, S1),
             vote(prevote, 1, 0, bbbb, bob, S2)].

evidence_half :-
    section('two signed votes that cannot both be honest'),
    iso('bob equivocates: the bond is taken, a tenth paid, nine burnt',
        ( bond_program, world(_, _, _, N), equivocated(Votes),
          c50(FF), c5(F5), c45(F45),
          slash_for_equivocation(Votes, N, slashed(Who, Taken, Reward)),
          coco_balance(N, Paid), coco_burnt_total(Burnt),
          want(Who-Taken-Reward-Paid-Burnt, bob-FF-F5-F5-F45) )),
    iso('conservation is exact through a slash, burn and all',
        ( bond_program, world(_, _, _, N), equivocated(Votes), supply(S0),
          slash_for_equivocation(Votes, N, _),
          ( coco_conservation -> W = conserved ; W = 'BROKEN' ),
          coco_supply(S), want(W-S, conserved-S0) )),
    iso('the culprit drops out of the table, and the quorum falls with it',
        ( bond_program, world(_, _, _, N), equivocated(Votes),
          slash_for_equivocation(Votes, N, _),
          stake_table(P), total_stake(T), quorum(T, Q),
          want(P-T-Q, [alice-100, carol-50]-150-101) )),
    %% THE ATTACK THE DELAY EXISTS FOR: equivocate, ask for everything back
    %% in the same breath, and the evidence still lands on money that has
    %% not gone home yet.
    iso('unbonding first does not save the culprit',
        ( bond_program, world(_, B, _, N), c50(FF), c45(F45),
          coco_unbond(B, FF, 1), equivocated(Votes),
          slash_for_equivocation(Votes, N, slashed(_, Taken, _)),
          coco_at_risk(B, Risk), coco_burnt_total(Burnt),
          want(Taken-Risk-Burnt, FF-'0'-F45) )),
    iso('the same evidence cannot be reported twice',
        ( bond_program, world(_, B, _, N), equivocated(Votes), c50(FF),
          slash_for_equivocation(Votes, N, _),
          coco_bond(B, FF),
          ( slash_for_equivocation(Votes, N, _) -> W = 'PAID AGAIN' ; W = refused ),
          coco_bond_of(B, Bd), want(W-Bd, refused-FF) )),
    %% RUBBISH IS NOT EVIDENCE, AND NOT AN EMERGENCY EITHER. A signature
    %% that is not a signature makes `secp256k1_verify/3' RAISE, so a list
    %% with one piece of garbage in it would have ended the turn of
    %% whichever node was asked to look at it. Each vote is verified under
    %% a catch first.
    iso('a garbage vote beside a real one is dropped, not fatal',
        ( bond_program, world(_, B, _, N), c50(FF), node_key(bob, BK),
          cast(BK, prevote, 1, 0, aaaa, S1),
          Votes = [vote(prevote, 1, 0, aaaa, bob, S1),
                   vote(prevote, 1, 0, bbbb, bob, junk)],
          ( slash_for_equivocation(Votes, N, _) -> W = 'SLASHED' ; W = no_evidence ),
          coco_bond_of(B, Bd), want(W-Bd, no_evidence-FF) )),
    iso('two votes for the SAME block are not evidence of anything',
        ( bond_program, world(_, B, _, N), c50(FF), node_key(bob, BK),
          cast(BK, prevote, 1, 0, aaaa, S1),
          Votes = [vote(prevote, 1, 0, aaaa, bob, S1)],
          ( slash_for_equivocation(Votes, N, _) -> W = 'SLASHED' ; W = no_evidence ),
          coco_bond_of(B, Bd), want(W-Bd, no_evidence-FF) )).

%% alice signs both sides at height 1. Each certificate carries a quorum
%% (150 of 200, and the quorum is 134), so both are real -- and the
%% INTERSECTION is what names her.
certificates(Q1, Q2) :-
    node_key(alice, AK), node_key(bob, BK), node_key(carol, CK),
    cast(AK, precommit, 1, 0, aaaa, A1), cast(BK, precommit, 1, 0, aaaa, B1),
    cast(AK, precommit, 1, 0, bbbb, A2), cast(CK, precommit, 1, 0, bbbb, C2),
    Q1 = qc(precommit, 1, 0, aaaa, [vote(precommit, 1, 0, aaaa, alice, A1),
                                    vote(precommit, 1, 0, aaaa, bob, B1)]),
    Q2 = qc(precommit, 1, 0, bbbb, [vote(precommit, 1, 0, bbbb, alice, A2),
                                    vote(precommit, 1, 0, bbbb, carol, C2)]).

certificate_half :-
    section('two certificates at one height, and two that were made up'),
    iso('the validator in both certificates is named and slashed',
        ( bond_program, world(_, _, _, N), certificates(Q1, Q2),
          c100(H), c10(F10), c90(F90),
          slash_for_certificates(Q1, Q2, N, report(Names, Taken, Reward)),
          coco_burnt_total(Burnt),
          want(Names-Taken-Reward-Burnt, [alice]-H-F10-F90) )),
    %% `culprits/3' would have named her on two fabrications just as
    %% happily.
    iso('two made-up certificates rob nobody',
        ( bond_program, world(A, _, _, N), c100(H),
          Q1 = qc(precommit, 1, 0, aaaa, [vote(precommit, 1, 0, aaaa, alice, deadbeef)]),
          Q2 = qc(precommit, 1, 0, bbbb, [vote(precommit, 1, 0, bbbb, alice, deadbeef)]),
          ( slash_for_certificates(Q1, Q2, N, _) -> W = 'ROBBED' ; W = refused ),
          coco_bond_of(A, Bd), want(W-Bd, refused-H) )).

%% ---- the chain half -----------------------------------------------------
%%
%% THE SPAWNED PROCESS LOADS THIS FILE: `whob/4' is here, and a goal that
%% names it in another process needs it there.

bond_kb(coco_bond_test).

bgoal(G0, G) :-
    ( is_list(G0) -> sh_join(G0, G1) ; G1 = G0 ),
    sh_join(['use_module(library(poa)), use_module(library(coco)), ',
             'use_module(library(pos)), use_module(library(bft)), ',
             'use_module(''test/bond.pl''), ', G1], G).

bnode(G0) :-
    bgoal(G0, G), bond_kb(KB),
    ( wire_as(alice, KB, G, '.', _) -> true ; true ).

bans(G0, A) :-
    bgoal(G0, G), bond_kb(KB),
    ( wire_as(alice, KB, G, '^answer\\(.*\\)$', A0) -> A = A0 ; A = none ).

bbare(G0, A) :-
    bgoal(G0, G), bond_kb(KB),
    ( wire(KB, G, '^answer\\(.*\\)$', A0) -> A = A0 ; A = none ).

answer(Parts, A) :- join_dash(Parts, S), sh_join(['answer(', S, ')'], A).

join_dash([], '').
join_dash([X], X) :- !.
join_dash([X|Xs], J) :- join_dash(Xs, R), sh_join([X, '-', R], J).

chain_half :-
    bond_kb(KB), wire_forget(KB),
    bond_files(Fs), forall(member(F, Fs), wire_consult(KB, F)),

    section("the bond arrives as a block, and matures against the chain's height"),
    c400(F4), c300(F3), c100(H), supply(S0), node_key(alice, AK),
    bnode(['whob(A, B, CA, _), coco_seal_genesis([A-''', F4, ''', B-''', F3,
           ''', CA-''', F3, '''])']),
    bnode(['secp256k1_pubkey(''', AK, ''', AP), Tx = tx(AP, 0, bond(''', H, '''), 5000), ',
           'coco_tx_seal(''', AK, ''', Tx, Sig), coco_submit(Tx, Sig)']),
    bnode('coco_settle_chain'),
    iso('a bonded validator, from rows a second process read',
        ( bans('stake_table(P), total_stake(T), write(answer(P-T)), nl', A),
          want(A, 'answer([alice-100]-100)') )),
    %% The unbonding is sealed at height 2, so it is ready at 5: three more
    %% blocks have to exist before the money is home. Nothing claims it --
    %% any node settling those heights moves it.
    bnode(['secp256k1_pubkey(''', AK, ''', AP), Tx = tx(AP, 1, unbond(''', H, '''), 5000), ',
           'coco_tx_seal(''', AK, ''', Tx, Sig), coco_submit(Tx, Sig)']),
    bnode('coco_settle_chain'),
    answer(['100', H], W1),
    iso('unbonding leaves the weight standing while the money is at risk',
        ( bans(['whob(A, _, _, _), stake_of(alice, W), coco_unbonding_of(A, U), ',
                'write(answer(W-U)), nl'], A),
          want(A, W1) )),
    forall(member(_, [1, 2, 3]), bnode('ledger_seal(tick)')),
    bnode('coco_settle_chain'),
    answer([F4, '0', no_weight], W2),
    iso('three blocks later it is home, and the weight is gone',
        ( bans(['whob(A, _, _, _), coco_balance(A, Bal), coco_unbonding_of(A, U), ',
                '( stake_of(alice, W) -> R = W ; R = no_weight ), ',
                'write(answer(Bal-U-R)), nl'], A),
          want(A, W2) )),
    answer([S0, ok], W3),
    iso('and a bare process finds the supply still whole',
        ( bbare(['coco_supply(S), ( coco_conservation -> W = ok ; W = ''BROKEN'' ), ',
                 'write(answer(S-W)), nl'], A),
          want(A, W3) )).

main :-
    table_half, tx_half, slow_half, evidence_half, certificate_half,
    (   server_up
    ->  chain_half
    ;   nl, skip('no Zigurat server (the chain half)')
    ),
    nl, checks_done.
