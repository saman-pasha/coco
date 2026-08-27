%% A worker: train locally, publish rows, submit a signed block.
%%
%%   train_and_submit(+Quality)   Quality is `honest' or one of mallory's
%%   publish_params(+Digest, +Params)
%%   settle_submissions            the verifier's side
%%   provenance(-Rows)             where a model came from
%%
%% TRAINING HAPPENS IN `--local', WITH NO DATABASE AT ALL. That is not an
%% optimisation, it is the discipline cocolog learned the hard way and
%% wrote into its CLAUDE.md: long compute never sits inside a database
%% turn, because the server's idle timeout takes the connection and the
%% turn is lost. So a worker trains in one process with no connection
%% open, and PUBLISHES in another -- short turns, each one a transaction.

%% libtorch is a LOADABLE module in cocolog now, under its modules/torch,
%% so it is asked for like any other library. It used to be compiled into
%% the binary and always present.
:- use_module(library(torch)).

:- use_module(library(poa)).
:- use_module(library(settle)).
:- use_module(library(lists)).

:- dynamic param_chunk/3.
:- dynamic settled/3.
:- dynamic submission_ready/2.

%% ---- training --------------------------------------------------------
%%
%% The task says what to hit; it says nothing about how, so this is an
%% ordinary training loop with no ceremony. `honest' trains properly.
%% The others are mallory's, and each is a different lie -- they live in
%% training/mallory.pl.
%% THE WORKER'S OWN SEED, not the task's. The task's seed is for
%% REPRODUCING a judgement -- `settle/4' uses it to rebuild the
%% architecture before loading someone's weights into it. Training is a
%% different business: two honest workers exploring from different
%% starting points is the normal case and the useful one, and it is
%% exactly why settlement cannot judge a submission by comparing it to
%% what the verifier would have got. It judges the model, not the method.
%%
%% Written the other way round -- every worker training from the task's
%% seed -- alice and bob produced BYTE-IDENTICAL weights, which meant one
%% digest, two sets of rows under it, and a join that came back twice as
%% long as it should. Every submission then failed its digest check, and
%% the reason was not fraud but determinism.
worker_seed(Seed) :-
    node_identity(Worker, _),
    atom_codes(Worker, Cs),
    sum_list(Cs, Sum),
    Seed is 1000 + Sum.

train_params(honest, Params) :-
    the_task(task(_, data(S, E), _, _, arch(Arch), _, _)),
    worker_seed(WS), torch_seed(WS),
    findall(X, (between(S, E, I), task_point(I, X, _)), Xs),
    findall(L, (between(S, E, I), task_point(I, _, L)), Ls),
    tensor_from_list(Xs, TX),
    tensor_from_list(Ls, TY),
    model_new(Arch, M),
    model_train(M, TX, TY,
                [epochs(300), batch(32), lr(0.02), optimiser(adam), loss(nll)]),
    model_params(M, Params).

%% ---- publishing ------------------------------------------------------
%%
%% The parameters as rows, and the submission as a block. Two different
%% things travelling two different ways, joined by the digest: a row must
%% fit in a page and a model does not, so the model cannot be in the
%% block -- but its FINGERPRINT can, and that is what is signed.
publish_params(Digest, Params) :-
    chunk_params(Params, 50, Chunks),
    publish_chunks(Digest, 0, Chunks).

publish_chunks(_, _, []).
publish_chunks(Digest, Seq, [C|T]) :-
    assertz(param_chunk(Digest, Seq, C)),
    Next is Seq + 1,
    publish_chunks(Digest, Next, T).

fetch_params(Digest, Params) :-
    findall(Seq-C, param_chunk(Digest, Seq, C), Pairs),
    Pairs \== [],
    keysort(Pairs, Sorted),
    findall(C, member(_-C, Sorted), Chunks),
    join_chunks(Chunks, Params).

%% Train, publish the rows, seal the claim. The CLAIM is whatever the
%% worker says -- an honest worker reports what it measured, and nothing
%% anywhere depends on that being true.
submit(Quality, Claim) :-
    the_task(task(TaskId, _, _, _, _, _, _)),
    node_identity(Worker, _),
    train_params(Quality, Params),
    params_digest(Params, Digest),
    length(Params, N),
    publish_params(Digest, Params),
    ledger_seal_submission(submission(TaskId, Worker, Digest,
                                      claim(accuracy, Claim), N)).

ledger_seal_submission(Sub) :-
    submission_payload(Sub, Payload),
    ledger_seal(Payload).

%% ---- settling --------------------------------------------------------
%%
%% Walk the chain, find every submission, and judge each on the measured
%% number. A submission whose digest was already accepted for this task
%% is rejected as a duplicate: the second worker to publish the same
%% weights did not do the work, whatever it says, and a chain that paid
%% twice for one model would pay a thousand times.
settle_submissions :-
    the_task(Task),
    Task = task(TaskId, _, _, _, _, _, _),
    ledger_head(head(_, Hash, _)),
    chain_from(Hash, Blocks),
    reverse(Blocks, Oldest),
    settle_blocks(Oldest, Task, TaskId).

settle_blocks([], _, _).
settle_blocks([block(_, _, _, Payload, _, _)|T], Task, TaskId) :-
    (   submission_of_payload(Payload, Sub),
        Sub = submission(TaskId, Worker, Digest, _, _),
        \+ settled(Worker, Digest, _)
    ->  judge(Task, Sub, Worker, Digest)
    ;   true
    ),
    settle_blocks(T, Task, TaskId).

judge(Task, Sub, Worker, Digest) :-
    (   settled(_, Digest, accepted(_))
    ->  assertz(settled(Worker, Digest, rejected(duplicate)))
    ;   \+ fetch_params(Digest, _)
    ->  assertz(settled(Worker, Digest, rejected(no_rows)))
    ;   fetch_params(Digest, Params),
        settle(Task, Sub, Params, Verdict),
        assertz(settled(Worker, Digest, Verdict))
    ).

%% ---- what a node can say afterwards ----------------------------------

settlement_report :-
    forall(settled(W, D, V),
           ( sub_atom(D, 0, 8, _, Short),
             format("~w ~w ~w~n", [W, Short, V]) )).

%% WHERE DID THIS MODEL COME FROM. The whole point of the rung, as a
%% query: the accepted digest, the worker who submitted it, the block
%% that carried it, the authority who sealed that block, and the height
%% it sits at. Federated learning with an audit trail is not a slogan
%% here -- it is one findall.
provenance(prov(Worker, Digest, Accuracy, Height, Author)) :-
    settled(Worker, Digest, accepted(Accuracy)),
    the_task(task(TaskId, _, _, _, _, _, _)),
    block(Height, _, Author, Payload, _, _),
    submission_of_payload(Payload, submission(TaskId, Worker, Digest, _, _)).

provenance_report :-
    forall(provenance(prov(W, D, A, H, Au)),
           ( sub_atom(D, 0, 8, _, Short),
             format("model ~w by ~w accuracy ~4f in block ~w sealed by ~w~n",
                    [Short, W, A, H, Au]) )).

%% ---- the split, and why it is a split --------------------------------
%%
%% `train_and_export/1' runs in `--local' with no connection open at all
%% and PRINTS its result as facts. A second process consults them into
%% the knowledge base, and a third seals the submission. Three short
%% turns, none of which contains three seconds of gradient descent.
%%
%% That shape is not fastidiousness. cocolog's CLAUDE.md carries it as
%% law -- long compute never sits inside a database turn -- because the
%% server's idle timeout takes the connection and the whole turn is lost.
%% A worker that trained inside its turn would lose the training too, and
%% cocolog's own trainer prints its parameters as facts for exactly this
%% reason.
train_and_export(Quality) :-
    train_params(Quality, Params),
    params_digest(Params, Digest),
    length(Params, N),
    chunk_params(Params, 50, Chunks),
    export_chunks(Digest, 0, Chunks),
    format("submission_ready('~w', ~w).~n", [Digest, N]).

export_chunks(_, _, []).
export_chunks(Digest, Seq, [C|T]) :-
    format("param_chunk('~w', ~w, ~q).~n", [Digest, Seq, C]),
    Next is Seq + 1,
    export_chunks(Digest, Next, T).

%% Seal what was published. The claim is the worker's to make and nothing
%% depends on it, so it is simply an argument.
%%
%% THE DIGEST IS AN ARGUMENT TOO, and it was not at first. `submit_ready'
%% used to look up `submission_ready/2' from the knowledge base -- which
%% works for one worker and is wrong for three, because every worker's
%% exported facts land in the same store and the lookup backtracks over
%% all of them. Each worker after the first sealed its predecessors'
%% digests as its own, and cocolog obligingly did it once per solution.
%% Settlement caught every one as a duplicate, which is the rule working
%% exactly as intended on a mistake nobody meant to make.
submit_ready(Digest, Claim) :-
    the_task(task(TaskId, _, _, _, _, _, _)),
    node_identity(Worker, _),
    submission_ready(Digest, N),
    ledger_seal_submission(submission(TaskId, Worker, Digest,
                                      claim(accuracy, Claim), N)),
    !.
