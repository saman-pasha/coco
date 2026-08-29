%% library(coco) -- COCO, the native token, and gas priced in INFERENCES.
%%
%% The chain's own money. Not a contract: an ERC-20 is a token deployed
%% ON a chain, and this is what the chain CHARGES IN -- the fence has no
%% way to price its own execution, and a contract that could move the
%% currency the node bills in would be a contract that pays itself.
%% `contracts/token/fungible.pl' is the other thing, and stays it.
%%
%%   coco_genesis(+Allocations)      mint the whole supply, ONCE
%%   coco_supply(-Total)             coco_balance(+Who, -Amount)
%%   coco_transfer(+From, +To, +Amount)
%%   coco_holders(-Addrs)            coco_conservation
%%
%%   coco_gas_price(-Price)          what one inference costs
%%   coco_intrinsic(-Steps)          the flat cost of being a transaction
%%   coco_fee(+Steps, -Fee)          coco_affordable(+Who, -Steps)
%%
%%   coco_tx_hash(+Tx, -Hash)        coco_tx_seal(+Priv, +Tx, -Sig)
%%   coco_tx_valid(+Tx, +Sig)        coco_tx_from(+Tx, -Addr)
%%   coco_nonce(+Who, -N)
%%   coco_apply(+Tx, +Sig, +Author, -Receipt)
%%
%% GAS IS THE ENGINE'S COUNT, NOT AN ESTIMATE OF IT. cocolog meters every
%% proof -- `call_metered/4' answers what a goal spent -- so a fee here is
%% arithmetic over a number the engine produced, and two parties who never
%% met compute the same one. That is the whole difference between metering
%% and a VM's gas table: nobody is maintaining a price list that has to be
%% kept in step with an implementation, because the implementation IS the
%% price list. `cocolog/test/meter.sh' holds the count to determinism
%% across processes, which is the property this file spends.
%%
%% A TRANSACTION IS `tx(Pub, Nonce, Action, GasLimit)', and an Action is
%% one of exactly two things:
%%
%%   transfer(To, Amount)    the native move. NOT metered: it is the
%%                           token's own operation, it is bounded, and it
%%                           costs a stated constant. Metering it would
%%                           also put a two-sided move under a ceiling
%%                           that could cut it in half -- money debited
%%                           and never credited -- which is the one thing
%%                           a ledger may not do.
%%   call(Contract, Goal)    a fenced contract entry, metered. The fence
%%                           is why a stranger's transaction is safe to
%%                           run at all, and `contract_call/2' stages its
%%                           writes and flushes them only on success, so
%%                           a ceiling that stops it mid-proof leaves
%%                           nothing behind.
%%
%% There is deliberately no third shape. A transaction carrying a BARE
%% GOAL would be `assertz' from anybody who can afford the fee.
%%
%% AN ACCOUNT IS AN ADDRESS, derived Ethereum's way -- the last twenty
%% bytes of keccak256 over the public key, `library(eth)', pinned to
%% published vectors in `test/crypto.sh'. The transaction carries the
%% PUBLIC KEY rather than the address, so verification needs no recovery
%% id and the address is a consequence rather than a claim: a signature
%% that verifies against that key, whose address is the account being
%% debited, is the entire question.
%%
%% THERE IS NO MINT. `coco_genesis/1' is the only rule in this file that
%% raises the supply, it refuses to run twice, and nothing else creates a
%% unit of COCO -- so the total is decided in one block and afterwards
%% only moves. A fee is not burnt either: it goes to the authority that
%% sealed the block, which is who spent the compute. Both halves are one
%% invariant, `coco_conservation/0': the balances sum to the supply,
%% always, and an auditor can check it without believing any of the code
%% above it.
%%
%% WHAT THE METER DOES NOT SEE, stated because it is the honest limit of
%% this rung: an inference is an inference. A `sha256/2' or an
%% `secp256k1_verify/3' is one C call and counts as ONE, while a
%% `between/3' step also counts as one, so a contract whose work is in
%% the crypto modules is under-priced against a contract whose work is in
%% clauses. `coco_intrinsic/1' answers that for the TRANSACTION's own
%% crypto -- the signature check the node pays for out of its own pocket
%% -- and nothing answers it inside a contract yet. Pricing a builtin by
%% weight is a table in the engine, which is a change to cocolog and
%% belongs there, on its own merits, with its own case.
%%
%% AND WHAT IS NOT HERE, on purpose: no fee market (one price, stated,
%% not bid), no refund of the unspent ceiling because nothing is taken up
%% front (the ceiling is what the balance can already cover, so the bill
%% is payable when it arrives), and no account abstraction. Each is an
%% addition to this rather than a correction of it.

:- use_module(library(u256)).
:- use_module(library(sha256)).
:- use_module(library(secp256k1)).
:- use_module(library(eth)).
:- use_module(library(contract)).

:- dynamic coco_bal/2.          % coco_bal(Address, Amount)
:- dynamic coco_total/1.        % the supply, written once by genesis
:- dynamic coco_nonce_at/2.     % coco_nonce_at(Address, NextNonce)

%% ---- the units -------------------------------------------------------
%%
%% Eighteen decimals, which is not imitation: it is the width every wallet
%% and every exchange already reads, and `library(u256)' is what makes it
%% safe -- one COCO is 10^18 and cocolog's own integers are 64 bits, so a
%% balance in `is/2' would wrap in silence at nineteen COCO.

coco_decimals(18).
coco_unit('1000000000000000000').

%% ---- the schedule ----------------------------------------------------
%%
%% ONE INFERENCE COSTS A BILLIONTH OF A COCO. So a transaction that
%% spends its intrinsic and nothing else costs 0.000001 COCO, and a
%% contract call that thinks for a million inferences costs 0.001. The
%% numbers are a starting point and they are HERE, in two clauses, rather
%% than spread through the code that charges: a schedule nobody can point
%% at is a schedule nobody can argue with.
coco_gas_price('1000000000').

%% THE INTRINSIC IS A FLOOR, NOT A MEASUREMENT. What the node actually
%% does per transaction is one ECDSA verify and two reads, and the meter
%% would count that as a handful of inferences -- which would make
%% flooding a chain with well-formed transactions nearly free. A thousand
%% is the price of taking up room in a block at all.
coco_intrinsic(1000).

%% A native move is bounded work: two balance reads, two writes, a nonce.
%% It is charged as a constant because it IS a constant, and because it
%% is done outside the meter for the reason the header gives.
coco_transfer_steps(200).

%% NO TRANSACTION MAY BUY MORE THAN THIS, however rich its sender. A
%% block that one account can occupy for as long as it can pay is a block
%% every other account is priced out of; the ceiling is the node's, not
%% the sender's.
coco_block_limit(10000000).

coco_fee(Steps, Fee) :-
    integer(Steps), Steps >= 0,
    coco_gas_price(P),
    u256_mul(P, Steps, Fee).

%% How many inferences this balance can already pay for -- floor, clamped
%% to the block limit before it is ever turned into a machine integer,
%% because a large enough balance divided by a small enough price does not
%% fit one and `u256_int/2' would rightly raise.
coco_affordable(Who, Steps) :-
    coco_balance(Who, Bal),
    coco_gas_price(P),
    u256_div(Bal, P, Bought),
    coco_block_limit(Max),
    (   u256_cmp(Bought, Max, '>')
    ->  Steps = Max
    ;   u256_int(Bought, Steps)
    ).

%% ---- genesis ---------------------------------------------------------
%%
%% The supply, allocated to addresses, once. `\+ coco_total(_)' is the
%% whole of "once": a second genesis on a chain that has one is refused,
%% and since the allocation is a block payload like any other, every node
%% computes the same supply from the same block.
%%
%% THE WHOLE LIST IS CHECKED BEFORE ONE ROW IS WRITTEN, which is the
%% lesson `library(contract)' paid for in its own file: `assertz' is not
%% undone by backtracking in any Prolog, so an allocation that failed
%% half way -- a duplicate address, an amount of zero -- would leave real
%% balances behind with no supply to account for them, and conservation
%% would be broken by the one predicate whose job is to establish it.
%% Validate, total, and only then write.
coco_genesis(Allocs) :-
    \+ coco_total(_),
    is_list(Allocs),
    Allocs \== [],
    coco_check_allocs(Allocs, [], '0', Total),
    coco_write_allocs(Allocs),
    assertz(coco_total(Total)).

coco_check_allocs([], _, Acc, Acc).
coco_check_allocs([Who-Amount|T], Seen, Acc, Total) :-
    ground(Who),
    u256_cmp(Amount, '0', '>'),
    \+ memberchk(Who, Seen),              % one line per account, no adding
    \+ coco_bal(Who, _),
    u256_add(Acc, Amount, Acc2),
    coco_check_allocs(T, [Who|Seen], Acc2, Total).

coco_write_allocs([]).
coco_write_allocs([Who-Amount|T]) :-
    u256_dec(Amount, Canonical),
    assertz(coco_bal(Who, Canonical)),
    coco_write_allocs(T).

coco_supply(Total) :- coco_total(Total).

%% An address nobody has funded holds zero, not nothing -- the same
%% answer every token gives, and the one that keeps every caller from
%% having to know whether an account has been seen before.
coco_balance(Who, Amount) :-
    ( coco_bal(Who, A) -> Amount = A ; Amount = '0' ).

coco_holders(Addrs) :-
    findall(W, coco_bal(W, _), Ws),
    sort(Ws, Addrs).

coco_set_balance(Who, Amount) :-
    ( retract(coco_bal(Who, _)) -> true ; true ),
    assertz(coco_bal(Who, Amount)).

%% ---- moving ----------------------------------------------------------
%%
%% Written with the self-transfer case explicit, for the reason
%% `fungible.pl' gives at length: subtracting and adding against two
%% separately-read copies of the SAME balance is how a token doubles
%% money when somebody pays themselves. It must still be well formed --
%% you may only pay yourself what you could have paid anyone -- because a
%% token where `transfer(me, me, more_than_i_have)' succeeds is a token
%% whose balance check can be skipped.
coco_transfer(From, To, Amount) :-
    ground(From), ground(To),
    u256_cmp(Amount, '0', '>'),
    coco_balance(From, FromBal),
    \+ u256_cmp(Amount, FromBal, '>'),
    (   From == To
    ->  true
    ;   coco_balance(To, ToBal),
        u256_sub(FromBal, Amount, NewFrom),
        u256_add(ToBal, Amount, NewTo),
        coco_set_balance(From, NewFrom),
        coco_set_balance(To, NewTo)
    ).

%% THE INVARIANT, and the reason the fee is paid rather than burnt: no
%% rule here destroys a unit or creates one, so the balances sum to the
%% supply at every moment, and this predicate is that sentence. Anyone
%% can run it; nothing above it needs it to be true in order to work,
%% which is exactly what makes it worth checking.
coco_conservation :-
    coco_total(Total),
    findall(A, coco_bal(_, A), Amounts),
    coco_sum256(Amounts, '0', Sum),
    u256_cmp(Sum, Total, '=').

coco_sum256([], Acc, Acc).
coco_sum256([A|T], Acc, Sum) :-
    u256_add(Acc, A, Acc2),
    coco_sum256(T, Acc2, Sum).

%% ---- a transaction ---------------------------------------------------
%%
%% WHAT IS SIGNED IS A TEXT, and every field a node would act on is in it
%% -- the sender's key, the nonce, the action and the ceiling. The
%% separator is not decoration: without it a nonce of 1 with a limit of
%% 23 and a nonce of 12 with a limit of 3 would sign the same bytes,
%% which is `library(poa)''s own lesson and the same attack.
%%
%% The action goes in through `term_to_atom/2', so what is signed is the
%% canonical written form of the term -- quoted, operator-free, and the
%% same text on every node that reads the block back.
coco_tx_signable(tx(Pub, Nonce, Action, GasLimit), Text) :-
    term_to_atom(Action, AT),
    atomic_list_concat([Pub, Nonce, AT, GasLimit], '|', Text).

coco_tx_hash(Tx, Hash) :-
    coco_tx_signable(Tx, Text),
    sha256(Text, Hash).

%% Signing is signing the hash, and the nonce never leaves
%% `library(secp256k1)': RFC 6979 derives it from the key and the hash
%% inside the module, so two processes sealing the same transaction
%% produce the same signature and there is no entropy source to get
%% wrong.
coco_tx_seal(Priv, Tx, Sig) :-
    coco_tx_hash(Tx, Hash),
    secp256k1_sign(Priv, Hash, Sig).

coco_tx_from(tx(Pub, _, _, _), Addr) :-
    eth_address(Pub, Addr).

coco_tx_valid(Tx, Sig) :-
    coco_well_formed(Tx),
    Tx = tx(Pub, _, _, _),
    coco_tx_hash(Tx, Hash),
    secp256k1_verify(Hash, Sig, Pub).

%% WHAT A TRANSACTION HAS TO BE before anybody spends a curve operation
%% on it. Shape first, signature second: verifying the signature of a
%% term that is not a transaction is work done for a sender who has not
%% even claimed to be one.
coco_well_formed(tx(Pub, Nonce, Action, GasLimit)) :-
    atom(Pub),
    integer(Nonce), Nonce >= 0,
    integer(GasLimit), GasLimit > 0,
    coco_action(Action).

%% A transfer of nothing is not a transfer, and it is refused HERE rather
%% than left to fail somewhere useful work has already been done -- the
%% same reason a zero-amount move is refused in every token in this
%% repository.
coco_action(transfer(To, Amount)) :- ground(To), u256_cmp(Amount, '0', '>').
coco_action(call(C, G)) :- ground(C), nonvar(G).

%% An account that has never sent anything is at nonce zero. The nonce is
%% what makes a signed transaction usable ONCE: it is part of the signed
%% text, so a replay carries the number it was signed with and no longer
%% matches.
coco_nonce(Who, N) :-
    ( coco_nonce_at(Who, M) -> N = M ; N = 0 ).

coco_bump_nonce(Who) :-
    coco_nonce(Who, N),
    N1 is N + 1,
    ( retract(coco_nonce_at(Who, _)) -> true ; true ),
    assertz(coco_nonce_at(Who, N1)).

%% ---- applying one ----------------------------------------------------
%%
%% `coco_apply(+Tx, +Sig, +Author, -Receipt)' -- Author is the account of
%% whoever sealed the block this transaction arrived in, and is who the
%% fee is paid to.
%%
%% IT ALWAYS ANSWERS, and the answer is a receipt:
%%
%%   receipt(From, ok,           Used, Fee)   it ran
%%   receipt(From, failed,       Used, Fee)   it ran and did not prove
%%   receipt(From, out_of_gas,   Used, Fee)   it ran into its ceiling
%%   receipt(From, refused(Why), 0,    '0')   it never ran, and cost nothing
%%
%% THE FIRST THREE PAY AND THE FOURTH DOES NOT, which is the line gas
%% exists to draw. A transaction that ran is charged for the inferences
%% it spent whether or not it proved anything -- searching for a proof
%% that is not there is precisely the work an attacker would like to have
%% for free. A transaction that was REFUSED never reached the engine: a
%% bad signature, a stale nonce, a sender who cannot cover the intrinsic
%% or the value it is trying to move. Nobody may be billed for a
%% transaction the node declined to run, and a node that seals one has
%% wasted its own block space, which is the incentive that keeps it from
%% doing it twice.
%%
%% A refusal is RECORDED rather than dropped -- the reason travels in the
%% receipt -- because a node that silently ignores a transaction is a
%% node nobody can ask why.
coco_apply(Tx, Sig, Author, Receipt) :-
    (   \+ coco_well_formed(Tx)
    ->  Receipt = receipt(unknown, refused(malformed), 0, '0')
    ;   \+ coco_tx_valid(Tx, Sig)
    ->  Receipt = receipt(unknown, refused(signature), 0, '0')
    ;   coco_tx_from(Tx, From),
        Tx = tx(_, Nonce, Action, GasLimit),
        (   \+ coco_nonce(From, Nonce)
        ->  Receipt = receipt(From, refused(nonce), 0, '0')
        ;   \+ coco_affordable_intrinsic(From)
        ->  Receipt = receipt(From, refused(gas), 0, '0')
        ;   \+ coco_funded(From, Action)
        ->  Receipt = receipt(From, refused(funds), 0, '0')
        ;   coco_run_action(From, Author, Action, GasLimit, Receipt)
        )
    ).

%% A sender must be able to pay the flat cost before anything is run,
%% because the flat cost is what running it costs the node.
coco_affordable_intrinsic(From) :-
    coco_intrinsic(Flat),
    coco_affordable(From, Steps),
    Steps > Flat.

%% ...and a transfer must be funded for its VALUE as well, which is a
%% separate question from the fee and asked before the fee is taken: a
%% transfer that could not have moved its amount is refused whole rather
%% than charged for discovering that.
coco_funded(From, transfer(_, Amount)) :-
    !,
    coco_balance(From, Bal),
    coco_intrinsic(Flat),
    coco_transfer_steps(Move),
    Total is Flat + Move,
    coco_fee(Total, Fee),
    u256_add(Amount, Fee, Needed),
    \+ u256_cmp(Needed, Bal, '>').
coco_funded(_, _).

%% THE NATIVE MOVE: constant-priced, and done OUTSIDE the meter so that a
%% ceiling can never sit between the debit and the credit.
coco_run_action(From, Author, transfer(To, Amount), _, receipt(From, ok, Used, Fee)) :-
    !,
    coco_intrinsic(Flat),
    coco_transfer_steps(Move),
    Used is Flat + Move,
    coco_fee(Used, Fee),
    %% ONE GOAL, so ONE TRANSACTION: the move, the fee and the nonce
    %% commit together or not at all. That is the store's property rather
    %% than care taken here, and it is why the debit can ride at the end
    %% -- a process that dies in the middle of this commits none of it.
    ( coco_transfer(From, To, Amount),
      coco_pay_fee(From, Author, Fee),
      coco_bump_nonce(From) ).

%% THE FENCED CALL: metered, and the count is the engine's own.
%%
%% The ceiling is the lower of what the sender asked for and what the
%% sender can pay for, so the bill is payable when it arrives and nothing
%% has to be taken up front and refunded. `call_metered/4' can overshoot
%% by the inference that noticed the budget was gone, so the charge is
%% capped at what was BOUGHT: nobody is billed for gas they were not
%% sold.
%%
%% The `catch/3' is INSIDE the meter deliberately -- that is what turns a
%% contract that throws into an outcome that pays, rather than an escape
%% that costs the node the work and the sender nothing.
coco_run_action(From, Author, call(C, G), GasLimit, receipt(From, Outcome, Used, Fee)) :-
    coco_intrinsic(Flat),
    coco_affordable(From, Steps),
    Ceiling is min(GasLimit, Steps - Flat),
    call_metered(catch(contract_call(C, G), _, fail), Ceiling, Spent, Result),
    contract_leave,                 % a ceiling can stop it mid-call
    Used is Flat + min(Spent, Ceiling),
    coco_fee(Used, Fee),
    coco_outcome_of(Result, Outcome),
    ( coco_pay_fee(From, Author, Fee),
      coco_bump_nonce(From) ).

coco_outcome_of(true, ok).
coco_outcome_of(failed, failed).
coco_outcome_of(inference_limit_exceeded, out_of_gas).

%% Paying yourself is the authority sealing its own transaction, and it
%% is a no-op rather than two writes against one balance -- the
%% self-transfer law again, in the one place where it is not hypothetical.
coco_pay_fee(From, Author, Fee) :-
    (   From == Author
    ->  true
    ;   coco_transfer(From, Author, Fee)
    ).
