%% library(contract) -- a contract is a predicate.
%%
%%   contract_admit(+Name, +Clauses, -Verdict)   the fence, before install
%%   contract_install(+Name, +Clauses)           assert an admitted contract
%%   contract_deploy_payload(+Name, +Clauses, -Payload)
%%   contract_of_payload(+Payload, -Name, -Clauses)
%%   contract_enter(+Name) / contract_leave      who is running
%%   state_put(+Key, +Value) / state_get(+Key, -Value)
%%
%% DEPLOYMENT IS AN ENTRY. A contract is deployed by sealing an ordinary
%% ledger block whose payload is the contract's clauses, written as one
%% atom. Nothing new is needed for that: the block hash already covers
%% the payload, so the contract's SOURCE is hash-committed and signed by
%% an authority the moment it is deployed, and every node that adopts the
%% block gets the same text. There is no separate deployment mechanism
%% because there does not need to be one.
%%
%% THE FENCE IS A STATIC CHECK, RUN BEFORE INSTALL. Every goal in every
%% clause body must be a member of the vocabulary below or a call to a
%% predicate the same contract defines. A contract that does not pass is
%% not installed -- so the check happens once, at admission, and a call
%% costs nothing.
%%
%% For that to be SOUND rather than decorative, three things are refused
%% outright, and each of them is a hole that a whitelist alone would
%% leave open:
%%
%%   call/1..8   builds a goal at run time. A static check cannot see
%%               what `call(X)' will call, so a contract holding it can
%%               reach anything the engine has.
%%   =../2       makes a term out of a list, which is the other way to
%%               build a goal out of parts.
%%   a VARIABLE in goal position, for the same reason: there is nothing
%%               to check.
%%
%% The meta-predicates that DO get through -- `,', `;', `->', `\+',
%% findall/3, forall/2 -- are recursed into, because their arguments are
%% goals and a fence that checked `findall(X, Anything, L)' by looking
%% only at the functor would be no fence at all.

:- dynamic contract_clause/2.
:- dynamic contract_state/3.
:- dynamic contract_deployed/2.

%% ---- the vocabulary --------------------------------------------------
%%
%% Deterministic, total, and unable to see anything outside the chain.
%% What is ABSENT is the design: no assertz or retract (the only write
%% path is state_put/2, which is scoped), no consult, no open or any
%% file, no getenv (a node's signing key lives there -- see mallory), no
%% clock or random (a contract that can read the time is a contract two
%% nodes can disagree about), no torch, no vacuum_kb, no use_module, no
%% halt.
%%
%% A contract is meant to be a FUNCTION OF THE CHAIN. Everything it is
%% allowed to touch is either its arguments or its own state, and both of
%% those are rows every node has.

allowed(true/0).       allowed(fail/0).      allowed(false/0).
allowed(!/0).
allowed((=)/2).        allowed((\=)/2).      allowed((==)/2).
allowed((\==)/2).      allowed((@<)/2).      allowed((@>)/2).
allowed((@=<)/2).      allowed((@>=)/2).     allowed(compare/3).
allowed(is/2).         allowed((=:=)/2).     allowed((=\=)/2).
allowed((<)/2).        allowed((>)/2).       allowed((=<)/2).
allowed((>=)/2).       allowed(between/3).   allowed(succ/2).
allowed(var/1).        allowed(nonvar/1).    allowed(atom/1).
allowed(number/1).     allowed(integer/1).   allowed(float/1).
allowed(atomic/1).     allowed(compound/1).  allowed(is_list/1).
allowed(ground/1).
allowed(member/2).     allowed(memberchk/2). allowed(append/3).
allowed(length/2).     allowed(nth0/3).      allowed(nth1/3).
allowed(reverse/2).    allowed(msort/2).     allowed(sort/2).
allowed(keysort/2).    allowed(last/2).      allowed(sum_list/2).
allowed(max_list/2).   allowed(min_list/2).  allowed(numlist/3).
allowed(atom_concat/3).   allowed(atom_length/2).  allowed(atom_chars/2).
allowed(atom_codes/2).    allowed(atom_number/2).  allowed(char_code/2).
allowed(sub_atom/5).      allowed(number_codes/2). allowed(upcase_atom/2).
allowed(downcase_atom/2). allowed(atomic_list_concat/3).
%% MONEY IS u256, and a contract may say so. `is/2' is in this
%% vocabulary and it is 64 bits wide: at ordinary token scale -- one
%% token is 10^18 -- it wraps in silence, so a contract that priced
%% anything with it would be confidently wrong and its own checks would
%% pass on the wrong numbers. library(u256) is the type a balance, a
%% price or an amount is written in here, and it belongs inside the
%% fence for exactly the reason the rest of this list does: every one of
%% these is deterministic, total, and sees nothing but its arguments.
%% They cannot wrap -- an operation that cannot represent its answer
%% raises -- which is what makes them safe to hand a contract.
allowed(u256_add/3).   allowed(u256_sub/3).    allowed(u256_mul/3).
allowed(u256_div/3).   allowed(u256_mod/3).    allowed(u256_muldiv/4).
allowed(u256_cmp/3).   allowed(u256_sqrt/2).   allowed(u256_dec/2).
allowed(u256_hex/2).   allowed(u256_int/2).
%% The chain's own primitives. A contract that could not hash or check a
%% signature could not talk about the chain it lives on.
allowed(sha256/2).     allowed(sha256_hex/2).   allowed(sha256d_hex/2).
allowed(keccak256/2).  allowed(blake2b256/2).   allowed(ripemd160/2).
allowed(secp256k1_verify/3).  allowed(ed25519_verify/3).
allowed(block_hash/5). allowed(valid_block/6).  allowed(in_turn/2).
%% The one write path, and the one read path, both scoped to the calling
%% contract by `contract_enter/2' -- a contract cannot name another.
allowed(state_put/2).  allowed(state_get/2).    allowed(state_has/1).
%% WHO IS CALLING. A contract that cannot ask this cannot own anything --
%% see `caller/1' below, and the header. It is in the vocabulary for the
%% same reason everything else here is: deterministic, total, and unable
%% to see anything but the call it is inside.
allowed(caller/1).

%% Meta-predicates whose goal arguments are checked rather than trusted.
meta((','), 2, [1,2]).
meta((';'), 2, [1,2]).
meta((->), 2, [1,2]).
meta((*->), 2, [1,2]).
meta((\+), 1, [1]).
meta(findall, 3, [2]).
meta(forall, 2, [1,2]).
meta(aggregate_all, 3, [2]).

%% Never, whatever else is true.
forbidden(call, _).
forbidden((=..), 2).
forbidden(assert, 1).    forbidden(asserta, 1).  forbidden(assertz, 1).
forbidden(retract, 1).   forbidden(retractall, 1).
forbidden(abolish, _).   forbidden(consult, _).  forbidden(use_module, _).
forbidden(halt, _).      forbidden(getenv, _).   forbidden(setenv, _).
forbidden(open, _).      forbidden(see, _).      forbidden(tell, _).
forbidden(nb_setval, _). forbidden(nb_getval, _).
forbidden(b_setval, _).  forbidden(b_getval, _).
forbidden(vacuum_kb, _).

%% ---- the check -------------------------------------------------------

contract_admit(Name, Clauses, Verdict) :-
    (   is_list(Clauses),
        Clauses \== [],
        heads_of(Clauses, Own),
        check_clauses(Clauses, Own, Name)
    ->  Verdict = admitted
    ;   Verdict = refused
    ).

%% What this contract defines -- so a contract may call itself, which is
%% what makes recursion possible without opening the fence.
heads_of([], []).
heads_of([C|T], [N/A|R]) :-
    clause_head(C, H),
    functor(H, N, A),
    heads_of(T, R).

clause_head((H :- _), H) :- !.
clause_head(H, H).

check_clauses([], _, _).
check_clauses([C|T], Own, Name) :-
    clause_head(C, H),
    nonvar(H),
    functor(H, HN, _),
    atom(HN),
    %% A contract may not define a predicate the vocabulary already has:
    %% a contract that defines its own `member/2' would shadow the real
    %% one for everything installed after it.
    \+ ( functor(H, HN2, HA2), allowed(HN2/HA2) ),
    (   C = (_ :- B) -> check_body(B, Own, Name) ; true ),
    check_clauses(T, Own, Name).

check_body(G, _, _) :- var(G), !, fail.          % nothing to check
check_body(G, Own, Name) :-
    functor(G, F, A),
    (   forbidden(F, A) -> fail
    ;   meta(F, A, Args)
    ->  check_meta_args(Args, G, Own, Name)
    ;   allowed(F/A) -> true
    ;   memberchk(F/A, Own)
    ).

check_meta_args([], _, _, _).
check_meta_args([I|T], G, Own, Name) :-
    arg(I, G, Sub),
    check_body(Sub, Own, Name),
    check_meta_args(T, G, Own, Name).

%% ---- installing ------------------------------------------------------
%%
%% A contract's clauses are asserted under their own names, and remembered
%% as `contract_clause/2' so a node can say later what it installed and
%% under which contract -- which is what makes an audit of the CODE
%% possible, not only of the data.
contract_install(Name, Clauses) :-
    install_each(Name, Clauses).

install_each(_, []).
install_each(Name, [C|T]) :-
    assertz(C),
    assertz(contract_clause(Name, C)),
    install_each(Name, T).

%% ---- deployment as a payload ----------------------------------------

contract_deploy_payload(Name, Clauses, Payload) :-
    term_to_atom(contract(Name, Clauses), Payload).

contract_of_payload(Payload, Name, Clauses) :-
    term_to_atom(T, Payload),
    T = contract(Name, Clauses).

%% ---- calling ---------------------------------------------------------
%%
%% THE ENTRY POINT IS CHECKED TOO. The fence keeps a contract from
%% reaching out; this keeps a caller from reaching IN. `contract_call/2'
%% refuses any goal whose functor is not a predicate this contract
%% actually defines -- so `contract_call(escrow, assertz(anything))' is
%% not a call into the escrow contract, it is a caller trying to run
%% `assertz' with a contract's name in front of it, and the answer is no.
%%
%% `call/1' appears here, in the library, and that is not a contradiction:
%% the library is not fenced. The fence is a property of what a CONTRACT
%% may contain, and the whole point of this predicate is to be the one
%% door through which a fenced thing is entered.
%% A CONTRACT CALL IS ALL OR NOTHING, and that needs a mechanism rather
%% than a hope. "It rolls back with the turn" is not true of a FAILED
%% goal in any Prolog: `assertz' is not undone by backtracking, so
%% `(state_put(k,v), fail)' would leave the write behind -- half a
%% contract's effects, committed. (The turn's transaction covers a
%% different accident: a process that dies mid-turn commits nothing.)
%%
%% So writes are STAGED. `state_put/2' appends to a pending list rather
%% than the database; `state_get/2' reads the pending list first, so a
%% contract sees its own writes exactly as if they had landed; and the
%% pending list is flushed to rows ONLY if the goal succeeds. Fail or
%% throw, and it is dropped -- nothing reached the chain and there is
%% nothing to undo, which also keeps the state append-only, because
%% rolling back by retracting would not be.
%% ---- WHO IS CALLING, and why a contract needs to know ---------------
%%
%% `contract_call(Name, Goal, Caller)' -- and `contract_call/2' is it
%% with a caller of `nobody'.
%%
%% A CONTRACT THAT CANNOT ASK WHO IS CALLING CANNOT OWN ANYTHING, and
%% until this rung none of them could. Every ownership predicate in this
%% repository takes its owner as an ARGUMENT --
%% `nft_transfer_from(Collection, Caller, From, To, Id)' names the caller
%% in the call, `ft_transfer(Token, From, To, Amount)' names the payer --
%% which is safe only while the caller is the node itself. The moment a
%% TRANSACTION can reach a contract (rung 9's `call(Contract, Goal)'), a
%% stranger writes whatever name they like into that argument and the
%% token is theirs. The escrow felt the same gap from the other side and
%% paid for it in machinery: `release/2' carries a SIGNATURE over the
%% escrow id, which is an entire signature scheme built to answer a
%% question the fence could not.
%%
%% THE CALLER IS THE NODE'S ANSWER, NEVER THE CALLER'S CLAIM. It comes
%% from `coco_apply/5', which knows the sender because it verified the
%% signature over the whole transaction before running anything. A
%% contract reads it with `caller/1' and cannot set it: `contract_enter/2'
%% is not in the vocabulary, and `nb_setval' is forbidden outright.
%%
%% `nobody' is what a direct call reports, and it is a real answer rather
%% than a missing one: a contract that guards anything refuses it, so
%% ownership cannot be exercised except through a signed transaction.
contract_call(Name, Goal) :- contract_call(Name, Goal, nobody).

contract_call(Name, Goal, Caller) :-
    nonvar(Goal),
    atomic(Caller),
    functor(Goal, F, A),
    entry_point(Name, F, A),
    contract_enter(Name, Caller),
    catch(( call(Goal) -> Ok = true ; Ok = fail ),
          E,
          ( contract_leave, throw(E) )),
    (   Ok == true
    ->  flush_pending(Name), contract_leave
    ;   contract_leave, fail
    ).

flush_pending(Name) :-
    nb_getval(contract_pending, Pending),
    flush_each(Name, Pending),
    nb_setval(contract_pending, []).

flush_each(_, []).
flush_each(Name, [K-V|T]) :-
    assertz(contract_state(Name, K, V)),
    flush_each(Name, T).

entry_point(Name, F, A) :-
    contract_clause(Name, C),
    clause_head(C, H),
    functor(H, F, A),
    !.

%% ---- state, scoped ---------------------------------------------------
%%
%% `contract_enter/1' names the contract that is running, and state_put
%% and state_get read that name rather than taking it as an argument.
%% That is the whole of the isolation: a contract has no way to SAY which
%% contract's state it means, so it cannot mean another's. The name is
%% supplied by the caller, who is the node -- never by the contract, who
%% is the thing being fenced.
contract_enter(Name) :- contract_enter(Name, nobody).

contract_enter(Name, Caller) :-
    nb_setval(contract_current, Name),
    nb_setval(contract_caller, Caller),
    nb_setval(contract_pending, []).
contract_leave :-
    nb_setval(contract_current, none),
    nb_setval(contract_caller, nobody),
    nb_setval(contract_pending, []).

current_contract(Name) :- nb_getval(contract_current, Name), Name \== none.

%% The caller, as the running contract sees it. Outside a contract there
%% is nobody calling and this fails rather than answering `nobody' -- the
%% two are different questions, and a contract asking it is always inside
%% one.
caller(Who) :-
    current_contract(_),
    nb_getval(contract_caller, Who).

%% Staged, not written. See `contract_call/2'.
state_put(Key, Value) :-
    current_contract(_),
    nb_getval(contract_pending, P),
    append(P, [Key-Value], P2),
    nb_setval(contract_pending, P2).

%% The LATEST value for a key. State is append-only like everything else
%% here, so a key's history is on the record and `state_get/2' is a rule
%% over it rather than a cell that was overwritten.
%% The pending writes first, then the committed rows -- so a contract
%% reads its own uncommitted writes and nobody else's. State is
%% append-only, so the value of a key is the LAST one written and its
%% whole history stays on the record.
state_get(Key, Value) :-
    current_contract(C),
    nb_getval(contract_pending, P),
    findall(V, member(Key-V, P), PVs),
    findall(V, contract_state(C, Key, V), CVs),
    append(CVs, PVs, All),
    All \== [],
    last(All, Value).

state_has(Key) :- state_get(Key, _), !.
