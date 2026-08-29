%% Rung 4: train freely, verify deterministically, commit rows.
%%
%% WHAT SETTLEMENT MEASURES, AND WHAT IT IGNORES. A submission carries a
%% CLAIM, and the claim is not evidence: the chain re-runs the weights
%% against a holdout it committed to before anybody trained, and the
%% verdict is what it MEASURED. So an honest worker and a liar making the
%% identical claim are separated by the only thing that can separate
%% them.
%%
%% TRAINING IS NOT REPRODUCIBLE AND DOES NOT HAVE TO BE. Two honest
%% workers reach DIFFERENT weights -- different seeds, and floating point
%% is not associative across a thread pool -- and both are accepted. What
%% must be deterministic is the VERIFICATION, which is one forward pass
%% over fixed rows. That split is the whole design: the expensive half is
%% free to be whatever it is, and the half that decides money is exact.
%%
%% WHO IS ASKING IS A PROPERTY OF THE SCENE. `ledger/node.pl' reads
%% NODE_NAME and NODE_KEY from the environment at call time, so the .sh
%% case spawned a fresh cocolog per worker -- three processes to ask
%% three questions. `iso_as/3' sets the identity and runs one isolated
%% proof instead. The CHAIN half below still spawns, because there the
%% claim is that a SECOND PROCESS reads what the first wrote.
%%
%% SKIPs without library(torch), and the chain half SKIPs without a
%% server -- "no server here" and "the backend is wrong" are different
%% findings.
%%
%% Run:  cocolog -s test/training.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

training_program :-
    use_module(library(poa)), use_module(library(settle)),
    use_module('ledger/federation.pl'), use_module('ledger/node.pl'),
    use_module('training/task.pl'), use_module('training/worker.pl'),
    use_module('training/mallory.pl').

training_files(['ledger/federation.pl', 'ledger/node.pl',
                'training/task.pl', 'training/worker.pl',
                'training/mallory.pl']).

%% the claim every submission below makes: 0.99, whatever it delivers
sub(submission(rings, W, D, claim(accuracy, 0.99), N), W, D, N).

%% a rejection naming a measured accuracy is one rejection whatever the
%% measurement was -- the number is the model's, not this file's
kind(rejected(accuracy(_)), rejected(accuracy(measured))) :- !.
kind(V, V).

main :-
    (   catch(( use_module(library(torch)), torch_seed(1) ), _, fail)
    ->  checks
    ;   skip('(no library(torch) -- sh modules/torch/build.sh in cocolog)')
    ).

checks :-
    training_program,

    section('what settlement measures, and what it ignores'),
    iso_as(alice, 'an honest model is accepted on its MEASURED accuracy',
        ( the_task(T), train_params(honest, P), params_digest(P, D),
          length(P, N), sub(S, alice, D, N),
          settle(T, S, P, V), want(V, accepted(1.0)) )),
    iso_as(carol, 'a liar claiming 0.99 is judged on what it delivers',
        ( the_task(T), train_params(liar, P), params_digest(P, D),
          length(P, N), sub(S, carol, D, N),
          settle(T, S, P, V), kind(V, K), want(K, rejected(accuracy(measured))) )),
    iso_as(carol, 'untrained weights, same claim, same treatment',
        ( the_task(T), train_params(junk, P), params_digest(P, D),
          length(P, N), sub(S, carol, D, N),
          settle(T, S, P, V), kind(V, K), want(K, rejected(accuracy(measured))) )),
    iso_as(carol, 'weights for a different architecture will not load',
        ( the_task(T), train_params(shapeshifter, P), params_digest(P, D),
          length(P, N), sub(S, carol, D, N),
          settle(T, S, P, V), want(V, rejected(shape(arch))) )),
    iso_as(carol, 'rows that do not hash to the committed digest',
        ( the_task(T), train_params(honest, G), params_digest(G, D),
          train_params(junk, B), length(B, N), sub(S, carol, D, N),
          settle(T, S, B, V), want(V, rejected(digest_mismatch)) )),
    iso_as(alice, 'a settler who moves the holdout after the fact',
        ( train_params(honest, P), params_digest(P, D), length(P, N),
          attack_moved_holdout(T), sub(S, alice, D, N),
          settle(T, S, P, V), want(V, rejected(holdout_moved)) )),

    section('the two properties settlement rests on'),
    iso_as(alice, "the task's holdout commitment is the real hash of its holdout",
        ( the_task(task(_, _, holdout(A, B), holdout_commit(HC), _, _, _)),
          term_to_atom(holdout(A, B), T2), sha256(T2, H2), want(H2, HC) )),
    %% TWO HONEST WORKERS LAND ON DIFFERENT WEIGHTS, and both are
    %% accepted above -- the point of the whole rung. Two identities in
    %% one process is exactly what as/2 is for.
    iso('two honest workers land on different weights',
        ( as(alice, ( train_params(honest, PA), params_digest(PA, DA) )),
          as(bob,   ( train_params(honest, PB), params_digest(PB, DB) )),
          ( DA \== DB -> true
          ; format("     both landed on ~q~n", [DA]), fail ) )),
    iso_as(alice, 'and training is repeatable for the same worker',
        ( train_params(honest, P1), params_digest(P1, D1),
          train_params(honest, P2), params_digest(P2, D2),
          want(D1, D2) )),

    (   server_up
    ->  chain_half
    ;   nl, skip('no Zigurat server (the chain half)')
    ),
    nl, checks_done.

%% ---- through the chain: train local, publish rows, seal, settle -------
%%
%% THIS HALF STILL SPAWNS, and it must. Every claim here is that a
%% SECOND PROCESS -- one that consulted nothing -- reads what the first
%% wrote into a shared knowledge base. run_isolated/2 is a fresh machine
%% in the same process and cannot make that claim; converting this to
%% iso/2 would keep the case green and delete the proof.
chain_half :-
    section('through the chain: train local, publish rows, seal, settle'),
    KB = training_test,
    wire_forget(KB),
    training_files(Fs),
    forall(member(F, Fs), wire_consult(KB, F)),
    forall(member(W-How, [alice-honest, bob-honest, carol-liar]),
           publish(KB, W, How)),

    iso('eight rows of weights per worker reached the store',
        ( count_chunks(N), want(N, 24) )),

    settle_now(KB),
    iso('alice, who trained honestly, is accepted',
        ( report_count('^alice .* accepted', N), want(N, 1) )),
    iso('bob, who trained honestly from another seed, is accepted too',
        ( report_count('^bob .* accepted', N), want(N, 1) )),
    iso('carol, who claimed the same 0.99, is rejected on the measurement',
        ( report_count('^carol .* rejected.accuracy', N), want(N, 1) )),

    section('plagiarism, and provenance'),
    %% carol submits ALICE's accepted digest: the weights are real and
    %% they are not hers, which is the only kind of theft a digest catches
    ( digest_of(alice, DA) -> submit_ready(KB, carol, DA) ; true ),
    settle_now(KB),
    iso('a second worker claiming an accepted digest is a duplicate',
        ( report_count('^carol .* rejected.duplicate', N), want(N, 1) )),
    iso('provenance names two models, their workers and their blocks',
        ( provenance_count('^model ', N), want(N, 2) )),
    iso('and names the authority that sealed each one',
        ( provenance_count('sealed by ', N), want(N, 2) )),

    section('and a second node settles to the same verdicts'),
    %% A DIFFERENT NODE, A DIFFERENT PROCESS, the same rows: two kinds of
    %% verdict come back, which is what "an independent settler agrees"
    %% means when nobody shares memory.
    iso('an independent settler agrees, verdict for verdict',
        ( independent_kinds(K), want(K, two_kinds) )).

%% ---- the chain half's own vocabulary ------------------------------------
%%
%% Every one of these starts a REAL cocolog against the shared knowledge
%% base, because that is the claim being made. They are predicates rather
%% than inline goals so the checks above read as what they assert.

:- dynamic '$digest'/2.

lib_prefix('use_module(library(poa)), use_module(library(settle)), ').

training_goal(G0, G) :-
    lib_prefix(P),
    ( is_list(G0) -> sh_join(G0, G1) ; G1 = G0 ),
    sh_join([P, G1], G).

%% TRAIN IN ONE PROCESS, keep the rows it printed, consult them back --
%% which is the rung's own shape: the expensive half runs anywhere, and
%% what reaches the chain is rows.
publish(KB, Who, How) :-
    coco_bin(C), training_files(Fs), join_sp(Fs, FL),
    sh_join(['/tmp/coco-tr-', Who, '.pl'], Out),
    lib_prefix(P),
    sh_join([P, 'train_and_export(', How, ')'], G),
    %% grep exits 1 when it matches nothing, so the pipeline's status is
    %% not the training run's -- the file it wrote is what says whether
    %% anything happened, and digest_in/2 below is what reads it
    ( as(Who, shl([C, ' run ', FL, ' "', G, '" 2>/dev/null | grep -aE ',
                   '"^(param_chunk|submission_ready)" > ', Out]))
    -> true ; true ),
    wire_consult(KB, Out),
    (   digest_in(Out, D)
    ->  assertz('$digest'(Who, D)),
        submit_ready(KB, Who, D)
    ;   true
    ).

digest_in(File, D) :-
    read_file_to_codes(File, Cs),
    re_lines('^submission_ready', Cs, [L|_]),
    atom_codes(A, L),
    quoted_run(A, D).

%% THE FIRST QUOTED RUN IN AN ATOM -- the digest `submission_ready'
%% carries. Written with sub_atom/5 rather than a character-code literal:
%% `0''' is the quote's own code and it does not read here, which cost
%% one syntax error that named the whole file and not the line.
quoted_run(A, D) :-
    sub_atom(A, B, 1, _, ''''), P is B + 1,
    sub_atom(A, P, _, 0, Rest),
    sub_atom(Rest, E, 1, _, ''''), !,
    sub_atom(Rest, 0, E, _, D).

digest_of(Who, D) :- '$digest'(Who, D).

count_chunks(N) :-
    training_goal('findall(1, param_chunk(_,_,_), L), length(L,M), write(M), nl', G),
    (   wire(training_test, G, '^[0-9]+$', A)
    ->  atom_number(A, N)
    ;   N = 0
    ).

settle_now(KB) :-
    training_goal('settle_submissions', G),
    ( wire_as(alice, KB, G, '.', _) -> true ; true ).

report_count(Pattern, N) :-
    training_goal('settlement_report', G),
    (   wire_lines(training_test, G, Pattern, Ls)
    ->  length(Ls, N)
    ;   N = 0
    ).

provenance_count(Pattern, N) :-
    training_goal('provenance_report', G),
    (   wire_lines(training_test, G, Pattern, Ls)
    ->  length(Ls, N)
    ;   N = 0
    ).

submit_ready(KB, Who, D) :-
    training_goal(['submit_ready(''', D, ''', 0.99)'], G),
    ( wire_as(Who, KB, G, '.', _) -> true ; true ).

independent_kinds(K) :-
    training_goal(['findall(V, (block(_,_,_,P,_,_), submission_of_payload(P, S), ',
                   'S = submission(rings,W2,D2,_,_), fetch_params(D2,Ps), ',
                   'the_task(T), settle(T,S,Ps,V)), Vs), sort(Vs, Sorted), ',
                   'length(Sorted, NK), ( NK =:= 2 -> write(two_kinds) ; write(NK) ), nl'], G),
    ( wire_as(bob, training_test, G, '^(two_kinds|[0-9]+)$', A) -> K = A ; K = none ).
