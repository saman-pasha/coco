%% library(settle) -- training as settlement.
%%
%%   params_digest(+Params, -Hex)      what a submission commits to
%%   chunk_params(+Params, +N, -Chunks)  and how they travel
%%   join_chunks(+Chunks, -Params)
%%   submission_payload(+Sub, -Payload) / submission_of_payload(+P, -Sub)
%%   settle(+Task, +Sub, +Params, -Verdict)   the acceptance predicate
%%
%% THE DISCIPLINE IN ONE SENTENCE: train freely, verify deterministically,
%% commit rows.
%%
%% Training is expensive, non-deterministic and unverifiable -- two
%% honest workers with the same data and the same seed can land on
%% different weights, and nobody can check a gradient step after the
%% fact. EVALUATION is none of those things: given the weights and the
%% held-out points, every node computes the same accuracy every time.
%%
%% So settlement never asks "did you really train this". It asks the only
%% question that has a checkable answer: DOES IT WORK. A worker's claim
%% about its own accuracy is worth nothing and is never used -- the
%% verifier re-evaluates and compares against the task's threshold. That
%% is what makes this proof of USEFUL work rather than proof of effort:
%% the chain pays for a model that performs, not for cycles burned.
%%
%% WHAT A SUBMISSION COMMITS TO. A block carries a submission TERM -- the
%% task, the worker, the digest of the parameters, and the worker's claim
%% -- and the parameters themselves travel as separate rows, because a
%% row must fit in a page and a model does not. The digest is the join
%% between them: the block is signed and hash-chained, the digest is
%% inside it, and the rows are only believed if they hash back to it.

%% libtorch is a LOADABLE module in cocolog now, under its modules/torch,
%% so it is asked for like any other library. It used to be compiled into
%% the binary and always present.
:- use_module(library(torch)).

:- use_module(library(sha256)).

%% ---- the parameters --------------------------------------------------

params_digest(Params, Hex) :-
    term_to_atom(Params, A),
    sha256(A, Hex).

%% A row must fit in a page; a model does not. Fifty floats to a row is
%% comfortably inside it and keeps the arithmetic obvious.
chunk_params([], _, []) :- !.
chunk_params(Ps, N, [C|Rest]) :-
    take_drop(N, Ps, C, Tail),
    chunk_params(Tail, N, Rest).

take_drop(0, L, [], L) :- !.
take_drop(_, [], [], []) :- !.
take_drop(N, [H|T], [H|C], R) :- M is N - 1, take_drop(M, T, C, R).

join_chunks([], []).
join_chunks([C|T], Ps) :- join_chunks(T, Rest), append(C, Rest, Ps).

%% ---- the submission as a payload -------------------------------------

submission_payload(Sub, Payload) :- term_to_atom(Sub, Payload).

submission_of_payload(Payload, Sub) :-
    term_to_atom(T, Payload),
    T = submission(_, _, _, _, _),
    Sub = T.

%% ---- the acceptance predicate ----------------------------------------
%%
%% Five questions, in this order, and the order is not arbitrary: each is
%% cheaper than the next, and a submission that fails an early one is
%% never given the expensive work.
%%
%%   1. do the rows hash to the digest the signed block committed to?
%%   2. is the holdout the one the task committed to, before any
%%      submission existed?
%%   3. is the parameter count the one this architecture has?
%%   4. what accuracy do these weights ACTUALLY reach on the holdout?
%%   5. is that at or above the task's threshold?
%%
%% The worker's own claim is checked LAST and only to be reported. It has
%% no authority over anything: a submission is accepted or rejected on
%% the measured number, and a worker who claims 0.99 and delivers 0.99 is
%% treated exactly like one who claims nothing at all.

settle(Task, Sub, Params, Verdict) :-
    Task = task(TaskId, _Data, holdout(HStart, HEnd), holdout_commit(HC),
                arch(Arch), seed(Seed), accept(accuracy, Threshold)),
    Sub  = submission(TaskId, _Worker, Digest, claim(accuracy, _Claim), NClaimed),
    (   \+ params_digest(Params, Digest)
    ->  Verdict = rejected(digest_mismatch)
    ;   \+ holdout_matches(HStart, HEnd, HC)
    ->  Verdict = rejected(holdout_moved)
    ;   length(Params, N), N =\= NClaimed
    ->  Verdict = rejected(shape(N, NClaimed))
    ;   \+ arch_fits(Arch, Seed, Params)
    ->  Verdict = rejected(shape(arch))
    ;   measure(Arch, Seed, Params, HStart, HEnd, Accuracy)
    ->  (   Accuracy >= Threshold
        ->  Verdict = accepted(Accuracy)
        ;   Verdict = rejected(accuracy(Accuracy))
        )
    ;   Verdict = rejected(would_not_load)
    ).

%% THE HOLDOUT IS COMMITTED BEFORE ANY SUBMISSION EXISTS, and re-checked
%% here. Without this a settler could look at the submissions and then
%% choose the range that gives the answer it wanted -- which is not a
%% hypothetical: it is the cheapest attack on any benchmark, and the one
%% nobody sees, because a settler moving the goalposts leaves no trace in
%% the result.
holdout_matches(HStart, HEnd, HC) :-
    term_to_atom(holdout(HStart, HEnd), A),
    sha256(A, HC).

arch_fits(Arch, Seed, Params) :-
    torch_seed(Seed),
    model_new(Arch, M),
    model_params(M, Fresh),
    length(Fresh, N),
    length(Params, N).

%% The only expensive step, and the only one that answers the real
%% question. Deterministic: same weights, same points, same number, on
%% every node, every time.
measure(Arch, Seed, Params, HStart, HEnd, Accuracy) :-
    torch_seed(Seed),
    model_new(Arch, M),
    model_set_params(M, Params),
    findall(X, (between(HStart, HEnd, I), task_point(I, X, _)), Xs),
    findall(L, (between(HStart, HEnd, I), task_point(I, _, L)), Ls),
    tensor_from_list(Xs, TX),
    tensor_from_list(Ls, TY),
    model_evaluate(M, TX, TY, accuracy, Accuracy).
