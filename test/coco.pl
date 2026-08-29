%% COCO: the native token, and gas priced in INFERENCES.
%%
%% The chain has had money in it since rung 3 -- `contracts/token' is
%% ERC-20's shape and ERC-721's -- but a token deployed ON a chain cannot
%% be what the chain CHARGES IN: the fence has no way to price its own
%% execution, and a contract able to move the currency the node bills in
%% would be a contract that pays itself. So COCO is `library(coco)', the
%% node's own, and this case is what it promises.
%%
%% WHAT IT IS CHECKING, in five parts.
%%
%%   THE COIN CONSERVES. There is no mint: `coco_genesis/1' writes the
%%   supply once and refuses a second time, no other rule raises it, and
%%   the fee is PAID to the sealing authority rather than burnt -- so the
%%   balances sum to the supply at every moment and `coco_conservation/0'
%%   says so after every part of this file.
%%
%%   GAS IS THE ENGINE'S COUNT. cocolog's `call_metered/4' answers what a
%%   goal actually spent, so a fee is arithmetic over a number the engine
%%   produced rather than an estimate of it. The checks are the ones that
%%   distinguish a meter from a constant: a contract asked for ten times
%%   the work costs strictly more COCO, and the same call twice costs the
%%   same to the unit -- which is what lets two nodes that never met agree
%%   on a bill.
%%
%%   WORK THAT FAILED IS STILL WORK. A contract call that does not prove
%%   pays; a contract that never stops pays exactly the gas it was sold.
%%   Searching for a proof that is not there is precisely the work an
%%   attacker would like for free.
%%
%%   YOU CANNOT BUY GAS YOU CANNOT PAY FOR. The ceiling is the lower of
%%   what the sender asked for and what the balance already covers, so
%%   nothing is taken up front and no bill arrives that cannot be met. The
%%   poor sender's runaway below spends its LAST unit and not one more,
%%   which is that rule stated as a number.
%%
%%   AND THE CHAIN IS THE ONLY WAY IN. A transaction is a block payload,
%%   so it inherits the ledger's own laws: mallory is not an authority,
%%   her block never joins the chain, and the account she signed for is
%%   never debited -- refused one layer down, where the gas layer never
%%   sees it. Two layers asking two questions: who may seal, and who may
%%   spend.
%%
%% EVERY LOCAL CHECK IS ONE ISOLATED PROOF, which is what the .sh was
%% paying a whole cocolog process per check to get: `run_isolated/2' is a
%% fresh machine and a fresh store, so a genesis in one check is invisible
%% to the next -- and there are eight genesis blocks in this file. The
%% chain half still spawns, because its claim is about a knowledge base
%% two processes share, and SKIPs without a Zigurat server.
%%
%% Run:  cocolog -s test/coco.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

coco_program :-
    use_module(library(poa)), use_module(library(contract)), use_module(library(coco)),
    use_module('ledger/federation.pl'), use_module('ledger/node.pl'),
    use_module('ledger/gas.pl'), use_module('contracts/sources.pl'),
    use_module('contracts/node.pl').

coco_files(['ledger/federation.pl', 'ledger/node.pl', 'ledger/gas.pl',
            'contracts/sources.pl', 'contracts/node.pl']).

%% The keys are the obvious ones, as everywhere in this repository: every
%% public key and every address below can be rederived with
%% `secp256k1_pubkey' and `eth_address' by anyone reading.
ann_key( '5555555555555555555555555555555555555555555555555555555555555555').
bea_key( '6666666666666666666666666666666666666666666666666666666666666666').
poor_key('7777777777777777777777777777777777777777777777777777777777777777').
mal_key( '4444444444444444444444444444444444444444444444444444444444444444').

%% The schedule, restated here so a check that disagrees with the library
%% says so rather than quietly following it: one inference costs 10^9, a
%% transaction pays 1000 inferences flat, and a native move costs 200.
one(     '1000000000000000000').        %% one COCO, 18 decimals
half(     '500000000000000000').
fee_xfer(   '1200000000000').           %% (1000 + 200) * 10^9
ann_left('499998800000000000').         %% one COCO, less a half, less the fee

%% Two accounts and an authority's, derived rather than pasted.
who4(AP, A, BP, B, AU) :-
    ann_key(AK), bea_key(BK),
    secp256k1_pubkey(AK, AP), eth_address(AP, A),
    secp256k1_pubkey(BK, BP), eth_address(BP, B),
    coco_authority_account(alice, AU).

who(A, B, AU) :- who4(_, A, _, B, AU).

fund(A) :- one(ONE), coco_genesis([A-ONE]).

%% the transaction the transfer checks all seal: ann pays bea a half
xfer_tx(Tx, Sig) :-
    who4(AP, _, _, B, _), half(HF), ann_key(K),
    Tx = tx(AP, 0, transfer(B, HF), 5000),
    coco_tx_seal(K, Tx, Sig).

adder :- contract_source(adder, Cs), contract_install(adder, Cs).
runaway :- attack_source(runaway, RCs, _), contract_install(runaway, RCs).

%% ---- part one: the coin -------------------------------------------------

coin_half :-
    section('the coin: a supply that is minted once and afterwards only moves'),
    iso('genesis mints exactly what it allocated',
        ( coco_program, who(A, _, _), fund(A), one(ONE),
          coco_supply(T), coco_balance(A, X), want(T-X, ONE-ONE) )),
    iso('a second genesis is refused: there is no mint',
        ( coco_program, who(A, B, _), fund(A), one(ONE),
          ( coco_genesis([B-ONE]) -> W = 'MINTED AGAIN' ; W = refused ),
          coco_supply(T), want(W-T, refused-ONE) )),
    %% `assertz' is not undone by backtracking in any Prolog, so an
    %% allocation that failed half way would leave real balances behind
    %% with no supply to account for them -- and conservation would be
    %% broken by the one predicate whose job is to establish it. The whole
    %% list is checked before a row is written.
    iso('a genesis it cannot honour writes nothing at all',
        ( coco_program, who(A, _, _), one(ONE),
          ( coco_genesis([A-ONE, A-ONE]) -> W = 'ALLOCATED' ; W = refused ),
          coco_balance(A, X), ( coco_supply(_) -> S = supply ; S = none ),
          want(W-X-S, refused-'0'-none) )),
    iso('an address nobody funded holds zero, not nothing',
        ( coco_program, who(A, B, _), fund(A),
          coco_balance(B, X), want(X, '0') )),
    iso('a transfer moves exactly what it says, both sides',
        ( coco_program, who(A, B, _), fund(A), half(HF),
          coco_transfer(A, B, HF),
          coco_balance(A, X), coco_balance(B, Y), want(X-Y, HF-HF) )),
    iso('more than you have is refused',
        ( coco_program, who(A, B, _), fund(A), one(ONE),
          ( coco_transfer(A, B, '2000000000000000000')
            -> W = 'OVERDRAWN' ; W = refused ),
          coco_balance(A, X), want(W-X, refused-ONE) )),
    %% The classic doubling bug: subtracting and adding against two
    %% separately read copies of ONE balance. It must still be well formed,
    %% though -- paying yourself what you do not have is how a balance
    %% check gets skipped.
    iso('paying yourself changes nothing, and must still be affordable',
        ( coco_program, who(A, _, _), fund(A), one(ONE), half(HF),
          coco_transfer(A, A, HF), coco_balance(A, X),
          ( coco_transfer(A, A, '2000000000000000000') -> W = 'DOUBLED' ; W = refused ),
          want(X-W, ONE-refused) )).

%% ---- part two: the schedule ---------------------------------------------

schedule_half :-
    section('the schedule, which is two clauses anyone can point at'),
    iso('a fee is the price of one inference times the count',
        ( coco_program, fee_xfer(FX), coco_fee(1200, F), want(F, FX) )),
    iso('a balance buys the inferences it can pay for, floored',
        ( coco_program, who(A, _, _), coco_genesis([A-'3500000000000']),
          coco_affordable(A, S), want(S, 3500) )),
    %% However rich the sender: a block one account can occupy for as long
    %% as it can pay is a block everybody else is priced out of.
    iso('and never more than the block limit, however rich',
        ( coco_program, who(A, _, _), fund(A),
          coco_affordable(A, S), coco_block_limit(M),
          ( S =:= M -> W = capped ; W = S ), want(W, capped) )).

%% ---- part three: a transaction ------------------------------------------

tx_half :-
    section('a transaction: signed, nonced, and paid for'),
    iso('a native transfer moves the money and pays the sealer',
        ( coco_program, who4(_, A, _, B, AU), fund(A),
          half(HF), fee_xfer(FX), ann_left(L),
          xfer_tx(Tx, Sig), coco_apply(Tx, Sig, AU, 0, receipt(_, O, U, _)),
          coco_balance(A, X), coco_balance(B, Y), coco_balance(AU, Z),
          want(O-U-X-Y-Z, ok-1200-L-HF-FX) )),
    iso('and the supply is untouched by all of it',
        ( coco_program, who(A, _, AU), fund(A), one(ONE),
          xfer_tx(Tx, Sig), coco_apply(Tx, Sig, AU, 0, _),
          ( coco_conservation -> W = conserved ; W = 'BROKEN' ),
          coco_supply(T), want(W-T, conserved-ONE) )),
    %% THE NONCE IS WHAT MAKES A SIGNATURE USABLE ONCE. It is inside the
    %% signed text, so a replay carries the number it was signed with.
    iso('the same transaction twice: the second is refused, and free',
        ( coco_program, who(A, _, AU), fund(A), ann_left(L),
          xfer_tx(Tx, Sig), coco_apply(Tx, Sig, AU, 0, _),
          coco_apply(Tx, Sig, AU, 0, receipt(_, O2, U2, F2)),
          coco_balance(A, X), want(O2-U2-F2-X, refused(nonce)-0-'0'-L) )),
    %% Every field a node acts on is in the signed text, so moving one
    %% breaks the signature -- here the ceiling, which is the field a cheat
    %% would most like to raise after the fact.
    iso('a raised gas limit does not survive the signature',
        ( coco_program, who4(AP, A, _, B, AU), fund(A), one(ONE), half(HF),
          xfer_tx(_, Sig), Tx2 = tx(AP, 0, transfer(B, HF), 900000),
          coco_apply(Tx2, Sig, AU, 0, receipt(_, O, _, _)),
          coco_balance(A, X), want(O-X, refused(signature)-ONE) )),
    iso('and neither does a raised amount',
        ( coco_program, who4(AP, A, _, B, AU), fund(A), one(ONE),
          xfer_tx(_, Sig), Tx2 = tx(AP, 0, transfer(B, ONE), 5000),
          coco_apply(Tx2, Sig, AU, 0, receipt(_, O, _, _)),
          want(O, refused(signature)) )),
    %% RUBBISH IS A REFUSAL, NOT AN EMERGENCY. Both the curve and the money
    %% RAISE on malformed input rather than failing -- `secp256k1_verify/3'
    %% answers domain_error('a 64-byte signature', deadbeef) and `u256_cmp/3'
    %% throws on an amount that is not a number -- and both are right to,
    %% because a program handing them rubbish has a bug. A transaction is
    %% not a program: it is bytes somebody else chose, and the one thing
    %% they must not be able to choose is whether this node finishes its
    %% turn. So the two gates are total, and these are the checks that say
    %% so.
    iso('a garbage signature is refused, and the node answers afterwards',
        ( coco_program, who4(AP, A, _, B, AU), fund(A), one(ONE), half(HF),
          Tx = tx(AP, 0, transfer(B, HF), 5000),
          coco_apply(Tx, deadbeef, AU, 0, receipt(_, O, _, _)),
          coco_balance(A, X), want(O-X, refused(signature)-ONE) )),
    iso('and an amount that is not a number is refused, not fatal',
        ( coco_program, who4(AP, A, _, B, AU), fund(A), one(ONE), ann_key(K),
          Tx = tx(AP, 0, transfer(B, lots), 5000),
          coco_tx_seal(K, Tx, S2), coco_apply(Tx, S2, AU, 0, receipt(_, O, _, _)),
          coco_balance(A, X), want(O-X, refused(malformed)-ONE) )),
    iso('a transfer of nothing is not a transaction',
        ( coco_program, who4(AP, A, _, B, AU), fund(A), ann_key(K),
          Tx = tx(AP, 0, transfer(B, '0'), 5000),
          coco_tx_seal(K, Tx, S2), coco_apply(Tx, S2, AU, 0, receipt(_, O, _, _)),
          want(O, refused(malformed)) )).

%% ---- part four: gas for steps -------------------------------------------

%% one contract call, sealed by ann and applied: the shell built these by
%% pasting generated variable names into the goal text, because sh has no
%% other way to keep two transactions apart
call_tx(AU, Nonce, Action, O, U, F) :-
    who4(AP, _, _, _, _), ann_key(K),
    Tx = tx(AP, Nonce, Action, 100000),
    coco_tx_seal(K, Tx, Sig),
    coco_apply(Tx, Sig, AU, 0, receipt(_, O, U, F)).

gas_half :-
    section('gas for steps: the engine counts, and the count is the price'),
    iso('a fenced call runs, and is billed for what it spent',
        ( coco_program, who(A, _, AU), fund(A), adder,
          call_tx(AU, 0, call(adder, sum_to(10, _)), O, U, F),
          coco_fee(U, F2),
          ( F == F2, U > 1000 -> W = billed ; W = U-F ),
          want(O-W, ok-billed) )),
    %% THE CHECK THAT SEPARATES A METER FROM A CONSTANT. Ten times the work
    %% costs strictly more, and the intrinsic is in both, so the difference
    %% is the inferences themselves.
    iso('ten times the work costs strictly more COCO',
        ( coco_program, who(A, _, AU), fund(A), adder,
          call_tx(AU, 0, call(adder, sum_to(10, _)), _, U, F),
          call_tx(AU, 1, call(adder, sum_to(100, _)), _, U2, F2),
          ( u256_cmp(F2, F, '>'), U2 > U -> W = dearer ; W = U-U2 ),
          want(W, dearer) )),
    %% ...and the same call twice costs the same to the unit, which is what
    %% lets a party who did not run it check the bill.
    iso('the same call twice is the same bill, to the unit',
        ( coco_program, who(A, _, AU), fund(A), adder,
          call_tx(AU, 0, call(adder, sum_to(50, _)), _, U, F),
          call_tx(AU, 1, call(adder, sum_to(50, _)), _, U2, F2),
          ( U =:= U2, F == F2 -> W = identical ; W = U-U2 ),
          want(W, identical) )),
    iso('a call that fails still pays: a search is work',
        ( coco_program, who(A, _, AU), fund(A), adder,
          call_tx(AU, 0, call(adder, sum_to(-5, _)), O, _, F),
          ( u256_cmp(F, '0', '>') -> W = paid ; W = free ),
          want(O-W, failed-paid) )),
    %% A CONTRACT THAT NEVER STOPS is admitted -- no static check can know
    %% it does not halt -- and gas is the whole answer. The fee is EXACT
    %% here: the intrinsic plus the ceiling, and not the inference the
    %% engine spent noticing the budget was gone. Nobody is billed for gas
    %% they were not sold.
    iso('a runaway is stopped, and charged its ceiling exactly',
        ( coco_program, who4(AP, A, _, _, AU), fund(A), runaway, ann_key(K),
          Tx = tx(AP, 0, call(runaway, spin(0)), 5000),
          coco_tx_seal(K, Tx, Sig), coco_apply(Tx, Sig, AU, 0, receipt(_, O, U, F)),
          want(O-U-F, out_of_gas-6000-'6000000000000') )),
    iso('and the node is unharmed and still answers afterwards',
        ( coco_program, who4(AP, A, _, _, AU), fund(A), runaway, ann_key(K),
          Tx = tx(AP, 0, call(runaway, spin(0)), 5000),
          coco_tx_seal(K, Tx, Sig), coco_apply(Tx, Sig, AU, 0, _),
          adder, call_tx(AU, 1, call(adder, sum_to(10, S)), O2, _, _),
          want(O2-S, ok-55) )).

%% ---- part five: you cannot buy gas you cannot pay for -------------------

%% The ceiling is the LOWER of what the sender asked for and what the
%% balance covers. This sender asks for 100 000 inferences holding 3000
%% inferences' worth; the runaway spends its last unit and not one more.
poor_runaway(Funds, O, U, F, X, N) :-
    poor_key(PK), secp256k1_pubkey(PK, PP), eth_address(PP, P),
    coco_authority_account(alice, AU),
    coco_genesis([P-Funds]), runaway,
    Tx = tx(PP, 0, call(runaway, spin(0)), 100000),
    coco_tx_seal(PK, Tx, Sig),
    coco_apply(Tx, Sig, AU, 0, receipt(_, O, U, F)),
    coco_balance(P, X), coco_nonce(P, N).

poor_half :-
    section('you cannot buy gas you cannot pay for'),
    iso("a poor sender's runaway costs exactly everything, and no more",
        ( coco_program,
          poor_runaway('3000000000000', O, U, F, X, _),
          want(O-U-F-X, out_of_gas-3000-'3000000000000'-'0') )),
    %% ...and below the intrinsic there is no transaction at all: nobody
    %% may be billed for one the node declined to run.
    iso('below the intrinsic it is refused, and nothing is taken',
        ( coco_program,
          poor_runaway('500000000000', O, _, F, X, N),
          want(O-F-X-N, refused(gas)-'0'-'500000000000'-0) )),
    iso('conservation survives every one of those',
        ( coco_program,
          poor_runaway('3000000000000', _, _, _, _, _),
          ( coco_conservation -> W = conserved ; W = 'BROKEN' ),
          want(W, conserved) )).

%% ---- the chain half -----------------------------------------------------
%%
%% THE SPAWNED PROCESS LOADS THIS FILE, not just the prelude: `who4/5' and
%% `xfer_tx/2' are here, and a goal that names them in another process
%% needs them there. Loading a case as a module is safe -- `main/0' comes
%% with it and nothing calls it.

gas_kb(coco_gas_test).

gas_goal(G0, G) :-
    ( is_list(G0) -> sh_join(G0, G1) ; G1 = G0 ),
    sh_join(['use_module(library(poa)), use_module(library(contract)), ',
             'use_module(library(coco)), use_module(''test/coco.pl''), ', G1], G).

gnode(G0) :-
    gas_goal(G0, G), gas_kb(KB),
    ( wire_as(alice, KB, G, '.', _) -> true ; true ).

gans(G0, A) :-
    gas_goal(G0, G), gas_kb(KB),
    ( wire_as(alice, KB, G, '^answer\\(.*\\)$', A0) -> A = A0 ; A = none ).

%% a bare process -- nobody's identity, nothing consulted
gbare(G0, A) :-
    gas_goal(G0, G), gas_kb(KB),
    ( wire(KB, G, '^answer\\(.*\\)$', A0) -> A = A0 ; A = none ).

answer(Parts, A) :- join_comma(Parts, S), sh_join(['answer(', S, ')'], A).

join_comma([], '').
join_comma([X], X) :- !.
join_comma([X|Xs], J) :- join_comma(Xs, R), sh_join([X, '-', R], J).

chain_half :-
    gas_kb(KB), wire_forget(KB),
    coco_files(Fs), forall(member(F, Fs), wire_consult(KB, F)),

    section('the chain is the only way in'),
    %% Genesis is a block, and so is every transaction after it. Nothing
    %% new was needed for either: the payload happens to be money.
    one(ONE),
    gnode(['who(A, _, _), coco_seal_genesis([A-''', ONE, '''])']),
    gnode('xfer_tx(Tx, Sig), coco_submit(Tx, Sig)'),
    gnode('coco_settle_chain'),
    half(HF), fee_xfer(FX), ann_left(L),
    answer([L, HF, FX], W1),
    iso('genesis and a transfer, settled off the chain this node agreed on',
        ( gans('who(A, B, AU), coco_balance(A, X), coco_balance(B, Y), coco_balance(AU, Z), write(answer(X-Y-Z)), nl', A),
          want(A, W1) )),
    %% A SECOND PASS IS NOT A SECOND DEBIT. A block settles once, marked by
    %% its hash, whatever order the blocks arrived in.
    answer([L], W2),
    iso('settling again moves nothing',
        ( gans('coco_settle_chain, who(A, _, _), coco_balance(A, X), write(answer(X)), nl', A),
          want(A, W2) )),
    %% THE OTHER LAYER. Mallory is not an authority, so her block is
    %% refused as a BLOCK -- the gas layer never sees the transaction
    %% inside it, and ann is never debited by a transaction ann never
    %% signed either.
    ann_key(AK), mal_key(MK),
    iso("mallory's sealed transaction never reaches the gas layer",
        ( gans(['who4(AP, A, _, B, _), Tx3 = tx(AP, 1, transfer(B, ''', HF, '''), 5000), ',
                'coco_tx_seal(''', AK, ''', Tx3, S3), term_to_atom(coco_send(Tx3, S3), P3), ',
                'ledger_head(head(H0, PH, _)), H is H0 + 1, ',
                'seal(''', MK, ''', H, PH, mallory, P3, MS, MH), ',
                'ledger_sync([block(H, PH, mallory, P3, MS, MH)]), ',
                'coco_settle_chain, coco_balance(A, X), write(answer(X)), nl'], A),
          want(A, W2) )),

    %% And the claim this whole family is built on: a process that
    %% consulted NOTHING reads the money back out of the knowledge base.
    section('a bare process, which consulted nothing, reads the money back'),
    answer([ONE, '3', ok], W3),
    iso('supply, holders and conservation, from rows alone',
        ( gbare(['coco_supply(T), coco_holders(Hs), length(Hs, N), ',
                 '( coco_conservation -> W = ok ; W = ''BROKEN'' ), ',
                 'write(answer(T-N-W)), nl'], A),
          want(A, W3) )),
    iso('and the receipt for what happened is on the record too',
        ( gbare(['findall(O, coco_receipt(_, receipt(_, O, _, _)), Os), ',
                 'msort(Os, S), write(answer(S)), nl'], A),
          want(A, 'answer([ok,ok])') )).

main :-
    coin_half, schedule_half, tx_half, gas_half, poor_half,
    (   server_up
    ->  chain_half
    ;   nl, skip('no Zigurat server (the chain half)')
    ),
    nl, checks_done.
