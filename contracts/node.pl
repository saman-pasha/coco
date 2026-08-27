%% A contract node: deploy, install from the chain, call under gas.
%%
%% Consulted beside ledger/node.pl, into the same knowledge base. A
%% contract node IS a ledger node -- there is no second system. A
%% deployment is a block, an installation is what a node does when it
%% adopts one, and a call is an ordinary goal that happens to be fenced.
%%
%%   deploy(+Name)          seal the contract into a block
%%   install_from_chain     admit and install every contract on the chain
%%   deployed_report        what this node installed, and what it refused
%%
%% THE ORDER MATTERS AND IS THE POINT. A node does not install a contract
%% because someone sent it: it installs a contract because the contract
%% arrived in a block that is on its chain, and the block was validated
%% by the ledger's own rules before the contract was looked at. So a
%% contract deployed by a non-authority is never admitted, never fenced,
%% never even parsed -- it is refused one layer down, as a block, and the
%% contract layer never sees it.

:- use_module(library(poa)).
:- use_module(library(contract)).

:- dynamic contract_refused/2.

%% ---- deploying -------------------------------------------------------
%%
%% An ordinary seal. The payload happens to be a contract, and nothing in
%% the ledger knows or cares -- which is why deployment needed no new
%% mechanism and gets the chain's guarantees for free: signed by an
%% authority, hash-chained, gossiped, and identical on every node.
deploy(Name) :-
    ( contract_source(Name, Clauses) -> true ; attack_source(Name, Clauses, _) ),
    contract_deploy_payload(Name, Clauses, Payload),
    ledger_seal(Payload).

%% ---- installing from the chain ---------------------------------------
%%
%% Walk the chain this node has agreed on -- not every block it holds,
%% THE CHAIN, so a contract on a losing fork is not installed -- and for
%% each payload that parses as a contract, admit it and install it if it
%% passes. A refusal is recorded rather than thrown away: a node that
%% silently ignores a contract it could not admit is a node nobody can
%% ask why.
install_from_chain :-
    ledger_head(head(_, Hash, _)),
    chain_from(Hash, Blocks),
    reverse(Blocks, Oldest),
    install_blocks(Oldest).

install_blocks([]).
install_blocks([block(_, _, _, Payload, _, _)|T]) :-
    (   contract_of_payload(Payload, Name, Clauses)
    ->  (   already_installed(Name)
        ->  true
        ;   contract_admit(Name, Clauses, admitted)
        ->  contract_install(Name, Clauses)
        ;   assertz(contract_refused(Name, fence))
        )
    ;   true                       % an ordinary payload, not a contract
    ),
    install_blocks(T).

already_installed(Name) :- contract_clause(Name, _), !.

%% ---- reporting -------------------------------------------------------

deployed_report :-
    findall(N, distinct_contract(N), Installed),
    findall(R, contract_refused(R, _), Refused),
    format("installed ~w refused ~w~n", [Installed, Refused]).

distinct_contract(N) :-
    findall(X, contract_clause(X, _), Xs),
    sort(Xs, Sorted),
    member(N, Sorted).

%% What a contract's code is, on this node, for an auditor. The clauses
%% came out of a block, so this is answerable from the chain alone -- an
%% audit of the CODE and not only of the data.
contract_listing(Name) :-
    forall(contract_clause(Name, C),
           ( term_to_atom(C, A), format("~w~n", [A]) )).
