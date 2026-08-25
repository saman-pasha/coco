%% mallory, the criminal worker.
%%
%% Rung 2 gave her a criminal node and rung 3 gave her criminal
%% contracts. Here she is a criminal WORKER, and the attacks are
%% different in kind: nothing she does is malformed. Every submission
%% below is a well-formed, correctly signed block from an entitled
%% author. She is not attacking the ledger. She is attacking the
%% SETTLEMENT -- trying to be paid for a model that does not work.
%%
%% Each `train_params/2' clause below is a different lie, and the one
%% that matters is the first.

%% 1. THE LIAR. Train for four epochs instead of three hundred, then
%% claim 0.99. This is the attack proof-of-useful-work exists to answer,
%% and the answer is not clever: the verifier ignores the claim entirely
%% and measures. A worker's word about its own accuracy is not evidence
%% and is never treated as any.
train_params(liar, Params) :-
    the_task(task(_, data(S, E), _, _, arch(Arch), _, _)),
    worker_seed(WS), torch_seed(WS),
    findall(X, (between(S, E, I), task_point(I, X, _)), Xs),
    findall(L, (between(S, E, I), task_point(I, _, L)), Ls),
    tensor_from_list(Xs, TX), tensor_from_list(Ls, TY),
    model_new(Arch, M),
    model_train(M, TX, TY,
                [epochs(1), batch(256), lr(0.0001), optimiser(adam), loss(nll)]),
    model_params(M, Params).

%% 2. THE JUNK SUBMITTER. Do not train at all -- submit the freshly
%% initialised weights. Cheapest possible submission, and it costs the
%% verifier exactly as much to reject as a real one, which is the honest
%% cost of this design.
train_params(junk, Params) :-
    the_task(task(_, _, _, _, arch(Arch), _, _)),
    worker_seed(WS), torch_seed(WS),
    model_new(Arch, M),
    model_params(M, Params).

%% 3. THE SHAPESHIFTER. Weights for a different architecture. They will
%% not load into the one the task named, and the count gives it away
%% before anything is loaded at all.
train_params(shapeshifter, Params) :-
    worker_seed(WS), torch_seed(WS),
    model_new([input(2), dense(4, tanh), dense(2, log_softmax)], M),
    model_params(M, Params).

%% ---- the attacks that are not about training -------------------------

%% 4. THE FORGER. Publish rows that are not the weights she committed to.
%% The block is signed and its digest is fixed; she changes the rows
%% afterwards, hoping the verifier trusts them. It re-hashes.
attack_forge(Digest) :-
    the_task(task(TaskId, _, _, _, _, _, _)),
    node_identity(Worker, _),
    train_params(honest, Good),
    params_digest(Good, Digest),
    length(Good, N),
    %% commit to the good weights ...
    ledger_seal_submission(submission(TaskId, Worker, Digest,
                                      claim(accuracy, 0.99), N)),
    %% ... and publish different ones under that digest
    train_params(junk, Bad),
    publish_params(Digest, Bad).

%% 5. THE PLAGIARIST. Take a digest that is already on the chain and
%% submit it again as her own. The weights are real and they work -- that
%% is the point. She did not produce them, and a chain that paid for the
%% same model twice would pay for it a thousand times.
attack_plagiarise(Digest) :-
    the_task(task(TaskId, _, _, _, _, _, _)),
    node_identity(Worker, _),
    fetch_params(Digest, Params),
    length(Params, N),
    ledger_seal_submission(submission(TaskId, Worker, Digest,
                                      claim(accuracy, 0.99), N)).

%% 6. THE CORRUPT SETTLER -- and this one is not mallory at all. It is
%% whoever runs settlement, looking at the submissions first and then
%% choosing a holdout range that gives the answer they wanted. Nobody
%% would ever see it in the result: the accuracy would be real, measured
%% honestly, on the wrong points.
%%
%% The task commits sha256 of its holdout BEFORE any worker has trained
%% anything, and `settle/4' re-checks that commitment on every single
%% submission. A moved goalpost is caught by arithmetic, not by trust.
attack_moved_holdout(Task2) :-
    the_task(task(Id, D, _, HC, A, S, Acc)),
    Task2 = task(Id, D, holdout(0, 149), HC, A, S, Acc).
