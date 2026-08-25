%% The first module: proof that the three pillars stand together and
%% The Coco runs on them unmodified. test/run.sh holds `hello' GREEN
%% in the --local arrangement, and over the wire it proves the claim
%% the whole family exists to make: one process writes these clauses
%% into a knowledge base, a second -- which consulted nothing -- reads
%% them back.

pillar(cicili,  philosopher, 'writes it').
pillar(zigurat, warrior,     'keeps it').
pillar(coco,    engineer,    'makes it think').

hello :-
    forall(pillar(Name, Role, Deed),
           format("~w, the ~w, ~w~n", [Name, Role, Deed])).
