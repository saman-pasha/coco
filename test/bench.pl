%% Rung 8: the TPS harness -- its RULES, checked.
%%
%% A TIMING IS NOT A PASS OR A FAIL. What is checkable about a benchmark
%% is not the number it printed but whether it would have refused a
%% dishonest one, so that is what this file checks. The numbers live in
%% bench/tps.sh, where they belong, with their arrangement printed beside
%% each of them.
%%
%% The five rules, and mallory's eight ways round them:
%%
%%   1. the count is verified against rows actually in the store
%%   2. a run under a second is not a measurement
%%   3. the arrangement is named on every line
%%   4. the clock is the wall, never CPU
%%   5. the first run of every lane is discarded
%%
%% Seven of her eight are one of those. The eighth -- choosing which
%% workload to run -- succeeds, and must, because it is upstream of every
%% rule a harness can have.
%%
%% NO SERVER: every rule here is a function of its arguments. Two things
%% still leave this process, and both because they have to. The scaling
%% curve is asserted, so those checks want a fresh store, which iso/2
%% gives them. And the LANGUAGE PAIRS are a claim about two languages
%% computing the same value, so one lane is a cocolog process and the
%% other is a python3 -- there is no way to ask CPython a question from
%% inside cocolog, and pretending otherwise would delete the comparison.
%%
%% Run:  cocolog -s test/bench.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

bench_program :-
    use_module('bench/harness.pl'), use_module('bench/mallory.pl').

%% WHAT A PREDICATE PRINTED, as a value. report/1's whole job is the LINE
%% it emits -- a rate that appears without its arrangement is the thing
%% the file exists to prevent -- so the check has to read the line rather
%% than a binding. The .sh got it by grepping a process's output; here it
%% is with_output_to/2, and the trailing newline comes off.
printed(Goal, A) :-
    with_output_to(codes(Cs), Goal),
    ( append(Ds, [10], Cs) -> true ; Ds = Cs ),
    atom_codes(A, Ds).

%% ---- the five rules -----------------------------------------------------

rule_half :-
    section('a reading has to earn its way onto the page'),
    iso('a verified count, long enough, with an arrangement, prints',
        ( bench_program,
          (   honest(reading(seal, 100, 4.0, server_one_kb, verified))
          ->  W = prints ; W = 'REFUSED' ),
          want(W, prints) )),
    iso('a count the rows do not back is refused',
        ( bench_program, verify_count(1000, 400, V),
          (   honest(reading(seal, 1000, 4.0, server_one_kb, V))
          ->  W = 'PRINTS' ; W = refused ),
          want(W, refused) )),
    iso('a count the rows DO back is verified',
        ( bench_program, verify_count(400, 400, V), want(V, verified) )),
    iso('a run under a second is refused',
        ( bench_program, refuses(honest(reading(seal, 5, 0.2, server_one_kb, verified))) )),
    iso('a rate with no arrangement is refused',
        ( bench_program, refuses(honest(reading(seal, 100, 40.0, none, verified))) )),
    iso('and so is a rate with an unbound one',
        ( bench_program, refuses(honest(reading(seal, 100, 40.0, _, verified))) )),
    iso('nothing happening is not a rate',
        ( bench_program, refuses(honest(reading(seal, 0, 40.0, server_one_kb, verified))) )).

%% ---- and there is one place a rate is computed --------------------------

rate_half :-
    section('and there is one place a rate is computed'),
    iso('tps/2 refuses what honest/1 refuses',
        ( bench_program, refuses(tps(reading(seal, 100, 0.5, server_one_kb, verified), _)) )),
    iso('an honest reading divides the way arithmetic does',
        ( bench_program, tps(reading(seal, 100, 4.0, server_one_kb, verified), R),
          want(R, 25.0) )),
    iso('report/1 prints the arrangement, not only the rate',
        ( bench_program,
          printed(report(reading(seal, 100, 4.0, server_one_kb, verified)), A),
          want(A, 'seal 25.00 server_one_kb 100 4.000') )),
    iso('and says REFUSED rather than printing a number it should not',
        ( bench_program,
          printed(report(reading(seal, 100, 0.1, server_one_kb, verified)), A),
          want(A, 'seal REFUSED server_one_kb') )),
    iso('a refusal says which rule it broke',
        ( bench_program,
          refusal(reading(seal, 100, 0.1, server_one_kb, verified), W),
          want(W, 'the run was too short to mean anything') )).

%% ---- the shape a single rate hides --------------------------------------

curve :-
    bench_program,
    assertz(scale_point(seal,  0, 0.805)), assertz(scale_point(seal, 10, 1.642)),
    assertz(scale_point(seal, 20, 2.591)), assertz(scale_point(seal, 30, 3.885)),
    assertz(scale_point(seal, 40, 5.201)).

curve_half :-
    section('the shape a single averaged rate hides'),
    iso('the measured curve comes back in order',
        ( curve, scale_shape(seal, S), length(S, N), want(N, 5) )),
    iso('and it is named for what it is',
        ( curve, scale_verdict(seal, V), want(V, grows_with_length) )),
    iso('a cost that does not grow is called flat',
        ( bench_program,
          assertz(scale_point(f, 0, 1.0)), assertz(scale_point(f, 10, 1.1)),
          assertz(scale_point(f, 20, 1.05)),
          scale_verdict(f, V), want(V, flat) )).

%% ---- mallory ------------------------------------------------------------

attack(A, L, Want) :-
    iso(L, ( bench_program, G =.. [A, V], call(G), want(V, Want) )).

mallory_half :-
    section('mallory reads the benchmark'),
    attack(attack_count_uncommitted,     'counting work that never committed',        refused),
    attack(attack_batch_as_transactions, 'calling one transaction a hundred of them', refused),
    attack(attack_cpu_time,              'dividing by CPU time instead of the wall',  refused),
    attack(attack_local_as_database,     'reporting a no-database run as a store rate', refused),
    attack(attack_first_run,             'reporting the cold run',                    refused),
    attack(attack_short_run,             'a run too short to mean anything',          refused),
    attack(attack_no_arrangement,        'a rate with nothing attached to it',        refused),
    attack(attack_choose_the_workload,   'choosing the workload -- SUCCEEDS, and must', 'ACCEPTED'),
    iso('the spread she is choosing from is real',
        ( bench_program, workload_spread(B, W0), R is B / W0,
          ( R > 100 -> W = hundredfold ; W = 'NARROW' ),
          want(W, hundredfold) )).

%% ---- the language comparison's own rule ---------------------------------
%%
%% `bench/langs.sh' times cocolog against CPython on five tasks, and its
%% first rule is that every lane must answer the SAME value or nothing is
%% printed. That rule protects a run; it does not protect the FILES, and
%% the likeliest way for this comparison to go quietly wrong is somebody
%% improving one side of a pair and not the other. So the pairs are
%% checked here, at a size small enough to cost nothing: same task, same
%% answer, both languages -- and the sqlite implementation of the store
%% task against the dict one, because those two must also stay the same
%% question asked twice.

langs_dir(D) :- coco_root(R), sh_join([R, '/bench/langs'], D).

%% one process, one `answer(...)' line, whatever it exited with
answer_of(Cmd, A) :-
    (   sh_any(Cmd, Out), re_lines('^answer\\(.*\\)$', Out, [L|_])
    ->  atom_codes(A, L)
    ;   A = 'NONE' ).

pair(T, N, R) :-
    coco_bin(C), langs_dir(D),
    answer_of(['timeout 60 ', C, ' run ', D, '/', T, '.pl "main(', N, ',', R, ')" 2>/dev/null'], PL),
    answer_of(['timeout 60 python3 ', D, '/', T, '.py ', N, ' ', R, ' 2>/dev/null'], PY),
    sh_join([T, ': cocolog and python answer the same'], L),
    %% AND NEITHER OF THEM IS `NONE'. The .sh compared "${_pl:-NONE}"
    %% against "${_py:-NONE}", so a run where BOTH lanes failed to start
    %% agreed perfectly and printed ok -- which is exactly what happened
    %% when a bench script was run from a directory with no coco.yaml
    %% above it and COCOLOG_BIN came out empty. Same answer, both
    %% present.
    iso(L, ( present(PL), want(PL, PY) )).

%% a lane that never started is not an agreement
present(A) :-
    ( A \== 'NONE' -> true ; format("     the lane printed no answer at all~n"), fail ).

lang_half :-
    section('the language pairs still compute the same thing'),
    (   have_tool(python3)
    ->  pair(nrev, '60', '2'),
        pair(queens, '6', '1'),
        pair(loop, '1000', '1'),
        pair(lookup, '200', '1'),
        pair(sortnums, '300', '1'),
        langs_dir(D),
        answer_of(['timeout 60 python3 ', D, '/lookup.py 200 1 2>/dev/null'], Dict),
        answer_of(['timeout 60 python3 ', D,
                   '/lookup_sqlite.py 200 1 /tmp/coco-benchpair.db 2>/dev/null'], Sq),
        %% `rm -f' is delete_file/1 behind its guard: gone is the
        %% postcondition, so a file that was never there is a success.
        ( exists_file('/tmp/coco-benchpair.db')
        ->  ( catch(delete_file('/tmp/coco-benchpair.db'), _, true) -> true ; true )
        ;   true ),
        iso('lookup: the dict and the sqlite store answer the same',
            ( present(Sq), want(Sq, Dict) ))
    ;   skip('no python3 -- the language pairs are not checked')
    ).

main :-
    rule_half, rate_half, curve_half, mallory_half, lang_half,
    nl, checks_done.
