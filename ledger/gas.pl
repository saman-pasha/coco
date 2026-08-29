%% The gas half of a ledger node: transactions ARE blocks, fees to the sealer.
%%
%% Consulted beside `ledger/node.pl' and `contracts/node.pl', into the
%% same knowledge base. There is no second system here either: a
%% transaction is a block payload, settling is what a node does when it
%% adopts one, and the fee is a transfer between two rows of the same
%% token the chain already carries.
%%
%%   coco_seal_genesis(+Allocations)   the supply, as a block
%%   coco_submit(+Tx, +Sig)            a signed transaction, as a block
%%   coco_settle_chain                 apply every unsettled block, in order
%%   coco_authority_account(?Name, ?Addr)
%%   coco_report / coco_receipts
%%
%% THE ORDER IS THE POINT, and it is `contracts/node.pl''s order for the
%% same reason. A node does not apply a transaction because somebody sent
%% it: it applies a transaction because the transaction arrived in a
%% block that is ON ITS CHAIN, and the block was validated by the
%% ledger's own rules before the payload was looked at. So a transaction
%% sealed by a non-authority never debits anybody -- it is refused one
%% layer down, as a block, and the gas layer never sees it. Two layers,
%% and they ask different questions: who may seal, and who may spend.
%%
%% THE CHAIN, NOT EVERY BLOCK THIS NODE HOLDS. `coco_settle_chain/0'
%% walks back from the head that fork choice chose, so a transaction on a
%% losing fork is not applied -- and if the fork closes the other way
%% later, the blocks that come with it are settled then. Which is also
%% why settlement is marked per block hash: a block settles once,
%% whatever order it arrived in.
%%
%% ONE TURN SETTLES EVERYTHING UNSETTLED, and that is right until the
%% chain is long. Every debit, receipt and mark commits together, which
%% is what makes settlement atomic -- but this repository's own
%% discipline says long compute never sits inside a database turn, and a
%% chain of ten thousand unsettled blocks is exactly that. The mark is
%% per BLOCK rather than per run, so settling in ranges is a change to
%% this predicate and nothing else; it is not written because nothing
%% here has a chain long enough to need it, and saying so is cheaper
%% than a mechanism nobody has measured.
%%
%% WHO IS PAID. The block's author is an authority NAME; the fee is paid
%% to the account at the address of the key that authority seals with, so
%% "who did the work" and "who holds the money" are the same key and
%% nobody has to keep a second roster. An author this node has no key
%% for -- a federation it has only half of -- is `unknown', which is a
%% real account like any other and holds what it was paid.

:- use_module(library(poa)).
:- use_module(library(coco)).

:- dynamic coco_settled/1.       % block hashes this node has applied
:- dynamic coco_receipt/2.       % coco_receipt(BlockHash, Receipt)

%% ---- sealing ---------------------------------------------------------
%%
%% Both of these are ordinary seals. The payload happens to be money, and
%% nothing in `library(poa)' knows or cares -- which is why neither
%% needed a new mechanism and both inherit the chain's guarantees for
%% free: signed by an authority, hash-chained, gossiped, and identical on
%% every node that adopts them.

coco_seal_genesis(Allocs) :-
    term_to_atom(coco_genesis(Allocs), Payload),
    ledger_seal(Payload).

coco_submit(Tx, Sig) :-
    term_to_atom(coco_send(Tx, Sig), Payload),
    ledger_seal(Payload).

%% ---- settling --------------------------------------------------------

coco_settle_chain :-
    ledger_head(head(_, Hash, _)),
    chain_from(Hash, Blocks),
    reverse(Blocks, Oldest),
    coco_settle_blocks(Oldest).

coco_settle_blocks([]).
coco_settle_blocks([block(Height, _, Author, Payload, _, Hash)|T]) :-
    %% THE HEIGHT IS THE CLOCK, so every block ticks it -- an unbonding
    %% matures against the chain's own growth and not against whether the
    %% block that matured it happened to carry money. Running this twice
    %% releases nothing twice: a released row is retracted.
    coco_mature(Height),
    (   coco_settled(Hash)
    ->  true
    ;   coco_payload(Payload, What)
    ->  coco_settle_one(What, Author, Height, Hash)
    ;   true                        % an ordinary payload: not ours
    ),
    coco_settle_blocks(T).

%% A PAYLOAD IS SOMEBODY ELSE'S TEXT until it parses, so the read is
%% caught: the chain carries prose, contract source and money side by
%% side, and a block whose payload is not a term at all must be walked
%% past rather than allowed to end the settlement of every block after
%% it.
coco_payload(Payload, T) :-
    catch(term_to_atom(T, Payload), _, fail),
    nonvar(T),
    ( T = coco_genesis(_) -> true ; T = coco_send(_, _) ).

coco_settle_one(coco_genesis(Allocs), _, _, Hash) :-
    !,
    (   coco_genesis(Allocs)
    ->  R = receipt(genesis, ok, 0, '0')
    ;   R = receipt(genesis, refused(twice), 0, '0')
    ),
    ( assertz(coco_receipt(Hash, R)),
      assertz(coco_settled(Hash)) ).
coco_settle_one(coco_send(Tx, Sig), Author, Height, Hash) :-
    (   coco_authority_account(Author, Acct)
    ->  true
    ;   Acct = unknown
    ),
    coco_apply(Tx, Sig, Acct, Height, R),
    %% ONE GOAL, so ONE TRANSACTION: the money moved by `coco_apply/4',
    %% the receipt and the mark that says this block is spent all commit
    %% together. A node that dies here settles nothing and will settle
    %% the same block cleanly next time.
    ( assertz(coco_receipt(Hash, R)),
      assertz(coco_settled(Hash)) ).

coco_authority_account(Name, Addr) :-
    authority(Name, Pub),
    eth_address(Pub, Addr).

%% ---- what happened to a unit, off the chain --------------------------
%%
%% `coco_unit_history(+Id, -Events)' -- every transaction that actually
%% MOVED this unit, oldest first, as `event(Height, Sender, Goal)'.
%%
%% There is no history table, and there must not be one: the chain
%% already carries every transaction, signed and hash-chained, and a
%% second copy kept beside it is the copy that goes stale. So provenance
%% is a QUERY -- walk the chain fork choice agreed on, read the payloads
%% back, and keep the ones about this id.
%%
%% AND ONLY THE ONES THAT TOOK EFFECT. The receipt says whether the
%% contract call succeeded, so a stranger's refused mint and a captured
%% unit's failed second capture are in the blocks but not in the history.
%% They were paid for -- gas is charged for work, not for outcomes -- and
%% they changed nothing, which is exactly the distinction a provenance
%% answer has to make.
coco_unit_history(Id, Events) :-
    ledger_head(head(_, Hash, _)),
    chain_from(Hash, Blocks),
    reverse(Blocks, Oldest),
    findall(event(H, From, Goal),
            ( member(block(H, _, _, Payload, _, BHash), Oldest),
              coco_receipt(BHash, receipt(From, ok, _, _)),
              %% parse into a FRESH variable and unify after: cocolog's
              %% term_to_atom/2 only READS into an unbound first argument
              %% -- hand it a bound one and it writes and compares, which
              %% would quietly match nothing here
              coco_payload(Payload, P),
              P = coco_send(tx(_, _, call(units, Goal), _), _),
              coco_unit_goal(Goal, Id) ),
            Events).

coco_unit_goal(unit_mint(Id, _, _, _), Id).
coco_unit_goal(unit_capture(Id, _), Id).
coco_unit_goal(unit_give(Id, _), Id).
coco_unit_goal(unit_kill(Id), Id).

%% ---- reporting, for the choreography ---------------------------------

coco_report :-
    coco_supply(Total),
    coco_holders(Hs),
    length(Hs, N),
    ( coco_conservation -> C = ok ; C = 'BROKEN' ),
    format("supply ~w holders ~w conservation ~w~n", [Total, N, C]).

coco_receipts :-
    forall(coco_receipt(_, R), ( term_to_atom(R, A), format("~w~n", [A]) )).
