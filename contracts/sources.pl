%% The contracts, honest and criminal, as source.
%%
%% A contract is a LIST OF CLAUSES and nothing else -- no bytecode, no
%% ABI, no compiler. Deployment writes this list into a ledger block's
%% payload, so what is signed and hash-chained is the source itself, and
%% every node installs the same text or none of it.
%%
%%   contract_source(Name, Clauses)   the honest ones
%%   attack_source(Name, Clauses, What)  mallory's, and what each tries
%%
%% THE CRIMINAL CONTRACTS ARE HERE, beside the honest ones, on purpose.
%% They are not test fixtures hidden in a test file: they are what a
%% deployed contract can look like, and a fence that has only ever been
%% shown well-behaved code has not been tested.

%% ---- the honest ones -------------------------------------------------

%% An escrow. The classic, and it is a real one: a deposit is held until
%% the BUYER signs a release over the escrow's own id. The buyer is a
%% public key, the authorisation is a secp256k1 signature, and the
%% contract checks it itself -- which is why `secp256k1_verify/3' is in
%% the vocabulary. Nothing here trusts the caller's word about who is
%% asking.
contract_source(escrow, [
    (open_escrow(Id, Buyer, Seller, Amount) :-
        atom(Id), atom(Buyer), atom(Seller), integer(Amount), Amount > 0,
        \+ state_has(Id),
        state_put(Id, escrow(Buyer, Seller, Amount, open))),

    (release(Id, Sig) :-
        state_get(Id, escrow(Buyer, Seller, Amount, open)),
        sha256(Id, H),
        secp256k1_verify(H, Sig, Buyer),
        state_put(Id, escrow(Buyer, Seller, Amount, released))),

    (status(Id, St) :-
        state_get(Id, escrow(_, _, _, St)))
]).

%% A registry, to have a second contract with a key of the same name --
%% which is how the suite shows that two contracts' states are separate
%% without either of them being able to say so.
contract_source(registry, [
    (put_entry(K, V) :- atom(K), state_put(K, V)),
    (get_entry(K, V) :- state_get(K, V))
]).

%% Recursion, which a contract is allowed: a predicate may call itself
%% and the fence permits it, because `heads_of/2' puts a contract's own
%% predicates in scope. This one terminates. The next one does not.
contract_source(adder, [
    (sum_to(0, 0) :- !),
    (sum_to(N, S) :- N > 0, M is N - 1, sum_to(M, S0), S is S0 + N)
]).

%% ---- mallory's ------------------------------------------------------

%% Steal the node's signing key. `NODE_KEY' is in the environment
%% precisely because it must not be a row -- and a contract that could
%% read the environment would make it one, on every node that ran the
%% contract, in a block anyone can read.
attack_source(thief, [
    (steal(K) :- getenv('NODE_KEY', K), state_put(stolen, K))
], 'read the node private key out of the environment').

%% Forge history from inside a contract. `assertz' is not in the
%% vocabulary at all, so this never reaches the question of whether the
%% block would have been valid.
attack_source(saboteur, [
    (forge :- assertz(block(99, fake, alice, payload, sig, hash)))
], 'assert a ledger block directly').

%% Read another contract's state by naming the underlying row. The rows
%% exist -- `contract_state/3' is an ordinary predicate -- and the fence
%% is what makes them unreachable: a contract may only use the scoped
%% `state_get/2', which cannot name a contract at all.
attack_source(spy, [
    (peek(V) :- contract_state(escrow, e1, V))
], 'read another contract state rows directly').

%% Build a goal at run time. This is the attack a whitelist alone does
%% not stop, which is why `call/N' is refused outright rather than merely
%% left off the list.
attack_source(shapeshifter, [
    (run(G) :- call(G))
], 'call a goal supplied by the caller').

%% The other way to build a goal: make the term out of a list first.
attack_source(univ, [
    (run(F, A) :- G =.. [F, A], call(G))
], 'construct a goal with univ').

%% Shadow a vocabulary predicate. If a contract could define its own
%% `member/2', every contract installed after it would get that one --
%% so the fence refuses a contract that defines any name the vocabulary
%% already has.
attack_source(shadow, [
    (member(_, _) :- true)
], 'redefine a vocabulary predicate for everyone').

%% Hide the forbidden goal inside a meta-predicate. A fence that checked
%% only the outer functor would pass this.
attack_source(smuggler, [
    (run(L) :- findall(X, assertz(planted(X)), L))
], 'hide assertz inside findall').

%% Never terminate. This one is ADMITTED -- there is nothing wrong with
%% its vocabulary and no static check can know it does not stop. Gas is
%% what answers it, and gas is the engine's own `--steps'.
attack_source(runaway, [
    (spin(N) :- M is N + 1, spin(M))
], 'loop forever - admitted, gas is the answer').
