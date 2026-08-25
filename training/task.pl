%% The task, and the data every node can regenerate.
%%
%% A TASK NAMES EVERYTHING NEEDED TO CHECK AN ANSWER: the data, the
%% architecture, the seed, the held-out range, and the threshold. It
%% names nothing about HOW to get there -- how many epochs, which
%% optimiser, what learning rate, whether to train at all. A worker that
%% finds the weights by gradient descent, by copying a paper, or by luck
%% is judged the same way, because the chain can check the answer and
%% cannot check the method.
%%
%% THE DATA IS A FUNCTION, NOT A FILE. Every point is computed from its
%% index by arithmetic that is the same on every machine, so there is no
%% dataset to distribute, no hash of a file to agree on, and no way for
%% two nodes to be evaluating different things. That is what makes
%% settlement reproducible rather than merely repeatable.

%% Two rings, one inside the other, with noise. The label is the ring.
noise(I, R) :-
    S is sin(I * 12.9898) * 43758.5453,
    R is S - truncate(S), !.

task_point(I, [X, Y], L) :-
    L is I mod 2,
    noise(I, N1), noise(I + 7000, N2), noise(I + 14000, N3),
    T is 6.28318 * N1,
    R is 0.5 + 0.5 * L + 0.08 * (N2 - 0.5),
    X is R * cos(T) + 0.02 * (N3 - 0.5),
    Y is R * sin(T), !.

%% The task itself. `holdout_commit' is sha256 of the holdout term, and
%% it is part of the task -- published before any worker has trained
%% anything, so the range cannot be chosen after the fact. `settle/4'
%% re-checks it every time.
the_task(task(rings,
              data(0, 899),
              holdout(900, 1049),
              holdout_commit('25053646af3aab1cc9027758029f9b443bc2bbaa789f6959c045385f1117ef36'),
              arch([input(2), dense(16, tanh), dense(16, tanh), dense(2, log_softmax)]),
              seed(7),
              accept(accuracy, 0.90))).
