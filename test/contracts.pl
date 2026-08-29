%% Rung 3: a contract is a predicate, and the fence is what makes that
%% safe to say.
%%
%% THE FENCE IS A VOCABULARY, NOT A SANDBOX. A contract's clauses are
%% admitted only if every goal in them is on a list -- and the list is
%% chosen so that what is admitted is deterministic, total, and blind to
%% everything but its arguments. Seven attacks below are refused by that
%% rule alone, and each one is a different way of reaching outside:
%% asserting, reading a file, reaching the network, changing shape,
%% calling a variable, shadowing a builtin, smuggling a goal in a term.
%%
%% AND ONE ATTACK IS ADMITTED ON PURPOSE. A contract that loops forever
%% passes the fence, because halting is not decidable and pretending
%% otherwise would be a lie in the code. GAS is the answer to it, and
%% part five is where that gets checked: it suspends at its budget.
%%
%% TWO DIFFERENT QUESTIONS, and the deployment part is where they
%% separate. WHO MAY DEPLOY is the ledger's question -- alice is an
%% authority, mallory is not, and mallory's block never joins the chain
%% at all, so her contract is never even parsed. WHAT MAY RUN is the
%% fence's, and it refuses alice's criminal contract even though alice
%% was entitled to seal it.
%%
%% MONEY HAS A TYPE. `is/2' is in the vocabulary and it is SIXTY-FOUR
%% BITS: at ordinary token scale -- one token is 10^18 -- it wraps in
%% silence, so a contract pricing anything with it would be confidently
%% wrong and its own checks would agree. library(u256) is inside the
%% fence for the same reason everything else there is, and the last three
%% checks hold both halves: it is admitted, it RUNS and pays Uniswap's
%% own number, and the fence is still a fence beside it.
%%
%% SKIPs without a Zigurat server for parts three to five -- the halves
%% that need a chain, and the ones where a second process is the point.
%%
%% Run:  cocolog -s test/contracts.pl   from coco/ -- the exit code is
%%       the verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

contracts_program :-
    use_module(library(poa)), use_module(library(contract)),
    use_module('ledger/federation.pl'), use_module('ledger/node.pl'),
    use_module('contracts/sources.pl'), use_module('contracts/node.pl').

contracts_files(['ledger/federation.pl', 'ledger/node.pl',
                 'contracts/sources.pl', 'contracts/node.pl']).

bobpub('466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f276728176c3c6431f8eeda4538dc37c865e2784f3a9e77d044f33e407797e1278a').
carolpub('3c72addb4fdf09af94f0c94d7fe92a386a7e70cf8a1d85916386bb2535c7b1b13b306b0fe085665d8fc1b28ae1676cd3ad6e08eaeda225fe38d0da4de55703e0').

%% a constant-product quote, priced in u256 -- the contract the last
%% three checks admit, run and compare against
amm([(quote(In, R0, R1, Out) :-
        u256_mul(In, '997', F), u256_mul(R0, '1000', S),
        u256_add(S, F, D), u256_muldiv(F, R1, D, Out))]).

main :- contracts_program, checks.

checks :-
    section('the fence'),
    forall(member(A, [thief, saboteur, spy, shapeshifter, univ, shadow, smuggler]),
           refuse_check(A)),
    iso('admits a contract that loops (gas is the answer)',
        ( attack_source(runaway, Cs, _), contract_admit(runaway, Cs, R),
          want(R, admitted) )),
    forall(member(H, [escrow, registry, adder]), admit_check(H)),

    section('isolation, the door, and all-or-nothing'),
    iso('two contracts keep separate keys of the same name',
        ( contract_install(x1, [(s :- state_put(n, from_x1))]),
          contract_install(x2, [(s2 :- state_put(n, from_x2))]),
          contract_call(x1, s), contract_call(x2, s2),
          contract_enter(x1), state_get(n, A),
          contract_enter(x2), state_get(n, B),
          want(A-B, from_x1-from_x2) )),
    iso("a caller cannot run assertz through a contract's door",
        ( contract_install(y1, [(s :- state_put(n, 1))]),
          refuses(contract_call(y1, assertz(sneaky(1)))) )),
    iso('a failing contract leaves nothing behind',
        ( contract_install(z1, [(halfway :- state_put(k, written), fail)]),
          ( contract_call(z1, halfway) -> true ; true ),
          contract_enter(z1), refuses(state_get(k, _)) )),
    iso('and a succeeding one reads its own write, then commits it',
        ( contract_install(z2, [(go(V) :- state_put(k, 42), state_get(k, V))]),
          contract_call(z2, go(V)), contract_enter(z2), state_get(k, W),
          want(V-W, 42-42) )),
    iso('recursion inside a contract is allowed and works',
        ( contract_source(adder, Cs), contract_install(adder, Cs),
          contract_call(adder, sum_to(10, S)), want(S, 55) )),

    section('money has a type, and it is inside the fence'),
    iso('admits a contract that prices in u256',
        ( use_module(library(u256)), amm(A),
          contract_admit(amm, A, R), want(R, admitted) )),
    iso('and it runs, paying the constant-product quote',
        ( use_module(library(u256)), amm(A), contract_install(amm, A),
          contract_call(amm, quote('1000000000000000000',
                                   '1000000000000000000000',
                                   '1000000000000000000000', Out)),
          want(Out, '996006981039903216') )),
    %% The fence is still a fence: u256 got in because it is safe, not
    %% because the list grew careless.
    iso('still refuses assertz beside the u256 calls',
        ( use_module(library(u256)),
          contract_admit(sneak,
                         [(q(A, B, C) :- u256_add(A, B, C), assertz(owned(C)))], R),
          want(R, refused) )),

    (   server_up
    ->  chain_half
    ;   nl, skip('no Zigurat server (parts three to five)')
    ),
    nl, checks_done.

%% each attack names ITSELF -- the source carries what it is trying, so
%% the label is the contract's own word rather than this file's
refuse_check(A) :-
    (   attack_source(A, _, What) -> true ; What = A ),
    sh_join(['refuses: ', What], L),
    iso(L, ( attack_source(A, Cs, _), contract_admit(A, Cs, R), want(R, refused) )).

admit_check(H) :-
    sh_join(['admits the honest contract ''', H, ''''], L),
    iso(L, ( contract_source(H, Cs), contract_admit(H, Cs, R), want(R, admitted) )).

%% ---- the chain half: deployment, escrow, gas, and an auditor ---------
%%
%% THIS HALF SPAWNS, and every check here is why. A deployment is a
%% BLOCK; an escrow is released by a signature a second process verifies;
%% a runaway contract is suspended by a node and dropped by another
%% invocation; and the auditor is the whole point -- a fresh process,
%% which consulted nothing, reading a contract's SOURCE out of the chain.
chain_half :-
    KB = contracts_test,
    wire_forget(KB),
    contracts_files(Fs),
    forall(member(F, Fs), wire_consult(KB, F)),

    section('deployment is a block, and inherits the chain'),
    forall(member(D, [escrow, registry, thief]), deploy(KB, D)),
    node(KB, alice, 'install_from_chain', _),
    iso('the honest contracts install; the criminal one is refused',
        ( node_answer(contracts_test, alice, 'deployed_report',
                      '^installed .escrow,registry. refused .thief.$', A),
          want(A, 'installed [escrow,registry] refused [thief]') )),
    %% The other layer: mallory is not an authority, so her deployment
    %% block never joins the chain and the contract is never seen.
    iso('a contract in a block that does not validate is never even parsed',
        ( node_answer(contracts_test, alice,
              ['contract_source(registry, Cs), contract_deploy_payload(mallory_coin, Cs, P), ',
               'genesis_prev(G), seal(''4444444444444444444444444444444444444444444444444444444444444444'', 0, G, mallory, P, S, H), ',
               'ledger_sync([block(0,G,mallory,P,S,H)]), ',
               '( contract_clause(mallory_coin,_) -> write(''INSTALLED'') ; write(never_arrived) ), nl'],
              '^(INSTALLED|never_arrived)$', A),
          want(A, never_arrived) )),

    section('the escrow contract, end to end'),
    bobpub(BP), carolpub(CP),
    node(KB, alice, ['contract_call(escrow, open_escrow(e1, ''', BP, ''', ''', CP, ''', 100))'], _),
    iso('an escrow opens',
        ( node_answer(contracts_test, alice, 'contract_call(escrow, status(e1, S)), write(S), nl',
                      '^(open|released)$', A), want(A, open) )),
    sig(carol, e1, SIGC), sig(bob, e1, SIGB),
    iso('the SELLER cannot release it',
        ( node_answer(contracts_test, alice,
              ['( contract_call(escrow, release(e1, ''', SIGC, ''')) -> write(''RELEASED'') ; write(refused) ), nl'],
              '^(RELEASED|refused)$', A), want(A, refused) )),
    iso("the buyer's signature does",
        ( node_answer(contracts_test, alice,
              ['( contract_call(escrow, release(e1, ''', SIGB, ''')) -> write(released_ok) ; write(''REFUSED'') ), nl'],
              '^(released_ok|REFUSED)$', A), want(A, released_ok) )),
    iso('and the status moved',
        ( node_answer(contracts_test, alice, 'contract_call(escrow, status(e1, S)), write(S), nl',
                      '^(open|released)$', A), want(A, released) )),
    iso('an escrow id cannot be opened twice',
        ( node_answer(contracts_test, alice,
              ['( contract_call(escrow, open_escrow(e1, ''', BP, ''', ''', CP, ''', 5)) -> write(''REOPENED'') ; write(refused) ), nl'],
              '^(REOPENED|refused)$', A), want(A, refused) )),

    section('gas: a contract that never stops'),
    node(KB, alice, 'attack_source(runaway, Cs, _), contract_install(runaway, Cs)', _),
    iso('it suspends at its budget instead of running',
        ( spinner_suspends(KB) )),
    iso('and dropping it leaves the node clean',
        ( spinner_dropped(KB) )),
    iso('the node still answers afterwards',
        ( node_answer(contracts_test, alice, 'contract_call(escrow, status(e1, S)), write(S), nl',
                      '^(open|released)$', A), want(A, released) )),

    section('an auditor, with no prior state'),
    %% A FRESH PROCESS, which consulted nothing, reading a contract's
    %% source out of the chain. This is the claim the whole rung is for,
    %% and it is the one iso/2 could not make.
    iso("a fresh process reads a contract's source out of the chain",
        ( node_answer(contracts_test, alice,
              'findall(1, contract_clause(escrow, _), L), length(L, N), ( N =:= 3 -> write(three_clauses) ; write(N) ), nl',
              '^(three_clauses|[0-9]+)$', A),
          want(A, three_clauses) )).

con_prefix('use_module(library(poa)), use_module(library(contract)), ').

con_goal(G0, G) :-
    con_prefix(P),
    ( is_list(G0) -> sh_join(G0, G1) ; G1 = G0 ),
    sh_join([P, G1], G).

node(KB, Who, G0, A) :-
    con_goal(G0, G),
    ( wire_as(Who, KB, G, '.', A) -> true ; A = none ).

node_answer(KB, Who, G0, Pattern, A) :-
    con_goal(G0, G),
    ( wire_as(Who, KB, G, Pattern, A0) -> A = A0 ; A = none ).

deploy(KB, What) :- node(KB, alice, ['deploy(', What, ')'], _).

sig(Who, Id, S) :-
    node_key(Who, K),
    sh_join(['use_module(library(secp256k1)), use_module(library(sha256)), sha256(',
             Id, ',H), secp256k1_sign(''', K, ''',H,S), write(S), nl'], G),
    ( solo_answer(G, '^[0-9a-f]{128}$', S0) -> S = S0 ; S = '' ).

%% `start' then `step': the machine is suspended by ONE process and
%% resumed by another, which is what a budget being real means
spinner_suspends(KB) :-
    coco_bin(C), dial(D),
    ( shl([C, ' ', D, ' --kb ', KB, ' --steps 400 start spinner "spin(0)" >/dev/null 2>&1'])
    -> true ; true ),
    %% `step' exits with the TURN'S OUTCOME, and a machine that suspended
    %% at its budget is a non-zero exit that means success -- so the
    %% status is not the test, the line it printed is
    sh_any([C, ' ', D, ' --kb ', KB, ' --steps 400 step spinner 2>&1'], Out),
    re_lines('suspended at [0-9]+ inference', Out, [_|_]).

spinner_dropped(KB) :-
    coco_bin(C), dial(D),
    ( shl([C, ' ', D, ' --kb ', KB, ' drop spinner >/dev/null 2>&1']) -> true ; true ),
    sh_any([C, ' ', D, ' --kb ', KB, ' list 2>&1'], Out),
    re_lines('no suspended machines', Out, [_|_]).
